#### Create KV-V2
resource "vault_mount" "personal" {
  path        = var.kv_personal_path
  type        = "kv"
  options     = { version = "2" }
  description = "Personal Secret"
}

#### Create Secret
resource "vault_kv_secret_v2" "personal_secret" {
  for_each            = toset(local.list_users)
  mount               = vault_mount.personal.path
  name                = "${each.value}/init"
  cas                 = 1
  delete_all_versions = true
  data_json           = jsonencode({})
  custom_metadata {
    max_versions = 5
  }
}

#### Create KV-V2
resource "vault_mount" "team" {
  path        = var.kv_team_path
  type        = "kv"
  options     = { version = "2" }
  description = "Team Secret"
}

#### Create Secret
resource "vault_kv_secret_v2" "team_secret" {
  for_each            = toset(local.list_groups)
  mount               = vault_mount.team.path
  name                = "${each.value}/init"
  cas                 = 1
  delete_all_versions = true
  data_json           = jsonencode({})
  custom_metadata {
    max_versions = 5
  }
}

#### Create KV-V2
resource "vault_mount" "infrastructure" {
  path        = var.kv_infras_path
  type        = "kv"
  options     = { version = "2" }
  description = "Infrastructure Secret"
}