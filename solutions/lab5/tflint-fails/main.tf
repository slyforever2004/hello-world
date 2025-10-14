terraform {
  # Missing required_version (triggers terraform_required_version)
}

# Missing required_providers block (triggers terraform_required_providers)

# Deprecated interpolation (terraform_deprecated_interpolation)
locals {
  app_name = "MyApp"
}

# Deprecated index syntax (terraform_deprecated_index)
locals {
  first_rg = local.rg_names.0
  rg_names = ["rgA", "rgB"]
}

/* Wrong comment style maybe flagged (terraform_comment_syntax) */

# Undocumented variable (terraform_documented_variables)
variable "AppName" {
  type = string
  # Bad naming (capital letter) (terraform_naming_convention)
}

# Untyped variable (terraform_typed_variables)
variable "env" {}

# Undocumented output (terraform_documented_outputs)
output "AppName_out" {
  value = var.AppName
}

# Unused variable (terraform_unused_declarations)
variable "unused_var" {
  type        = string
  description = "Not referenced anywhere"
  default     = "x"
}

# Unused provider (terraform_unused_required_providers once added below)
provider "azurerm" {
  features {}
}

module "random_pet_example" {
  # Unpinned source (terraform_module_pinned_source)
  source = "github.com/hashicorp/example"
}

resource "azurerm_resource_group" "RGMain" { # Bad naming (camel case)
  name     = "rg-${var.AppName}"
  location = "eastus"
}
