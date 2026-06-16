variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  nullable    = false
}

variable "zone" {
  description = "Single GCP zone for the cluster + node pool"
  type        = string
  nullable    = false
}

variable "project_id" {
  description = "GCP project ID (for the Workload Identity pool)"
  type        = string
  nullable    = false
}

variable "kubernetes_version" {
  description = "GKE master version — accepts a partial version like \"1.31\" (latest patch). null = GKE default."
  type        = string
  default     = null
}

# ---- Networking (from the networking module) ----
variable "network_id" {
  description = "VPC network ID"
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "Node subnet ID"
  type        = string
  nullable    = false
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
  nullable    = false
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
  nullable    = false
}

variable "node_network_tag" {
  description = "Network tag applied to nodes — must match the firewall rules"
  type        = string
  nullable    = false
}

# ---- Node pool ----
variable "node_machine_type" {
  description = "GCE machine type for nodes"
  type        = string
  default     = "e2-medium"
  nullable    = false
}

variable "min_node_count" {
  description = "Minimum nodes in the pool"
  type        = number
  default     = 1
  nullable    = false
}

variable "max_node_count" {
  description = "Maximum nodes in the pool"
  type        = number
  default     = 3
  nullable    = false
}

variable "disk_size_gb" {
  description = "Node boot disk size in GB"
  type        = number
  default     = 30
  nullable    = false
}

variable "disk_type" {
  description = "Node boot disk type — pd-standard (cheapest) or pd-ssd"
  type        = string
  default     = "pd-standard"
  nullable    = false
}

variable "use_spot" {
  description = "Use Spot VMs (~70% cheaper; reclaimable). Set false for staging/prod."
  type        = bool
  default     = true
  nullable    = false
}

variable "node_service_account_email" {
  description = "Email of the node service account (from the iam module)"
  type        = string
  nullable    = false
}

variable "node_labels" {
  description = "Labels applied to all nodes"
  type        = map(string)
  default     = {}
}

# ---- Cluster options ----
variable "http_load_balancing_disabled" {
  description = "Disable the GKE GCE L7 ingress add-on (nginx-only cluster)"
  type        = bool
  default     = true
  nullable    = false
}

variable "deletion_protection" {
  description = "Block terraform destroy of the cluster (set true for prod)"
  type        = bool
  default     = false
  nullable    = false
}
