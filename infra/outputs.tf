output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "GKE cluster API endpoint"
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "zone" {
  description = "GCP zone"
  value       = var.zone
}

output "vpc_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "node_service_account" {
  description = "Service account email attached to GKE nodes"
  value       = google_service_account.nodes.email
}

output "eso_service_account" {
  description = "ESO service account email (Workload Identity)"
  value       = google_service_account.eso.email
}

output "kubectl_config_command" {
  description = "Run this after apply to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --zone ${var.zone} --project ${var.project_id}"
}
