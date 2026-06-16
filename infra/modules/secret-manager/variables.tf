variable "secrets" {
  description = "Map of secret_id => secret value to seed into GCP Secret Manager"
  type        = map(string)
  sensitive   = true
  nullable    = false
}
