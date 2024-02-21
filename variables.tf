variable "project" {
    default = "csye6225-cloudcomputing" 
}

variable "credentials_file" { 
    default = "credentials.json"
}

variable "network"{
    default = "vpc-network1"
}

variable "router"{
    default = "router1"
}

variable "route"{
    default = "route1"
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
