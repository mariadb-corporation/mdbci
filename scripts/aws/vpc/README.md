# README

## What is it?
This is a terraform configuration for creating a new VPC in the AWS.
You can use this VPC to create all the AWS configurations using
mdbci. In standard mode, mdbci creates its own VPC for each
new configuration, but AWS has a limit on the number of VPCs.
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
    terraform apply -auto-approve -var 'availability_zone=eu-west-1a' -var 'access_key=<enter-key>' -var 'secret_key=<secret_key>'
    ```
4. It's all, you can get VPC information via command `terraform output -json vpc_info`

## What's next?
Configure mdbci for use created VPC for AWS configurations.
1. Get VPC information via command
    ```
    terraform output -json vpc_info
    ```
2. Execute
    ```
    mdbci configure --product aws
    ```
    1. To the question `Use existing VPC for AWS instances?`, answer `yes`
    2. Take the `vpc_id` and `subnet_id` settings from the information obtained in the first paragraph
3. It's all

## How to destroy created VPC?
Execute
```
terraform destroy -auto-approve -var 'availability_zone=eu-west-1a' -var 'access_key=<enter-key>' -var 'secret_key=<secret_key>'
```
