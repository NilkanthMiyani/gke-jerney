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
  description = "Namespace to install ESO into"
  type        = string
  default     = "external-secrets"
  nullable    = false
}

variable "eso_service_account_email" {
  description = "GCP service account email for the ESO Workload Identity annotation"
  type        = string
  nullable    = false
}

variable "project_id" {
  description = "GCP project ID — used by the gcpsm ClusterSecretStore"
  type        = string
  nullable    = false
}

variable "secret_store_name" {
  description = "Name of the ClusterSecretStore (referenced by ExternalSecrets in GitOps)"
  type        = string
  default     = "gcp-secret-manager"
  nullable    = false
}

variable "gitops_repo_url" {
  description = "Git repository URL for the ArgoCD App-of-Apps"
  type        = string
  nullable    = false
}

variable "gitops_target_revision" {
  description = "Git branch/tag for ArgoCD to track"
  type        = string
  default     = "main"
  nullable    = false
}

variable "gitops_apps_path" {
  description = "Path within the repo to the ArgoCD Application manifests"
  type        = string
  nullable    = false
}
