terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.23.0"
    }
  }
}

provider "vault" {
  # Configuration options
  address = var.address
  token   = var.token
}