output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "GKE cluster API endpoint (no scheme)"
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_pool_name" {
  description = "Name of the managed node pool"
  value       = google_container_node_pool.this.name
}
