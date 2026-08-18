<#
.SYNOPSIS
  Scaffolds a standards-compliant APIOps artifact skeleton for a new API.

.DESCRIPTION
  Generates the folder/file layout the APIOps publisher expects under
  apimartifacts, pre-wired for enterprise concerns: API + operation policies,
  environment-driven backend routing via a named value, a shared policy
  fragment include, and tag governance. Designed for onboarding 50-500 APIs
  consistently.

.PARAMETER ApiName
  Artifact/URL-safe API name (folder name and APIM api name). e.g. isclaims

.PARAMETER DisplayName
  Human-friendly API display name. Defaults to ApiName.

.PARAMETER Path
  API URL suffix (APIM path). Defaults to ApiName.

.PARAMETER BackendUrl
  Default (dev) backend URL. Stored in the api-specific backend-url named value.

.PARAMETER Operations
  One or more operationIds to scaffold operation-level policy.xml files for.

.PARAMETER Tags
  One or more tag names to link the API to (tags are created if missing).

.PARAMETER ArtifactsRoot
  Root artifacts folder. Defaults to the repo's apimartifacts folder.

.EXAMPLE
  ./New-ApiScaffold.ps1 -ApiName isclaims -BackendUrl https://claims.dev.internal `
    -Operations getClaim,createClaim -Tags partner
#>
[CmdletBinding()]
param(
  [string] $ApiName,
  [string] $DisplayName,
  [string] $Path,
  [string] $BackendUrl,
  [string[]] $Operations = @(),
  [string[]] $Tags = @(),
  [string] $ArtifactsRoot = (Join-Path (Join-Path (Join-Path $PSScriptRoot '..') '..') 'apimartifacts')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Friendly prompts when values are not supplied (e.g. run from the VS Code task).
if (-not $ApiName) { $ApiName = (Read-Host 'API name (lowercase, url-safe, e.g. isclaims)').Trim() }
if (-not $ApiName) { throw 'API name is required.' }
if (-not $BackendUrl) { $BackendUrl = (Read-Host 'Backend base URL for dev (e.g. https://claims.dev.internal)').Trim() }
if (-not $BackendUrl) { throw 'Backend URL is required.' }

if (-not $DisplayName) { $DisplayName = $ApiName }
if (-not $Path) { $Path = $ApiName }

# Normalize so comma-separated values work whether passed as a real array
# (& call / dot-source) or as a single literal string (pwsh -File).
$Operations = @($Operations | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Tags = @($Tags | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$backendName = "$ApiName-backend"
$backendUrlNamedValue = "$ApiName-backend-url"

function New-File {
  param([string] $FilePath, [string] $Content)
  $dir = Split-Path -Parent $FilePath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (Test-Path -LiteralPath $FilePath) {
    Write-Warning "Skipping existing file: $FilePath"
    return
  }
  Set-Content -LiteralPath $FilePath -Value $Content -Encoding UTF8
  Write-Information "Created $FilePath" -InformationAction Continue
}

$apiRoot = Join-Path $ArtifactsRoot "apis/$ApiName"

# apiInformation.json
New-File (Join-Path $apiRoot 'apiInformation.json') (@"
{
  "properties": {
    "apiRevision": "1",
    "authenticationSettings": {},
    "description": "$DisplayName API published through APIOps.",
    "displayName": "$DisplayName",
    "path": "$Path",
    "protocols": [
      "https"
    ],
    "serviceUrl": "$BackendUrl",
    "subscriptionRequired": true
  }
}
"@)

# API-level policy: fragment include + backend routing + governance headers.
New-File (Join-Path $apiRoot 'policy.xml') (@"
<policies>
  <inbound>
    <base />
    <include-fragment fragment-id="correlation-id" />
    <set-backend-service backend-id="$backendName" />
    <set-header name="X-Api-Name" exists-action="override">
      <value>$ApiName</value>
    </set-header>
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
"@)

foreach ($op in $Operations) {
  New-File (Join-Path $apiRoot "operations/$op/policy.xml") (@"
<policies>
  <inbound>
    <base />
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
"@)
}

# Per-API backend + environment-driven URL named value.
New-File (Join-Path $ArtifactsRoot "backends/$backendName/backendInformation.json") (@"
{
  "properties": {
    "description": "$DisplayName backend. URL is environment-driven via the $backendUrlNamedValue named value.",
    "protocol": "http",
    "url": "{{$backendUrlNamedValue}}"
  }
}
"@)

New-File (Join-Path $ArtifactsRoot "named values/$backendUrlNamedValue/namedValueInformation.json") (@"
{
  "properties": {
    "displayName": "$backendUrlNamedValue",
    "secret": false,
    "tags": [
      "backend"
    ],
    "value": "$BackendUrl"
  }
}
"@)

foreach ($tag in $Tags) {
  New-File (Join-Path $ArtifactsRoot "tags/$tag/tagInformation.json") (@"
{
  "properties": {
    "displayName": "$tag"
  }
}
"@)
  New-File (Join-Path $ArtifactsRoot "tags/$tag/apis/$ApiName/tagApiInformation.json") "{}"
}

Write-Information "Scaffold complete for '$ApiName'. Add specification.json/.yaml next, then add the prod override in configuration.prod.yaml." -InformationAction Continue
Write-Information "  namedValues:`n    - name: $backendUrlNamedValue`n      properties:`n        value: <prod-url>" -InformationAction Continue
