# ==========================================
# FILE: terraform/azure/main.tf
# ==========================================
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# Storage Account for CDC landing zone
resource "azurerm_storage_account" "landing" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true # Enable hierarchical namespace for ADLS Gen2
  tags                     = var.tags
}

# Storage Container
resource "azurerm_storage_container" "landing" {
  name                  = "landing"
  storage_account_name  = azurerm_storage_account.landing.name
  container_access_type = "private"
}

# User Assigned Managed Identity for Container App
resource "azurerm_user_assigned_identity" "cdc_app" {
  name                = "${var.app_name}-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# Grant Storage Blob Data Contributor to Managed Identity
resource "azurerm_role_assignment" "storage_contributor" {
  scope                = azurerm_storage_account.landing.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.cdc_app.principal_id
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.app_name}-env"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = var.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.app_name}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Container App
resource "azurerm_container_app" "cdc" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cdc_app.id]
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "cdc-pipeline"
      image  = "${azurerm_container_registry.acr.login_server}/cdc-pipeline:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "PG_HOST"
        value = var.pg_host
      }

      env {
        name  = "PG_PORT"
        value = var.pg_port
      }

      env {
        name  = "PG_DB"
        value = var.pg_database
      }

      env {
        name  = "PG_USER"
        value = var.pg_user
      }

      env {
        name        = "PG_PASSWORD"
        secret_name = "pg-password"
      }

      env {
        name  = "PG_PUBLICATION"
        value = var.pg_publication
      }

      env {
        name  = "PG_SLOT"
        value = var.pg_slot
      }

      env {
        name  = "TABLE_INCLUDE"
        value = var.table_include
      }

      env {
        name  = "CLOUD_PROVIDER"
        value = "azure"
      }

      env {
        name  = "AZURE_STORAGE_ACCOUNT_URL"
        value = azurerm_storage_account.landing.primary_blob_endpoint
      }

      env {
        name  = "AZURE_STORAGE_CONTAINER"
        value = azurerm_storage_container.landing.name
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.cdc_app.client_id
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }
    }
  }

  secret {
    name  = "pg-password"
    value = var.pg_password
  }

  ingress {
    external_enabled = false
    target_port      = 8080
  }
}
