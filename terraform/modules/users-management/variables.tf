variable "teams_map_users" {
  type = any
}

variable "userpass_path" {
  type    = string
  default = "userpass"
}

variable "user_default_password" {
  type    = string
  default = "Hello@123"
}

variable "kv_personal_path" {
  type    = string
  default = "personal"
}

variable "kv_team_path" {
  type    = string
  default = "team"
}

variable "kv_infras_path" {
  type    = string
  default = "infrastructure"
}