# ==============================================================================
# Mobile Network Resilience - Safe Windows Updater with Automatic Rollback
# ==============================================================================

[CmdletBinding()]
param(
    [string]$TargetVersion = "latest"
)

$ErrorActionPreference = "Stop"

function Write-UpdateLog {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "CRITICAL: Administrator privileges required for updater."
    exit 1
}

$InstallDir = "$env:ProgramFiles\Xray"
$DataDir    = "$env:ProgramData\Xray"
$BackupDir  = Join-Path $DataDir "backups"
$ConfigFile = Join-Path $DataDir "config\config.json"
$TaskName   = "XrayProxyService"
$XrayExe    = Join-Path $InstallDir "xray.exe"

if (-not (Test-Path $BackupDir)) {
    New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
}

# 1. Resolve Target Version URL
Write-UpdateLog "INFO" "Resolving target version ($TargetVersion)..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$downloadUrl = ""
$resolvedTag = ""
if ($TargetVersion -eq "latest") {
    try {
        $apiRes = Invoke-RestMethod -Uri "https://api.github.com/repos/XTLS/Xray-core/releases/latest" -Headers @{ "User-Agent" = "PowerShell-Updater" } -TimeoutSec 15
        $resolvedTag = $apiRes.tag_name
        $asset = $apiRes.assets | Where-Object { $_.name -eq "Xray-windows-64.zip" }
        $downloadUrl = $asset.browser_download_url
        Write-UpdateLog "INFO" "Latest release tag is $resolvedTag"
    } catch {
        Write-UpdateLog "WARN" "Failed to query GitHub API. Using pinned fallback release v26.3.27."
        $resolvedTag = "v26.3.27"
        $downloadUrl = "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-windows-64.zip"
    }
} else {
    $resolvedTag = $TargetVersion
    $downloadUrl = "https://github.com/XTLS/Xray-core/releases/download/$TargetVersion/Xray-windows-64.zip"
}

# Check current version
if (Test-Path $XrayExe) {
    $currentVer = & $XrayExe version 2>&1 | Select-Object -First 1
    Write-UpdateLog "INFO" "Current installed version: $currentVer"
}

# 2. Download and Verify New Archive
$tempZip = Join-Path $env:TEMP "Xray-update-$resolvedTag.zip"
$extractTemp = Join-Path $env:TEMP "Xray-extracted-$resolvedTag"

Write-UpdateLog "INFO" "Downloading new version from $downloadUrl..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing

if (-not (Test-Path $tempZip) -or ((Get-Item $tempZip).Length -lt 1000000)) {
    Write-Error "Downloaded file is corrupted or missing."
    exit 1
}

# Test extraction in temporary sandbox
if (Test-Path $extractTemp) { Remove-Item $extractTemp -Recurse -Force }
Expand-Archive -Path $tempZip -DestinationPath $extractTemp -Force
$newXrayExe = Join-Path $extractTemp "xray.exe"

if (-not (Test-Path $newXrayExe)) {
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "Downloaded archive did not contain xray.exe."
    exit 1
}

# 3. Create Backup of Current Version
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$currentBackupPath = Join-Path $BackupDir "xray-backup-$timestamp"
Write-UpdateLog "INFO" "Creating backup of current installation to $currentBackupPath..."
New-Item -Path $currentBackupPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$InstallDir\*" -Destination $currentBackupPath -Recurse -Force

# Rollback function
function Invoke-Rollback {
    Write-UpdateLog "ERROR" "============================================================"
    Write-UpdateLog "ERROR" "CRITICAL: Upgrade failed healthcheck! INITIATING ROLLBACK..."
    Write-UpdateLog "ERROR" "============================================================"
    
    # Stop any crashed process
    Get-Process -Name "xray" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Restore files from backup
    Copy-Item -Path "$currentBackupPath\*" -Destination $InstallDir -Recurse -Force
    Write-UpdateLog "INFO" "Restored previous binaries from $currentBackupPath."
    
    # Start previous version
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 3
    
    $checkProc = Get-Process -Name "xray" -ErrorAction SilentlyContinue
    if ($checkProc) {
        Write-UpdateLog "INFO" "Rollback successful. Previous version restored and active."
    } else {
        Write-UpdateLog "ERROR" "Rollback failed to start previous service. Operator intervention required."
    }
}

try {
    # 4. Stop Service for Binary Swap
    Write-UpdateLog "INFO" "Stopping $TaskName for binary update..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Get-Process -Name "xray" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # 5. Install New Binaries
    Write-UpdateLog "INFO" "Deploying new binaries to $InstallDir..."
    Copy-Item -Path "$extractTemp\*" -Destination $InstallDir -Recurse -Force

    # 6. Validate Configuration with New Binary
    Write-UpdateLog "INFO" "Validating configuration with upgraded binary..."
    $valOutput = & $XrayExe -test -config $ConfigFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-UpdateLog "ERROR" "New binary rejected configuration!`n$valOutput"
        throw "ConfigValidationFailed"
    }

    # 7. Start Service
    Write-UpdateLog "INFO" "Starting updated service..."
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 4

    # 8. Multi-Level Health Check
    $upProc = Get-Process -Name "xray" -ErrorAction SilentlyContinue
    $portOpen = Test-NetConnection -ComputerName 127.0.0.1 -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue

    if (-not $upProc -or -not $portOpen) {
        Write-UpdateLog "ERROR" "Health check failed after upgrade! Process running: $([bool]$upProc), Port 8080 open: $portOpen"
        throw "HealthCheckFailed"
    }

    Write-UpdateLog "INFO" "Health check PASSED. New version is operational."
    
    # Cleanup temporary download files
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
    
    # Rotate backups: keep last 3 backups, delete older ones
    $oldBackups = Get-ChildItem -Path $BackupDir -Directory | Sort-Object CreationTime -Descending | Select-Object -Skip 3
    foreach ($ob in $oldBackups) {
        Remove-Item -Path $ob.FullName -Recurse -Force
        Write-UpdateLog "INFO" "Pruned old backup: $($ob.Name)"
    }

    Write-UpdateLog "INFO" "Upgrade to $resolvedTag completed successfully with verified healthcheck!"

} catch {
    Write-UpdateLog "ERROR" "Caught failure during update: $($_.Exception.Message)"
    Invoke-Rollback
    exit 1
}
