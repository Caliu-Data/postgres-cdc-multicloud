# ==========================================
# FILE: terraform/gcp/outputs.tf
# ==========================================
output "cloud_run_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.cdc.uri
}

output "gcs_bucket_name" {
  description = "Name of the GCS bucket"
  value       = google_storage_bucket.landing.name
}

output "gcs_bucket_url" {
  description = "URL of the GCS bucket"
  value       = "gs://${google_storage_bucket.landing.name}"
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.cdc.repository_id}"
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.cdc_app.email
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

