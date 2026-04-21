output "public_ip" {
  value       = azurerm_public_ip.main.ip_address
  description = "Verejná IP adresa VM"
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.main.id
}
