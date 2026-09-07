# ==============================================================================
# Mobile Network Resilience - Configuration & Client Profile Generator
# Generates UUIDs, server configs, and HAPP client URIs without hardcoding secrets.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$Domain = "tunnel.yourdomain.com",
    [string]$ZeroTierIp = "10.147.17.1",
    [string]$OutputFile = "$env:ProgramData\Xray\config\config.json"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$TemplateFile = Join-Path $ProjectRoot "config\xray\config.windows.template.json"

if (-not (Test-Path $TemplateFile)) {
    Write-Error "Template file not found at $TemplateFile"
    exit 1
}

# 1. Generate Cryptographically Secure Values
$uuid = [guid]::NewGuid().ToString()
$rndBytes = New-Object byte[] 8
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($rndBytes)
$wsPath = "/ws-" + [System.BitConverter]::ToString($rndBytes).Replace("-", "").ToLower()

$rng.GetBytes($rndBytes)
$xhPath = "/xh-" + [System.BitConverter]::ToString($rndBytes).Replace("-", "").ToLower()

# 2. Populate Template
$templateContent = Get-Content $TemplateFile -Raw
$runtimeContent = $templateContent.Replace("00000000-0000-0000-0000-000000000000", $uuid)
$runtimeContent = $runtimeContent.Replace("/stream-ws-change-me", $wsPath)
$runtimeContent = $runtimeContent.Replace("/stream-xh-change-me", $xhPath)

# 3. Save Runtime Configuration
$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}
Set-Content -Path $OutputFile -Value $runtimeContent -Encoding UTF8

# 4. Generate HAPP Client URIs
$encodedWsPath = [System.Uri]::EscapeDataString($wsPath)
$encodedXhPath = [System.Uri]::EscapeDataString($xhPath)

$uriB1 = "vless://$uuid@$Domain`:443?security=tls&encryption=none&type=ws&path=$encodedWsPath&host=$Domain&fp=chrome&sni=$Domain#Profile-B1-Cloudflare-WS"
$uriB2 = "vless://$uuid@$Domain`:443?security=tls&encryption=none&type=xhttp&path=$encodedXhPath&mode=packet-up&host=$Domain&fp=chrome&sni=$Domain#Profile-B2-Cloudflare-XHTTP"
$uriC  = "vless://$uuid@$ZeroTierIp`:10808?security=none&encryption=none&type=tcp#Profile-C-ZeroTier-Emergency"

Write-Host "============================================================"
Write-Host " Configuration Generated Successfully"
Write-Host "============================================================"
Write-Host "Saved server configuration to: $OutputFile"
Write-Host "`n[HAPP ANDROID PROFILES - IMPORT VIA CLIPBOARD]" -ForegroundColor Green

Write-Host "`n--- Profile B1: Cloudflare Tunnel (WebSocket - Primary) ---" -ForegroundColor Cyan
Write-Host $uriB1

Write-Host "`n--- Profile B2: Cloudflare Tunnel (XHTTP - Fallback) ---" -ForegroundColor Cyan
Write-Host $uriB2

Write-Host "`n--- Profile C: ZeroTier (Emergency Out-of-Band) ---" -ForegroundColor Cyan
Write-Host $uriC

Write-Host "`n============================================================"
Write-Host "NOTE: Keep these URIs private. Do not share or commit them."
Write-Host "============================================================"
