variable "project_id" {
    default = "cyse6225-cloudcomputing-webapp"
}

variable "credentials_file" { 
    default = "credentials.json"
}
// compute engine instance //
variable "service_account"{
    default = "960667116773-compute@developer.gserviceaccount.com"
}

variable "network"{
    default = "terraform-vpc"
}

variable "routing_mode"{
    default = "REGIONAL"
}

variable "ip_range1"{
    default = "198.162.1.0/24"
}

variable "ip_range2"{
    default = "10.0.2.0/24"
}

variable "routing_mode"{
    default = "REGIONAL"
}

variable "routing_mode"{
    default = "REGIONAL"
}

variable "router"{
    default = "router"
}

variable "route"{
    default = "route"
}

variable "subnet1"{
    default = "webapp"
}

variable "subnet2"{
    default = "db"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

variable "auto_create"{
    default = false
}

variable "next_gateway"{
    default = "default-internet-gateway"
}


variable "server_name"{
    default = "web-server"
}

variable "machine_type"{
    default = "n1-standard-2"
}

variable "server_tag"{
    default = ["http-server"]
}

variable "image"{
    default = "custom-image"
}

variable "image_size"{
    default = 100
}

variable "image_type"{
    default = "pd-balanced"
}

# firewalls
variable "firewall1"{
    default = "webapp-firewall"
}
variable "firewall2"{
    default = "ssh-firewall"
}
variable "allow_port"{
    default = ["8080"]
}
variable "protocol"{
    default = "tcp"
}
variable "deny_port"{
    default = ["22"]
}
variable "source_ranges"{
    default = "0.0.0.0/0"
}
variable "startup_script" {
  default = "cd /opt/csye6225 && node app.js"
}
variable "service_scope" {
  default = ["cloud-platform"]
}