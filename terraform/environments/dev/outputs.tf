output "app_url" {
  value       = module.app.app_url
  description = "URL nasadenej aplikácie"
}

output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "ACR login server pre docker push"
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}
