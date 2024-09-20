# Example - Users Management
## 1. Setup Resources
- Fill in all the empty variables in `examples/kubernetes-auth/kubernetes-terraform-example/terraform.tfvars.example`, then apply the Terraform configuration to create the resources.
```
cd examples/users-management/terraform-user-management
mv terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply --auto-approve
```
## 2. Demo
- Access the UI and log in using the user created in `terraform.tfvars` with the default password `Hello@123`.
- The user can access the internal secret engine at `/personal/<username>`.
- The user can access the team they are assigned to in the `/team/<team> secret engine`.
- All users have access to the infrastructures secret engine.
- Users with the team `admin/devops` have full access and can perform any actions.