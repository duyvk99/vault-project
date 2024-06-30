data "vault_auth_backend" "auth_jwt_exists" {
  count              = length(var.auth_jwt_exists) > 0 ? 1 : 0
    path = var.auth_jwt_exists
}

data "vault_auth_backend" "auth_kubernetes_exists" {
  count              = length(var.auth_kubernetes_exists) > 0 ? 1 : 0
    path = var.auth_kubernetes_exists
}