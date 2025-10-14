# Resource Group outputs
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# Networking outputs
output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "ID of the application subnet"
  value       = azurerm_subnet.app.id
}

# VM outputs
output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.app.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "ssh_connection_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

# Environment information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
}

# Monitoring outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].name : null
}

# Security outputs
output "network_security_group_id" {
  description = "ID of the network security group"
  value       = azurerm_network_security_group.app.id
}

# Resource counts for monitoring
output "resource_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_groups          = 1
    virtual_networks         = 1
    subnets                  = 1
    network_security_groups  = 1
    virtual_machines         = 1
    public_ips               = 1
    network_interfaces       = 1
    log_analytics_workspaces = var.enable_monitoring ? 1 : 0
  }
}