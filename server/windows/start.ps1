# ==============================================================================
# Mobile Network Resilience - Windows Service Start
# ==============================================================================

$ErrorActionPreference = "Stop"

$TaskName = "XrayProxyService"
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Error "Task $TaskName is not registered. Run install.ps1 first."
    exit 1
}

Write-Host "Starting $TaskName..."
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2

$proc = Get-Process -Name "xray" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "Xray service is active (PID: $($proc.Id))."
} else {
    Write-Warning "Xray process did not appear. Check logs in $env:ProgramData\Xray\logs or run check.ps1."
}
