variable "cidr_vpc" {
  type = string
  default = "10.1.0.0/16"
  description = "CIDR block for the VPC"
}

variable "cidr_subnet" {
  type = string
  default = "10.1.0.0/24"
  description = "CIDR block for the subnet"
}

variable "availability_zone" {
  type = string
  default = "eu-west-1a"
  description = "Availability zone to create subnet"
}

variable "region" {
  type = string
  default = "eu-west-1"
  description = "Region to create VPC"
}

variable "access_key" {
  type = string
  description = "AWS credentials access key"
}

variable "secret_key" {
  type = string
  description = "AWS credentials secret key"
}
