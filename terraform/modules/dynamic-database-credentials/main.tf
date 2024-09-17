resource "vault_mount" "db" {
  path = "database"
  type = "database"
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.db.path
  name          = "${var.db_name}-${var.db_username}"
  allowed_roles = ["${var.db_name}-${var.db_username}"]
  plugin_name = "postgresql-database-plugin"
  postgresql {
    connection_url = "postgres://${var.db_username}:${var.db_password}@${var.db_host}:5432/${var.db_name}"
  }
}
