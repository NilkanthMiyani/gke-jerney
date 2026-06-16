# ==============================================================
# Environment composition: DEV
#
# Wires the resource modules into a single cluster with its own
# state file. Environment-specific values come from variables
# (see variables.tf defaults and terraform.tfvars), so this file is
# identical across dev/staging/prod.
#
# Dependency graph:
#   networking ──┐
#   iam ─────────┤
#                ├── gke_cluster ── argocd_bootstrap
#   secret_manager ──────────────/
# ==============================================================

data "google_client_config" "default" {}

locals {
  common_labels = {
    env        = var.environment
    project    = "jerney"
    managed_by = "terraform"
  }
  node_network_tag = "gke-${var.cluster_name}"
}

# ---- Enable required GCP APIs ----
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# ---- 1. Networking ----
module "networking" {
  source = "../../modules/networking"

  cluster_name     = var.cluster_name
  region           = var.region
  subnet_cidr      = var.subnet_cidr
  pods_cidr        = var.pods_cidr
  services_cidr    = var.services_cidr
  node_network_tag = local.node_network_tag

  depends_on = [google_project_service.compute]
}

# ---- 2. IAM (node SA + ESO SA + Workload Identity) ----
module "iam" {
  source = "../../modules/iam"

  cluster_name = var.cluster_name
  project_id   = var.project_id
}

# ---- 3. Secret Manager (values seeded from tfvars) ----
module "secret_manager" {
  source = "../../modules/secret-manager"

  secrets = {
    "jerney-postgres-password"      = var.postgres_password
    "jerney-grafana-admin-password" = var.grafana_admin_password
    "jerney-alertmanager-smtp-key"  = var.alertmanager_smtp_key
  }

  depends_on = [google_project_service.secretmanager]
}

# ---- 4. GKE Cluster ----
module "gke_cluster" {
  source = "../../modules/gke-cluster"

  cluster_name = var.cluster_name
  zone         = var.zone
  project_id   = var.project_id

  network_id          = module.networking.network_id
  subnet_id           = module.networking.subnet_id
  pods_range_name     = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name
  node_network_tag    = local.node_network_tag

  kubernetes_version         = var.kubernetes_version
  node_machine_type          = var.node_machine_type
  min_node_count             = var.min_node_count
  max_node_count             = var.max_node_count
  disk_size_gb               = var.disk_size_gb
  use_spot                   = var.use_spot
  node_service_account_email = module.iam.node_service_account_email
  node_labels                = local.common_labels

  http_load_balancing_disabled = true
  deletion_protection          = var.deletion_protection

  depends_on = [google_project_service.container, module.iam]
}

# ---- 5. ArgoCD Bootstrap ----
# Point the helm + kubectl providers at the new GKE cluster.
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke_cluster.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = "https://${module.gke_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke_cluster.cluster_ca_certificate)
  load_config_file       = false
}

module "argocd_bootstrap" {
  source = "../../modules/argocd-bootstrap"

  eso_service_account_email = module.iam.eso_service_account_email
  project_id                = var.project_id

  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = var.gitops_target_revision
  gitops_apps_path       = var.gitops_apps_path

  depends_on = [module.gke_cluster, module.secret_manager]
}
