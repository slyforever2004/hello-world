# Production Environment Configuration
environment  = "production"
location     = "southeastasia"
project_name = "lab4"

# VM Configuration for production
vm_size        = "Standard_B2s" # Larger size for production
admin_username = "azureuser"

# Monitoring settings
enable_monitoring = true # Enable full monitoring in production

# Backup settings
backup_retention_days = 30 # Longer retention for production

# Resource tags
tags = {
  Environment = "production"
  Project     = "lab4"
  ManagedBy   = "terraform"
  CreatedBy   = "github-actions"
  CostCenter  = "production"
  Owner       = "platform-team"
}
