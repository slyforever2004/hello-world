terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    alz = {
      source  = "azure/alz"
      version = "~> 0.19"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.management_subscription_id
}

provider "azurerm" {
  alias           = "connectivity"
  features {}
  subscription_id = var.connectivity_subscription_id
}

provider "alz" {
  library_references = [
    {
      path = "platform/alz"
      ref  = "2025.02.0"
    }
  ]
}

variable "management_subscription_id" { type = string }
variable "connectivity_subscription_id" { type = string }
variable "location" {
  type    = string
  default = "southeastasia"
}
