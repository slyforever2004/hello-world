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

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "name_prefix" {
  type    = string
  default = "lab1net"
}

resource "azurerm_resource_group" "net" {
  name     = "${var.name_prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_prefix}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
}

resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
}

output "vnet_id" { value = azurerm_virtual_network.vnet.id }
output "subnet_ids" {
  value = {
    (azurerm_subnet.app.name) = azurerm_subnet.app.id
    (azurerm_subnet.db.name)  = azurerm_subnet.db.id
  }
}
