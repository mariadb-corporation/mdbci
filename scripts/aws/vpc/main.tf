provider "aws" {
  version = "~> 2.48"
  profile = "default"
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_vpc
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    owner = "manually-generated-by-mdbci-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    owner = "manually-generated-by-mdbci-vpc"
  }
}

resource "aws_subnet" "subnet_public" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.cidr_subnet
  map_public_ip_on_launch = true
  availability_zone = var.availability_zone
  tags = {
    owner = "manually-generated-by-mdbci-vpc"
  }
}

resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    owner = "manually-generated-by-mdbci-vpc"
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.rtb_public.id
}

output "vpc_info" {
  value = {
    vpc_id = aws_vpc.vpc.id
    subnet_id = aws_subnet.subnet_public.id
  }
}
