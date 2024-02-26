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
provider2 "google2" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

# Create a VPC network
resource2 "google_compute_network" "vpc_network" {
  name                  = var.network
  auto_create_subnetworks = var.auto_create
  routing_mode          = var.routing_mode
}

# Create a subnet for webapp
resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.subnet1
  ip_cidr_range = var.ip_range1
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
}

# Create a subnet for db
resource "google_compute_subnetwork" "db_subnet" {
  name          = var.subnet2
  ip_cidr_range = var.ip_range2
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
  dest_range        = var.source_ranges
  network           = google_compute_network.vpc_network.self_link
  next_hop_gateway  = var.next_gateway
  priority          = 1000  # Set priority higher to ensure it's preferred over default route
  depends_on        = [google_compute_subnetwork.webapp_subnet]
}



# Create firewall rules
resource "google_compute_firewall" "webapp_firewall" {
  name    = var.firewall1
  network = google_compute_network.vpc_network.name
  allow {
    protocol = var.protocol
    ports    = var.allow_port
  }
  source_ranges = [var.source_ranges]
}

resource "google_compute_firewall" "ssh_firewall" {
  name    = var.firewall2
  network = google_compute_network.vpc_network.name
  # Deny SSH traffic from the internet
  deny {
    protocol = var.protocol
    ports    = var.deny_port
  }
  source_ranges = [var.source_ranges]
}

# Create a Compute Engine instance
resource "google_compute_instance" "web_server" {
  name         = var.server_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.server_tag
  boot_disk {
    initialize_params {
      image = var.image
      size  = var.image_size
      type  = var.image_type
    }
  }
  network_interface {
    # network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.name
    access_config {
      // Ephemeral public IP
    }
  }
  metadata_startup_script =  var.startup_script

  service_account {  
    email  = var.service_account
    scopes = var.service_scope
  }
}
