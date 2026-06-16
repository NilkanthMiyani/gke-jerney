output "network_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "ID of the node subnet"
  value       = google_compute_subnetwork.nodes.id
}

output "subnet_name" {
  description = "Name of the node subnet"
  value       = google_compute_subnetwork.nodes.name
}

output "pods_range_name" {
  description = "Secondary range name for pods (used by ip_allocation_policy)"
  value       = google_compute_subnetwork.nodes.secondary_ip_range[0].range_name
}

output "services_range_name" {
  description = "Secondary range name for services (used by ip_allocation_policy)"
  value       = google_compute_subnetwork.nodes.secondary_ip_range[1].range_name
}
