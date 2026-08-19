terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = "us-central1"
  access_token = var.gcp_token
}

resource "google_storage_bucket" "drift_check_resource" {
  name          = "${var.gcp_project_id}-drift-check-resource"
  location      = "US-CENTRAL1"
  force_destroy = true
  storage_class = "STANDARD"
  labels = {
    env = "lab"
    managed_by = "terraform"
    drift_test = "original"
  }
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = true
}