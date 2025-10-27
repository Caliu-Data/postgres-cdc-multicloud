
# ==========================================
# FILE: terraform/gcp/variables.tf
# ==========================================
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Name of the CDC application"
  type        = string
  default     = "cdc-pipeline"
}

variable "gcs_bucket_name" {
  description = "Name of the GCS bucket for CDC landing zone (must be globally unique)"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "data_retention_days" {
  description = "Number of days to retain data in GCS"
  type        = number
  default     = 90
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
  description = "Comma-separated list of tables to include"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    environment = "production"
    project     = "cdc-pipeline"
  }
}
