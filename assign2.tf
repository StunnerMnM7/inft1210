provider "google" {
  project = "dc-cloud-451321"
  region  = "us-central1"
}

resource "google_compute_network" "vpc_network" {
  name = "mihir-assign2-vpc" 
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "mihir-public-subnet"  
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "mihir-private-subnet"  
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_instance" "flask_instance" {
  name         = "mihir-app-instance"  
  machine_type = "e2-small"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {}
  }

  metadata = {
    gce-container-declaration = <<EOF
    spec:
      containers:
        - name: flask-app
          image: gcr.io/dc-cloud-451321/inft1210assign2-flask:latest
          ports:
            - containerPort: 5000
    EOF
  }

  tags = ["mihir-flask-app"] 
}

resource "google_compute_firewall" "flask_firewall" {
  name    = "mihir-flask-firewall" 
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
}