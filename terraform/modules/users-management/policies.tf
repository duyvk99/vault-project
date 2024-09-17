####################
### Admin Policy ###
####################
resource "vault_policy" "admin_policy" {
  name   = "admin-policy"
  policy = <<EOT
# Read system health check
path "sys/health"
{
  capabilities = ["read", "sudo"]
}

# Create and manage ACL policies broadly across Vault

# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# Create and manage ACL policies
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Enable and manage authentication methods broadly across Vault

# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# Identity
path "identity/*" {
  capabilities = ["read", "list", "create", "update", "delete"]
}

# Enable and manage the key/value secrets engine at `secret/` path
# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "infrastructure/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}
EOT
}

####################
# User Policy
####################
resource "vault_policy" "user_policy" {
  name   = "user-policy"
  policy = <<EOT
path "sys/auth" {
  capabilities = ["read"]
}

path "auth/${vault_auth_backend.userpass.path}/users" {
  capabilities = ["list"]
}

path "auth/${vault_auth_backend.userpass.path}/users/{{identity.entity.aliases.${vault_auth_backend.userpass.accessor}.name}}" {
  capabilities = ["update", "read"]
  allowed_parameters = {
    "*" = []
    "token_policies" = [["user-policy"]]
  }
}

path "${vault_mount.personal.path}/metadata/" {
  capabilities = ["list"]
}

path "${vault_mount.personal.path}/metadata/{{identity.entity.aliases.${vault_auth_backend.userpass.accessor}.name}}/" {
	capabilities = ["list"]
}

path "${vault_mount.personal.path}/data/{{identity.entity.aliases.${vault_auth_backend.userpass.accessor}.name}}/*" {
	capabilities = ["create", "update", "patch", "read", "delete", "list"]
}

path "${vault_mount.personal.path}/destroy/{{identity.entity.aliases.${vault_auth_backend.userpass.accessor}.name}}/*" {
  capabilities = ["update", "delete"]
}

path "${vault_mount.personal.path}/metadata/{{identity.entity.aliases.${vault_auth_backend.userpass.accessor}.name}}/*" {
	capabilities = ["create", "update", "patch", "read", "delete", "list"]
}
EOT

  depends_on = [vault_auth_backend.userpass]
}

####################
# Infrastructure Policy
####################

resource "vault_policy" "infrastructure_policy" {
  name   = "infrastructure-policy"
  policy = <<EOT
path "infrastructure/data/stg/*" {
  capabilities = ["deny"]
}

path "infrastructure/*" {
  capabilities = ["read", "list"]
}
EOT
}

####################
# Secrets Policy
####################
resource "vault_policy" "secret_policy" {
  name   = "secret-policy"
  policy = <<EOT
path "secret/data/+/stg/*" {
  capabilities = ["deny"]
}

path "secret/*"
{
  capabilities = ["read", "list"]
}
EOT
}

####################
### Group Policy ###
####################
resource "vault_policy" "group_policy" {
  for_each = var.teams_map_users
  name     = each.key
  policy   = <<EOT
path "${vault_mount.team.path}/metadata/" {
  capabilities = ["list"]
}

path "${vault_mount.team.path}/metadata/${each.key}/" {
  capabilities = ["list"]
}

path "${vault_mount.team.path}/data/${each.key}/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "${vault_mount.team.path}/metadata/${each.key}/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}
