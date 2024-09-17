resource "vault_database_secret_backend_role" "role" {
  backend             = vault_mount.db.path
  name                = "${var.db_name}-${var.db_username}"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]
  revocation_statements=[
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";", 
    "DROP ROLE \"{{name}}\";"
  ]
  max_ttl="${var.max_ttl}"
}
