resource "vault_policy" "policy" {
  for_each = var.policies_map_roles
  name     = "${var.project}/${var.environment}/${each.key}"
  policy   = <<EOT
path "${length(var.secret_path) > 0 ? "${var.secret_path}" : vault_mount.secret[0].path}/data/${var.project}/${var.environment}/${each.key}" {
  capabilities = ["read","list"]
}
EOT
}
