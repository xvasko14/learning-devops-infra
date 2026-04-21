variable "app_name" {
  type        = string
  description = "Názov Container App"
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "infrastructure_subnet_id" {
  type        = string
  description = "Subnet ID pre Container App Environment"
}

variable "container_image" {
  type        = string
  description = "Full image URL (napr. myacr.azurecr.io/app:v1)"
}

variable "acr_login_server" {
  type = string
}

variable "acr_username" {
  type = string
}

variable "acr_password" {
  type      = string
  sensitive = true
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 0.5
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 3
}
