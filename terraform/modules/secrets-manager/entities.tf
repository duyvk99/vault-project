# Create entities
resource "vault_identity_entity" "entity" {
  for_each                         = { for idx, role in local.services : "${var.project}-${var.environment}-${role.service}" => role }
  name      =  "${var.project}-${var.environment}-${each.value.service}"
  policies  = flatten([
    for policy in local.policies_map_roles :
    policy.role == each.value.service ? [
      "${var.project}/${var.environment}/${policy.policy}"
    ] : []
  ])

  metadata  = {
    project = "${var.project}",
    environment = "${var.environment}"
    name = "${var.project}-${var.environment}-${each.value.service}"
  }

}


