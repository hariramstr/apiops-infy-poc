# API Platform (APIOps)

This repository is the **single source of truth** for the APIs we publish to
Azure API Management (APIM). You describe each API as plain files here, open a
pull request, and when it merges to `main` a GitHub Actions pipeline publishes
the changes to **dev** and then **prod** automatically. There are **no manual
Azure portal steps** for day-to-day work.

> New here? Read [Quick start](#quick-start), then [Add a new API](#add-a-new-api).
> Setting up Azure for the first time? See [First-time setup](#first-time-setup-admins).

## Table of contents
- [How it works](#how-it-works)
- [Quick start](#quick-start)
- [Prerequisites](#prerequisites)
- [Repository structure](#repository-structure)
- [Add a new API](#add-a-new-api)
- [Configure an API](#configure-an-api)
- [How promotion works (dev → prod)](#how-promotion-works-dev--prod)
- [Validate before you push](#validate-before-you-push)
- [Republish everything vs. only changes](#republish-everything-vs-only-changes)
- [Who edits what](#who-edits-what)
- [Troubleshooting](#troubleshooting)
- [Glossary](#glossary)
- [First-time setup (admins)](#first-time-setup-admins)
- [Handy links](#handy-links)

## How it works

Two pipelines drive everything:

- **Publisher** ([.github/workflows/run-publisher.yaml](.github/workflows/run-publisher.yaml)) —
  runs on every push to `main`. It reads the files under `apimartifacts/` and
  applies them to APIM: first **dev**, then **prod**.
- **Extractor** ([.github/workflows/run-extractor.yaml](.github/workflows/run-extractor.yaml)) —
  run manually. It reads an existing APIM instance and writes the files back
  into this repo (useful to import changes someone made in the portal).

```mermaid
flowchart LR
  A[Edit your API files] --> B[Open pull request]
  B --> R[Reviewers approve]
  R --> C[Merge to main]
  C --> D[Publisher: deploy to Dev]
  D --> E[Publisher: deploy to Prod]
```

Under the hood the pipeline downloads the official
[Azure/APIOps](https://github.com/Azure/apiops) `publisher`/`extractor`
binaries and runs them against your APIM using a service principal stored in
GitHub environment secrets.

## Quick start

```text
1. Open this repo in VS Code.
2. Terminal → Run Task… → "APIOps: Add new API" → answer the prompts.
3. Paste your OpenAPI/Swagger into apimartifacts/apis/<your-api>/specification.json
4. Terminal → Run Task… → "APIOps: Validate artifacts"
5. Commit on a branch, open a pull request, get it approved, and merge.
```

Merging to `main` deploys automatically. That's it.

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| **VS Code** | Runs the built-in tasks. | <https://code.visualstudio.com> |
| **PowerShell 7 (`pwsh`)** | Runs the helper scripts/tasks. | <https://aka.ms/powershell> |
| **Git** | Clone and push. | <https://git-scm.com> |
| **Azure CLI** (admins only) | First-time Azure provisioning. | <https://aka.ms/azcli> |

> App teams only need VS Code, PowerShell 7, and Git. Azure CLI is for admins
> doing [first-time setup](#first-time-setup-admins).

## Repository structure

```text
apimartifacts/                     # Everything that gets published to APIM
  apis/
    swagger-petstore/              # Reference example — copy this pattern
      apiInformation.json          # API name, path, service URL
      specification.json           # The OpenAPI/Swagger definition
      policy.xml                   # API-wide rules (inbound/backend/outbound)
      operations/
        getPetById/policy.xml      # Rules for a single operation
  backends/                        # Where APIs forward requests to
  named values/                    # Per-environment settings ({{tokens}})
  tags/                            # Labels to group/govern APIs
  policy fragments/                # Reusable policy snippets
configuration.prod.yaml            # Values that differ in production
.github/workflows/                 # The publisher/extractor pipelines
tools/scripts/                     # Helper scripts (scaffold + validate)
docs/                              # Admin setup guides
```

### What each file means

| File / folder | In plain words |
|---|---|
| `apis/<name>/apiInformation.json` | The API's basic details (display name, URL path, backend service URL). |
| `apis/<name>/specification.json` | Your API definition (the Swagger/OpenAPI document). |
| `apis/<name>/policy.xml` | Rules applied to the whole API (headers, routing, auth). |
| `apis/<name>/operations/<op>/policy.xml` | Rules for one endpoint only (e.g. caching, rate limits). |
| `backends/<name>/backendInformation.json` | A named target the API forwards to. |
| `named values/<name>/namedValueInformation.json` | A setting referenced in policies as `{{name}}`; overridable per environment. |
| `tags/<name>/…` | Labels used to group and govern APIs. |
| `policy fragments/<name>/…` | Reusable policy snippets shared by many APIs. |
| `configuration.prod.yaml` | Values that differ in production (e.g. a prod backend URL). |

## Add a new API

### Option A — use the task (recommended)
1. In VS Code: **Terminal → Run Task… → "APIOps: Add new API"**.
2. Answer the prompts (API name, dev backend URL, etc.).
3. Paste your OpenAPI/Swagger into the generated
   `apimartifacts/apis/<your-api>/specification.json`.
4. Run **"APIOps: Validate artifacts"**, then open a pull request.

### Option B — run the script directly
```powershell
pwsh -File tools/scripts/New-ApiScaffold.ps1 `
  -ApiName isclaims `
  -DisplayName "IS Claims" `
  -Path isclaims `
  -BackendUrl https://claims.dev.internal `
  -Operations getClaim,createClaim `
  -Tags partner
```

This generates a ready-to-edit skeleton:

```text
apimartifacts/apis/isclaims/apiInformation.json
apimartifacts/apis/isclaims/policy.xml
apimartifacts/apis/isclaims/operations/getClaim/policy.xml
apimartifacts/apis/isclaims/operations/createClaim/policy.xml
apimartifacts/backends/isclaims-backend/backendInformation.json
apimartifacts/named values/isclaims-backend-url/namedValueInformation.json
apimartifacts/tags/partner/apis/isclaims/tagApiInformation.json
```

> **Operation folder names must match the `operationId`s in your spec.** If your
> OpenAPI has `"operationId": "getClaim"`, the folder must be
> `operations/getClaim/`.

## Configure an API

These are the pieces most APIs need. Copy the reference example under
`apimartifacts/apis/swagger-petstore/` for a working template.

### API basics — `apiInformation.json`
```json
{
  "properties": {
    "apiRevision": "1",
    "displayName": "IS Claims",
    "path": "isclaims",
    "protocols": [ "https" ],
    "serviceUrl": "https://claims.dev.internal",
    "subscriptionRequired": true
  }
}
```

### Inbound / outbound / backend rules — `policy.xml`
```xml
<policies>
  <inbound>
    <base />
    <include-fragment fragment-id="correlation-id" />
    <set-backend-service backend-id="isclaims-backend" />
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <base />
    <set-header name="X-Owner-Team" exists-action="override">
      <value>{{platform-owner-team}}</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

### Backend URL — `backends/<name>/backendInformation.json`
Use a **literal absolute URL**. APIM does **not** resolve `{{tokens}}` in a
backend's `url`. Per-environment differences are handled by an override (below).
```json
{
  "properties": {
    "description": "IS Claims backend.",
    "protocol": "http",
    "url": "https://claims.dev.internal"
  }
}
```

### Per-environment overrides — `configuration.prod.yaml`
Override the backend URL (and the API `serviceUrl`) for production:
```yaml
backends:
  - name: isclaims-backend
    properties:
      url: https://claims.prod.internal

apis:
  - name: isclaims
    properties:
      serviceUrl: https://claims.prod.internal
```

> **Named values** (`named values/<name>/…`) are still useful for values you
> reference **inside policies** as `{{name}}` — they just can't be used as a
> backend `url`.

### Tags — `tags/<tag>/…`
```text
tags/partner/tagInformation.json                     # { "properties": { "displayName": "partner" } }
tags/partner/apis/isclaims/tagApiInformation.json    # {}
```

## How promotion works (dev → prod)

- Every merge to `main` publishes to **dev** first.
- If dev succeeds, the same commit publishes to **prod**.
- **Prod** can require approval — see
  [Protect production](docs/environment-setup.md#3-protect-production-recommended).
- Environment-specific differences (like URLs) live in
  `configuration.prod.yaml`, not in the API files themselves.

## Validate before you push

Run the **"APIOps: Validate artifacts"** task, or:
```powershell
pwsh -File tools/scripts/Validate-Artifacts.ps1
```
It checks that every JSON/XML file is valid and that each API has both an
`apiInformation.json` and a `specification.*`. Fix anything it reports before
opening a pull request.

## Republish everything vs. only changes

The publisher can run in two modes (choose when you trigger it manually from the
Actions tab):

| Mode | When to use |
|---|---|
| **Publish changes** (default) | Normal merges. Publishes only what changed in the last commit — fast. |
| **Publish all** | Recovery only. Republishes every artifact (e.g. after a failed run or a rebuilt environment). |

## Who edits what

- **API teams:** only your own folder `apimartifacts/apis/<your-api>/`.
- **Platform/senior team:** shared folders (`named values`, `backends`,
  `policy fragments`, `tags`), the pipelines in `.github/`, and
  `configuration.prod.yaml`. This split is enforced by
  [.github/CODEOWNERS](.github/CODEOWNERS).

## Troubleshooting

| Symptom | Likely cause & fix |
|---|---|
| Pipeline fails: *"Missing dev environment configuration: AZURE_CLIENT_SECRET"* | The secret was added as an **Environment variable** instead of an **Environment secret**. See [environment-setup.md](docs/environment-setup.md). |
| Spectral step: *"No files found to lint"* | The API folder has no `specification.*` file, or the operation folder names don't match your `operationId`s. |
| Operation policy not applied | The `operations/<op>/` folder name must equal the `operationId` in the spec. |
| Prod job never runs | Prod is waiting for a required reviewer, or the `prod` environment's branch rule doesn't include `main`. |
| `pwsh: command not found` | Install [PowerShell 7](https://aka.ms/powershell). |

## Glossary

| Term | Meaning |
|---|---|
| **APIM** | Azure API Management — the gateway that hosts our APIs. |
| **Artifact** | Any file under `apimartifacts/` that describes part of APIM. |
| **Named value** | A reusable setting referenced in policies as `{{name}}`; can differ per environment. |
| **Backend** | A named destination an API forwards requests to. |
| **Policy** | Rules applied to requests/responses (headers, routing, rate limits). |
| **Policy fragment** | A reusable snippet of policy shared across APIs. |
| **Service principal** | The identity the pipeline uses to sign in to Azure. |

## First-time setup (admins)

Do these once before the pipeline can publish:

1. **Create Azure resources** (resource groups, APIM, service principals) —
   [docs/provision-azure.md](docs/provision-azure.md).
2. **Configure GitHub environments** (secrets, variables, prod protection) —
   [docs/environment-setup.md](docs/environment-setup.md).

## Handy links
- Reference example to copy: [apimartifacts/apis/swagger-petstore/](apimartifacts/apis/swagger-petstore)
- First-time Azure setup (admins): [docs/provision-azure.md](docs/provision-azure.md)
- GitHub environment setup (admins): [docs/environment-setup.md](docs/environment-setup.md)
- New-API tool: [tools/scripts/New-ApiScaffold.ps1](tools/scripts/New-ApiScaffold.ps1)
- Pre-check tool: [tools/scripts/Validate-Artifacts.ps1](tools/scripts/Validate-Artifacts.ps1)
- Upstream project: [Azure/APIOps](https://github.com/Azure/apiops)
