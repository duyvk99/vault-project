variable "address" {
  type = string
}

variable "token" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

#### Vault Kubernetes Auth Config
variable "enable_kubernetes_auth" {
  type    = bool
  default = false
}

variable "kubernetes_host" {
  type = string
}

variable "auth_kubernetes_path" {
  type    = string
  default = "kubernetes-uat"
}

variable "auth_kubernetes_exists" {
  type    = string
  default = ""
}

#### Vault Kubernetes Auth Config
variable "enable_jwt_auth" {
  type    = bool
  default = true
}

variable "oidc_discovery_url" {
  type    = string
  default = ""
}

variable "auth_jwt_path" {
  type    = string
  default = "jwt-uat"
}

variable "auth_jwt_exists" {
  type    = string
  default = ""
}

#### Secret
variable "secret_path" {
  type    = string
  default = "secret"
}

variable "path_exists" {
  type    = string
  default = ""
}
