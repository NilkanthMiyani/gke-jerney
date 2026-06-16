variable "cluster_name" {
  description = "Cluster name used as prefix for network resources"
  type        = string
  nullable    = false
}

variable "region" {
  description = "GCP region for the subnet"
  type        = string
  nullable    = false
}

variable "subnet_cidr" {
  description = "Primary CIDR for the node subnet"
  type        = string
  default     = "10.0.0.0/24"
  nullable    = false
}

variable "pods_range_name" {
  description = "Name of the secondary range for pod IPs"
  type        = string
  default     = "pods"
  nullable    = false
}

variable "pods_cidr" {
  description = "Secondary CIDR for pod IPs (VPC-native)"
  type        = string
  default     = "10.100.0.0/14"
  nullable    = false
}

variable "services_range_name" {
  description = "Name of the secondary range for service IPs"
  type        = string
  default     = "services"
  nullable    = false
}

variable "services_cidr" {
  description = "Secondary CIDR for ClusterIP service IPs"
  type        = string
  default     = "10.104.0.0/20"
  nullable    = false
}

variable "node_network_tag" {
  description = "Network tag applied to nodes — firewall rules target this tag"
  type        = string
  nullable    = false
}
