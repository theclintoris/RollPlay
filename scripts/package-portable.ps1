#requires -Version 5.1
<#
.SYNOPSIS
    Package the Windows release as a portable ZIP for distribution.

.DESCRIPTION
    Creates a self-contained folder with RollPlay.exe, licenses, a portable
    marker, and a short readme, then compresses it into build\portable.
    The resulting build keeps its caches in RollPlayData beside the executable.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\package-portable.ps1
#>
[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$WindowsDir = "build\windows",
    [string]$OutputDir = "build\portable"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

function Fail([string]$message) {
    Write-Host "ERROR: $message" -ForegroundColor Red
    exit 1
}

try {
    if (-not $Version) {
        $projectSource = Get-Content -Raw -Path "project.godot"
        if ($projectSource -match 'config/version="([^"]+)"') {
            $Version = $Matches[1]
        } else {
            Fail "Could not read config/version from project.godot."
        }
    }

    if (-not (Test-Path (Join-Path $WindowsDir "RollPlay.exe"))) {
        Fail "Windows build not found. Run scripts\build-release.ps1 -SkipLinux first."
    }
    if (-not (Test-Path (Join-Path $WindowsDir "LICENSES"))) {
        Fail "License folder missing from the Windows build."
    }

    $packageName = "RollPlay-$Version-portable-win64"
    $stageDir = Join-Path $OutputDir $packageName
    $zipPath = Join-Path $OutputDir "$packageName.zip"
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    if (Test-Path $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force }
    if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

    Copy-Item -Path (Join-Path $WindowsDir "RollPlay.exe") -Destination $stageDir -Force
    Copy-Item -Path (Join-Path $WindowsDir "THIRD_PARTY_NOTICES.txt") -Destination $stageDir -Force
    Copy-Item -Path (Join-Path $WindowsDir "LICENSES") -Destination $stageDir -Recurse -Force

    Set-Content -Path (Join-Path $stageDir "portable.txt") -Encoding ASCII -Value @"
RollPlay portable mode.
Keep this file next to RollPlay.exe.
Caches and cover art are stored in the RollPlayData folder beside the app.
"@

    Set-Content -Path (Join-Path $stageDir "README-PORTABLE.txt") -Encoding ASCII -Value @"
RollPlay $Version - Portable Windows
Your library. One roll.

HOW TO PLAY
1. Unzip this folder anywhere you can write, for example:
   Desktop\RollPlay
2. Double-click RollPlay.exe.
3. Keep portable.txt next to RollPlay.exe. It keeps local data in
   RollPlayData beside the app instead of writing to AppData.

REQUIREMENTS
- Windows 10/11 (64-bit)
- Steam installed and signed in
- At least one fully installed Steam game
- Internet access the first time metadata and cover art are fetched

FIRST LAUNCH
- The all-random pool is ready immediately. Genres and cover art fill in as
  Steam store metadata loads in the background.
- R rolls or rolls again. Esc closes the library drawer.
- This build is unsigned, so Windows SmartScreen may warn. Choose
  More info > Run anyway if you trust the download.

DATA
- portable.txt switches RollPlay to portable data mode.
- Delete RollPlayData to clear cached metadata and covers.
- RollPlay does not install anything or modify your Steam library.

PRIVACY
- RollPlay itself has no account, telemetry, or backend.
- It reads local Steam manifests and requests public metadata and images from
  Valve's Steam Store. Launching uses Steam's steam:// protocol.

Source and updates:
https://github.com/theclintoris/RollPlay
"@

    # Hash every packaged file, including the readme and portable marker.
    $lines = @()
    Get-ChildItem -Path $stageDir -Recurse -File |
        Where-Object { $_.Name -ne "SHA256SUMS.txt" } |
        Sort-Object FullName |
        ForEach-Object {
            $hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash.ToLower()
            $relative = $_.FullName.Substring($stageDir.Length).TrimStart("\", "/").Replace("\", "/")
            $lines += "$hash  $relative"
        }
    $lines | Set-Content -Path (Join-Path $stageDir "SHA256SUMS.txt") -Encoding ASCII

    Compress-Archive -Path $stageDir -DestinationPath $zipPath -CompressionLevel Optimal -Force
    $zipHash = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLower()
    Set-Content -Path "$zipPath.sha256" -Encoding ASCII -Value "$zipHash  $(Split-Path -Leaf $zipPath)"

    $sizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Host "Portable package: $zipPath ($sizeMb MB)"
    Write-Host "Checksum: $zipPath.sha256"
} finally {
    Pop-Location
}
