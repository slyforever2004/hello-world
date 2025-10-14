# Input Variables
variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Name of the resource group for testing policy compliance"
  type        = string
  default     = "lab3-rg"
}

variable "tag_name" {
  description = "The name of the required tag"
  type        = string
  default     = "cost-center"
  
  validation {
    condition     = length(var.tag_name) > 0
    error_message = "Tag name cannot be empty."
  }
}

variable "tag_value" {
  description = "The value for the required tag"
  type        = string
  default     = "lab3"
  
  validation {
    condition     = length(var.tag_value) > 0
    error_message = "Tag value cannot be empty."
  }
}

variable "log_analytics_workspace_id" {
  description = "The resource ID of the Log Analytics workspace for Azure Monitor Agent"
  type        = string
  default     = null
}

variable "vm_admin_username" {
  description = "Admin username for the test VM"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  description = "Admin password for the test VM (must meet Azure complexity requirements)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.vm_admin_password) >= 12
    error_message = "Admin password must be at least 12 characters long."
  }
}
