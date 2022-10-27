# GCP regions management in MDBCI

## Configuration file
Currently supported regions are listed in `config.yaml` file in the `~/.config/mdbci`.
If the set of machines to be created does not meet the CPU quota in the default region, MDBCI will select another one from the `regions`
list

```yaml
gcp:
  ...
  default_region: # the region used when the CPU quota is met
  regions: # list of supported regions
  - us-central1
  - europe-west4
  ...
```

## Add support for a new region

### 1. Modify configuration file

Add region name to the configuration file described above.

### 2. Check Cloud Routers

Check if the added zone has a Cloud Router. The Router allows the machines without external IPs to access the external resources. You can list the routers in the current project using this command:

```
gcloud compute routers list
```

### 3. Create the Router

Create and configure the Cloud Router if none exists in the current region using gcloud cli or a Terrafom file.

#### Create a router instance:

```
gcloud compute routers create ROUTER_REGION \
    --network default \
    --region ROUTER_REGION
```
#### Configure the router for Cloud NAT:
```
gcloud compute routers nats create nat-config \
    --router-region ROUTER_REGION \
    --router ROUTER_NAME \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips
```

Read more about [building internet connectivity to GCP VMs](https://cloud.google.com/architecture/building-internet-connectivity-for-private-vms)

## Create and configure the Cloud Router using terraform

### 1. Create Terraform NAT configuration file
```terraform
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.65.0"
    }
  }
}

provider "google" {
  credentials = file("<path to GCP credentials file>")
  project     = "<project name>"
}

resource "google_compute_router" "<router name>" {
  name    = "<router name>"
  region  = "<router region>"
  network  = "default"
}

resource "google_compute_router_nat" "<NAT name>" {
  name                               = "<NAT name>"
  router                             = "<router name>"
  region                             = "<router region>"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
```
### 2. Apply the Terraform configuration
```
terraform apply
```
