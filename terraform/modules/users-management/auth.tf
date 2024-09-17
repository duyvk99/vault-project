locals {
  list_users  = flatten([for team, users in var.teams_map_users : users])
  list_groups = flatten([for team, users in var.teams_map_users : team])
  teams_map_users = flatten([
    for team, users in var.teams_map_users : [
      for user in users : {
        team = team
        user = user
      }
    ]
  ])
  default_policies = [
    "${vault_policy.infrastructure_policy.name}",
    "${vault_policy.secret_policy.name}",
  ] 
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = var.userpass_path
  tune {
    listing_visibility = "unauth"
  }
}

# User
resource "vault_generic_endpoint" "user" {
  for_each             = toset(local.list_users)
  path                 = "auth/${vault_auth_backend.userpass.path}/users/${each.value}"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["${vault_policy.user_policy.name}"],
  "password": "${var.user_default_password}"
}
EOT

  depends_on = [vault_auth_backend.userpass]
}

resource "vault_identity_entity" "entity" {
  for_each = toset(local.list_users)
  name     = each.value
}

resource "vault_identity_entity_alias" "entity_alias" {
  for_each       = toset(local.list_users)
  name           = each.value
  mount_accessor = vault_auth_backend.userpass.accessor
  canonical_id   = vault_identity_entity.entity["${each.value}"].id
}

# Group
resource "vault_identity_group" "internal" {
  for_each = toset(local.list_groups)
  name     = each.value
  type     = "internal"

  external_policies = true

  lifecycle {
    ignore_changes = [
      member_entity_ids
    ]
  }
}

resource "vault_identity_group_policies" "attach_group_policies" {
  for_each = vault_identity_group.internal

  policies = each.value.name == "devops" ? concat([], [
    "${vault_policy.admin_policy.name}",
    "${vault_policy.group_policy["${each.value.name}"].name}", 
  ]) : concat(local.default_policies,["${vault_policy.group_policy["${each.value.name}"].name}"])

  exclusive = false

  group_id = each.value.id
}

resource "vault_identity_group_member_entity_ids" "members" {
  for_each  = var.teams_map_users
  exclusive = true
  member_entity_ids = flatten([
    for user in each.value : vault_identity_entity.entity["${user}"].id
  ])
  group_id = vault_identity_group.internal["${each.key}"].id
}