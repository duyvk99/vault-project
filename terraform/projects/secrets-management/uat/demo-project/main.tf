module "secrets-manager" {
  source             = "../../../../modules/secrets-manager/"
  services           = local.services
  policies_map_roles = local.secrets_map_services
  project            = var.project
  environment        = var.environment

  #### Vault Kubernetes Auth Config
  enable_kubernetes_auth = var.enable_kubernetes_auth
  kubernetes_host        = var.kubernetes_host
  auth_kubernetes_path   = var.auth_kubernetes_path
  auth_kubernetes_exists = var.auth_kubernetes_exists

  #### Vault Kubernetes JWT Config
  enable_jwt_auth    = var.enable_jwt_auth
  auth_jwt_path      = var.auth_jwt_path
  auth_jwt_exists    = var.auth_jwt_exists
  oidc_discovery_url = var.oidc_discovery_url

  # Secret
  secret_path = var.secret_path
  path_exists = var.path_exists
}
