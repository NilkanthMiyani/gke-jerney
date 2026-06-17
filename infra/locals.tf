locals {
  # Map of secrets to seed into GCP Secret Manager
  secrets = {
    "jerney-postgres-password"      = var.postgres_password
    "jerney-grafana-admin-password" = var.grafana_admin_password
    "jerney-alertmanager-smtp-key"  = var.alertmanager_smtp_key
  }
}
