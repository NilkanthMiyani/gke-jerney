# ==============================================================
# Module: secret-manager
#
# GCP Secret Manager secrets created from a single map, so the set of
# secrets is data rather than duplicated resource blocks. ESO reads
# these at runtime via the ClusterSecretStore.
# ==============================================================

# for_each cannot take a sensitive value, so iterate over the secret
# names (not the values) and look up each sensitive value by key.
resource "google_secret_manager_secret" "this" {
  for_each = nonsensitive(toset(keys(local.secrets)))

  secret_id = each.value

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "this" {
  for_each = google_secret_manager_secret.this

  secret      = each.value.id
  secret_data = local.secrets[each.key]
}
