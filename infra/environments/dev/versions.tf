# ==============================================================
# Dev Environment — Provider & Backend Configuration
# ==============================================================

terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  backend "gcs" {
    bucket = "jerney-tfstate" # from infra/bootstrap output
    prefix = "jerney-gke/dev/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
