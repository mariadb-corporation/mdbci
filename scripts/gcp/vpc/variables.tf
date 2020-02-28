variable "project" {
  type = string
  description = "Name of the Google Cloud Platform project"
}

variable "region" {
  type = string
  default = "us-central1"
  description = "Google Cloud Platform region to create VPC"
}

variable "zone" {
  type = string
  default = "us-central1-a"
  description = "Google Cloud Platform zone to create VPC"
}

variable "credentials_file_path" {
  type = string
  description = "Path to the Google Cloud Platform json credentials file"
}

variable "vpc_name" {
  type = string
  default = "manually-generated-by-mdbci-vpc"
  description = "Name of created VPC"
}

variable "firewall_name" {
  type = string
  default = "manually-generated-by-mdbci-firewall"
  description = "Name of created firewall"
}
