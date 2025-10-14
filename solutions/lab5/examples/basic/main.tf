terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "southeastasia"
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Create a resource group for the example
resource "azurerm_resource_group" "example" {
  name     = "rg-lab5-example-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "lab5-module-example"
    CreatedBy   = "terraform"
  }
}

# Deploy the web app module with enhanced configuration
module "web_app" {
  source = "../../modules/web_app"

  name                = "lab5-example-web-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name

  # App Service Plan configuration
  sku       = "B1"
  always_on = true

  # Security settings
  https_only = true

  # Application stack
  node_version = "18-lts"

  # App settings
  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "NODE_ENV"                     = var.environment
    "APP_ENV"                      = var.environment
  }

  # Enable managed identity
  enable_system_identity = true

  # Tags
  tags = {
    Environment = var.environment
    Module      = "web_app"
    Example     = "basic"
    CreatedBy   = "terraform"
  }
}

# Output examples
output "web_app_url" {
  description = "The URL of the deployed web app"
  value       = module.web_app.web_app_url
}

output "web_app_hostname" {
  description = "The default hostname of the web app"
  value       = module.web_app.default_hostname
}

output "managed_identity_principal_id" {
  description = "The principal ID of the managed identity"
  value       = module.web_app.principal_id
}

output "hostname" { value = module.web_app.default_hostname }
