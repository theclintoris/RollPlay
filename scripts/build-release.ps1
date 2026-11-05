#requires -Version 5.1
<#
.SYNOPSIS
    Build the RollPlay release binaries and stage the license files beside them.

.DESCRIPTION
    Requires Godot 4.7.2 with the Windows and Linux export templates installed.
    By default the script looks for the portable editor at
    ..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe, then falls back to
    GODOT_BIN or a `godot` command on PATH.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1

.EXAMPLE
    .\scripts\build-release.ps1 -SkipLinux -Version 0.2.0
#>
[CmdletBinding()]
param(
    [string]$Godot = "",
    [string]$Version = "",
    [switch]$SkipWindows,
    [switch]$SkipLinux
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

function Fail([string]$message) {
    Write-Host "ERROR: $message" -ForegroundColor Red
    exit 1
}

function Copy-Licenses([string]$targetDir) {
    $licenseDir = Join-Path $targetDir "LICENSES"
    New-Item -ItemType Directory -Force -Path $licenseDir | Out-Null
    Copy-Item -Path (Join-Path $projectRoot "THIRD_PARTY_NOTICES.txt") -Destination $targetDir -Force
    Copy-Item -Path (Join-Path $projectRoot "licenses\*.txt") -Destination $licenseDir -Force
}

function Write-Checksums([string]$targetDir, [string]$binaryName) {
    $lines = @()
    $binaryPath = Join-Path $targetDir $binaryName
    $binaryHash = (Get-FileHash -Algorithm SHA256 -Path $binaryPath).Hash
    $lines += "$($binaryHash.ToLower())  $binaryName"
    Get-ChildItem -Path $targetDir -Recurse -File |
        Where-Object { $_.Name -ne $binaryName -and $_.FullName -notlike "*SHA256SUMS*" } |
        Sort-Object FullName |
        ForEach-Object {
            $hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash.ToLower()
            $relative = $_.FullName.Substring($targetDir.Length).TrimStart("\", "/").Replace("\", "/")
            $lines += "$hash  $relative"
        }
    $lines | Set-Content -Path (Join-Path $targetDir "SHA256SUMS.txt") -Encoding ASCII
}

try {
    $resolvedGodot = $Godot
    if (-not $resolvedGodot -and $env:GODOT_BIN) {
        $resolvedGodot = $env:GODOT_BIN
    }
    if (-not $resolvedGodot) {
        $portable = Join-Path (Split-Path -Parent $projectRoot) ".tools\godot\Godot_v4.7.2-stable_win64_console.exe"
        if (Test-Path $portable) {
            $resolvedGodot = $portable
        }
    }
    if (-not $resolvedGodot) {
        $command = Get-Command "godot" -ErrorAction SilentlyContinue
        if ($command) { $resolvedGodot = $command.Source }
    }
    if (-not $resolvedGodot -or -not (Test-Path $resolvedGodot)) {
        Fail "Godot editor not found. Pass -Godot <path>, set GODOT_BIN, or add godot to PATH."
    }

    if ($Version) {
        $projectPath = Join-Path $projectRoot "project.godot"
        $source = Get-Content -Raw -Path $projectPath
        $updated = [regex]::Replace($source, 'config/version="[^"]+"', "config/version=`"$Version`"")
        Set-Content -Path $projectPath -Value $updated -Encoding UTF8 -NoNewline

        $presetsPath = Join-Path $projectRoot "export_presets.cfg"
        $presets = Get-Content -Raw -Path $presetsPath
        $numericVersion = $Version
        if ($numericVersion -notmatch '^\d+\.\d+\.\d+\.\d+$') {
            $numericVersion = "$Version.0"
        }
        $presets = [regex]::Replace($presets, 'application/file_version="[^"]+"', "application/file_version=`"$numericVersion`"")
        $presets = [regex]::Replace($presets, 'application/product_version="[^"]+"', "application/product_version=`"$numericVersion`"")
        Set-Content -Path $presetsPath -Value $presets -Encoding UTF8 -NoNewline
        Write-Host "Set project version to $Version (file version $numericVersion)"
    }

    # Godot writes project.binary into the OS temp directory during export.
    # Keep that work inside the repository so the build also works in sandboxes
    # and CI containers with a non-writable system temp folder.
    $tempDir = Join-Path $projectRoot ".tmp_export"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    $oldTemp = $env:TEMP
    $oldTmp = $env:TMP
    $oldTmpDir = $env:TMPDIR
    $env:TEMP = $tempDir
    $env:TMP = $tempDir
    $env:TMPDIR = $tempDir

    if (-not $SkipWindows) {
        $windowsDir = Join-Path $projectRoot "build\windows"
        New-Item -ItemType Directory -Force -Path $windowsDir | Out-Null
        Write-Host "Exporting Windows release..."
        & $resolvedGodot --headless --path $projectRoot --export-release "Windows Desktop" (Join-Path $windowsDir "RollPlay.exe")
        if ($LASTEXITCODE -ne 0) { Fail "Windows export failed with exit code $LASTEXITCODE." }
        # Never let a local metadata cache (or portable data folder) leak into a release.
        foreach ($localDir in @(".userdata", "RollPlayData")) {
            $localPath = Join-Path $windowsDir $localDir
            if (Test-Path $localPath) { Remove-Item -LiteralPath $localPath -Recurse -Force }
        }
        Copy-Licenses $windowsDir
        Write-Checksums $windowsDir "RollPlay.exe"
        Write-Host "Windows build ready: $windowsDir"
    }

    if (-not $SkipLinux) {
        $linuxDir = Join-Path $projectRoot "build\linux"
        New-Item -ItemType Directory -Force -Path $linuxDir | Out-Null
        Write-Host "Exporting Linux release..."
        & $resolvedGodot --headless --path $projectRoot --export-release "Linux" (Join-Path $linuxDir "RollPlay.x86_64")
        if ($LASTEXITCODE -ne 0) { Fail "Linux export failed with exit code $LASTEXITCODE." }
        foreach ($localDir in @(".userdata", "RollPlayData")) {
            $localPath = Join-Path $linuxDir $localDir
            if (Test-Path $localPath) { Remove-Item -LiteralPath $localPath -Recurse -Force }
        }
        Copy-Licenses $linuxDir
        Write-Checksums $linuxDir "RollPlay.x86_64"
        Write-Host "Linux build ready: $linuxDir"
        Write-Host "Tip: on Linux, run chmod +x RollPlay.x86_64 before archiving."
    }

    Write-Host ""
    Write-Host "Build complete. Test with:"
    if (-not $SkipWindows) { Write-Host "  build\windows\RollPlay.exe" }
} finally {
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
    $env:TMPDIR = $oldTmpDir
    Pop-Location
}
