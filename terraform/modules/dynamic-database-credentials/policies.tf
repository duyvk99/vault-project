resource "vault_policy" "db_admin_policy" {
  name   = "database-admin-policy"
  policy = <<EOT
# Configure the database secrets engine and create roles
path "database/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Manage the leases
path "sys/leases/+/database/creds/readonly/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

path "sys/leases/+/database/creds/readonly" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

# Manage tokens for verification
path "auth/token/create" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
EOT
}

resource "vault_policy" "db_application_policy" {
  name   = "${vault_database_secret_backend_role.role.name}-application-policy"
  policy = <<EOT
# Get credentials from the database secrets engine '${vault_database_secret_backend_role.role.name}' role.
path "database/creds/${vault_database_secret_backend_role.role.name}" {
  capabilities = [ "read" ]
}
EOT
}