# Get credentials from the database secrets engine '${vault_database_secret_backend_role.role.name}' role.
path "database/creds/readonly" {
  capabilities = [ "read" ]
}