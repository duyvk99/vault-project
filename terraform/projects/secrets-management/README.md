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
- Update your Terraform variables and execute the command below to create resources in Vault.
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
| token                  | Vault tokens are authorized to create resources.                                               |  string  |                  |      yes     |
| project                | Project Name                                                                                   |  string  |                  |      yes     |
| environment            | Environment                                                                                    |  string  |                  |      yes     |
| secret_path            | Vault Secret KV2 path                                                                          |  string  | secret           |      no      |
| path_exists            | Utilizing an existing secret path.                                                             |  string  | ""               |      no      |
| enable_kubernetes_auth | Enable Vault Kubernetes Auth                                                                   |   bool   | false            |      no      |
| kubernetes_host        | Kubernetes Endpoints for Vault to authenticate .Specifiy `enable_kubernetes_auth = true`                                                  |  string  | ""               |      no      |
| auth_kubernetes_path   | Vault Kubernetes Auth Path Specifiy when `enable_kubernetes_auth = true`                       |  string  | "kubernetes-uat" |      no      |
| auth_kubernetes_exists | Use this option when you already have Vault Kubernetes authentication set up. Specify `enable_kubernetes_auth = true`|  string  | ""               |      no      |
| enable_jwt_auth        | Enable Vault JWT/OIDC Auth                                                                     |   bool   | true             |      no      |
| oidc_discovery_url     | Publish well-know URL. Specifiy `enable_jwt_auth = true`                                                         |  string  | ""               |      no      |
| auth_jwt_path          | Use this option for Vault JWT/OIDC authentication. Specify `enable_jwt_auth = true`            |  string  | "jwt-uat"        |      no      |
| auth_jwt_exists        | Use this option when you already have Vault JWT/OIDC authentication setup. Specifiy `enable_jwt_auth = true` |  string  | ""               |      no      |