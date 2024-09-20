# # Enable JWT Auth Method
resource "vault_jwt_auth_backend" "jwt" {
  count              = length(var.auth_jwt_exists) > 0 || var.enable_jwt_auth == false ? 0 : 1
  description        = "JWT Auth Backend"
  path               = var.auth_jwt_path
  oidc_discovery_url = var.oidc_discovery_url
}

# # Create JWT Auth Roles
resource "vault_jwt_auth_backend_role" "jwt_roles" {
  for_each  = { for idx, role in local.services : "${var.project}-${var.environment}-${role.service}" => role if var.enable_jwt_auth }
  backend   = length(var.auth_jwt_exists) > 0 ?  "${var.auth_jwt_exists}" :vault_jwt_auth_backend.jwt[0].path
  role_name = "${var.project}-${var.environment}-${each.value.service}"

  bound_audiences = ["vault"]
  bound_subject   = "system:serviceaccount:${each.value.namespace}:${each.value.service}"
  user_claim      = "sub"
  role_type       = "jwt"
  claim_mappings = {
    "/kubernetes.io/pod/name"            = "pod_name",
    "/kubernetes.io/serviceaccount/name" = "service_account_name",
    "/kubernetes.io/serviceaccount/uid"  = "service_account_uid",
    "/kubernetes.io/namespace"           = "namespace",
    "iss"                                = "cluster_url"
  }
  depends_on = [
    vault_policy.policy,
    vault_jwt_auth_backend.jwt
  ]
}

resource "vault_identity_entity_alias" "jwt_entity_alias" {
  for_each  = { for idx, role in local.services : "${var.project}-${var.environment}-${role.service}" => role if var.enable_jwt_auth }

  name            = "system:serviceaccount:${each.value.namespace}:${each.value.service}"
  mount_accessor  = length(var.auth_jwt_exists) > 0 ? data.vault_auth_backend.auth_jwt_exists[0].accessor : vault_jwt_auth_backend.jwt[0].accessor
  canonical_id    = vault_identity_entity.entity["${var.project}-${var.environment}-${each.value.service}"].id
}