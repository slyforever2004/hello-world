## Lab 7 – Terraform Cloud + GitHub VCS Workflow

Integrate Terraform Cloud (TFC) with a GitHub repository to provision secure Azure infrastructure using remote state, run tasks / policies. This lab focuses on the end‑to‑end workflow: local authoring → VCS trigger in TFC → Azure apply with least privilege.

---

## 1. Learning Objectives
By the end you will be able to:
* Connect a GitHub repo to a Terraform Cloud workspace (VCS driven)
* Configure Terraform Cloud remote state & execution mode (remote)
* Use Azure OIDC (no static creds) in Terraform Cloud via Workload Identity / Service Principal
* Manage sensitive & non‑sensitive variables in TFC (env vs Terraform vars)
* Enforce a simple Sentinel / OPA-style policy check (conceptual stub) or run tasks hook (e.g. cost)
* Trigger plans via PRs and applies via merges using the VCS workflow
* Detect drift with speculative plan and optional scheduled runs

## 2. What You Will Build
Minimal Azure footprint managed by Terraform Cloud:
* Resource Group
* Storage Account (standard LRS) – demonstrates naming constraints & tagging

The emphasis is the workflow integration rather than complex Azure resources.

## 3. Architecture Overview
```mermaid
flowchart LR
    Dev[Developer Commit/PR] --> GH[GitHub Repo]
    GH -->|Webhook| TFC[Terraform Cloud Workspace]
    TFC -->|Plan & Apply| AZ[Azure Subscription]
    
    subgraph "GitHub"
        GH
    end
    
    subgraph "Terraform Cloud"
        TFC
    end
    
    subgraph "Azure"
        AZ
    end
```
Execution mode: Remote (Terraform Cloud runs terraform; state stored in TFC). Azure credentials injected as environment variables referencing a Federated Credential (OIDC) Service Principal.

## 4. Prerequisites
| Item | Details |
|------|---------|
| Terraform Cloud Account | Free tier ok (create org) |
| GitHub Repo | This workshop repository fork or clone |
| Azure Subscription | Rights to create App Registration + role assignment |
| Local Tools | terraform, az, gh, bash |
| Auth | `az login`, `gh auth login` |
| Variables | Terraform Cloud org name, desired workspace name |

## 5. Quick Start (High Level)
1. Create Azure Service Principal with federated credential for Terraform Cloud.
2. In Terraform Cloud: create organization (if new) and a workspace (VCS workflow) pointing to this repo folder `solutions/lab7`.
3. Add variables in TFC:
   * Terraform variables (Category: Terraform): `location`, `resource_group_name` (optional overrides)
   * Environment variables (Category: Env): `TFC_AZURE_PROVIDER_AUTH`, `TFC_AZURE_RUN_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`
4. Replace placeholders in `versions.tf` cloud block (organization + workspace name) OR remove and set via CLI/TFC workspace settings.
5. Commit & push a change – TFC queues a plan (speculative for PR, confirm/apply on main if auto‑apply enabled).
6. Observe plan & apply in TFC UI; inspect state & outputs.

## 6. Repository Layout (Lab 7)
```
solutions/lab7/
  README.md
  versions.tf
  variables.tf
  main.tf
  prepare.sh
```

## 7. Terraform Cloud Workspace Setup
1. In TFC UI: New Workspace → Version Control workflow.
2. Connect GitHub OAuth (or GitHub App) → select this repository.
3. Set working directory: `solutions/lab7`.
4. Execution Mode: Remote.
5. Apply Method: (a) Auto apply (fast iteration) or (b) Manual (safer for production patterns).
6. Save workspace.

## 8. Azure Service Principal (Federated) Creation
Create an App Registration + Service Principal with a federated credential for Terraform Cloud.
```bash
cd terraform-advanced-workshop/solutions/lab7
export TFC_ORG="<your_org>"
export TFC_PROJECT="<project_name>"
export TFC_WORKSPACE="<workspace_name>"
# optional
export APP_NAME="tfc-cicd"
./prepare.sh
```
Export values into TFC env vars.

### 9. Variables in TFC
Configure these variables in the TFC workspace (<Your workspace> → Variables):
| Type | Name | Example | Sensitive | Notes |
|------|------|---------|-----------|-------|
| Env | TFC_AZURE_RUN_CLIENT_ID | <appId> | Yes | Azure auth |
| Env | TFC_AZURE_PROVIDER_AUTH | true | No | Azure auth |
| Env | ARM_TENANT_ID | <tenantId> | No | |
| Env | ARM_SUBSCRIPTION_ID | <subId> | No | |
| Terraform | location | southeastasia | No | Overrides default |
| Terraform | resource_group_name | lab7-rg | No | Custom RG name |

(If using workload identity federation directly from TFC: export env vars from the SP. For OIDC from TFC to Azure, currently use a client secret or workload identity – prefer secretless where GA; else store CLIENT_SECRET as env var sensitive.)

## 10. Code Walkthrough
`versions.tf`: Configures provider + Terraform Cloud remote backend (update placeholders).
`variables.tf`: Declares Azure + naming variables.
`main.tf`: Creates a resource group and a storage account (simple LRS, TLS 1.2, tagged). Demonstrates deterministic SA naming with optional suffix.

## 11. Policy / Run Tasks (Conceptual Extension)
You can attach a cost estimation or policies:
1. Organization Settings → Cost estimation → Enable cost estimation for all workspaces.
2. Organization Settings → Policies → Create a new policy.
2. Workspace → Settings → Run Tasks → attach to pre-plan / post-plan.
3. Re-run plan to see gating behavior.

For Sentinel (paid tiers): create a simple policy enforcing a tag key exists. Example (pseudo):
```hcl
# sentinel.hcl (outline, not runnable here)
import "tfplan/v2" as tfplan
main = rule { all tfplan.resource_changes as r { "tags" in r.change.after and "project" in r.change.after.tags } }
```

## 12. GitHub PR Flow
* Open PR → TFC speculative plan runs (no apply).
* Merge PR → main branch push triggers new plan; if auto‑apply enabled, resources change.
* Use TFC notifications (optional) to post status back to VCS checks.

## 13. Cleanup
In TFC workspace: Actions → Queue destroy plan → Confirm destroy → Apply.
Then delete workspace (optionally) and Azure role assignment / app registration if dedicated.

## 14. Troubleshooting
| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Workspace stuck pending | Missing variable or credentials | Add env vars / re-run |
| Plan fails provider auth | Wrong SP values or missing role | Verify role assignment, IDs |
| Name already taken (storage) | Not unique globally | Add `storage_account_suffix` var |
| No speculative plan on PR | VCS connection not installed | Reconnect GitHub integration |
| Sentinel policy block | Tag missing / rule mismatch | Add required tag or adjust policy |

## 15. Review Questions
1. When would you choose CLI-driven workspace vs VCS-driven?
2. How do run tasks differ from Sentinel policies?
3. What are pros/cons of auto-apply for production?
4. How do you rotate Azure credentials without downtime in TFC?
5. How do you extend this pattern for multi-environment (workspaces vs directories)?

## 16. Next Extensions
* Add Infracost run task for cost feedback
* Introduce OPA policy evaluation via plan JSON export
* Integrate notifications (Slack/Teams) using TFC notification triggers
* Migrate to workload identity (secretless) if/when fully supported

