provider "google" {
  project = "dc-cloud-451321"
  region  = "us-central1"
}

# Create VPC Network
resource "google_compute_network" "vpc_network" {
  name = "assign2-vpc"
}

# Create Public Subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "mihir-public-subnet"
  network       = google_compute_network.vpc_network.self_link
  region        = "us-central1"
  ip_cidr_range = "10.0.1.0/24"
}

# Create Private Subnet
resource "google_compute_subnetwork" "private_subnet" {
  name                     = "mihir-private-subnet"
  network                  = google_compute_network.vpc_network.self_link
  region                   = "us-central1"
  ip_cidr_range            = "10.0.2.0/24"
  private_ip_google_access = true
}

# Create Firewall Rule for HTTP access on port 5000
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.self_link
  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }
  source_ranges = ["0.0.0.0/0"]
}

# Create Compute Engine Instance for Flask App
resource "google_compute_instance" "flask_instance" {
  name         = "mihir-app-instance"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.public_subnet.self_link
    access_config {}
  }

  metadata = {
    google-logging-enabled = "true"
  }

  metadata_startup_script = <<-EOT
  #! /bin/bash
  docker run -d -p 5000:5000 gcr.io/dc-cloud-451321/inft1210assign2-flask/inft1210assign2-flask:latest
  EOT
}

# Create Cloud Storage Bucket for Cloud Build Logs
resource "google_storage_bucket" "cloudbuild_logs" {
  name          = "cloudbuild-logs-dc-cloud-451321"
  location      = "US"
  force_destroy = true
}

# Assign Storage Admin Role to Cloud Build
resource "google_project_iam_binding" "cloudbuild_storage_access" {
  project = "dc-cloud-451321"
  role    = "roles/storage.admin"

  members = [
    "serviceAccount:467886545001-compute@developer.gserviceaccount.com"
  ]
}

# Create Cloud Build Trigger for Continuous Deployment
resource "google_cloudbuild_trigger" "flask_build_trigger" {
  name        = "flask-app-trigger"
  location    = "global"

  github {
    owner = "StunnerMnM7"
    name  = "inft1210"
    push {
      branch = "main"
    }
  }

  build {
    logs_bucket = google_storage_bucket.cloudbuild_logs.url

    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "-t", "gcr.io/dc-cloud-451321/inft1210assign2-flask/inft1210assign2-flask:latest", "."]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", "gcr.io/dc-cloud-451321/inft1210assign2-flask/inft1210assign2-flask:latest"]
    }
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "compute", "ssh", "flask-app-instance",
        "--zone=us-central1-a",
        "--command=docker stop $(docker ps -q) && docker run -d -p 5000:5000 gcr.io/dc-cloud-451321/inft1210assign2-flask/inft1210assign2-flask:latest"
      ]
    }
  }
}
