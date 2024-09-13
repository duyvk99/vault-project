storage "postgresql" {
  connection_url = "postgres://VAULT_DB_USERNAME:VAULT_DB_PASSWORD@VAULT_DB_ENDPOINT/vault_server?sslmode=disable"
  ha_enabled = true
}