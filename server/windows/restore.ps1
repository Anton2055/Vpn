# ==============================================================================
# Mobile Network Resilience - Windows Restore Utility
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceArchive = ""
)

$ErrorActionPreference = "Stop"

$DataDir = "$env:ProgramData\Xray"
$BackupDir = Join-Path $DataDir "backups"
$ConfigDir = Join-Path $DataDir "config"
$InstallDir = "$env:ProgramFiles\Xray"
$XrayExe = Join-Path $InstallDir "xray.exe"
$TaskName = "XrayProxyService"

if ($SourceArchive -eq "") {
    # Pick latest backup file
    $latest = Get-ChildItem -Path $BackupDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Error "No backup archive found in $BackupDir."
        exit 1
    }
    $SourceArchive = $latest.FullName
    Write-Host "Auto-selected latest backup: $SourceArchive"
}

if (-not (Test-Path $SourceArchive)) {
    Write-Error "Archive not found at $SourceArchive"
    exit 1
}

Write-Host "Extracting backup to $ConfigDir..."
Expand-Archive -Path $SourceArchive -DestinationPath $ConfigDir -Force

# Validate restored configuration
$configFile = Join-Path $ConfigDir "config.json"
if (Test-Path $XrayExe -and Test-Path $configFile) {
    Write-Host "Validating restored configuration syntax..."
    $val = & $XrayExe -test -config $configFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Restored configuration failed syntax validation:`n$val"
        exit 1
    }
    Write-Host "Restored configuration syntax verified OK."
}

Write-Host "Restarting service to apply restored configuration..."
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir "restart.ps1")

Write-Host "Restore complete."
