output "secret_ids" {
  description = "IDs of the created Secret Manager secrets"
  value       = [for s in google_secret_manager_secret.this : s.secret_id]
}
