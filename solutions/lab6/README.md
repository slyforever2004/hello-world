## Lab 6 – Importing Existing Azure Resources into Terraform State

Practice brownfield adoption—bring existing Azure resources under Terraform control using declarative `import {}` blocks, verify drift, and perform safe state operations.

---

## 1. Learning Objectives
* Contrast declarative (`import {}`) vs imperative (`terraform import`) techniques
* Build precise resource blocks before importing
* Perform deterministic, reviewable imports
* Detect and reconcile configuration drift
* Selectively adopt only what you intend (data source → managed transition)
* Apply safe state surgery (rm, mv, backup, re-import)

## 2. Concepts at a Glance
| Topic | Declarative Import (`import {}`) | Imperative `terraform import` | Notes |
|-------|----------------------------------|-------------------------------|-------|
| Definition | HCL block in config | CLI command | Declarative is versioned |
| Reviewability | Code review diff | Command history only | Prefer declarative for audit |
| Repeatability | Automatic on init/plan | Must re-run manually | Declarative improves onboarding |
| Drift Signal | Same as normal plan | Same | Post-import identical |
| Best Use | Bulk or structured migration | One-off quick fix | Can mix both |

## 3. Resource Set Used
Provisioned externally (script) to simulate brownfield:
| Type | Items |
|------|-------|
| Storage | Storage Account + Blob Container |
| Networking | Virtual Network + Subnet |
| Networking Edge | Public IP Address |
| Resource Group | Referenced via data source (not imported initially) |

## 4. Prerequisites
| Requirement | Detail |
|-------------|--------|
| Azure Auth | `az login` successful |
| Terraform Version | >= 1.5 (import blocks) |
| Permissions | Read/create storage + network; list resource groups |
| Shell | bash |

## 5. Quick Start / Bootstrap
```bash
cd solutions/lab6
chmod +x prepare.sh
./prepare.sh
```
Script creates the brownfield resources (do NOT delete them manually during the lab).

## 6. Repository Layout (Lab 6)
```
solutions/lab6/
  main.tf          # Resource definitions mirroring existing infra
  import.tf        # Declarative import blocks
  variables.tf     # Subscription / naming vars
  outputs.tf       # IDs & confirmations
  terraform.tfvars # (if present) variable values
  prepare.sh       # Creates pre-existing resources
  terraform.tfstate (created after apply)
```

## 7. Workflow Summary
| Phase | Action | Goal | Result |
|-------|--------|-----|--------|
| 1 | Bootstrap script | Create unmanaged Azure resources | Brownfield baseline |
| 2 | Write HCL blocks | Describe desired state | Config matches real infra |
| 3 | `import {}` + plan/apply | Hydrate state deterministically | Imported resources tracked |
| 4 | Introduce drift (tag change) | Simulate config divergence | Plan reveals difference |
| 5 | Reconcile or adjust | Align code or accept drift pattern | Stable zero-drift plan |
| 6 | Optional state ops | rm / re-import / mv | State mastery |

## 8. Declarative Import Execution
Run:
```bash
terraform init
terraform plan
terraform apply -auto-approve
```
Expected (first apply): `Resources: * imported, 0 added, 0 changed, 0 destroyed.`
If you see planned creates, the HCL doesn't precisely match remote settings—fix before applying.

## 9. Imperative Import (Optional Exercise)
Comment out blocks in `import.tf`, then:
```bash
rm terraform.tfstate terraform.tfstate.backup
terraform state list
terraform import azurerm_storage_account.imported \
  /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<name>
terraform import azurerm_storage_container.imported \
  https://<acct>.blob.core.windows.net/<container>
# Repeat for vnet, subnet, public IP
terraform plan
```
Remove imperative usage once comfortable—avoid leaving undocumented historical commands.

## 10. Drift Simulation & Detection
Add a tag directly in Azure:
```bash
az tag create --resource-id $(terraform output -raw storage_account_id) --tags Owner=DriftDemo || \
az tag update --resource-id $(terraform output -raw storage_account_id) --operation Merge --tags Owner=DriftDemo
terraform plan
```
Outcome options:
| Plan Output | Meaning | Action |
|-------------|---------|--------|
| Remove tag | Tag absent in HCL | Add tag block locally OR ignore via lifecycle |
| No change | Provider ignores tag | Confirm tag attribute support |

## 11. Selective Adoption Pattern
Why resource group is a data source:
* Owned by platform team
* Reduces accidental deletion blast-radius
To adopt later:
```hcl
resource "azurerm_resource_group" "existing" {
  name     = var.resource_group_name
  location = var.location
}
```
Import (declarative or imperative) then remove the original data block.

## 12. State Operations Cheat Sheet
| Command | Purpose | Example |
|---------|---------|---------|
| `terraform state list` | List tracked objects | Identify addresses |
| `terraform state show <addr>` | Inspect attributes | Validate import correctness |
| `terraform state rm <addr>` | Detach from tracking (not delete cloud) | Force re-import |
| `terraform state mv <src> <dest>` | Refactor address (e.g., into module) | Module migration |
| Backup state file | Manual copy before surgery | `cp terraform.tfstate terraform.tfstate.bak` |

### Module Address Import Example
```hcl
import {
  to = module.network.azurerm_virtual_network.this
  id = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>"
}
```

## 13. Troubleshooting
| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Planned create after import | Config mismatch | Align SKU, address space, replication, flags |
| Import ID rejected | Formatting error | Copy exact provider ID from Azure CLI output |
| Constant tag diff | Tag missing/extra locally | Add tag or use `lifecycle { ignore_changes = [tags] }` selectively |
| Attribute keeps showing | Computed field | Omit it; Terraform will manage internally |
| State rm → big create plan | Removed tracking intentionally | Re-import or revert backup |

## 14. Cleanup (Optional)
Delete resource group (if created solely for lab):
```bash
az group delete -n $(terraform output -raw azurerm_resource_group_name 2>/dev/null || echo lab6-rg) --yes --no-wait
```

## 15. Key Learning Outcomes
* Versioned, reviewable imports via `import {}`
* Safe migration path from data sources to managed resources
* Practical drift simulation + reconciliation workflow
* Confident execution of core state commands

## 16. Extension Ideas
* Import Key Vault + secrets (handle soft-delete & purge protection)
* Move imported infra into modules (`terraform state mv`)
* Scheduled drift detection pipeline failing on unexpected changes
* Use `terraform plan -json` + policy engine to enforce import completeness

## 17. Reference Links
* Terraform Import Blocks (1.5+): https://developer.hashicorp.com/terraform/language/resources/import#the-import-block
* Imperative terraform import CLI: https://developer.hashicorp.com/terraform/cli/import
* State Command Reference: https://developer.hashicorp.com/terraform/cli/commands/state
* Moving Resources in State: https://developer.hashicorp.com/terraform/cli/commands/state/mv
* Removing Resources from State: https://developer.hashicorp.com/terraform/cli/commands/state/rm
* Terraform Plan JSON Output: https://developer.hashicorp.com/terraform/cli/commands/plan#json-output
* Lifecycle ignore_changes: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#ignore_changes
* Azure Resource ID Structure: https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules
* Azure Tags: https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources
* Drift Detection Concepts: https://developer.hashicorp.com/terraform/cloud-docs/workspaces/state/drift
* Terraform Best Practices: https://developer.hashicorp.com/terraform/language/best-practices


