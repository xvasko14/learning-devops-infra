resource "azurerm_container_app_environment" "main" {
  name                     = "${var.app_name}-env"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  infrastructure_subnet_id = var.infrastructure_subnet_id
}

resource "azurerm_container_app" "main" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  registry {
    server               = var.acr_login_server
    username             = var.acr_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = var.acr_password
  }

  template {
    container {
      name   = var.app_name
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory
    }
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }

  ingress {
    external_enabled = true
    target_port      = var.target_port
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
