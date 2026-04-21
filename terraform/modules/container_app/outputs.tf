output "app_fqdn" {
  value       = azurerm_container_app.main.ingress[0].fqdn
  description = "FQDN aplikácie (bez https://)"
}

output "app_url" {
  value = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}

output "environment_id" {
  value = azurerm_container_app_environment.main.id
}
