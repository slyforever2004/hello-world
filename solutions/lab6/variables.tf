variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region for imported resources (must match existing)."
}

# Subscription ID placeholder used inside import blocks (cannot be inferred automatically there).
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID containing the existing resources. Provide via TF_VAR_subscription_id or terraform.tfvars."
}

variable "resource_group_name" {
  type        = string
  default     = "lab6-rg"
  description = "Existing resource group that will host the pre-created resources. We will not import the RG (data source only) to demonstrate selective adoption."
}

variable "storage_account_name" {
  type        = string
  default     = "lab6importsa"
  description = "Existing storage account to import (must be globally unique, 3-24 lowercase)."
}

variable "container_name" {
  type        = string
  default     = "tfstate"
  description = "Existing storage container inside the storage account to import."
}

variable "vnet_name" {
  type        = string
  default     = "lab6-vnet"
  description = "Existing virtual network to import."
}

variable "subnet_name" {
  type        = string
  default     = "default"
  description = "Existing subnet inside the virtual network to import."
}

variable "public_ip_name" {
  type        = string
  default     = "lab6-public-ip"
  description = "Existing Public IP to import."
}
