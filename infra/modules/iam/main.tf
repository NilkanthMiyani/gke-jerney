# ==============================================================
# Module: iam
# Service accounts + IAM for the cluster:
#   - GKE node service account (least privilege)
#   - External Secrets Operator service account + Workload Identity
#     binding to the in-cluster ServiceAccount external-secrets/external-secrets
# ==============================================================

# ---- GKE node service account ----
resource "google_service_account" "nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "Jerney GKE Node SA (${var.cluster_name})"
}

resource "google_project_iam_member" "node_roles" {
  for_each = toset(var.node_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# ---- External Secrets Operator service account ----
resource "google_service_account" "eso" {
  account_id   = "${var.cluster_name}-eso"
  display_name = "External Secrets Operator (${var.cluster_name})"
}

resource "google_project_iam_member" "eso_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso.email}"
}

# Workload Identity: lets the k8s SA impersonate the ESO GCP SA without static keys.
resource "google_service_account_iam_member" "eso_workload_identity" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.eso_namespace}/${var.eso_k8s_service_account}]"
}
