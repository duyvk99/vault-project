# Terraform Vault - Users Management
## Requirements
- Install Terraform.
- If you are using Terraform Cloud to save the terraform state, you need to create a `backend.tf` file with the following format example.
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
cd terraform/project/users-management
mv terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out tf.plan
terraform show -no-color tf.plan > tfplan.txt
terraform apply
```
## Inputs
---

|        **Name**       | **Description**              | **Type** | **Default**                                                         | **Required** |
|:---------------------:|------------------------------|:--------:|---------------------------------------------------------------------|:------------:|
| address               | Vault FQDN                                      | string   |                                                                     |      yes     |
| token                 | Vault tokens are authorized to create resources. | string   |                                                                     |      yes     |
| teams_map_users    | Mapping teams to users.         |    any   | <pre><br>{<br>  "devops": ["admin"],<br>  "qc": ["qc"],<br>  "backend": ["backend"]<br>}</pre> |      yes     |
| userpass_path     | Userpass Auth path |  string  | userpass                                                            |      no      |
| user_default_password | Default user password        |  string  | Hello@123                                                           |      no      |
| kv_personal_path   | Personal secret path   |  string  | personal                                                            |      no      |
| kv_team_path     | Teams secret path       |  string  | team                                                                |      no      |
| kv_infras_path    | Infrastructures secret path   |  string  | infrastructure                                                      |      no      |