provider "google" {
  project = "dc-cloud-451321"
  region  = "us-central1"
}

# Create VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "assign2-vpc"
  auto_create_subnetworks = false
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

# Firewall Rule to Allow HTTP Access on Port 5000
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.self_link
  direction = "INGRESS"
  priority = 1000
  
  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# NAT Gateway for Private Subnet
resource "google_compute_router" "nat_router" {
  name    = "mihir-nat-router"
  network = google_compute_network.vpc_network.self_link
  region  = "us-central1"
}

resource "google_compute_router_nat" "nat_config" {
  name                               = "mihir-nat"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Create Compute Engine Instance with Flask App
resource "google_compute_instance" "flask_vm" {
  name         = "mihir-flask-vm"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.public_subnet.self_link
    access_config {}
  }

  service_account {
    email  = "467886545001-compute@developer.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y python3 python3-pip
    pip3 install flask
    
    cat << EOF > /home/flask_app.py
    from flask import Flask
    app = Flask(__name__)
    
    @app.route('/')
    def hello_cloud():
        return 'Hello Cloud from Mihir and this is updated Hello Cloud' 
    
    if __name__ == "__main__":
        app.run(host='0.0.0.0', port=5000)
    EOF
    
    python3 /home/flask_app.py &
    
    # Authenticate with Artifact Registry
    gcloud auth configure-docker us-east1-docker.pkg.dev
    
    # Pull and run the Docker container
    docker pull us-east1-docker.pkg.dev/dc-cloud-451321/inft1210assign2-flask/inft1210assign2-flask:latest
    docker run -d -p 5000:5000 us-east1-docker.pkg.dev/dc-cloud-451321/inft1210assign2-flask/inft1210assign2-flask:latest
  EOT
}

# Output Variables
output "vm_external_ip" {
  value = google_compute_instance.flask_vm.network_interface[0].access_config[0].nat_ip
}

output "vpc_name" {
  value = google_compute_network.vpc_network.name
}

output "public_subnet" {
  value = google_compute_subnetwork.public_subnet.self_link
}

output "private_subnet" {
  value = google_compute_subnetwork.private_subnet.self_link
}
