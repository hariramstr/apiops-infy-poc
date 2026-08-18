# Create Azure API Management from scratch (admins)

Do this once to stand up the **dev** and **prod** environments before the
pipeline can publish. Replace every `<PLACEHOLDER>` with your own value.
**Never commit real IDs, passwords, or keys.**

## Table of contents
- [Prerequisites](#prerequisites)
- [Placeholders](#placeholders)
- [1. Sign in](#1-sign-in)
- [2. Create resource groups](#2-create-resource-groups-dev--prod)
- [3. Create the APIM services](#3-create-the-apim-services)
- [4. Create a service principal per environment](#4-create-a-service-principal-per-environment)
- [5. Map the outputs to GitHub](#5-map-the-outputs-to-github)
- [6. Point the repo at your prod APIM](#6-point-the-repo-at-your-prod-apim)
- [Cost note](#cost-note)
- [Tear down (cleanup)](#tear-down-cleanup)
- [Troubleshooting](#troubleshooting)

## Prerequisites
- **Azure CLI** installed and signed in — <https://aka.ms/azcli>.
- Permission to **create resource groups** and **role assignments** in the
  subscription (Owner or User Access Administrator + Contributor).
- Permission to **create Entra app registrations** (for the service principals).

Check your CLI is ready:
```bash
az version
az account show --query "{subscription:name, id:id, tenant:tenantId}" -o table
```

## Placeholders

| Placeholder | Meaning |
|---|---|
| `<SUBSCRIPTION_ID>` | Your Azure subscription ID |
| `<LOCATION>` | Azure region, e.g. `centralindia` |
| `<PUBLISHER_NAME>` | APIM publisher/display name |
| `<PUBLISHER_EMAIL>` | APIM publisher email |
| `<DEV_RG>` / `<PROD_RG>` | Resource group names, e.g. `rg-apiops-dev` / `rg-apiops-prod` |
| `<DEV_APIM>` / `<PROD_APIM>` | APIM service names, e.g. `apim-apiops-dev-poc` / `apim-apiops-prod-poc` |

> APIM service names must be **globally unique**.

## 1. Sign in
```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

## 2. Create resource groups (dev + prod)
```bash
az group create --name <DEV_RG>  --location <LOCATION>
az group create --name <PROD_RG> --location <LOCATION>
```

## 3. Create the APIM services
Developer SKU is fine for a POC. Creation takes ~30-45 min; `--no-wait` returns immediately.
```bash
az apim create --name <DEV_APIM>  --resource-group <DEV_RG> \
  --publisher-name "<PUBLISHER_NAME>" --publisher-email "<PUBLISHER_EMAIL>" \
  --sku-name Developer --location <LOCATION> --no-wait

az apim create --name <PROD_APIM> --resource-group <PROD_RG> \
  --publisher-name "<PUBLISHER_NAME>" --publisher-email "<PUBLISHER_EMAIL>" \
  --sku-name Developer --location <LOCATION> --no-wait
```

If you see *"Resource provider 'Microsoft.ApiManagement' is not registered"*, the CLI
registers it automatically; just re-run the command if needed. To register manually:
```bash
az provider register --namespace Microsoft.ApiManagement
```

Check progress until it shows `Succeeded`:
```bash
az apim show --name <DEV_APIM>  --resource-group <DEV_RG>  --query "provisioningState" -o tsv
az apim show --name <PROD_APIM> --resource-group <PROD_RG> --query "provisioningState" -o tsv
```

## 4. Create a service principal per environment
These are the credentials the pipeline uses to publish. Scope each one to its own
resource group (least privilege).
```bash
az ad sp create-for-rbac -n "apiops-dev-sp"  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<DEV_RG>

az ad sp create-for-rbac -n "apiops-prod-sp" --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<PROD_RG>
```

Each command prints something like (values shown as placeholders):
```json
{
  "appId":       "<CLIENT_ID>",
  "displayName": "apiops-dev-sp",
  "password":    "<CLIENT_SECRET>",
  "tenant":      "<TENANT_ID>"
}
```
Copy these somewhere safe **once** — the password cannot be retrieved again.
If you lose it, reset it:
```bash
az ad sp credential reset --id <CLIENT_ID>
```

## 5. Map the outputs to GitHub
For each GitHub environment (`dev`, `prod`), use that environment's service principal:

| From the CLI | GitHub name | Where |
|---|---|---|
| `password` | `AZURE_CLIENT_SECRET` | Environment **secret** |
| `appId` | `AZURE_CLIENT_ID` | Environment variable |
| `tenant` | `AZURE_TENANT_ID` | Environment variable |
| `<SUBSCRIPTION_ID>` | `AZURE_SUBSCRIPTION_ID` | Environment variable |
| `<DEV_RG>` / `<PROD_RG>` | `AZURE_RESOURCE_GROUP_NAME` | Environment variable |
| `<DEV_APIM>` / `<PROD_APIM>` | `API_MANAGEMENT_SERVICE_NAME` | Environment variable |

Then follow [environment-setup.md](environment-setup.md) to finish the GitHub side
(branch protection, reviewers, PR permissions).

## 6. Point the repo at your prod APIM
Set `apimServiceName` in [../configuration.prod.yaml](../configuration.prod.yaml) to `<PROD_APIM>`:
```yaml
apimServiceName: <PROD_APIM>
```
The dev APIM name comes from the `API_MANAGEMENT_SERVICE_NAME` variable in the `dev` environment.

## Cost note
The **Developer** SKU is for non-production/testing and is billed hourly while it
exists (it is **not** free). Delete the resource groups when you're done testing
(see below) to stop charges.

## Tear down (cleanup)
Deletes the APIM instance and everything in the resource groups. **Irreversible.**
```bash
az group delete --name <DEV_RG>  --yes --no-wait
az group delete --name <PROD_RG> --yes --no-wait
```
Optionally remove the service principals:
```bash
az ad sp delete --id <DEV_CLIENT_ID>
az ad sp delete --id <PROD_CLIENT_ID>
```

## Troubleshooting

| Symptom | Cause & fix |
|---|---|
| *"Resource provider 'Microsoft.ApiManagement' is not registered"* | Run `az provider register --namespace Microsoft.ApiManagement`, then retry. |
| *"The resource name is already taken"* | APIM names are global — pick a more unique `<DEV_APIM>`/`<PROD_APIM>`. |
| *"Insufficient privileges"* on `az ad sp create-for-rbac` | You lack app-registration or role-assignment rights; ask an admin. |
| APIM stuck on `Activating` | Developer SKU creation takes ~30-45 min; keep polling `provisioningState`. |
| Lost the SP password | `az ad sp credential reset --id <CLIENT_ID>` and update the GitHub secret. |
