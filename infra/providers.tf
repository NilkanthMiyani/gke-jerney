provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# The cluster credentials might not be available during the first terraform plan,
# but we configure them here anyway. Best practice is to use a separate apply phase
# or retrieve the cluster token dynamically.

data "google_client_config" "default" {}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.this.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.this.master_auth[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.this.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}
