output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster API endpoint"
  value       = module.gke_cluster.endpoint
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
  value       = module.networking.network_name
}

output "node_service_account" {
  description = "Service account email attached to GKE nodes"
  value       = module.iam.node_service_account_email
}

output "eso_service_account" {
  description = "ESO service account email (Workload Identity)"
  value       = module.iam.eso_service_account_email
}

output "kubectl_config_command" {
  description = "Run this after apply to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.gke_cluster.cluster_name} --zone ${var.zone} --project ${var.project_id}"
}
