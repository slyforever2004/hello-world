terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
  backend "azurerm" {
    container_name   = "tfstate"
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}
}

variable "name_prefix" {
  type    = string
  default = "lab1app"
}
variable "location" {
  type    = string
  default = "southeastasia"
}

# Backend configuration variables for remote state
variable "backend_resource_group_name" {
  type        = string
  description = "Resource group name for the backend storage account"
}

variable "backend_storage_account_name" {
  type        = string
  description = "Storage account name for the backend"
}

variable "backend_container_name" {
  type        = string
  description = "Storage container name for the backend"
  default     = "tfstate"
}

# Remote state from networking layer
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "infrastructure.tfstate"
    use_azuread_auth     = true
  }
}
