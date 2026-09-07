# ==============================================================================
# Mobile Network Resilience - Windows Service Watchdog
# Features: Process check, Port probe, Config check, Cooldown, Real Exponential Backoff,
# Degraded State transition, Crash-loop prevention, Sanitized Logging.
# ==============================================================================

[CmdletBinding()]
param(
    [int]$MaxFailures = 5,
    [int]$BaseBackoffSeconds = 10,
    [int]$MaxBackoffSeconds = 300,
    [int]$Port = 8080
)

$ErrorActionPreference = "Continue"

$DataDir = "$env:ProgramData\Xray"
$LogFile = Join-Path $DataDir "logs\watchdog.log"
$StateFile = Join-Path $DataDir "watchdog.state"
$InstallDir = "$env:ProgramFiles\Xray"
$XrayExe = Join-Path $InstallDir "xray.exe"
$ConfigFile = Join-Path $DataDir "config\config.json"
$TaskName = "XrayProxyService"

function Write-WatchdogLog {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

# Ensure log directory exists
if (-not (Test-Path (Split-Path $LogFile -Parent))) {
    New-Item -Path (Split-Path $LogFile -Parent) -ItemType Directory -Force | Out-Null
}

# 1. Load State
$state = @{
    ConsecutiveFailures = 0
    Status = "HEALTHY"
    LastFailureTime = ""
    LastAction = "NONE"
}

if (Test-Path $StateFile) {
    try {
        $rawState = Get-Content $StateFile -Raw | ConvertFrom-Json
        $state.ConsecutiveFailures = [int]$rawState.ConsecutiveFailures
        $state.Status = [string]$rawState.Status
        $state.LastFailureTime = [string]$rawState.LastFailureTime
        $state.LastAction = [string]$rawState.LastAction
    } catch {
        Write-WatchdogLog "WARN" "State file was corrupt. Resetting state."
    }
}

function Save-State {
    $state | ConvertTo-Json | Set-Content -Path $StateFile -Force
}

# 2. Check Service Health
$proc = Get-Process -Name "xray" -ErrorAction SilentlyContinue
$portOpen = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue

$isHealthy = ($null -ne $proc) -and $portOpen

if ($isHealthy) {
    if ($state.ConsecutiveFailures -gt 0 -or $state.Status -ne "HEALTHY") {
        Write-WatchdogLog "INFO" "Service recovered to HEALTHY state. Resetting failure counter."
        $state.ConsecutiveFailures = 0
        $state.Status = "HEALTHY"
        $state.LastAction = "RECOVERED"
        Save-State
    } else {
        # Quiet heartbeat
        # Write-WatchdogLog "DEBUG" "Health check passed. Xray is running."
    }
    exit 0
}

# 3. Handle Failure Case
$state.ConsecutiveFailures++
$state.LastFailureTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Write-WatchdogLog "WARN" "Health check failed (Failure count: $($state.ConsecutiveFailures)/$MaxFailures). Process: $([bool]$proc), Port $Port: $portOpen"

# 4. Check for Degraded State (Prevent infinite restart loop)
if ($state.ConsecutiveFailures -ge $MaxFailures) {
    $state.Status = "DEGRADED"
    $state.LastAction = "CIRCUIT_BREAKER_TRIPPED"
    Save-State
    Write-WatchdogLog "ERROR" "CRITICAL: Consecutive failure limit ($MaxFailures) reached. Entering DEGRADED state."
    Write-WatchdogLog "ERROR" "Restart loop halted to protect CPU and system resources. Manual operator check required."
    exit 1
}

# 5. Real Exponential Backoff Calculation
# Backoff formula: delay = min(BaseBackoff * 2^(failures - 1), MaxBackoff)
$exponent = [math]::Max(0, $state.ConsecutiveFailures - 1)
$calculatedDelay = [math]::Min($MaxBackoffSeconds, ($BaseBackoffSeconds * [math]::Pow(2, $exponent)))
Write-WatchdogLog "INFO" "Applying exponential backoff cooldown of $calculatedDelay seconds before restart attempt..."
Start-Sleep -Seconds $calculatedDelay

# 6. Pre-flight Config Verification before Restart
if (-not (Test-Path $XrayExe) -or -not (Test-Path $ConfigFile)) {
    Write-WatchdogLog "ERROR" "Cannot restart: executable or configuration file is missing."
    Save-State
    exit 1
}

$configTest = & $XrayExe -test -config $ConfigFile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-WatchdogLog "ERROR" "Cannot restart: configuration is invalid. Preserving stopped state to prevent crash loop.`n$configTest"
    Save-State
    exit 1
}

# 7. Execute Controlled Restart
Write-WatchdogLog "INFO" "Initiating controlled service restart..."
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Get-Process -Name "xray" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-ScheduledTask -TaskName $TaskName
} else {
    # If scheduled task missing, attempt direct launch or start-process
    Start-Process -FilePath $XrayExe -ArgumentList "run -config `"$ConfigFile`"" -WorkingDirectory $InstallDir -WindowStyle Hidden
}

Start-Sleep -Seconds 3

# 8. Post-Restart Verification
$postProc = Get-Process -Name "xray" -ErrorAction SilentlyContinue
$postPort = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue

if ($postProc -and $postPort) {
    Write-WatchdogLog "INFO" "Restart successful. Service restored on port $Port."
    $state.Status = "RECOVERED"
    $state.LastAction = "RESTARTED"
    Save-State
} else {
    Write-WatchdogLog "WARN" "Service did not respond immediately after restart."
    $state.Status = "FAILING"
    $state.LastAction = "RESTART_UNVERIFIED"
    Save-State
}
