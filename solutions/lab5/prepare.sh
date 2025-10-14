#!/bin/bash

# Azure OIDC Setup Script for GitHub Actions
# This script configures Azure OpenID Connect authentication for GitHub Actions

set -e

# Colors for output
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

# Check if required environment variables are set
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPO}" ]]; then
        print_error "GITHUB_REPO environment variable is not set"
        print_status "Please set it like: export GITHUB_REPO='your-org/repo-name'"
        exit 1
    fi
    
    if [[ -z "${APP_NAME}" ]]; then
        export APP_NAME="github-terraform-cicd"
        print_warning "APP_NAME not set, using default: ${APP_NAME}"
    fi
    
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed or not in PATH"
        print_status "Install from: https://cli.github.com/ and re-run"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

# Create App Registration
create_app_registration() {
    print_status "Creating App Registration: ${APP_NAME}"
    
    # Check if app already exists
    EXISTING_APP=$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "${EXISTING_APP}" && "${EXISTING_APP}" != "null" ]]; then
        print_warning "App Registration '${APP_NAME}' already exists with ID: ${EXISTING_APP}"
        export APP_ID="${EXISTING_APP}"
    else
        export APP_ID=$(az ad app create \
            --display-name "${APP_NAME}" \
            --query appId \
            --output tsv)
        
        print_success "Created App Registration with ID: ${APP_ID}"
    fi
    
    # Create service principal if it doesn't exist
    SP_EXISTS=$(az ad sp show --id "${APP_ID}" --query "appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${SP_EXISTS}" || "${SP_EXISTS}" == "null" ]]; then
        az ad sp create --id "${APP_ID}" > /dev/null
        print_success "Created Service Principal"
    else
        print_warning "Service Principal already exists"
    fi
}

# Configure Federated Identity Credentials
configure_federated_credentials() {
    print_status "Configuring Federated Identity Credentials..."

    # Environment-specific federated credentials (development)
    for env in development; do
        CRED_NAME="github-env-${env}"
        EXISTING_ENV_CRED=$(az ad app federated-credential list --id "${APP_ID}" \
            --query "[?name=='${CRED_NAME}'].name | [0]" -o tsv 2>/dev/null || echo "")
        if [[ -z "${EXISTING_ENV_CRED}" || "${EXISTING_ENV_CRED}" == "null" ]]; then
            az ad app federated-credential create \
                --id "${APP_ID}" \
                --parameters '{
                    "name": "'${CRED_NAME}'",
                    "issuer": "https://token.actions.githubusercontent.com",
                    "subject": "repo:'"${GITHUB_REPO}"':environment:'"${env}"'",
                    "description": "GitHub Actions environment '"${env}"' deployments",
                    "audiences": ["api://AzureADTokenExchange"]
                }' > /dev/null
            print_success "Created federated credential for environment: ${env}"
        else
            print_warning "Federated credential for environment '${env}' already exists"
        fi
    done
}

# Assign Azure RBAC permissions
assign_permissions() {
    print_status "Assigning Azure RBAC permissions..."
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    
    # Check if role assignment already exists
    EXISTING_ASSIGNMENT=$(az role assignment list \
        --assignee "${APP_ID}" \
        --role "Contributor" \
        --scope "/subscriptions/${SUBSCRIPTION_ID}" \
        --query "[0].principalId" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${EXISTING_ASSIGNMENT}" || "${EXISTING_ASSIGNMENT}" == "null" ]]; then
        az role assignment create \
            --assignee "${APP_ID}" \
            --role "Contributor" \
            --scope "/subscriptions/${SUBSCRIPTION_ID}" > /dev/null
        
        print_success "Assigned Contributor role to Service Principal"
    else
        print_warning "Service Principal already has Contributor role"
    fi
}


# Create GitHub environments and add secrets
create_github_environments() {
    print_status "Creating GitHub environments and adding secrets..."

    local SUBSCRIPTION_ID TENANT_ID
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)

    create_env() {
        local env_name="$1"

        # Ensure environment exists
        gh api --method PUT "repos/${GITHUB_REPO}/environments/${env_name}" >/dev/null 2>&1 \
            && print_success "Ensured GitHub environment '${env_name}' exists" \
            || print_warning "Could not explicitly create '${env_name}' (may already exist)"

        set_secret() {
            local key="$1"
            local value="$2"
            gh secret set "${key}" --env "${env_name}" --repo "${GITHUB_REPO}" --body "${value}" >/dev/null
        }

        set_secret AZURE_CLIENT_ID "${APP_ID}"
        set_secret AZURE_SUBSCRIPTION_ID "${SUBSCRIPTION_ID}"
        set_secret AZURE_TENANT_ID "${TENANT_ID}"
        print_success "Configured secrets for environment '${env_name}'"
    }

    create_env "development"
}

# Display final configuration
display_configuration() {
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    print_success "Azure OIDC configuration completed!"
    echo ""
    print_status "=== GitHub Repository Secrets ==="
    echo "Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):"
    echo ""
    echo "AZURE_CLIENT_ID: ${APP_ID}"
    echo "AZURE_TENANT_ID: ${TENANT_ID}"
    echo "AZURE_SUBSCRIPTION_ID: ${SUBSCRIPTION_ID}"
    echo ""
    print_status "=== GitHub Environments ==="
    echo "Configured environments: development (with required secrets)"
    echo ""
    print_status "=== Next Steps ==="
    echo "1. Reference 'development' environment in your GitHub Actions workflows"
    echo "2. Protect 'development' environment (optional approvals) if needed"
    echo ""
}

# Main execution
main() {
    print_status "Starting Azure OIDC setup for GitHub Actions..."
    echo ""
    
    check_prerequisites
    create_app_registration
    configure_federated_credentials
    assign_permissions
    create_github_environments
    display_configuration
    
    print_success "Setup completed successfully!"
}

# Run main function
main "$@"
