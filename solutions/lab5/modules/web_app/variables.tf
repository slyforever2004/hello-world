# Required variables
variable "name" {
  description = "The name of the web app. Must be globally unique."
  type        = string

  validation {
    condition     = length(var.name) >= 2 && length(var.name) <= 60
    error_message = "Web app name must be between 2 and 60 characters."
  }
}

variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the web app."
  type        = string
}

# Optional variables with defaults
variable "sku" {
  description = "The SKU for the App Service Plan. Valid options include B1, B2, B3, S1, S2, S3, P1v2, P2v2, P3v2, P1v3, P2v3, P3v3."
  type        = string
  default     = "B1"

  validation {
    condition = contains([
      "B1", "B2", "B3",       # Basic
      "S1", "S2", "S3",       # Standard  
      "P1v2", "P2v2", "P3v2", # Premium v2
      "P1v3", "P2v3", "P3v3"  # Premium v3
    ], var.sku)
    error_message = "SKU must be a valid App Service Plan SKU."
  }
}

variable "tags" {
  description = "A mapping of tags to assign to the resources."
  type        = map(string)
  default     = {}
}

variable "enable_system_identity" {
  description = "Whether to enable system-assigned managed identity for the web app."
  type        = bool
  default     = true
}

variable "https_only" {
  description = "Whether the web app should only accept HTTPS traffic."
  type        = bool
  default     = true
}

variable "always_on" {
  description = "Should the app be loaded at all times? Required for Premium SKUs."
  type        = bool
  default     = true
}

variable "node_version" {
  description = "The Node.js version to use for the web app."
  type        = string
  default     = "18-lts"

  validation {
    condition = contains([
      "16-lts", "18-lts", "20-lts"
    ], var.node_version)
    error_message = "Node version must be a supported LTS version."
  }
}

variable "app_settings" {
  description = "A map of key-value pairs for app settings."
  type        = map(string)
  default     = {}
}

variable "connection_strings" {
  description = "A list of connection strings for the web app."
  type = list(object({
    name  = string
    type  = string
    value = string
  }))
  default = []
}

variable "sticky_app_setting_names" {
  description = "A list of app setting names that should be sticky (not swapped during deployment slots)."
  type        = list(string)
  default     = []
}

variable "sticky_connection_string_names" {
  description = "A list of connection string names that should be sticky (not swapped during deployment slots)."
  type        = list(string)
  default     = []
}
