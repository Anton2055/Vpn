# ==============================================================================
# Mobile Network Resilience - Sanitized Log Inspector
# Masks UUIDs, Tokens, and Private Keys from log output.
# ==============================================================================

[CmdletBinding()]
param(
    [int]$Lines = 50,
    [switch]$Follow = $false,
    [string]$Level = "ALL"
)

$ErrorActionPreference = "Continue"

$DataDir = "$env:ProgramData\Xray"
$WatchdogLog = Join-Path $DataDir "logs\watchdog.log"
$AccessLog   = Join-Path $DataDir "logs\access.log"
$ErrorLog    = Join-Path $DataDir "logs\error.log"

function Sanitize-Line {
    param([string]$line)
    # Mask standard UUIDs
    $line = $line -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', 'REDACTED-UUID'
    # Mask tokens or long base64 keys
    $line = $line -replace 'token=[a-zA-Z0-9_\-\.]{15,}', 'token=REDACTED-TOKEN'
    $line = $line -replace 'pbk=[a-zA-Z0-9_\-\.]{20,}', 'pbk=REDACTED-KEY'
    $line = $line -replace 'privateKey":\s*"[^"]+"', 'privateKey": "REDACTED"'
    return $line
}

Write-Host "============================================================"
Write-Host "  Sanitized Service Logs (Last $Lines lines)"
Write-Host "============================================================"

if (Test-Path $WatchdogLog) {
    Write-Host "`n--- [Watchdog Event Log] ---" -ForegroundColor Cyan
    Get-Content $WatchdogLog -Tail $Lines | ForEach-Object {
        $clean = Sanitize-Line $_
        if ($clean -match "\[ERROR\]") {
            Write-Host $clean -ForegroundColor Red
        } elseif ($clean -match "\[WARN\]") {
            Write-Host $clean -ForegroundColor Yellow
        } else {
            Write-Host $clean -ForegroundColor Gray
        }
    }
} else {
    Write-Host "No watchdog log found at $WatchdogLog." -ForegroundColor DarkGray
}

if (Test-Path $ErrorLog) {
    Write-Host "`n--- [Xray Error Log] ---" -ForegroundColor Yellow
    Get-Content $ErrorLog -Tail $Lines | ForEach-Object {
        $clean = Sanitize-Line $_
        Write-Host $clean -ForegroundColor DarkYellow
    }
}

Write-Host "`n============================================================"
