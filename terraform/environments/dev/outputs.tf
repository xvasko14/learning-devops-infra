output "app_url" {
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
  description = "URL nasadenej aplikácie"
}

output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "ACR login server pre docker push"
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}
