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
provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
  region      = "us-central1"
}

# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name                  = "terraform-network"
  auto_create_subnetworks = false
  routing_mode          = "REGIONAL"
}

# Create a subnet for webapp
resource "google_compute_subnetwork" "webapp_subnet" {
  name          = "webapp"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc_network.self_link
  region        = "us-central1"
}

# Create a subnet for db
resource "google_compute_subnetwork" "db_subnet" {
  name          = "db"
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.vpc_network.self_link
  region        = "us-central1"
}

# Create a router
resource "google_compute_router" "my_router" {
  name    = "my-router"
  network = google_compute_network.vpc_network.self_link
}

# Create a global address for the NAT gateway
resource "google_compute_global_address" "nat_address" {
  name = "nat-address1"
}

# Create a Cloud NAT gateway
resource "google_compute_router_nat" "nat_gateway" {
  name                        = "nat-gateway"
  router                      = google_compute_router.my_router.name
  region                      = "us-central1"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  nat_ip_allocate_option      = "MANUAL_ONLY"
  nat_ips                     = [google_compute_global_address.nat_address.address]  # Use the address from the global address resource
  depends_on                  = [google_compute_router.my_router]
}

# Create a route for the webapp subnet
resource "google_compute_route" "webapp_route" {
  name              = "webapp-route"
  dest_range        = "0.0.0.0/0"
  network           = google_compute_network.vpc_network.self_link
  next_hop_gateway  = google_compute_router.my_router.self_link
  priority          = 1000  # Set priority higher to ensure it's preferred over default route
  depends_on        = [google_compute_subnetwork.webapp_subnet, google_compute_router_nat.nat_gateway]
}
