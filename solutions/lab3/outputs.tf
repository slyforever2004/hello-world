# Outputs
output "policy_initiative_id" {
  description = "The ID of the policy initiative (policy set definition)"
  value       = azurerm_policy_set_definition.enterprise_governance.id
}

output "policy_assignment_id" {
  description = "The ID of the resource-group scoped policy assignment"
  value       = azurerm_resource_group_policy_assignment.enterprise_governance.id
}

output "test_resource_group_name" {
  description = "Name of the test resource group"
  value       = azurerm_resource_group.policy_testing.name
}

output "test_vm_name" {
  description = "Name of the test virtual machine"
  value       = azurerm_linux_virtual_machine.test_vm.name
}

output "policy_compliance_url" {
  description = "URL to view policy compliance in Azure Portal"
  value       = "https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyComplianceBlade"
}

output "remediation_tasks" {
  description = "Information about remediation tasks"
  value = {
    require_tag_remediation = azapi_resource.tag_remediation.id
    ama_remediation         = azapi_resource.ama_remediation.id
  }
}
