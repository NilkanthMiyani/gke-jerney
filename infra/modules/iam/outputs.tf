output "node_service_account_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.nodes.email
}

output "eso_service_account_email" {
  description = "Email of the ESO service account — used for the Workload Identity annotation on the in-cluster SA"
  value       = google_service_account.eso.email
}
