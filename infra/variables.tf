# ==============================================================
# Input Variables
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
  description = "Single GCP zone — single-zone cluster is ~3x cheaper than regional"
  type        = string
  default     = "us-central1-a"
  nullable    = false
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
  nullable    = false
}

# ---- Cluster ----
variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "jerney-gke-dev"
  nullable    = false
}

variable "kubernetes_version" {
  description = "GKE Kubernetes version (partial like \"1.31\" = latest patch; null = GKE default)"
  type        = string
  default     = null
}

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
  description = "Use Spot VMs (cheap, reclaimable) — true for dev"
  type        = bool
  default     = true
  nullable    = false
}

variable "deletion_protection" {
  description = "Block terraform destroy of the cluster"
  type        = bool
  default     = false
  nullable    = false
}

variable "http_load_balancing_disabled" {
  description = "Disable the GKE GCE L7 ingress add-on (nginx-only cluster)"
  type        = bool
  default     = true
  nullable    = false
}

variable "node_labels" {
  description = "Labels applied to all nodes"
  type        = map(string)
  default     = {}
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

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
  default     = "pods"
  nullable    = false
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
  default     = "services"
  nullable    = false
}

variable "node_network_tag" {
  description = "Network tag applied to nodes — must match the firewall rules"
  type        = string
  default     = "gke-node"
  nullable    = false
}

# ---- IAM ----
variable "node_sa_roles" {
  description = "IAM roles granted to the GKE node service account"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ]
  nullable = false
}

# ---- GitOps & Bootstrapping ----
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

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.5.20"
  nullable    = false
}

variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.10.7"
  nullable    = false
}

variable "eso_namespace" {
  description = "Kubernetes namespace where ESO runs"
  type        = string
  default     = "external-secrets"
  nullable    = false
}

variable "eso_k8s_service_account" {
  description = "Kubernetes ServiceAccount name ESO uses (target of the Workload Identity binding)"
  type        = string
  default     = "external-secrets"
  nullable    = false
}

variable "secret_store_name" {
  description = "Name of the ClusterSecretStore (referenced by ExternalSecrets in GitOps)"
  type        = string
  default     = "gcp-secret-manager"
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
