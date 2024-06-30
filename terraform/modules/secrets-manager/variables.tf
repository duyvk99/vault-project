variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "services" {
  type = any
}

variable "policies_map_roles" {
  type = any
}

#### Vault Kubernetes Auth Config
variable "enable_kubernetes_auth" {
  type = bool
}

variable "kubernetes_host" {
  type = string
  default = ""
}

variable "auth_kubernetes_path" {
  type    = string
  default = "kuberentes"
}

variable "auth_kubernetes_exists" {
  type    = string
  default = ""
}

#### Vault JWT Auth Config
variable "enable_jwt_auth" {
  type = bool
}

variable "oidc_discovery_url" {
  type = string
  default = ""
}

variable "auth_jwt_path" {
  type    = string
  default = "jwt"
}

variable "auth_jwt_exists" {
  type    = string
  default = ""
}

##### Secret
variable "secret_path" {
  type    = string
  default = "secret"
}

variable "path_exists" {
  type    = string
  default = ""
}
