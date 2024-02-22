variable "project" {
    default = "cloudcomputing-415019"
}

variable "credentials_file" { 
    default = "credentials.json"
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

// compute engine instance //
variable "service_account"{
    default = "1025734219928-compute@developer.gserviceaccount.com"
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

variable "startup_script"{
    default = "cp -r /tmp/webapp /home/danakwoh"
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