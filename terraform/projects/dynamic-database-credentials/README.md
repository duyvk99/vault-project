# Terraform Vault - Users Management
## Requirements
- Install Terraform.
- If you are using Terraform Cloud to save the state, you need to create a `backend.tf` file with the following format example.
```
terraform {
  backend "remote" {
    organization = "<ORGANIZATION>"

    workspaces {
      name = "<WORKSPACE>"
    }
  }
}

``` 
## Setup
- Replace your terraform variables and run the command below to create resources in Vault. 
```
cd terraform/project/users-management
mv terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out tf.plan
terraform show -no-color tf.plan > tfplan.txt
terraform apply
```
## Inputs
---
