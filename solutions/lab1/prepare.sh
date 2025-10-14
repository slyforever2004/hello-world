#!/bin/bash

# Lab1 Terraform Backend Preparation Script
# Creates Azure Storage Account for Terraform remote state and generates backend config

set -e

# Default values
RESOURCE_GROUP=${RESOURCE_GROUP:-"lab1tf-rg"}
LOCATION=${LOCATION:-"southeastasia"}
CONTAINER_NAME=${CONTAINER_NAME:-"tfstate"}

# Generate random storage account name: lab1 + 6 random alphanumeric characters
generate_storage_name() {
    local random_suffix=$(openssl rand -hex 3 | tr '[:upper:]' '[:lower:]')
    echo "lab1${random_suffix}"
}

# Check if Azure CLI is installed and user is logged in
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it first."
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Generate storage account name
STORAGE_ACCOUNT=$(generate_storage_name)

echo "Creating Azure storage resources..."
echo "Using Resource Group: $RESOURCE_GROUP"
echo "Using Location: $LOCATION"
echo "Using Storage Account: $STORAGE_ACCOUNT"
echo "Using Container: $CONTAINER_NAME"

# Create resource group
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

# Create storage account
az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --access-tier Hot \
    --output table

# Get current user's object ID for role assignment
CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Assign Storage Blob Data Contributor role to current user
az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee "$CURRENT_USER_ID" \
    --scope "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" \
    --output table || echo "Role assignment may already exist, continuing..."

# Create blob container
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login \
    --output table

echo "Storage resources created successfully!"

# Generate backend config files for infrastructure and application
echo "Generating backend config files..."

# Infrastructure backend config
cat > infrastructure/infrastructure.tfbackend << EOF
resource_group_name  = "$RESOURCE_GROUP"
storage_account_name = "$STORAGE_ACCOUNT"
container_name       = "$CONTAINER_NAME"
key                  = "infrastructure.tfstate"
use_azuread_auth     = true
EOF

# Application backend config
cat > application/application.tfbackend << EOF
resource_group_name  = "$RESOURCE_GROUP"
storage_account_name = "$STORAGE_ACCOUNT"
container_name       = "$CONTAINER_NAME"
key                  = "application.tfstate"
use_azuread_auth     = true
EOF

# Application terraform.tfvars for remote state configuration
cat > application/terraform.tfvars << EOF
backend_resource_group_name  = "$RESOURCE_GROUP"
backend_storage_account_name = "$STORAGE_ACCOUNT"
backend_container_name       = "$CONTAINER_NAME"
EOF

echo ""
echo "Generated files:"
echo "- infrastructure/infrastructure.tfbackend"
echo "- application/application.tfbackend"
echo "- application/terraform.tfvars"
echo ""
echo "Next steps:"
echo "1. cd infrastructure && terraform init -backend-config=infrastructure.tfbackend"
echo "2. cd ../application && terraform init -backend-config=application.tfbackend"