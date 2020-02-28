provider "google" {
  version     = "~> 3.1"
  credentials = file(var.credentials_file_path)
  project     = var.project
  region      = var.region
  zone        = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = var.vpc_name
}

resource "google_compute_firewall" "firewall_rules" {
  name        = var.firewall_name
  description = "Allow all traffic"
  network     = google_compute_network.vpc_network.name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-all-traffic"]
}

output "vpc_info" {
  value = {
    network = google_compute_network.vpc_network.name
    tags     = google_compute_firewall.firewall_rules.target_tags
  }
}
