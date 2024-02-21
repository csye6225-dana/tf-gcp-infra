# Specify the required provider and version
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

# Configure the Google Cloud provider
provider "google2" {
  credentials = file(var.credentials_file)
  project     = var.project
  region      = var.region
}

# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name                  = var.network
  auto_create_subnetworks = false
  routing_mode          = "REGIONAL"
}

# Create a subnet for webapp
resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.subnet1
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
}

# Create a subnet for db
resource "google_compute_subnetwork" "db_subnet" {
  name          = var.subnet2
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
}

# Create a router
resource "google_compute_router" "my_router" {
  name    = var.router
  network = google_compute_network.vpc_network.self_link
}

# Create a route for the webapp subnet
resource "google_compute_route" "webapp_route" {
  name              = var.route
  dest_range        = "0.0.0.0/0"
  network           = google_compute_network.vpc_network.self_link
  next_hop_gateway  = "default-internet-gateway"
  priority          = 1000  # Set priority higher to ensure it's preferred over default route
  depends_on        = [google_compute_subnetwork.webapp_subnet]
}


# Create firewall rules
resource "google_compute_firewall" "webapp_firewall" {
  name    = "webapp-firewall"
  network = google_compute_network.vpc_network.self_link
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"] # Allow traffic from the internet
}


resource "google_compute_firewall" "deny_ssh" {
  name    = "deny-ssh"
  network = google_compute_network.vpc_network.self_link
  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]  # Deny traffic from the internet
}


# Create a Compute Engine instance based on image
resource "google_compute_instance" "web_server" {
  name         = "web-server"
  machine_type = "n1-standard-2"
  zone         = "us-central1-a"
  tags         = ["http-server"]

  boot_disk {
    initialize_params {
      image = "custom-image"
      size  = "100"
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.self_link
  }
  metadata_startup_script = "sudo systemctl start node app.js"
}
