# ==============================================================================
# Mobile Network Resilience - Windows Uninstaller
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$KeepData = $false
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "CRITICAL: Administrator privileges are required to uninstall the service."
    exit 1
}

$TaskName = "XrayProxyService"
$InstallDir = "$env:ProgramFiles\Xray"
$DataDir = "$env:ProgramData\Xray"

Write-Host "Stopping and removing $TaskName..."
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Scheduled Task $TaskName removed."
}

# Terminate running xray processes if any linger
Get-Process -Name "xray" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "Removed binaries from $InstallDir."
}

if (-not $KeepData) {
    if (Test-Path $DataDir) {
        Remove-Item -Path $DataDir -Recurse -Force
        Write-Host "Removed data directory $DataDir."
    }
} else {
    Write-Host "Preserved data and configuration in $DataDir as requested."
}

Write-Host "Uninstallation complete."
