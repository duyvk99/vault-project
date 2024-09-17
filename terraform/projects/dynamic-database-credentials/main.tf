module "dynamic-database-credentials" {
  source         = "../../modules/dynamic-database-credentials"

  db_host = var.db_host
  db_name = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  max_ttl = var.max_ttl

  group_id = data.vault_identity_group.vault_group.id
}