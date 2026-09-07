# ==============================================================================
# Mobile Network Resilience - Service Status Inspector
# ==============================================================================

$ErrorActionPreference = "Continue"

$TaskName = "XrayProxyService"
$InstallDir = "$env:ProgramFiles\Xray"
$ConfigFile = "$env:ProgramData\Xray\config\config.json"

Write-Host "============================================================"
Write-Host "  Mobile Network Resilience - Service Status Overview"
Write-Host "============================================================"

# 1. Scheduled Task Status
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "[TASK] State: $($task.State)"
} else {
    Write-Host "[TASK] State: NOT REGISTERED" -ForegroundColor Red
}

# 2. Process Status
$procs = Get-Process -Name "xray" -ErrorAction SilentlyContinue
if ($procs) {
    foreach ($p in $procs) {
        $workingSetMb = [math]::Round($p.WorkingSet64 / 1MB, 2)
        Write-Host "[PROC] PID: $($p.Id), Threads: $($p.Threads.Count), Memory: $workingSetMb MB, UpSince: $($p.StartTime)" -ForegroundColor Green
    }
} else {
    Write-Host "[PROC] No active xray.exe process found." -ForegroundColor Yellow
}

# 3. Local Ports Listening
Write-Host "[PORT CHECK]"
$ports = @(8080, 8081, 10808)
foreach ($p in $ports) {
    $t = Test-NetConnection -ComputerName 127.0.0.1 -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($t) {
        Write-Host "  - 127.0.0.1:$p : LISTENING (OK)" -ForegroundColor Green
    } else {
        Write-Host "  - 127.0.0.1:$p : CLOSED / UNREACHABLE" -ForegroundColor Yellow
    }
}

# 4. Cloudflared Service Status
$cfService = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
if ($cfService) {
    Write-Host "[CLOUDFLARED] Service Status: $($cfService.Status)"
} else {
    Write-Host "[CLOUDFLARED] Service not installed as Windows Service (manual or not running)."
}

# 5. ZeroTier Status
$ztService = Get-Service -Name "ZeroTierOneService" -ErrorAction SilentlyContinue
if ($ztService) {
    Write-Host "[ZEROTIER] Service Status: $($ztService.Status)"
} else {
    Write-Host "[ZEROTIER] ZeroTier service not installed or not running."
}

Write-Host "============================================================"
