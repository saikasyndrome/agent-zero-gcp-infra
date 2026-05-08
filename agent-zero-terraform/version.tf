terraform {
  required_version = "~> 1.9"
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "google" {
  project = local.gc_project_id
  region  = local.default_region
}
provider "google-beta" {
  project = local.gc_project_id
  region  = local.default_region
}

locals {
  gc_project_id     = "YOUR_PROJECT_ID"     # TODO: replace with your GCP project ID
  gc_project_number = data.google_project.project.number
  default_region    = "YOUR_REGION"         # TODO: replace with your GCP region
  default_zone      = "YOUR_ZONE"           # TODO: replace with your GCP zone
}

data "google_project" "project" {
  project_id = local.gc_project_id
}
