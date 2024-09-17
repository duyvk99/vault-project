# Terraform Vault - Dynamic Database Credentials
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
cd terraform/project/dynamic-database-credentials
mv terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out tf.plan
terraform show -no-color tf.plan > tfplan.txt
terraform apply
```
## Inputs
---

|     Name    | Description                                         |  Type  | Default | Required |
|:-----------:|-----------------------------------------------------|:------:|---------|:--------:|
|   address   | Vault FQDN                                          | string |         |    yes   |
|    token    | Vault tokens have permission to create resources    | string |         |    yes   |
| db_host     | Postgres Database Host                              | string |         | yes      |
| db_username | Database username                                   | string |         | yes      |
| db_name     | Database name                                       | string |         | yes      |
| db_password | Database Password                                   | string |         | yes      |
| max_ttl     | Lease expired time                                  | number | 600     |          |
| group_name  | The group name for attach the database admin policy | string |         | yes      |