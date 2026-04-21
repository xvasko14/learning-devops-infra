terraform {
  backend "azurerm" {
    resource_group_name  = "devops-lab-rg-tf"
    storage_account_name = "devopslabstatedcbd53c0"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
  }
}
