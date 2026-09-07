# ==============================================================================
# Mobile Network Resilience - Windows Service Restart
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Restarting Xray service..."
& (Join-Path $ScriptDir "stop.ps1")
Start-Sleep -Seconds 2
& (Join-Path $ScriptDir "start.ps1")
Write-Host "Restart sequence completed."
