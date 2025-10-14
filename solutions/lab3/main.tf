# Data Sources
data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

# Create Log Analytics Workspace if not provided
resource "azurerm_resource_group" "logs" {
  count    = var.log_analytics_workspace_id == null ? 1 : 0
  name     = "lab3-policy-logs-rg"
  location = var.location

  tags = {
    Environment = "lab3"
    Purpose     = "policy governance"
  }
}

resource "azurerm_log_analytics_workspace" "policy_logs" {
  count               = var.log_analytics_workspace_id == null ? 1 : 0
  name                = "law-policy-governance"
  location            = azurerm_resource_group.logs[0].location
  resource_group_name = azurerm_resource_group.logs[0].name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = "lab3"
    Purpose     = "policy governance"
  }
}

locals {
  log_analytics_workspace_id = var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.policy_logs[0].id
}

# Custom Policy Definitions
resource "azurerm_policy_definition" "require_tag" {
  name         = "require-${var.tag_name}-tag"
  display_name = "Require ${var.tag_name} Tag with Modify Effect"
  description  = "This policy requires resources to have the ${var.tag_name} tag. If the tag is missing, it will be added with the specified value using the modify effect."
  policy_type  = "Custom"
  mode         = "Indexed"
  metadata = jsonencode({
    category = "Tags"
    version  = "1.0.0"
  })

  policy_rule = file("${path.module}/policies/require-tag.json")

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "Tag Name"
        description = "Name of the tag to require"
      }
    }
    tagValue = {
      type = "String"
      metadata = {
        displayName = "Tag Value"
        description = "Value to assign to the tag if missing"
      }
    }
  })
}

resource "azurerm_policy_definition" "require_disk_encryption" {
  name         = "require-disk-encryption"
  display_name = "Require Disk Encryption on Virtual Machines"
  description  = "This policy denies creation of virtual machines that do not have disk encryption enabled."
  policy_type  = "Custom"
  mode         = "Indexed"
  metadata = jsonencode({
    category = "Security"
    version  = "1.0.0"
  })

  policy_rule = file("${path.module}/policies/require-disk-encryption.json")
}

resource "azurerm_policy_definition" "deploy_ama" {
  name         = "deploy-ama-linux-vms"
  display_name = "Deploy Azure Monitor Agent to Linux VMs"
  description  = "This policy ensures Azure Monitor Agent is installed on Linux virtual machines using deployIfNotExists effect."
  policy_type  = "Custom"
  mode         = "Indexed"
  metadata = jsonencode({
    category = "Monitoring"
    version  = "1.0.0"
  })

  policy_rule = file("${path.module}/policies/ensure-ama.json")

  parameters = jsonencode({
    logAnalyticsWorkspaceId = {
      type = "String"
      metadata = {
        displayName = "Log Analytics Workspace ID"
        description = "Resource ID of the Log Analytics workspace"
      }
    }
  })
}

# Policy Initiative (Policy Set Definition)
resource "azurerm_policy_set_definition" "enterprise_governance" {
  name         = "enterprise-governance-initiative"
  display_name = "Enterprise Governance Initiative"
  description  = "Comprehensive policy set for enterprise governance including tagging, security, and monitoring requirements."
  policy_type  = "Custom"
  metadata = jsonencode({
    category = "Enterprise Governance"
    version  = "1.0.0"
  })

  # Policy 1: Require specific tag with modify effect
  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_tag.id
    reference_id         = "RequireTag"

    parameter_values = jsonencode({
      tagName = {
        value = var.tag_name
      }
      tagValue = {
        value = var.tag_value
      }
    })
  }

  # Policy 2: Require disk encryption with deny effect
  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_disk_encryption.id
    reference_id         = "RequireDiskEncryption"
  }

  # Policy 3: Deploy Azure Monitor Agent with deployIfNotExists effect
  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deploy_ama.id
    reference_id         = "DeployAMA"

    parameter_values = jsonencode({
      logAnalyticsWorkspaceId = {
        value = local.log_analytics_workspace_id
      }
    })
  }
}

# Policy Assignment scoped to the policy_testing Resource Group
resource "azurerm_resource_group_policy_assignment" "enterprise_governance" {
  name                 = "enterprise-governance-assignment"
  display_name         = "Enterprise Governance Policy Assignment (RG)"
  resource_group_id    = azurerm_resource_group.policy_testing.id
  policy_definition_id = azurerm_policy_set_definition.enterprise_governance.id
  location             = var.location
  enforce              = true

  identity { type = "SystemAssigned" }

  depends_on = [
    azurerm_policy_set_definition.enterprise_governance,
    azurerm_resource_group.policy_testing
  ]
}

# Role Assignment for Policy Remediation
resource "azurerm_role_assignment" "policy_remediation_contributor" {
  scope                = azurerm_resource_group.policy_testing.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.enterprise_governance.identity[0].principal_id

  depends_on = [
    azurerm_resource_group_policy_assignment.enterprise_governance
  ]
}

resource "azurerm_role_assignment" "policy_remediation_vm_contributor" {
  scope                = azurerm_resource_group.policy_testing.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.enterprise_governance.identity[0].principal_id

  depends_on = [
    azurerm_resource_group_policy_assignment.enterprise_governance
  ]
}

# Test Resources for Policy Compliance Demonstration
resource "azurerm_resource_group" "policy_testing" {
  name     = var.resource_group_name
  location = var.location

  # Intentionally missing the required tag to test policy remediation
  tags = {
    Environment = "lab3"
    Purpose     = "policy testing"
  }
}

# Virtual Network for Test VM
resource "azurerm_virtual_network" "test_vnet" {
  name                = "vnet-policy-test"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.policy_testing.location
  resource_group_name = azurerm_resource_group.policy_testing.name

  tags = {
    Environment = "lab3"
    Purpose     = "policy testing"
  }
}

resource "azurerm_subnet" "test_subnet" {
  name                 = "subnet-vms"
  resource_group_name  = azurerm_resource_group.policy_testing.name
  virtual_network_name = azurerm_virtual_network.test_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "test_nsg" {
  name                = "nsg-policy-test"
  location            = azurerm_resource_group.policy_testing.location
  resource_group_name = azurerm_resource_group.policy_testing.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "lab3"
    Purpose     = "policy testing"
  }
}

# Public IP for Test VM
resource "azurerm_public_ip" "test_vm_pip" {
  name                = "pip-policy-test"
  location            = azurerm_resource_group.policy_testing.location
  resource_group_name = azurerm_resource_group.policy_testing.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "lab3"
    Purpose     = "policy testing"
  }
}

# Network Interface for Test VM
resource "azurerm_network_interface" "test_vm_nic" {
  name                = "nic-policy-test"
  location            = azurerm_resource_group.policy_testing.location
  resource_group_name = azurerm_resource_group.policy_testing.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test_vm_pip.id
  }

  tags = {
    Environment = "lab3"
    Purpose     = "policy testing"
  }
}

# Associate Network Security Group to Network Interface
resource "azurerm_network_interface_security_group_association" "test_vm_nsg_association" {
  network_interface_id      = azurerm_network_interface.test_vm_nic.id
  network_security_group_id = azurerm_network_security_group.test_nsg.id
}

# Test Linux Virtual Machine (intentionally non-compliant)
resource "azurerm_linux_virtual_machine" "test_vm" {
  name                = "vm-policy-test"
  location            = azurerm_resource_group.policy_testing.location
  resource_group_name = azurerm_resource_group.policy_testing.name
  size                = "Standard_B1s"
  admin_username      = var.vm_admin_username

  # Enable password authentication (lab requirement)
  disable_password_authentication = false
  admin_password                  = var.vm_admin_password

  network_interface_ids = [
    azurerm_network_interface.test_vm_nic.id,
  ]

  # SSH key block removed; using password authentication

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    # Intentionally not enabling encryption to test policy
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Intentionally missing the required tag to test policy remediation
  tags = {
    Environment = "lab3"
    Purpose     = "policy testing"
  }
}

# Remediation Tasks
# Remediation for tag policy
# (Replaced unsupported azurerm_policy_remediation with azapi_resource)
resource "azapi_resource" "tag_remediation" {
  type      = "Microsoft.PolicyInsights/remediations@2021-10-01"
  name      = "remediate-missing-tags"
  parent_id = azurerm_resource_group.policy_testing.id

  body = jsonencode({
    properties = {
      policyAssignmentId          = azurerm_resource_group_policy_assignment.enterprise_governance.id
      policyDefinitionReferenceId = "RequireTag"
      resourceDiscoveryMode       = "ReEvaluateCompliance"
      filters = {
        locations = [var.location]
      }
    }
  })

  depends_on = [
    azurerm_resource_group_policy_assignment.enterprise_governance,
    azurerm_role_assignment.policy_remediation_contributor,
    azurerm_linux_virtual_machine.test_vm
  ]
}

# Remediation for AMA deployment (unchanged)
resource "azapi_resource" "ama_remediation" {
  type      = "Microsoft.PolicyInsights/remediations@2021-10-01"
  name      = "remediate-ama-deployment"
  parent_id = azurerm_resource_group.policy_testing.id

  body = jsonencode({
    properties = {
      policyAssignmentId          = azurerm_resource_group_policy_assignment.enterprise_governance.id
      policyDefinitionReferenceId = "DeployAMA"
      resourceDiscoveryMode       = "ReEvaluateCompliance"
      filters = {
        locations = [var.location]
      }
    }
  })

  depends_on = [
    azurerm_resource_group_policy_assignment.enterprise_governance,
    azurerm_role_assignment.policy_remediation_vm_contributor,
    azurerm_linux_virtual_machine.test_vm
  ]
}
