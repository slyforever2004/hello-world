# Lab 6 core resource definitions to match existing (out-of-band created) Azure resources.
# IMPORTANT: These blocks must reflect the actual remote configuration; otherwise the first plan after import will show drift.

# We intentionally DO NOT manage the resource group; we reference it via data source to demonstrate selective adoption.
data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

resource "azurerm_storage_account" "imported" {
  name                             = var.storage_account_name
  resource_group_name              = data.azurerm_resource_group.existing.name
  location                         = data.azurerm_resource_group.existing.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  shared_access_key_enabled        = false
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  min_tls_version                  = "TLS1_0"
  # Keep minimal arguments; many attributes (enable_https_traffic_only, min_tls_version, etc.) are computed/defaults.
  # Adjust only AFTER successful import + zero-drift plan.
}

resource "azurerm_storage_container" "imported" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.imported.name
  container_access_type = "private"
}

resource "azurerm_virtual_network" "imported" {
  name                = var.vnet_name
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  address_space       = ["10.60.0.0/16"] # Must match existing VNet; update if script changed.
}

resource "azurerm_subnet" "imported" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.imported.name
  address_prefixes     = ["10.60.1.0/24"] # Must match existing subnet.
}

resource "azurerm_public_ip" "imported" {
  name                = var.public_ip_name
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  allocation_method   = "Static"
  sku                 = "Standard"
  # NOTE: If existing public IP was Basic or Dynamic adjust here BEFORE import.
}
