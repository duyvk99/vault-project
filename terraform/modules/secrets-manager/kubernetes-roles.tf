# Enable Kubernetes Auth Method
resource "vault_auth_backend" "kubernetes" {
  count = length(var.auth_kubernetes_exists) > 0 ? 0 : 1
  type  = "kubernetes"
  path  = var.auth_kubernetes_path
}

# Update Kubernetes Auth Config
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  count = length(var.auth_kubernetes_exists) > 0 ? 0 : 1
  backend         = vault_auth_backend.kubernetes[0].path
  kubernetes_host = var.kubernetes_host #### API Endpoint
}

# Create Kubernetes Auth Roles
resource "vault_kubernetes_auth_backend_role" "kubernetes_role" {
  for_each                         = { for idx, role in local.services : "${var.project}-${var.environment}-${role.service}" => role if var.enable_kubernetes_auth }
  backend                          = length(var.auth_kubernetes_exists) > 0 ? "${var.auth_kubernetes_exists}" : vault_auth_backend.kubernetes[0].path
  role_name                        = "${var.project}-${var.environment}-${each.value.service}"
  bound_service_account_names      = [each.value.service]
  bound_service_account_namespaces = [each.value.namespace]
  token_ttl                        = 3600
  alias_name_source                = "serviceaccount_name"
  depends_on = [vault_policy.policy]
}

resource "vault_identity_entity_alias" "kubernetes_entity_alias" {
  for_each  = { for idx, role in local.services : "${var.project}-${var.environment}-${role.service}" => role if var.enable_kubernetes_auth }

  name            = "${each.value.namespace}/${each.value.service}"
  mount_accessor  = length(var.auth_kubernetes_exists) > 0 ? data.vault_auth_backend.auth_kubernetes_exists[0].accessor : vault_auth_backend.kubernetes[0].accessor
  canonical_id    = vault_identity_entity.entity["${var.project}-${var.environment}-${each.value.service}"].id
}