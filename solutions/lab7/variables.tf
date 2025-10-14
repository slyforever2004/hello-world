variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "lab7-rg"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Project = "lab7"
    Owner   = "platform-team"
    Team    = "platform-team"
  }
}

variable "storage_account_suffix" {
  description = "Optional suffix to make storage account globally unique"
  type        = string
  default     = ""
}
