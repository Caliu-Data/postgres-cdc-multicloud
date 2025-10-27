

# ==========================================
# FILE: terraform/azure/outputs.tf
# ==========================================
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "container_app_name" {
  description = "Name of the Container App"
  value       = azurerm_container_app.cdc.name
}

output "container_app_url" {
  description = "URL of the Container App"
  value       = "https://${azurerm_container_app.cdc.latest_revision_fqdn}"
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.landing.name
}

output "storage_account_url" {
  description = "URL of the storage account"
  value       = azurerm_storage_account.landing.primary_blob_endpoint
}

output "acr_login_server" {
  description = "ACR login server"
  value       = azurerm_container_registry.acr.login_server
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity"
  value       = azurerm_user_assigned_identity.cdc_app.client_id
}


