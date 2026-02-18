param(
  [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path
)

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
  Write-Host "Flutter not found in PATH."
  Write-Host "Install Flutter SDK, add it to PATH, then rerun this script."
  exit 1
}

Push-Location $ProjectRoot
try {
  flutter create --platforms=android,windows,linux,macos --project-name airbridge --org com.airbridge.prototype .
  flutter pub get
  Write-Host "AirBridge bootstrap complete."
  Write-Host "Run: flutter run -d windows"
} finally {
  Pop-Location
}

