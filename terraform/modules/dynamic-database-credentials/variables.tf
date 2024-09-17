variable "db_host" {
  type = string  
}

variable "db_username" {
    type = string
}

variable "db_name" {
  type = string 
}

variable "db_password" {
  type = string
  sensitive = true
}

variable "max_ttl" {
  type = number
  default = 600
}

variable "group_id" {
  type = string
}