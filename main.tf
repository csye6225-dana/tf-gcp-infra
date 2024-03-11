# Specify the required provider and version
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}
# Enable private services access in your VPC
resource "google_project_service" "vpc_service" {
  service = "servicenetworking.googleapis.com"
}


# Configure the Google Cloud provider
provider "google2" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

# Create a VPC network
resource "google_compute_network" "vpc_network" {
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
  private_ip_google_access = var.if_private_ip
}

# Create a subnet for db
resource "google_compute_subnetwork" "db_subnet" {
  name          = var.subnet2
  ip_cidr_range = var.ip_range2
  network       = google_compute_network.vpc_network.self_link
  region        = var.region
  private_ip_google_access = var.if_private_ip
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
    ports    = [var.allow_port]
  }
  source_ranges = [var.source_ranges]
}

resource "google_compute_firewall" "ssh_firewall" {
  name    = var.firewall2
  network = google_compute_network.vpc_network.name
  # Deny SSH traffic from the internet
  deny {
    protocol = var.protocol
    ports    = [var.deny_port]
  }
  source_ranges = [var.source_ranges]
}

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
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
    access_config {}
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash

    # Set environment variables for MySQL connection
    MYSQL_HOST="127.0.0.1"
    DB_NAME="${google_sql_database.database.name}"
    DB_USER="${google_sql_user.users.name}"
    DB_PASSWORD="${google_sql_user.users.password}"

    # Write environment variables to .env file
    cat << EOF > /opt/csye6225/.env
    MYSQL_HOST="$MYSQL_HOST"
    MYSQL_PORT="${var.sql_port}"
    PORT="${var.allow_port}"
    DB_NAME="$DB_NAME"
    DB_USER="$DB_USER"
    DB_PASSWORD="$DB_PASSWORD"
    EOF

    # Decode and set the service account key
    export SERVICE_ACCOUNT_KEY="$(echo '${var.credentials_file}' | base64 -d)"

    # Download and make the Cloud SQL Proxy executable
    curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
    chmod +x cloud_sql_proxy

    # Start the Cloud SQL Proxy in the background
    ./cloud_sql_proxy -instances=cyse6225-cloudcomputing-webapp:us-central1:mysql-instance=tcp:3306 &

    # Connect to MySQL and grant permissions
    mysql -h 127.0.0.1 -u root -p"${google_sql_database_instance.mysql.root_password}" <<EOT
    USE mysql;
    GRANT ALL PRIVILEGES ON webapp.* TO 'webapp'@'localhost';
    FLUSH PRIVILEGES;
    EXIT;
    EOT

    # Wait for 5 seconds
    sleep 5

    # Write a confirmation message
    echo 'Instance ready' > /tmp/instance_ready
    sudo systemctl start webapp.service
  SCRIPT


  # Service account
  service_account {
    email  = var.service_account
    scopes = var.service_scope
  }
}


resource "google_compute_global_address" "private_ip_block" {
  name         = "private-ip-block"
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"
  ip_version   = "IPV4"
  prefix_length = 20
  network       = google_compute_network.vpc_network.self_link
}
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_block.name]
}

data "google_compute_instance" "web_server" {
  name = var.server_name
  zone = var.zone
}

# CloudSQL Instance
resource "google_sql_database_instance" "mysql" {
  name                = "mysql-instance"
  region              = var.region
  database_version    = "MYSQL_8_0"
  root_password       = "1234567890"
  depends_on = [google_service_networking_connection.private_vpc_connection]
  settings {
    tier               = "db-f1-micro"
    disk_type          = "PD_SSD"
    disk_size          = 100
    availability_type  = "REGIONAL"
    backup_configuration {
      binary_log_enabled = true
      enabled            = true
    }
    ip_configuration {
      authorized_networks{
        name = "webapp-internal-ip"
        value = google_compute_subnetwork.webapp_subnet.ip_cidr_range
      }
      ipv4_enabled     = false
      private_network  = google_compute_network.vpc_network.self_link
    }
  }
  deletion_protection = false

}

# Firewall Rule for Cloud SQL
resource "google_compute_firewall" "sql_firewall" {
  name    = "allow-cloudsql"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
  source_ranges = [google_compute_subnetwork.webapp_subnet.ip_cidr_range]
}
 

# Generate a random password for Cloud SQL user
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
# DB User
resource "google_sql_user" "users" {
  name     = "webapp"
  instance = google_sql_database_instance.mysql.name
  password = random_password.password.result
  host     = "localhost"
}

# Database
resource "google_sql_database" "database" {
  name     = "webapp"
  instance = google_sql_database_instance.mysql.name
}

resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering              = google_service_networking_connection.private_vpc_connection.peering
  network              = google_compute_network.vpc_network.name
  import_custom_routes = true
  export_custom_routes = true
}
