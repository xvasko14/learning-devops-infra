terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
  required_version = ">= 1.5"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

module "vnet" {
  source = "../../modules/vnet"

  name                = "${var.resource_group_name}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

module "app" {
  source = "../../modules/container_app"

  app_name                 = "devops-lab-app"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  infrastructure_subnet_id = module.vnet.subnet_id
  container_image          = var.container_image
  acr_login_server         = azurerm_container_registry.main.login_server
  acr_username             = var.acr_username
  acr_password             = var.acr_password
}

module "vm" {
  source = "../../modules/vm"

  name                = "devops-lab-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.vnet.vm_subnet_id
  ssh_public_key      = var.ssh_public_key
}
