# ==============================================================
# Module: gke-cluster
# GKE Standard cluster + a separately-managed node pool.
# Expects networking + the node service account to be created externally.
# ==============================================================

resource "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.zone # single zone → ~3x cheaper than regional (3 control planes)

  # Master version — null lets GKE pick its default for the channel.
  # Node pools follow the master version unless pinned separately.
  min_master_version = var.kubernetes_version

  # Best practice: create an empty cluster and manage the node pool separately,
  # so the pool can be replaced without recreating the cluster.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.this.id
  subnetwork = google_compute_subnetwork.nodes.id

  # VPC-native cluster — pods get real VPC IPs, enables NetworkPolicy.
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Workload Identity — lets k8s ServiceAccounts impersonate GCP service accounts.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      # nginx-only cluster — disable GCE L7 ingress so a classless Ingress
      # can't spin up a billable GCP LB.
      disabled = var.http_load_balancing_disabled
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  deletion_protection = var.deletion_protection
}

resource "google_container_node_pool" "this" {
  name     = "${var.cluster_name}-nodes"
  location = var.zone
  cluster  = google_container_cluster.this.name

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    spot         = var.use_spot

    service_account = google_service_account.nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA" # required for Workload Identity on nodes
    }

    tags   = [var.node_network_tag] # matches firewall rule target
    labels = var.node_labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
