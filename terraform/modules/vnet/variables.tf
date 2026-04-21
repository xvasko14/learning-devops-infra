variable "name" {
  type        = string
  description = "Názov VNet"
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "CIDR blok pre VNet"
}

variable "subnet_address_prefix" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR blok pre Container Apps subnet"
}
