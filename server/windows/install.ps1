# ==============================================================================
# Mobile Network Resilience - Windows 11 Automated Installer
# Role: Senior Network / Systems Engineer
# ==============================================================================

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:ProgramFiles\Xray",
    [string]$DataDir = "$env:ProgramData\Xray",
    [string]$Version = "latest",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# 1. Administrator Elevation Check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "CRITICAL: This installer must be executed within an elevated PowerShell session (Run as Administrator)."
    exit 1
}

# 2. OS & Architecture Check
$os = Get-CimInstance Win32_OperatingSystem
if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {
    Write-Error "CRITICAL: Unsupported architecture ($env:PROCESSOR_ARCHITECTURE). Only 64-bit Windows x64 is supported."
    exit 1
}
Write-Log "INFO" "Operating System: $($os.Caption) ($($os.Version)) 64-bit"

# 3. Directory Layout Creation (Idempotent)
$ConfigDir = Join-Path $DataDir "config"
$LogDir    = Join-Path $DataDir "logs"
$BackupDir = Join-Path $DataDir "backups"

foreach ($dir in @($InstallDir, $ConfigDir, $LogDir, $BackupDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Log "INFO" "Created directory: $dir"
    }
}

# 4. Resolve Xray-core Version
$XrayZipUrl = ""
$TargetVersion = ""
if ($Version -eq "latest") {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $apiUrl = "https://api.github.com/repos/XTLS/Xray-core/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell-Installer" } -TimeoutSec 15
        $TargetVersion = $release.tag_name
        $asset = $release.assets | Where-Object { $_.name -eq "Xray-windows-64.zip" }
        $XrayZipUrl = $asset.browser_download_url
        Write-Log "INFO" "Resolved latest official Xray release: $TargetVersion"
    } catch {
        Write-Log "WARN" "Failed to query GitHub API for latest release. Falling back to pinned release v26.3.27."
        $TargetVersion = "v26.3.27"
        $XrayZipUrl = "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-windows-64.zip"
    }
} else {
    $TargetVersion = $Version
    $XrayZipUrl = "https://github.com/XTLS/Xray-core/releases/download/$Version/Xray-windows-64.zip"
}

# 5. Download and Extract Binary
$XrayExePath = Join-Path $InstallDir "xray.exe"
$TempZip = Join-Path $env:TEMP "Xray-windows-64-$TargetVersion.zip"

if ((-not (Test-Path $XrayExePath)) -or $Force) {
    Write-Log "INFO" "Downloading Xray-core binary ($TargetVersion)..."
    Invoke-WebRequest -Uri $XrayZipUrl -OutFile $TempZip -UseBasicParsing
    
    if (-not (Test-Path $TempZip) -or ((Get-Item $TempZip).Length -lt 1000000)) {
        Write-Error "CRITICAL: Downloaded archive is invalid or truncated."
        exit 1
    }

    Write-Log "INFO" "Extracting archive to $InstallDir..."
    Expand-Archive -Path $TempZip -DestinationPath $InstallDir -Force
    Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
} else {
    Write-Log "INFO" "Xray binary already present at $XrayExePath. Use -Force to overwrite."
}

# Verify Executable
if (-not (Test-Path $XrayExePath)) {
    Write-Error "CRITICAL: xray.exe was not found in $InstallDir after extraction."
    exit 1
}

# 6. Configuration Generation / Provisioning
$ConfigFile = Join-Path $ConfigDir "config.json"
if (-not (Test-Path $ConfigFile)) {
    Write-Log "INFO" "Generating runtime configuration..."
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
    $TemplatePath = Join-Path $ProjectRoot "config\xray\config.windows.template.json"
    
    if (-not (Test-Path $TemplatePath)) {
        Write-Error "CRITICAL: Configuration template not found at $TemplatePath"
        exit 1
    }

    $rawContent = Get-Content $TemplatePath -Raw
    $newUuid = [guid]::NewGuid().ToString()
    $randomWsPath = "/ws-" + [System.IO.Path]::GetRandomFileName().Replace(".", "")
    $randomXhPath = "/xh-" + [System.IO.Path]::GetRandomFileName().Replace(".", "")

    $runtimeContent = $rawContent.Replace("00000000-0000-0000-0000-000000000000", $newUuid)
    $runtimeContent = $runtimeContent.Replace("/stream-ws-change-me", $randomWsPath)
    $runtimeContent = $runtimeContent.Replace("/stream-xh-change-me", $randomXhPath)

    Set-Content -Path $ConfigFile -Value $runtimeContent -Encoding UTF8
    Write-Log "INFO" "Configuration generated successfully at $ConfigFile (UUID generated: Redacted)"
} else {
    Write-Log "INFO" "Existing configuration preserved at $ConfigFile."
}

# 7. Validate Configuration Syntax with xray -test
Write-Log "INFO" "Validating configuration file syntax..."
$testOutput = & $XrayExePath -test -config $ConfigFile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "CRITICAL: Configuration validation failed:`n$testOutput"
    exit 1
}
Write-Log "INFO" "Configuration validation passed: Configuration OK."

# 8. Create or Update Windows Scheduled Task (Idempotent Service Alternative)
# Standard Windows Service creation for arbitrary executables without native SCM hooks
# is best maintained as an elevated boot-time Scheduled Task or NSSM wrapper.
$TaskName = "XrayProxyService"
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Log "INFO" "Unregistering previous scheduled task instance..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Write-Log "INFO" "Registering Scheduled Task '$TaskName' to start on system boot..."
$action = New-ScheduledTaskAction -Execute $XrayExePath -Argument "run -config `"$ConfigFile`"" -WorkingDirectory $InstallDir
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 3650)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

# 9. Start the Service
Write-Log "INFO" "Starting $TaskName..."
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 3

# 10. Multi-Level Health Check
Write-Log "INFO" "Performing initial health check..."
$CheckScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "check.ps1"
if (Test-Path $CheckScript) {
    & $CheckScript
} else {
    # Fallback port probe
    $wsPortOk = Test-NetConnection -ComputerName 127.0.0.1 -Port 8080 -InformationLevel Quiet
    if ($wsPortOk) {
        Write-Log "INFO" "Port 8080 (VLESS-WS) is successfully listening on 127.0.0.1."
    } else {
        Write-Log "WARN" "Port 8080 is not answering yet. Check Windows Event Viewer or logs."
    }
}

Write-Log "INFO" "============================================================"
Write-Log "INFO" "Installer completed successfully!"
Write-Log "INFO" "Binaries:      $InstallDir"
Write-Log "INFO" "Configuration: $ConfigFile"
Write-Log "INFO" "Logs:          $LogDir"
Write-Log "INFO" "============================================================"
