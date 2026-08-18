<#
.SYNOPSIS
  Checks that all APIOps artifacts are valid before publishing.

.DESCRIPTION
  Parses every JSON and XML file under apimartifacts and reports problems in
  plain language. Run this (or the "APIOps: Validate artifacts" VS Code task)
  before opening a pull request. Exits with a non-zero code if anything fails,
  so it can also be used in CI.

.PARAMETER ArtifactsRoot
  Root artifacts folder. Defaults to the repo's apimartifacts folder.
#>
[CmdletBinding()]
param(
  [string] $ArtifactsRoot = (Join-Path (Join-Path $PSScriptRoot '..') '..' | Join-Path -ChildPath 'apimartifacts')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ArtifactsRoot)) {
  Write-Host "Could not find artifacts folder: $ArtifactsRoot" -ForegroundColor Red
  exit 1
}

$failures = New-Object System.Collections.Generic.List[string]

Get-ChildItem -LiteralPath $ArtifactsRoot -Recurse -File -Filter *.json | ForEach-Object {
  try {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null
  }
  catch {
    $failures.Add("Invalid JSON: $($_.FullName) -> $($_.Exception.Message)")
  }
}

Get-ChildItem -LiteralPath $ArtifactsRoot -Recurse -File -Filter *.xml | ForEach-Object {
  try {
    [xml](Get-Content -LiteralPath $_.FullName -Raw) | Out-Null
  }
  catch {
    $failures.Add("Invalid XML (policy): $($_.FullName) -> $($_.Exception.Message)")
  }
}

# Every API folder must have an apiInformation.json and a specification file.
Get-ChildItem -LiteralPath (Join-Path $ArtifactsRoot 'apis') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  $apiFolder = $_.FullName
  if (-not (Test-Path -LiteralPath (Join-Path $apiFolder 'apiInformation.json'))) {
    $failures.Add("Missing apiInformation.json in $apiFolder")
  }
  $hasSpec = @(Get-ChildItem -LiteralPath $apiFolder -File | Where-Object { $_.Name -like 'specification.*' }).Count -gt 0
  if (-not $hasSpec) {
    $failures.Add("Missing specification.json/.yaml in $apiFolder")
  }
}

if ($failures.Count -gt 0) {
  Write-Host "Validation FAILED. Fix these before opening a pull request:" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}

Write-Host "All artifacts look good. You're ready to open a pull request." -ForegroundColor Green
exit 0
