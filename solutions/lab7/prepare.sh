#!/usr/bin/env bash
set -euo pipefail

# Lab7 helper: validate tooling and print instructions for Terraform Cloud setup.
# Does NOT create Azure resources (TFC run will). Optionally can fetch SP details.

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){ echo -e "${RED}[ERR]${NC} $*"; }

log "Checking prerequisites"
for cmd in terraform az; do
  if ! command -v "$cmd" >/dev/null 2>&1; then err "Missing required command: $cmd"; exit 1; fi
done
ok "CLI tools present (terraform, az)"

if ! az account show >/dev/null 2>&1; then err "Run 'az login' first"; exit 1; fi
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
ok "Azure context: subscription=$SUBSCRIPTION_ID tenant=$TENANT_ID"

APP_NAME=${APP_NAME:-"tfc-cicd"}
ok "Application display name target: ${APP_NAME}"

# Required inputs for federation subject pattern
if [[ -z "${TFC_ORG:-}" ]]; then
  err "TFC_ORG not set. Export TFC_ORG to identify Terraform Cloud organization."; exit 1; fi
if [[ -z "${TFC_WORKSPACE:-}" ]]; then
  err "TFC_WORKSPACE not set. Export TFC_WORKSPACE to identify Terraform Cloud workspace."; exit 1; fi
TFC_PROJECT=${TFC_PROJECT:-default}
# Base (without run phase)
FED_SUBJECT_BASE="organization:${TFC_ORG}:project:${TFC_PROJECT}:workspace:${TFC_WORKSPACE}"
ok "Federated subject base: ${FED_SUBJECT_BASE} (will append run_phase)"

# Locate or create application
APP_ID=$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv 2>/dev/null || true)
if [[ -n "$APP_ID" && "$APP_ID" != "null" ]]; then
  ok "Found existing application: $APP_ID"
else
  log "Creating Azure AD application ${APP_NAME}"
  APP_ID=$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)
  ok "Created application appId=${APP_ID}"
fi
export APP_ID

# Ensure service principal exists
SP_EXISTS=$(az ad sp show --id "$APP_ID" --query appId -o tsv 2>/dev/null || true)
if [[ -z "$SP_EXISTS" || "$SP_EXISTS" == "null" ]]; then
  log "Creating service principal for appId=${APP_ID}"
  az ad sp create --id "$APP_ID" >/dev/null
  ok "Service principal created"
else
  ok "Service principal already exists"
fi

# Assign RBAC (Contributor) at subscription scope (idempotent)
ASSIGN_PRESENT=$(az role assignment list --assignee "$APP_ID" --role Contributor --scope "/subscriptions/${SUBSCRIPTION_ID}" --query '[0].id' -o tsv 2>/dev/null || true)
if [[ -z "$ASSIGN_PRESENT" || "$ASSIGN_PRESENT" == "null" ]]; then
  log "Assigning Contributor at subscription scope"
  az role assignment create --assignee "$APP_ID" --role Contributor --scope "/subscriptions/${SUBSCRIPTION_ID}" >/dev/null
  ok "Role assignment created"
else
  ok "Role assignment already exists"
fi

# Create federated credentials for Terraform Cloud plan & apply phases
# Subject format now: organization:ORG:project:PROJECT:workspace:WORKSPACE:run_phase:{plan|apply}
for phase in plan apply; do
  FED_SUBJECT="${FED_SUBJECT_BASE}:run_phase:${phase}"
  FED_NAME="tfc-${TFC_ORG}-${TFC_WORKSPACE}-${phase}"
  EXISTING_FED=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='${FED_NAME}'].name | [0]" -o tsv 2>/dev/null || true)
  if [[ -z "$EXISTING_FED" || "$EXISTING_FED" == "null" ]]; then
    log "Creating federated identity credential: ${FED_NAME} (subject=${FED_SUBJECT})"
    TMP_JSON=$(mktemp 2>/dev/null || echo "/tmp/tfc_fed_${phase}_$$.json")
    cat > "$TMP_JSON" <<JSON
{
  "name": "${FED_NAME}",
  "issuer": "https://app.terraform.io",
  "subject": "${FED_SUBJECT}",
  "description": "Terraform Cloud Workspace Federation (${phase})",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON
    az ad app federated-credential create --id "$APP_ID" --parameters @"$TMP_JSON" >/dev/null
    rm -f "$TMP_JSON" || true
    ok "Federated credential created (${phase})"
  else
    ok "Federated credential already exists (${FED_NAME})"
  fi
done

# (Optional) detect legacy single credential without run_phase and warn
LEGACY_NAME="tfc-${TFC_ORG}-${TFC_WORKSPACE}"
LEGACY_EXISTS=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='${LEGACY_NAME}'].name | [0]" -o tsv 2>/dev/null || true)
if [[ -n "$LEGACY_EXISTS" && "$LEGACY_EXISTS" != "null" ]]; then
  warn "Legacy federated credential '${LEGACY_NAME}' (without run_phase) still present. Consider removing to enforce phase-specific scoping."
fi

cat <<EOF

Summary:
  APP_NAME:               ${APP_NAME}
  APP_ID (Client ID):     ${APP_ID}
  TENANT_ID:              ${TENANT_ID}
  SUBSCRIPTION_ID:        ${SUBSCRIPTION_ID}
  Federated Credentials:  tfc-${TFC_ORG}-${TFC_WORKSPACE}-plan , tfc-${TFC_ORG}-${TFC_WORKSPACE}-apply
  Subjects:               ${FED_SUBJECT_BASE}:run_phase:plan | ${FED_SUBJECT_BASE}:run_phase:apply

Terraform Cloud Configuration:
  Set environment variables in the workspace:
    TFC_AZURE_PROVIDER_AUTH=true
    TFC_AZURE_RUN_CLIENT_ID=${APP_ID}
    ARM_TENANT_ID=${TENANT_ID}
    ARM_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}    
  (No client secret required - federated identity in use.)

If authentication fails:
  - Verify workspace organization/workspace names match subject.
  - Confirm federated credential appears under App Registration > Federated credentials.
  - Ensure the run uses workload identity (beta features may apply).

Next steps:
  1. Create/confirm TFC workspace (VCS) pointing to solutions/lab7
  2. Add above env vars
  3. Trigger a run (commit or queue plan) - expect successful provider auth
  4. Add policy/run tasks as desired

EOF
