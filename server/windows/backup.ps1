# ==============================================================================
# Mobile Network Resilience - Windows Backup Utility
# ==============================================================================

[CmdletBinding()]
param(
    [string]$TargetArchive = ""
)

$ErrorActionPreference = "Stop"

$DataDir = "$env:ProgramData\Xray"
$BackupDir = Join-Path $DataDir "backups"
$ConfigDir = Join-Path $DataDir "config"

if (-not (Test-Path $BackupDir)) {
    New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ($TargetArchive -eq "") {
    $TargetArchive = Join-Path $BackupDir "xray-config-backup-$timestamp.zip"
}

Write-Host "Creating backup of configuration to $TargetArchive..."
Compress-Archive -Path "$ConfigDir\*" -DestinationPath $TargetArchive -Force

Write-Host "Backup created successfully. Size: $((Get-Item $TargetArchive).Length) bytes."
Write-Host "Location: $TargetArchive"
