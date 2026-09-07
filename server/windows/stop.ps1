# ==============================================================================
# Mobile Network Resilience - Windows Service Stop
# ==============================================================================

$ErrorActionPreference = "Stop"

$TaskName = "XrayProxyService"
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($task) {
    Write-Host "Stopping Scheduled Task $TaskName..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
}

$procs = Get-Process -Name "xray" -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "Terminating active xray processes..."
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
}

Write-Host "Xray service stopped."
