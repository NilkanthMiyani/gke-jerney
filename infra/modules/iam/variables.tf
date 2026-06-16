variable "cluster_name" {
  description = "Cluster name used as prefix for service account IDs"
  type        = string
  nullable    = false

  validation {
    # account_id is "<cluster_name>-nodes"/"-eso" and must be ≤30 chars total
    condition     = length(var.cluster_name) <= 24
    error_message = "cluster_name must be ≤24 chars so the derived service account IDs stay within the 30-char limit."
  }
}

variable "project_id" {
  description = "GCP project ID (for IAM bindings and the Workload Identity pool)"
  type        = string
  nullable    = false
}

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
