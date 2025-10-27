

# ==========================================
# FILE: terraform/azure/variables.tf
# ==========================================
variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "app_name" {
  description = "Name of the CDC application"
  type        = string
  default     = "cdc-pipeline"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique)"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, 3-24 chars, lowercase)"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# PostgreSQL Configuration
variable "pg_host" {
  description = "PostgreSQL hostname"
  type        = string
}

variable "pg_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

variable "pg_database" {
  description = "PostgreSQL database name"
  type        = string
}

variable "pg_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "pg_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "pg_publication" {
  description = "PostgreSQL publication name"
  type        = string
  default     = "cdc_pub"
}

variable "pg_slot" {
  description = "PostgreSQL replication slot name"
  type        = string
  default     = "cdc_slot"
}

variable "table_include" {
  description = "Comma-separated list of tables to include (schema.table format)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "CDC-Pipeline"
  }
}