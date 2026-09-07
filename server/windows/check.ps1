# ==============================================================================
# Mobile Network Resilience - Comprehensive Multi-Tier Health Check
# Checks: Binary -> Configuration -> Process -> Local Ports -> Tunnel -> Remote Endpoint
# ==============================================================================

[CmdletBinding()]
param(
    [string]$Domain = "",
    [switch]$Quiet = $false
)

$ErrorActionPreference = "Continue"

$InstallDir = "$env:ProgramFiles\Xray"
$XrayExe = Join-Path $InstallDir "xray.exe"
$ConfigFile = "$env:ProgramData\Xray\config\config.json"

$passed = $true

function Report-Check {
    param([string]$Tier, [string]$Name, [bool]$Success, [string]$Details)
    if ($Success) {
        Write-Host "[PASS] [$Tier] $Name: $Details" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] [$Tier] $Name: $Details" -ForegroundColor Red
        $script:passed = $false
    }
}

Write-Host "============================================================"
Write-Host " Running Multi-Tier System Health Check"
Write-Host "============================================================"

# Level 1: Binary Integrity
if (Test-Path $XrayExe) {
    $verOutput = & $XrayExe version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -eq 0) {
        Report-Check "LEVEL 1: BINARY" "xray.exe" $true "$verOutput"
    } else {
        Report-Check "LEVEL 1: BINARY" "xray.exe" $false "Binary execution failed with code $LASTEXITCODE"
    }
} else {
    Report-Check "LEVEL 1: BINARY" "xray.exe" $false "Binary missing at $XrayExe"
}

# Level 2: Configuration Validation
if (Test-Path $ConfigFile) {
    $testResult = & $XrayExe -test -config $ConfigFile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Report-Check "LEVEL 2: CONFIG" "config.json" $true "Syntax verified by Xray core"
    } else {
        Report-Check "LEVEL 2: CONFIG" "config.json" $false "Validation failed: $testResult"
    }
} else {
    Report-Check "LEVEL 2: CONFIG" "config.json" $false "Config file missing at $ConfigFile"
}

# Level 3: Process Execution
$proc = Get-Process -Name "xray" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc) {
    Report-Check "LEVEL 3: PROCESS" "xray" $true "Running (PID: $($proc.Id), Memory: $([math]::Round($proc.WorkingSet64/1MB,1)) MB)"
} else {
    Report-Check "LEVEL 3: PROCESS" "xray" $false "No active xray process found"
}

# Level 4: Local Port Bindings
$wsPort = Test-NetConnection -ComputerName 127.0.0.1 -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue
Report-Check "LEVEL 4: PORT" "WebSocket Inbound (127.0.0.1:8080)" $wsPort $(if ($wsPort) { "Listening" } else { "Not listening" })

$xhPort = Test-NetConnection -ComputerName 127.0.0.1 -Port 8081 -InformationLevel Quiet -WarningAction SilentlyContinue
Report-Check "LEVEL 4: PORT" "XHTTP Inbound (127.0.0.1:8081)" $xhPort $(if ($xhPort) { "Listening" } else { "Not listening" })

$ztPort = Test-NetConnection -ComputerName 127.0.0.1 -Port 10808 -InformationLevel Quiet -WarningAction SilentlyContinue
Report-Check "LEVEL 4: PORT" "ZeroTier Inbound (Port 10808)" $ztPort $(if ($ztPort) { "Listening" } else { "Not listening" })

# Level 5: Cloudflare Tunnel Daemon (cloudflared)
$cfProc = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cfProc) {
    Report-Check "LEVEL 5: TUNNEL" "cloudflared" $true "Daemon running (PID: $($cfProc.Id))"
} else {
    Report-Check "LEVEL 5: TUNNEL" "cloudflared" $false "cloudflared daemon is NOT running"
}

# Level 6: Remote Endpoint Resolution & Reachability
if ($Domain -ne "") {
    try {
        $dnsRes = Resolve-DnsName -Name $Domain -ErrorAction Stop
        Report-Check "LEVEL 6: ENDPOINT" "DNS Resolution for $Domain" $true "Resolved to $(($dnsRes | Select-Object -First 1).IPAddress)"
        
        # Test HTTPS handshake to edge
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $req = [System.Net.WebRequest]::Create("https://$Domain")
        $req.Timeout = 10000
        $req.Method = "GET"
        try {
            $resp = $req.GetResponse()
            Report-Check "LEVEL 6: ENDPOINT" "HTTPS Reachability" $true "Status: $([int]$resp.StatusCode)"
            $resp.Close()
        } catch [System.Net.WebException] {
            $statusCode = [int]$_.Response.StatusCode
            if ($statusCode -eq 404 -or $statusCode -eq 400 -or $statusCode -eq 403) {
                # 404 from Cloudflare Tunnel is expected for non-matching root path
                Report-Check "LEVEL 6: ENDPOINT" "HTTPS Reachability" $true "Edge reachable (HTTP $statusCode expected for non-proxy root)"
            } elseif ($statusCode -eq 524) {
                Report-Check "LEVEL 6: ENDPOINT" "HTTPS Reachability" $false "HTTP 524 Timeout (Tunnel not connected to origin)"
            } else {
                Report-Check "LEVEL 6: ENDPOINT" "HTTPS Reachability" $false "HTTP Status: $statusCode"
            }
        }
    } catch {
        Report-Check "LEVEL 6: ENDPOINT" "DNS / Connectivity" $false "$($_.Exception.Message)"
    }
} else {
    Write-Host "[INFO] [LEVEL 6: ENDPOINT] Domain check skipped (no -Domain provided)." -ForegroundColor DarkGray
}

Write-Host "============================================================"
if ($passed) {
    Write-Host "HEALTH CHECK RESULT: ALL TESTED TIERS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "HEALTH CHECK RESULT: ONE OR MORE TIERS FAILED" -ForegroundColor Red
    exit 1
}
