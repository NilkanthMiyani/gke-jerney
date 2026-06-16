output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}

output "eso_namespace" {
  description = "Namespace where External Secrets Operator is installed"
  value       = helm_release.external_secrets.namespace
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore created for ESO"
  value       = var.secret_store_name
}
