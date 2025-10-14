resource "azurerm_network_interface" "nic" {
  name                = "${var.name_prefix}-nic"
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.vnet_id != "" ? regex(".*/resourceGroups/([^/]+)/.*", data.terraform_remote_state.network.outputs.vnet_id)[0] : "REPLACE-RG" # simple derive RG from vnet id (first capture)

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = data.terraform_remote_state.network.outputs.subnet_ids["app-subnet"]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "${var.name_prefix}-vm"
  location                        = var.location
  resource_group_name             = azurerm_network_interface.nic.resource_group_name
  size                            = "Standard_B2s"
  disable_password_authentication = false
  admin_username                  = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_password = "ChangeM3!" # For demo only - replace with Key Vault retrieval in later lab

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
