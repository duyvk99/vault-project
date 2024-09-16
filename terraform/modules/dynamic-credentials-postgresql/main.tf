resource "vault_mount" "db" {
  path = "postgres"
  type = "database"
}


resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.db.path
  name          = "postgres"
  allowed_roles = [ "test" ]

  postgresql {
    connection_url = "postgres://${var.db_username}:${var.db_password}@${var.db_host}:5432/${var.db_name}"
  }
}

