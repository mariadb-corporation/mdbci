# README

## What is it?
This is a terraform configuration for creating a new VPC in the Google Cloud Compute.
You can use this VPC to create all the GCP configurations using
mdbci. In standard mode, mdbci creates its own VPC for each
new configuration, but GCP has a limit on the number of VPCs.
Creating one VPC and using it for all created configurations
allows you to fit into the VPCs limit, because for all
configurations one network will be used.

## How to create new VPC?
1. Install Terraform
    1. You can do it via command
    ```
    mdbci setup-dependencies
   ```
    2. or download it from https://www.terraform.io/downloads.html
2. Execute
   ```
    terraform init
   ```
3. Execute
    ```
    terraform apply -auto-approve \
                    -var 'project=<enter-project-name>' \
                    -var 'credentials_file_path=<enter-path>'
    ```
4. It's all, you can get VPC information via command `terraform output -json vpc_info`

## What's next?
Configure mdbci for use created VPC for GCP configurations.
1. Get VPC information via command
    ```
    terraform output -json vpc_info
    ```
2. Execute
    ```
    mdbci configure --product gcp
    ```
    1. To the question `Use existing network for Google Compute instances?`, answer `y`
    2. Take the `network` and `tags` settings from the information obtained in the first paragraph
3. It's all

## How to destroy created VPC?
Execute
```
terraform destroy -auto-approve \
                  -var 'project=<enter-project-name>' \
                  -var 'credentials_file_path=<enter-path>'
```
