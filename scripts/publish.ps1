param(
  [Parameter(Mandatory = $true)]
  [string]$Message
)

$ErrorActionPreference = "Stop"

Push-Location (Resolve-Path "$PSScriptRoot\..").Path
try {
  git add -A

  $hasChanges = git status --porcelain
  if (-not $hasChanges) {
    Write-Host "No changes to commit."
    exit 0
  }

  git commit -m $Message
  git push -u origin main
} finally {
  Pop-Location
}

