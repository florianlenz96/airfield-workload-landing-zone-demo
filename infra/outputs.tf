# The platform's pipeline template reads these three.
output "acr_name" {
  value = azurerm_container_registry.this.name
}

output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "webapp_name" {
  value = azurerm_linux_web_app.api.name
}

output "api_url" {
  value = "https://${azurerm_linux_web_app.api.default_hostname}"
}
