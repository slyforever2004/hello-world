# Random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}


# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = var.environment == "production" ? ["10.1.0.0/16"] : ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(var.tags, {
    Environment = var.environment
    Purpose     = "main-network"
  })
}

# Subnet for application resources
resource "azurerm_subnet" "app" {
  name                 = "subnet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.environment == "production" ? ["10.1.1.0/24"] : ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "app" {
  name                = "${var.project_name}-${var.environment}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # HTTP access (for testing)
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS access
  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Purpose     = "network-security"
  })
}

# SSH rule (wildcard case)
resource "azurerm_network_security_rule" "ssh_wildcard" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Public IP for the VM
resource "azurerm_public_ip" "vm" {
  name                = "${var.project_name}-${var.environment}-vm-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(var.tags, {
    Environment = var.environment
    Purpose     = "vm-public-access"
  })
}

# Network Interface for VM
resource "azurerm_network_interface" "vm" {
  name                = "${var.project_name}-${var.environment}-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Purpose     = "vm-network-interface"
  })
}

# Generate SSH key for VM access (if local key doesn't exist)
resource "tls_private_key" "vm" {
  count     = fileexists("~/.ssh/id_rsa.pub") ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_ssh_public_key" "vm" {
  name                = "${var.project_name}-${var.environment}-vm-ssh-key"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  public_key          = fileexists("~/.ssh/id_rsa.pub") ? file("~/.ssh/id_rsa.pub") : tls_private_key.vm[0].public_key_openssh

  tags = merge(var.tags, {
    Environment = var.environment
    Purpose     = "vm-ssh-access"
  })
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "app" {
  name                = "${var.project_name}-${var.environment}-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = fileexists("~/.ssh/id_rsa.pub") ? file("~/.ssh/id_rsa.pub") : tls_private_key.vm[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.environment == "production" ? "Premium_LRS" : "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Custom data script for initial setup
  custom_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yml", {
    environment = var.environment
    hostname    = "${var.project_name}-${var.environment}-vm"
  }))

  tags = merge(var.tags, {
    Environment = var.environment
    Purpose     = "application-server"
    Tier        = "web"
  })
}

# Log Analytics Workspace (if monitoring enabled)
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "${var.project_name}-${var.environment}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "production" ? 90 : 30

  tags = merge(var.tags, {
    Environment = var.environment
    Purpose     = "monitoring"
  })
}
