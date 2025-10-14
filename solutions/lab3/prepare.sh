#!/bin/bash

# Lab 3: Advanced Policy as Code & Remediation Setup Script
# This script validates prerequisites and sets up the environment for policy deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Azure CLI authentication
check_azure_auth() {
    print_status "Checking Azure CLI authentication..."
    
    if ! command_exists az; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! az account show >/dev/null 2>&1; then
        print_error "You are not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    USER_NAME=$(az account show --query user.name -o tsv)
    
    print_success "Authenticated as: $USER_NAME"
    print_success "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    
    # Export subscription ID for Terraform
    export ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
    echo "export ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID" >> ~/.bashrc
}

# Function to check required permissions
check_permissions() {
    print_status "Checking required permissions..."

    # Retrieve signed-in user's object ID (Graph)
    if ! USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null); then
        print_error "Unable to retrieve signed-in user object id. Ensure you have consented to required Graph permissions."
        print_error "If this persists, try: az login --scope https://graph.microsoft.com//.default"
        exit 1
    fi

    echo "User Object Id: $USER_OBJECT_ID"

    # Show all role assignments for visibility
    print_status "Listing role assignments for this user (scope may include management groups / subscriptions):"
    az role assignment list --assignee "$USER_OBJECT_ID" -o table || {
        print_error "Failed to list role assignments."
        exit 1
    }

    # Check for required roles
    POLICY_ROLE=$(az role assignment list --assignee "$USER_OBJECT_ID" --query "[?roleDefinitionName=='Policy Contributor']" -o tsv)
    OWNER_ROLE=$(az role assignment list --assignee "$USER_OBJECT_ID" --query "[?roleDefinitionName=='Owner']" -o tsv)

    if [ -z "$POLICY_ROLE" ] && [ -z "$OWNER_ROLE" ]; then
        print_error "Missing required role. Need either 'Policy Contributor' or 'Owner' at subscription (or higher) scope."
        print_error "Ask your administrator to assign one of these roles, then re-run this script."
        exit 1
    fi

    print_success "Required permissions verified (Owner or Policy Contributor present)."
}

# Function to check Terraform installation
check_terraform() {
    print_status "Checking Terraform installation..."
    
    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install Terraform 1.7+ first."
        exit 1
    fi
    
    TERRAFORM_VERSION=$(terraform version -json | jq -r .terraform_version)
    print_success "Terraform version: $TERRAFORM_VERSION"
    
    # Check minimum version (1.7.0)
    if ! terraform version -json | jq -r .terraform_version | grep -E '^1\.[7-9]\.' >/dev/null; then
        print_warning "Terraform version 1.7+ is recommended for this lab"
    fi
}

# Function to register required Azure providers
register_providers() {
    print_status "Registering required Azure providers..."
    
    PROVIDERS=(
        "Microsoft.PolicyInsights"
        "Microsoft.Authorization"
        "Microsoft.Compute"
        "Microsoft.Network"
        "Microsoft.OperationalInsights"
        "Microsoft.Insights"
        "Microsoft.ManagedIdentity"
    )
    
    for provider in "${PROVIDERS[@]}"; do
        print_status "Registering provider: $provider"
        az provider register --namespace "$provider" --wait
    done
    
    print_success "All required providers registered"
}

# Function to check SSH key
# Removed SSH key check: Lab now uses username/password authentication.

generate_password() {
    # Generates a 20-char password with upper, lower, digits, symbols meeting Azure complexity
    tr -dc 'A-Za-z0-9@#%^&*_+=' < /dev/urandom | head -c 20
}

ensure_admin_password() {
    if [ -z "$TF_VAR_vm_admin_password" ]; then
        print_status "No vm_admin_password provided; generating a random secure password (store it safely)."
        export TF_VAR_vm_admin_password=$(generate_password)
        echo "Generated VM admin password: $TF_VAR_vm_admin_password"
        print_warning "Record this password; it will not be retrievable later. Consider rotating after lab."
    else
        print_success "Using provided vm_admin_password environment variable."
    fi
}

# Function to set environment variables
set_environment_variables() {
    print_status "Setting up environment variables..."
    
    # Set default location if not already set
    if [ -z "$TF_VAR_location" ]; then
        export TF_VAR_location="southeastasia"
        echo "export TF_VAR_location=southeastasia" >> ~/.bashrc
        print_success "Set TF_VAR_location to southeastasia"
    else
        print_success "Using existing TF_VAR_location: $TF_VAR_location"
    fi
    
    # Set subscription ID
    if [ -z "$ARM_SUBSCRIPTION_ID" ]; then
        export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        echo "export ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID" >> ~/.bashrc
    fi
    
    print_success "Environment variables configured"
}

# Function to validate JSON policy files
validate_policy_files() {
    print_status "Validating policy definition files..."
    
    POLICY_FILES=(
        "policies/require-tag.json"
        "policies/require-disk-encryption.json"  
        "policies/ensure-ama.json"
    )
    
    for policy_file in "${POLICY_FILES[@]}"; do
        if [ ! -f "$policy_file" ]; then
            print_error "Policy file not found: $policy_file"
            exit 1
        fi
        
        if ! jq . "$policy_file" >/dev/null 2>&1; then
            print_error "Invalid JSON in policy file: $policy_file"
            exit 1
        fi
        
        print_success "Validated: $policy_file"
    done
}

# Function to create terraform.tfvars if it doesn't exist
create_tfvars() {
    if [ ! -f "terraform.tfvars" ]; then
        print_status "Creating terraform.tfvars file..."
        
        cat > terraform.tfvars << EOF
# Lab 3: Policy as Code Configuration
location              = "$TF_VAR_location"
resource_group_name   = "lab3-rg"
tag_name              = "cost-center"
tag_value             = "lab3"
vm_admin_username     = "azureuser"
vm_admin_password     = "${TF_VAR_vm_admin_password:-ChangeM3!}" # generated or placeholder; rotate if placeholder
EOF
        
        print_success "Created terraform.tfvars with default values"
        print_status "You can edit terraform.tfvars to customize the deployment"
    else
        print_success "terraform.tfvars already exists"
    fi
}

# Function to display next steps
show_next_steps() {
    echo
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    SETUP COMPLETE                              ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${BLUE}Environment is ready for Lab 3: Advanced Policy as Code & Remediation${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review the terraform.tfvars file and customize if needed"
    echo "2. Run: terraform init"
    echo "3. Run: terraform plan"
    echo "4. Run: terraform apply"
    echo
    echo -e "${YELLOW}Key Environment Variables:${NC}"
    echo "  ARM_SUBSCRIPTION_ID: $ARM_SUBSCRIPTION_ID"
    echo "  TF_VAR_location: $TF_VAR_location"
    echo
    echo -e "${YELLOW}Policy Files:${NC}"
    echo "  policies/require-tag.json - Tag enforcement with modify effect"
    echo "  policies/require-disk-encryption.json - Disk encryption with deny effect"
    echo "  policies/ensure-ama.json - AMA deployment with deployIfNotExists"
    echo
    echo -e "${YELLOW}Documentation:${NC}"
    echo "  See README.md for detailed instructions and troubleshooting"
    echo
}

# Main execution
main() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}    Lab 3: Advanced Policy as Code & Remediation Setup          ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    check_azure_auth
    check_permissions
    check_terraform
    register_providers
    ensure_admin_password
    set_environment_variables
    validate_policy_files
    create_tfvars
    show_next_steps
}

# Run main function
main "$@"
