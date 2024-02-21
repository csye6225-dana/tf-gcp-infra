variable "project" {
    default = "csye6225-cloudcomputing" 
}

variable "credentials_file" { 
    default = "credentials.json"
}

variable "network"{
    default = "vpc-network2"
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
    default = "router2"
}

variable "route"{
    default = "route"
}

variable "subnet1"{
    default = "webapp2"
}

variable "subnet2"{
    default = "db2"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}
