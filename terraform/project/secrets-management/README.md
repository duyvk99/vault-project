# Terraform Vault - Secrets Management
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
cd terraform/project/secrets-management/<PROJECT_NAME>/
mv terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out tf.plan
terraform show -no-color tf.plan > tfplan.txt
terraform apply
```
## Inputs
---

|        **Name**        | **Description**                                                                                | **Type** | **Default**      | **Required** |
|:----------------------:|------------------------------------------------------------------------------------------------|:--------:|------------------|:------------:|
| address                | Vault FQDN                                                                                     |  string  |                  |      yes     |
| token                  | Vault token have permission to create resources                                                |  string  |                  |      yes     |
| project                | Project Name                                                                                   |  string  |                  |      yes     |
| environment            | Environment                                                                                    |  string  |                  |      yes     |
| secret_path            | Enable Vault Secret with path                                                                  |  string  | secret           |      no      |
| path_exists            | Using existing secret path                                                                     |  string  | ""               |      no      |
| enable_kubernetes_auth | Enable Vault Kubernetes Auth                                                                   |   bool   | false            |      no      |
| kubernetes_host        | Specifiy when enable_kubernetes_auth = true                                                    |  string  | ""               |      no      |
| auth_kubernetes_path   | Vault Kubernetes Auth Path Specifiy when enable_kubernetes_auth = true                         |  string  | "kubernetes-uat" |      no      |
| auth_kubernetes_exists | Using when already have an vault kubernetes auth.  Specifiy when enable_kubernetes_auth = true |  string  | ""               |      no      |
| enable_jwt_auth        | Enable Vault JWT/OIDC Auth                                                                     |   bool   | true             |      no      |
| oidc_discovery_url     | Specifiy when enable_jwt_auth = true                                                           |  string  | ""               |      no      |
| auth_jwt_path          | Vault JWT/OIDC Auth Path Specifiy when enable_jwt_auth = true                                  |  string  | "jwt-uat"        |      no      |
| auth_jwt_exists        | Using when already have an vault jwt auth.  Specifiy when enable_jwt_auth = true               |  string  | ""               |      no      |