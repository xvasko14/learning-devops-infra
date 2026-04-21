variable "resource_group_name" {
  type        = string
  description = "Názov Azure Resource Group"
}

variable "location" {
  type        = string
  description = "Azure región"
  default     = "westeurope"
}

variable "acr_name" {
  type        = string
  description = "Globálne unikátny názov Azure Container Registry"
}

variable "container_image" {
  type        = string
  description = "Full image URL vrátane tagu (napr. myacr.azurecr.io/devops-lab:v1)"
}

variable "acr_username" {
  type        = string
  description = "ACR admin username"
}

variable "acr_password" {
  type        = string
  description = "ACR admin password"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH verejný kľúč pre VM prístup"
}
