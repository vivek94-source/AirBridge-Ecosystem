param(
  [switch]$CliMode,
  [string]$Device = "windows",
  [switch]$NoElevate
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step {
  param([string]$Text)
  Write-Host "[AirBridge] $Text" -ForegroundColor Cyan
}

function Resolve-Flutter {
  $candidates = @()

  $fromPath = Get-Command flutter -ErrorAction SilentlyContinue
  if ($fromPath) {
    $candidates += $fromPath.Source
  }

  $candidates += @(
    "C:\Users\ken07\flutter\bin\flutter.bat",
    "$env:USERPROFILE\flutter\bin\flutter.bat",
    "C:\src\flutter\bin\flutter.bat",
    "C:\flutter\bin\flutter.bat"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return (Resolve-Path $candidate).Path
    }
  }
  throw "Flutter SDK not found. Install Flutter and ensure flutter.bat is available."
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-SymlinkSupport {
  param([string]$Root)

  $probeDir = Join-Path $Root ".symlink_probe"
  $target = Join-Path $probeDir "target.txt"
  $link = Join-Path $probeDir "link.txt"

  try {
    New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
    Set-Content -Path $target -Value "probe" -Encoding ASCII
    New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
    return $true
  } catch {
    return $false
  } finally {
    Remove-Item -Path $probeDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Ensure-SymlinkCapability {
  param(
    [string]$Root,
    [switch]$CliMode,
    [string]$Device,
    [switch]$NoElevate
  )

  if (Test-SymlinkSupport -Root $Root) {
    return
  }

  if ((-not $NoElevate) -and (-not (Test-IsAdmin))) {
    Write-Step "Symlink support not available. Relaunching as Administrator..."
    $args = @(
      "-NoLogo",
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      "`"$PSCommandPath`"",
      "-Device",
      $Device,
      "-NoElevate"
    )
    if ($CliMode) {
      $args += "-CliMode"
    }

    Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList $args
    exit 0
  }

  throw "Symlink support is required. Enable Windows Developer Mode or run this script as Administrator."
}

function Ensure-FlutterProject {
  param([string]$FlutterPath, [string]$Root)

  if (-not (Test-Path (Join-Path $Root "windows"))) {
    Write-Step "Generating Flutter platform folders..."
    & $FlutterPath create --platforms=android,windows,linux,macos --project-name airbridge --org com.airbridge.prototype .
  }

  Write-Step "Running flutter pub get..."
  & $FlutterPath pub get
}

function Ensure-NodeDeps {
  param([string]$Root)
  $serverDir = Join-Path $Root "signaling-server"
  if (-not (Test-Path (Join-Path $serverDir "node_modules"))) {
    Write-Step "Installing signaling-server dependencies..."
    Push-Location $serverDir
    try {
      & npm.cmd install
    } finally {
      Pop-Location
    }
  }
}

function Ensure-PythonDeps {
  param([string]$Root)
  $gestureDir = Join-Path $Root "gesture_engine\desktop"
  $venvDir = Join-Path $gestureDir ".venv"
  $venvPython = Join-Path $venvDir "Scripts\python.exe"

  if (-not (Test-Path $venvPython)) {
    Write-Step "Creating gesture-engine virtual environment..."
    Push-Location $gestureDir
    try {
      & python -m venv .venv
    } finally {
      Pop-Location
    }
  }

  Write-Step "Installing gesture-engine dependencies..."
  & $venvPython -m pip install --upgrade pip
  & $venvPython -m pip install -r (Join-Path $gestureDir "requirements.txt")
}

$root = $PSScriptRoot
Write-Step "Project root: $root"

Ensure-SymlinkCapability -Root $root -CliMode:$CliMode -Device $Device -NoElevate:$NoElevate

$flutter = Resolve-Flutter
Write-Step "Flutter: $flutter"

Ensure-FlutterProject -FlutterPath $flutter -Root $root
Ensure-NodeDeps -Root $root
Ensure-PythonDeps -Root $root

$serverDir = Join-Path $root "signaling-server"
$gestureDir = Join-Path $root "gesture_engine\desktop"
$venvPython = Join-Path $gestureDir ".venv\Scripts\python.exe"

Write-Step "Starting signaling server..."
$serverProc = Start-Process -FilePath "powershell" -ArgumentList @(
  "-NoLogo",
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-Command",
  "Set-Location '$serverDir'; npm.cmd start"
) -PassThru

Write-Step "Starting gesture engine..."
$gestureProc = Start-Process -FilePath "powershell" -ArgumentList @(
  "-NoLogo",
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-Command",
  "Set-Location '$gestureDir'; & '$venvPython' '.\gesture_engine.py'"
) -PassThru

Start-Sleep -Seconds 2

Write-Step "Launching Flutter app..."
try {
  if ($CliMode) {
    & $flutter run -d $Device --dart-define=AIRBRIDGE_CLI=true
  } else {
    & $flutter run -d $Device
  }
} finally {
  Write-Step "Stopping background services..."
  if ($serverProc -and -not $serverProc.HasExited) {
    Stop-Process -Id $serverProc.Id -Force
  }
  if ($gestureProc -and -not $gestureProc.HasExited) {
    Stop-Process -Id $gestureProc.Id -Force
  }
}
