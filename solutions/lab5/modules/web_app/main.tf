# Azure Web App Service Plan
resource "azurerm_service_plan" "this" {
  name                = "${var.name}-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.sku
  tags                = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Azure Linux Web App with security best practices
resource "azurerm_linux_web_app" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = var.https_only
  tags                = var.tags

  site_config {
    ftps_state                  = "Disabled"
    http2_enabled               = true
    minimum_tls_version         = "1.2"
    scm_use_main_ip_restriction = false
    use_32_bit_worker           = false
    always_on                   = var.always_on

    application_stack {
      node_version = var.node_version
    }
  }

  # System-assigned managed identity
  dynamic "identity" {
    for_each = var.enable_system_identity ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  # Application settings
  app_settings = var.app_settings

  # Connection strings
  dynamic "connection_string" {
    for_each = var.connection_strings
    content {
      name  = connection_string.value.name
      type  = connection_string.value.type
      value = connection_string.value.value
    }
  }

  # Sticky settings
  dynamic "sticky_settings" {
    for_each = length(var.sticky_app_setting_names) > 0 || length(var.sticky_connection_string_names) > 0 ? [1] : []
    content {
      app_setting_names       = var.sticky_app_setting_names
      connection_string_names = var.sticky_connection_string_names
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to app_settings that might be managed outside Terraform
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}
