output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_id" {
  value = azurerm_subnet.container_apps.id
}

output "vm_subnet_id" {
  value = azurerm_subnet.vm.id
}
