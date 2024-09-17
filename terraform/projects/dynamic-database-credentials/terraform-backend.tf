terraform {
  backend "s3" {
    bucket         = "danny-terraform-infrastructure-state"
    key            = "vault/dynamic-database-credentials/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "danny-terraform-infrastructure-state-dynamodb-table"
  }
}