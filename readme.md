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

This is the full layout. Every folder is explained in the tables below.

```text
apiops-infy-poc/
├─ apimartifacts/                       # SOURCE OF TRUTH — everything published to APIM
│  ├─ apis/                             # One folder per API
│  │  └─ swagger-petstore/             # Reference example — copy this pattern
│  │     ├─ apiInformation.json        # API name, URL path, backend service URL
│  │     ├─ specification.json         # The OpenAPI/Swagger definition
│  │     ├─ policy.xml                 # API-wide rules (inbound/backend/outbound)
│  │     └─ operations/                # One folder per endpoint (name = operationId)
│  │        ├─ listPets/policy.xml     # Rules for just this endpoint
│  │        ├─ createPet/policy.xml
│  │        ├─ getPetById/policy.xml
│  │        └─ deletePet/policy.xml
│  ├─ backends/                         # Named targets an API forwards requests to
│  │  └─ petstore-backend/
│  │     └─ backendInformation.json    # Backend name + absolute URL
│  ├─ named values/                     # Reusable settings referenced in policies as {{name}}
│  │  ├─ petstore-backend-url/
│  │  │  └─ namedValueInformation.json
│  │  └─ platform-owner-team/
│  │     └─ namedValueInformation.json
│  ├─ policy fragments/                 # Reusable policy snippets shared by many APIs
│  │  └─ correlation-id/
│  │     ├─ policy.xml                 # The snippet body
│  │     └─ policyFragmentInformation.json  # Fragment name/description
│  └─ tags/                             # Labels to group & govern APIs
│     ├─ public/
│     │  ├─ tagInformation.json        # The tag itself
│     │  └─ apis/swagger-petstore/
│     │     └─ tagApiInformation.json  # Attaches this tag to that API
│     └─ partner/
│        ├─ tagInformation.json
│        └─ apis/swagger-petstore/
│           └─ tagApiInformation.json
├─ .github/                             # GitHub automation
│  ├─ workflows/                        # The CI/CD pipelines (GitHub Actions)
│  │  ├─ run-publisher.yaml            # Entry pipeline: push → publish to dev then prod
│  │  ├─ run-publisher-with-env.yaml   # Reusable job that runs the APIOps publisher
│  │  └─ run-extractor.yaml            # Pulls existing APIM config back into the repo
│  ├─ CODEOWNERS                        # Who must review changes to which folders
│  └─ pull_request_template.md          # Checklist shown on every PR
├─ docs/                                # Admin/setup guides (one-time setup)
│  ├─ provision-azure.md               # Create the Azure resources
│  └─ environment-setup.md             # Configure GitHub secrets/variables/environments
├─ tools/                               # Local helper tooling
│  └─ scripts/
│     ├─ New-ApiScaffold.ps1           # Generates a ready-to-edit API folder
│     └─ Validate-Artifacts.ps1        # Checks your files before you push
├─ .vscode/
│  └─ tasks.json                        # VS Code menu shortcuts for the scripts above
├─ configuration.prod.yaml              # Prod overrides (values that differ in production)
├─ configuration.extractor.yaml         # Settings for the extractor pipeline
├─ .gitignore
└─ readme.md                            # This file
```

### Top-level folders

| Folder | Purpose |
|---|---|
| `apimartifacts/` | **The source of truth.** Every file here describes part of your APIM and is what the pipeline publishes. This is where API teams work. |
| `.github/` | GitHub automation — the pipelines that publish your changes, plus review rules (`CODEOWNERS`) and the PR checklist. |
| `docs/` | One-time **admin** setup guides (create Azure resources, wire up GitHub). You rarely touch these after setup. |
| `tools/` | Helper scripts you run locally to scaffold a new API and to validate your files before pushing. |
| `.vscode/` | Editor convenience — Run Task menu entries that call the scripts in `tools/`. |

### Inside `apimartifacts/` (the folders you edit)

| Folder | What it holds | Nested folders |
|---|---|---|
| `apis/` | One sub-folder per API. | `<api>/operations/<operationId>/` — per-endpoint policies. Folder name must match the `operationId` in the spec. |
| `backends/` | Named targets an API routes to (one sub-folder per backend). | `<backend>/` holds `backendInformation.json` (name + absolute URL). |
| `named values/` | Reusable/secret settings referenced in policies as `{{name}}`; overridable per environment. | `<name>/` holds `namedValueInformation.json`. |
| `policy fragments/` | Reusable policy snippets many APIs can `include-fragment`. | `<fragment>/` holds the snippet `policy.xml` + its info file. |
| `tags/` | Labels to group and govern APIs. | `<tag>/apis/<api>/` attaches that tag to an API. |

### Per-API files (inside `apimartifacts/apis/<name>/`)

| File / folder | In plain words |
|---|---|
| `apiInformation.json` | The API's basic details (display name, URL path, backend service URL). |
| `specification.json` | Your API definition (the Swagger/OpenAPI document). |
| `policy.xml` | Rules applied to the whole API (headers, routing, auth). |
| `operations/<op>/policy.xml` | Rules for one endpoint only (e.g. caching, rate limits). |

### Root configuration files

| File | In plain words |
|---|---|
| `configuration.prod.yaml` | Production overrides — values that differ in prod (e.g. the prod APIM name, a prod backend URL). |
| `configuration.extractor.yaml` | Settings used by the extractor pipeline when pulling APIM config back into the repo. |

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
      <value>api-platform</value>
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
| Publish fails: *"Cannot find a property '<name>'"* | The policy references a named value or policy fragment that isn't in the target APIM yet. The pipeline auto-bootstraps fresh environments; if you still hit this, the referenced artifact is missing from the repo — add it, or run the publisher once in **Publish all** mode. |
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

> **Fresh environments bootstrap themselves.** The first time you publish to a
> brand-new APIM (dev, prod, or any new environment), the pipeline detects that
> the shared artifacts (policy fragments, named values, backends, tags) are
> missing and automatically runs a one-time **Publish all** to seed them before
> the incremental publish. No manual step required — every environment behaves
> the same way.

## Handy links
- Reference example to copy: [apimartifacts/apis/swagger-petstore/](apimartifacts/apis/swagger-petstore)
- First-time Azure setup (admins): [docs/provision-azure.md](docs/provision-azure.md)
- GitHub environment setup (admins): [docs/environment-setup.md](docs/environment-setup.md)
- New-API tool: [tools/scripts/New-ApiScaffold.ps1](tools/scripts/New-ApiScaffold.ps1)
- Pre-check tool: [tools/scripts/Validate-Artifacts.ps1](tools/scripts/Validate-Artifacts.ps1)
- Upstream project: [Azure/APIOps](https://github.com/Azure/apiops)
