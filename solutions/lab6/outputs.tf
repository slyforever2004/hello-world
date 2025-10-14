output "storage_account_id" {
  value = azurerm_storage_account.imported.id
}

output "vnet_id" {
  value = azurerm_virtual_network.imported.id
}

output "subnet_id" {
  value = azurerm_subnet.imported.id
}

output "public_ip_id" {
  value = azurerm_public_ip.imported.id
}
