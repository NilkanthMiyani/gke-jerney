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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }

  backend "gcs" {
    # Terraform Workspaces will automatically prepend `env/<workspace_name>/` to this prefix if used.
    bucket = "jerney-tfstate"
    prefix = "jerney-gke/state"
  }
}
