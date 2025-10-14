# Output the Web App ID
output "web_app_id" {
  description = "The ID of the Azure Linux Web App"
  value       = azurerm_linux_web_app.this.id
}

# Output the default hostname
output "default_hostname" {
  description = "The default hostname of the Azure Linux Web App"
  value       = azurerm_linux_web_app.this.default_hostname
}

# Output the service plan ID
output "service_plan_id" {
  description = "The ID of the Azure Service Plan"
  value       = azurerm_service_plan.this.id
}

# Output the Web App URL
output "web_app_url" {
  description = "The URL of the Azure Linux Web App"
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
}

# Output the managed identity principal ID (if enabled)
output "principal_id" {
  description = "The Principal ID of the system-assigned managed identity"
  value       = var.enable_system_identity ? azurerm_linux_web_app.this.identity[0].principal_id : null
}

# Output the managed identity tenant ID (if enabled)
output "tenant_id" {
  description = "The Tenant ID of the system-assigned managed identity"
  value       = var.enable_system_identity ? azurerm_linux_web_app.this.identity[0].tenant_id : null
}

# Output the Web App kind
output "kind" {
  description = "The kind of the Azure Linux Web App"
  value       = azurerm_linux_web_app.this.kind
}

# Output custom domain verification ID
output "custom_domain_verification_id" {
  description = "The custom domain verification ID for the Azure Linux Web App"
  value       = azurerm_linux_web_app.this.custom_domain_verification_id
}
