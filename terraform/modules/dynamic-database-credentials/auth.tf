# Group
resource "vault_identity_group_policies" "database_admin_policy" {
  policies = [
    vault_policy.db_admin_policy.name,
  ]

  exclusive = false

  group_id = var.group_id
}