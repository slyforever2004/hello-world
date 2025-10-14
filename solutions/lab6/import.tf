# Terraform 1.5+ import blocks.
# After writing these, run: terraform init && terraform plan (or apply) and Terraform will ingest remote objects into state.
# Comment/uncomment selectively if demonstrating failures or partial imports.

import {
  to = azurerm_storage_account.imported
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
}

import {
  to = azurerm_storage_container.imported
  id = "https://${var.storage_account_name}.blob.core.windows.net/${var.container_name}"
}

import {
  to = azurerm_virtual_network.imported
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}"
}

import {
  to = azurerm_subnet.imported
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.subnet_name}"
}

import {
  to = azurerm_public_ip.imported
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Network/publicIPAddresses/${var.public_ip_name}"
}

# NOTE: Replace subscription_id variable (see variables.tf addition) with actual subscription ID or export TF_VAR_subscription_id
