# ==============================================================
# Module: networking
# Custom VPC + VPC-native subnet (secondary ranges for pods/services)
# + firewall rules for web traffic and GCP LB health checks.
# ==============================================================

resource "google_compute_network" "this" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# VPC-native subnet — secondary ranges give pods/services real VPC IPs
# (better performance + NetworkPolicy support).
resource "google_compute_subnetwork" "nodes" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.this.id

  secondary_ip_range {
    range_name    = var.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.services_range_name
    ip_cidr_range = var.services_cidr
  }
}

# ---- Firewall: allow HTTP/HTTPS from the internet ----
resource "google_compute_firewall" "allow_web" {
  name    = "${var.cluster_name}-allow-web"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.node_network_tag]
}

# ---- Firewall: allow GCP Load Balancer health checks ----
# The L4 network LB fronting the nginx ingress controller probes nodes from these
# GCP-owned ranges. Without this rule health checks fail → backends marked unhealthy.
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.cluster_name}-allow-health-checks"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "10256"]
  }

  # GCP Load Balancer and health check prober source ranges (documented by Google)
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = [var.node_network_tag]
}

# ---- Private Egress: Cloud Router + Cloud NAT ----
# Allows private GKE nodes to pull images and reach the internet.
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
