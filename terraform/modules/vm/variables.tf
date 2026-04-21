variable "name" {
  type        = string
  description = "Názov VM"
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID pre network interface"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH verejný kľúč pre prístup k VM"
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}
