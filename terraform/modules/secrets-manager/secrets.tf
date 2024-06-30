locals {
  services = flatten([
    for namespace, services in var.services : [
      for service in services : {
        service   = service
        namespace = namespace
      }
    ]
  ])

  policies_map_roles = flatten([
    for policy, roles in var.policies_map_roles : [
      for role in roles : {
        policy = policy
        role   = role
      }
    ]
  ])
}

#### Create KV-V2
resource "vault_mount" "secret" {
  count       = length(var.path_exists) > 0 ? 0 : 1
  path        = var.secret_path
  type        = "kv"
  options     = { version = "2" }
  description = "Central Secrets manager"
}

#### Create Secret
resource "vault_kv_secret_v2" "secret" {
  for_each            = var.policies_map_roles
  mount               = length(var.path_exists) > 0 ? "${var.path_exists}" : vault_mount.secret[0].path
  name                = "${var.project}/${var.environment}/${each.key}"
  cas                 = 1
  delete_all_versions = true
  data_json           = jsonencode({})
  custom_metadata {
    max_versions = 5
    data = {
      project = "${var.project}",
      bar     = "${var.environment}"
    }
  }
}