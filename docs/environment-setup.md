# GitHub environment setup (admins)

Configure GitHub so the pipeline can sign in to Azure and publish. Do this once
per environment (`dev` and `prod`). **App teams don't need this.**

## Table of contents
- [Prerequisites](#prerequisites)
- [1. Create the environments](#1-create-the-environments)
- [2. Add the sign-in details](#2-add-the-sign-in-details)
- [3. Protect production (recommended)](#3-protect-production-recommended)
- [4. Allow pull-request automation](#4-allow-pull-request-automation)
- [5. Verify](#5-verify)
- [Troubleshooting](#troubleshooting)

## Prerequisites
- You are a repo **admin** (Settings access).
- You have the service principal details from
  [provision-azure.md](provision-azure.md) — one per environment:
  `appId`, `password`, `tenant`, plus the subscription / resource-group / APIM names.

## 1. Create the environments
GitHub repo → **Settings** → **Environments** → **New environment**.
Create two, named exactly:

```text
dev
prod
```

Open **dev** first and complete steps 2-4, then repeat for **prod**.

## 2. Add the sign-in details

Add the **secret** under **Environment secrets** (masked — required):

| Name | What to paste | From the CLI |
|---|---|---|
| `AZURE_CLIENT_SECRET` | The service principal's client secret **value** | `password` |

Add the rest under **Environment variables** (not masked — fine as variables):

| Name | What to paste | From the CLI |
|---|---|---|
| `AZURE_CLIENT_ID` | Service principal application (client) ID | `appId` |
| `AZURE_TENANT_ID` | Azure tenant ID | `tenant` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | your subscription |
| `AZURE_RESOURCE_GROUP_NAME` | The APIM resource group | `rg-apiops-dev` / `rg-apiops-prod` |
| `API_MANAGEMENT_SERVICE_NAME` | The APIM service name | `apim-apiops-dev-poc` / `apim-apiops-prod-poc` |

> **Golden rule:** the client **secret** goes in *Environment secrets*; everything
> else can go in *Environment variables*. Never put the client secret in variables
> — variables are **not** masked in logs. The workflow reads the secret as
> `${{ secrets.AZURE_CLIENT_SECRET }}` and the rest as `${{ secrets.* || vars.* }}`.

## 3. Protect production (recommended)
In the **prod** environment only:
- **Deployment branches and tags** → *Selected branches and tags* → add `main`.
  This blocks any branch other than `main` from deploying to prod.
- **Required reviewers** → add the people who must approve before prod deploys.
  The prod job then pauses under **Actions → Review deployments** until approved.

## 4. Allow pull-request automation
The extractor opens a pull request with what it pulled from APIM. Allow it:

Repo → **Settings** → **Actions** → **General** → **Workflow permissions** →
enable **"Allow GitHub Actions to create and approve pull requests."**

## 5. Verify
1. Repo → **Settings** → **Environments** → confirm both `dev` and `prod` exist
   and each has the 1 secret + 5 variables above.
2. Push a trivial change to `main` (or re-run the last publisher run).
3. **Actions** → open the run → the **dev** job should pass the
   *"Validate publisher configuration"* step (no missing-config error), then
   the **Publish** step should run.

## Troubleshooting

| Symptom | Cause & fix |
|---|---|
| *"Missing dev/prod environment configuration: AZURE_CLIENT_SECRET"* | The secret is missing, or was added as a **variable**. Add it under **Environment secrets**. |
| *"Missing … configuration: AZURE_CLIENT_ID, …"* | Those names aren't set as variables (or secrets) in that environment. Add them. |
| Prod never starts | Prod is waiting for a **required reviewer**, or its branch rule doesn't include `main`. |
| Values look empty in logs | You put them in the **repo** scope, not the **environment** scope. Add them under the specific environment. |

After this, merging to `main` deploys to **dev**, then **prod**.
