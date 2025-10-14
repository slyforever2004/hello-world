# Staging Environment Configuration
environment  = "staging"
location     = "southeastasia"
project_name = "lab4"

# VM Configuration for staging
vm_size        = "Standard_B1s"
admin_username = "azureuser"

# Monitoring settings
enable_monitoring = false # Disable for cost optimization in staging

# Backup settings
backup_retention_days = 7

# Resource tags
tags = {
  Environment = "staging"
  Project     = "lab4"
  ManagedBy   = "terraform"
  CreatedBy   = "github-actions"
  CostCenter  = "development"
  Owner       = "platform-team"
}
