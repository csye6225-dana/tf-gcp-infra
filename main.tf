# Specify the required provider and version
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.20.0"
    }
  }
}

# Configure the Google Cloud provider
provider "google" {
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
  allow {
    protocol = var.protocol
    ports    = [var.ssh_port]
  }
  source_ranges = [var.source_ranges]
}
resource "google_compute_firewall" "sql_firewall" {
  name    = var.firewall3
  network = google_compute_network.vpc_network.name
  allow {
    protocol = var.protocol
    ports    = [var.sql_port]
  }
  source_ranges = [google_compute_subnetwork.webapp_subnet.ip_cidr_range]
  # source_ranges = [var.source_ranges]
}


# Private services connection
resource "google_compute_global_address" "private_ip_block" {
  name         = var.private_ip_name
  purpose      = var.private_ip_purpose
  address_type = var.private_ip_address_type
  ip_version   = var.private_ip_version
  prefix_length = var.private_ip_prefix_length
  network       = google_compute_network.vpc_network.self_link
}
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_block.name]
}

# CloudSQL Instance
resource "google_sql_database_instance" "mysql" {
  name                = var.mysql_name
  region              = var.region
  database_version    = var.db_version 
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier               = var.tier
    disk_type          = var.disk_type
    disk_size          = var.disk_size
    availability_type  = var.availability_type
    ip_configuration {
      ipv4_enabled     = var.if_ipv4_enabled
      private_network  = google_compute_network.vpc_network.id
    }
    backup_configuration {
      binary_log_enabled = var.if_binary_log_enabled
      enabled            = var.if_back_up
    }
  }
  deletion_protection = var.if_delete
}
# Generate a random password for Cloud SQL user
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}
# DB User
resource "google_sql_user" "users" {
  name     = var.user_name
  instance = google_sql_database_instance.mysql.name
  password = random_password.password.result
}
# Database
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.mysql.name
}

# Compute Instance (VM)
resource "google_compute_instance_template" "web_server_template" {
  name         = var.server_name
  project      = var.project_id
  machine_type = var.machine_type
  region       = var.region
  tags         = ["web-server"]
  disk {
    source_image = var.image
    disk_size_gb  = var.image_size
    disk_type  = var.image_type
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
    access_config {}
  }
  metadata_startup_script = <<-SCRIPT
    # Create .env file and assign configurations
    cat << EOF > /opt/csye6225/.env
    MYSQL_HOST=127.0.0.1
    MYSQL_PORT=${var.sql_port}
    PORT=${var.allow_port}
    DB_NAME=${google_sql_database.database.name}
    DB_USER=${google_sql_user.users.name}
    DB_PASSWORD=${google_sql_user.users.password}
    EOF
    
    # Download and make the Cloud SQL Proxy executable
    curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.9.0/cloud-sql-proxy.linux.amd64
    sleep 3
    chmod +x cloud-sql-proxy
    ./cloud-sql-proxy --private-ip --credentials-file /opt/csye6225/credentials.json ${google_sql_database_instance.mysql.connection_name} &
    sleep 5

    # Write a confirmation message
    echo 'Instance ready' > /tmp/instance_ready
    sudo systemctl stop webapp
    sudo systemctl start webapp
  SCRIPT
  # Service account
  service_account {
    email  = var.service_account
    scopes = var.service_scope
  }
}

# Autoscaling
resource "google_compute_autoscaler" "web_autoscaler" {
  name        = "web-autoscaler"
  project     = var.project_id
  zone        = var.zone
  target      = google_compute_instance_template.web_server_template.self_link
  
  autoscaling_policy {
    max_replicas      = 10
    min_replicas      = 1
    cooldown_period   = 60
    cpu_utilization {
      target = 0.05
    }
  }
}

# resource "google_compute_target_pool" "web_target_pool" {
#   name             = var.target_pool_name
#   region           = var.region
#   health_checks    = [google_compute_http_health_check.default.self_link]
# }

resource "google_compute_http_health_check" "default" {
  name               = var.health_check_name
  request_path       = "/healthz"
  # port               = "8080"
  check_interval_sec = 10
  timeout_sec        = 5
}
# Group Manager
resource "google_compute_instance_group_manager" "default" {
  name        = var.instance_group_manager_name
  base_instance_name = "webapp-instance"
  project     = var.project_id
  zone        = var.zone
  target_size = 1
  version {
    instance_template = google_compute_instance_template.web_server_template.self_link
  }
  named_port {
    name = "http"
    port = 8080
  }
  # target_pools = [google_compute_target_pool.web_target_pool.self_link]
  auto_healing_policies {
    health_check = google_compute_http_health_check.default.id
    initial_delay_sec = 300
  }

  # update_policy {
  #   type = "PROACTIVE"
  #   minimal_action = "RESTART"
  #   max_surge = 1
  #   max_unavailable = 1
  # }

  depends_on = [google_compute_http_health_check.default]
}

# Update firewall ingress rules to allow only load balancer access
resource "google_compute_firewall" "firewall" {
  name    = "allow-lb"
  network = "default"  # Update this if using a custom network

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]  # Google's load balancer IP ranges
}
# Create a external Application Load Balancer
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "https-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy.self_link
  port_range = "443"
}

# Create a target HTTPS proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-proxy"
  description      = "HTTPS proxy for load balancer"
  url_map          = google_compute_url_map.url_map.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_certificate.id]
}

# Create a URL map for the load balancer
resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_service.web_backend_service.self_link
}

# Create a backend service for the load balancer
resource "google_compute_backend_service" "web_backend_service" {
  name           = "backend-service"
  health_checks  = [google_compute_http_health_check.default.self_link]
  port_name      = "http"
  protocol       = "HTTP"
  backend {
    group = google_compute_instance_group_manager.default.self_link
  }
}

# Create a Google-managed SSL certificate
resource "google_compute_managed_ssl_certificate" "ssl_certificate" {
  name = "ssl-certificate"
  
}

# DNS
resource "google_dns_record_set" "DNS" {
  name         = var.dns_name
  type         = var.dns_type
  ttl          = 300
  managed_zone = var.dns_zone
  rrdatas = [google_compute_global_forwarding_rule.forwarding_rule.ip_address]
}


# resource "google_pubsub_topic" "verify_email_topic" {
#   name                           = "verify_email"
#   message_retention_duration     = "604800s" # 7 days
# }

# resource "google_pubsub_subscription" "verify_email_subscription" {
#   name  = "email_func"
#   topic = google_pubsub_topic.verify_email_topic.name
#   ack_deadline_seconds = 60
# }
# resource "google_storage_bucket" "my_bucket" {
#   name     = "csy6255-webapp-serverless"
#   location = var.region 
#   force_destroy = true
# }

# resource "google_storage_bucket_object" "function_source" {
#   name   = "email_func.zip"  # Name of the file inside the bucket
#   bucket = google_storage_bucket.my_bucket.name
#   source = "/Users/Dana_G/Documents/Code/NEU/CloudComputing/serverless/email_func.zip"
# }

# resource "google_cloudfunctions_function" "send_verification_email" {
#   name        = "emailPubSub"
#   description = "Cloud Function for sending verification emails"
#   runtime     = "nodejs18"

#   source_archive_bucket = google_storage_bucket.my_bucket.name
#   source_archive_object = google_storage_bucket_object.function_source.name

#   trigger_http = true
 
#   environment_variables = {
#     SENDGRID_API_KEY="8J4FAE1HYFZWQHEG6MK2WSDW"
#   }
  # event_trigger {
  #   event_type     = "providers/cloud.pubsub/eventTypes/topic.publish"
  #   resource       = google_pubsub_topic.verify_email_topic.id
  # }
  
# }

