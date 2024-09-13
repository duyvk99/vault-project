module "users-management" {
  source         = "../../modules/users-management"
  teams_map_users = var.teams_map_users
}