# ==========================================
# FILE: terraform/gcp/main.tf
# ==========================================
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "storage-api.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com"
  ])
  
  project = var.project_id
  service = each.key
  
  disable_on_destroy = false
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "cdc" {
  location      = var.region
  repository_id = var.app_name
  format        = "DOCKER"
  description   = "CDC Pipeline Docker images"
  
  depends_on = [google_project_service.required_apis]
}

# GCS Bucket for CDC landing zone
resource "google_storage_bucket" "landing" {
  name          = var.gcs_bucket_name
  location      = var.region
  force_destroy = false
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = var.data_retention_days
    }
    action {
      type = "Delete"
    }
  }
  
  depends_on = [google_project_service.required_apis]
}

# Service Account for Cloud Run
resource "google_service_account" "cdc_app" {
  account_id   = "${var.app_name}-sa"
  display_name = "CDC Pipeline Service Account"
  description  = "Service account for CDC Cloud Run service"
}

# Grant Storage Object Admin to Service Account
resource "google_storage_bucket_iam_member" "cdc_app_storage" {
  bucket = google_storage_bucket.landing.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cdc_app.email}"
}

# Secret Manager for PostgreSQL password
resource "google_secret_manager_secret" "pg_password" {
  secret_id = "${var.app_name}-pg-password"
  
  replication {
    auto {}
  }
  
  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "pg_password" {
  secret      = google_secret_manager_secret.pg_password.id
  secret_data = var.pg_password
}

# Grant Secret Manager access to Service Account
resource "google_secret_manager_secret_iam_member" "cdc_app_secret" {
  secret_id = google_secret_manager_secret.pg_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cdc_app.email}"
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "cdc" {
  name     = var.app_name
  location = var.region
  
  template {
    service_account = google_service_account.cdc_app.email
    
    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.cdc.repository_id}/cdc-pipeline:${var.image_tag}"
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
      
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
        name = "PG_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.pg_password.secret_id
            version = "latest"
          }
        }
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
        value = "gcp"
      }
      
      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.landing.name
      }
      
      env {
        name  = "GOOGLE_PROJECT_ID"
        value = var.project_id
      }
      
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }
      
      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 30
        timeout_seconds       = 3
        period_seconds        = 30
        failure_threshold     = 3
      }
    }
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_secret_manager_secret_version.pg_password
  ]
}

# Allow unauthenticated access (for health checks)
# In production, you might want to restrict this
resource "google_cloud_run_service_iam_member" "noauth" {
  location = google_cloud_run_v2_service.cdc.location
  service  = google_cloud_run_v2_service.cdc.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

