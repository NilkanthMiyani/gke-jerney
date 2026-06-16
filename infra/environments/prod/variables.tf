# ==============================================================
# Prod Environment — Input Variables
# ==============================================================

# ---- GCP Context ----
variable "project_id" {
  description = "GCP project ID"
  type        = string
  nullable    = false

  validation {
    condition     = length(var.project_id) > 0 && var.project_id != "YOUR_GCP_PROJECT_ID"
    error_message = "project_id must be set to your real GCP project ID in terraform.tfvars."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
  nullable    = false
}

variable "zone" {
  description = "Single GCP zone"
  type        = string
  default     = "us-central1-a"
  nullable    = false
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "prod"
  nullable    = false
}

# ---- Cluster ----
variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "jerney-gke-prod"
  nullable    = false
}

variable "node_machine_type" {
  description = "GCE machine type for nodes"
  type        = string
  default     = "e2-standard-2"
  nullable    = false
}

variable "min_node_count" {
  description = "Minimum nodes in the pool"
  type        = number
  default     = 2
  nullable    = false
}

variable "max_node_count" {
  description = "Maximum nodes in the pool"
  type        = number
  default     = 5
  nullable    = false
}

variable "disk_size_gb" {
  description = "Node boot disk size in GB"
  type        = number
  default     = 50
  nullable    = false
}

variable "use_spot" {
  description = "Use Spot VMs — false for prod (on-demand for stability)"
  type        = bool
  default     = false
  nullable    = false
}

variable "deletion_protection" {
  description = "Block terraform destroy of the cluster — true for prod"
  type        = bool
  default     = true
  nullable    = false
}

# ---- Networking ----
variable "subnet_cidr" {
  description = "Primary CIDR for the node subnet"
  type        = string
  default     = "10.0.0.0/24"
  nullable    = false
}

variable "pods_cidr" {
  description = "Secondary CIDR for pod IPs"
  type        = string
  default     = "10.100.0.0/14"
  nullable    = false
}

variable "services_cidr" {
  description = "Secondary CIDR for service IPs"
  type        = string
  default     = "10.104.0.0/20"
  nullable    = false
}

# ---- GitOps ----
variable "gitops_repo_url" {
  description = "Git repo URL for ArgoCD"
  type        = string
  default     = "https://github.com/NilkanthMiyani/gke-jerney.git"
  nullable    = false
}

variable "gitops_target_revision" {
  description = "Git branch/tag for ArgoCD"
  type        = string
  default     = "main"
  nullable    = false
}

variable "gitops_apps_path" {
  description = "Path to ArgoCD app manifests in the repo"
  type        = string
  default     = "k8s-gke/apps"
  nullable    = false
}

# ---- Secrets (seeded into GCP Secret Manager) ----
variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "alertmanager_smtp_key" {
  description = "Resend SMTP API key for Alertmanager"
  type        = string
  sensitive   = true
  nullable    = false
}
