output "vault_auth_group_id" {
  value = vault_identity_group.internal[*]
}