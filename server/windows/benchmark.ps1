# ==============================================================================
# Mobile Network Resilience - Multi-Tier Network Benchmark
# Accurately distinguishes: Direct Internet vs Tunnel/Proxy vs End-to-End Mobile
# ==============================================================================

[CmdletBinding()]
param(
    [string]$CloudflareDomain = "",
    [string]$ZeroTierServerIp = "10.147.17.1",
    [int]$Samples = 5
)

$ErrorActionPreference = "Continue"

Write-Host "============================================================"
Write-Host "  Mobile Network Resilience - Tiered Benchmark Engine"
Write-Host "============================================================"

# TIER 1: Direct Internet Baseline
Write-Host "`n[TIER 1: DIRECT INTERNET BASELINE]" -ForegroundColor Cyan

# 1.1 DNS Resolution Latency
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$dnsDirect = Resolve-DnsName -Name "cloudflare.com" -Type A -ErrorAction SilentlyContinue
$sw.Stop()
$dnsMs = $sw.ElapsedMilliseconds
Write-Host "  - Direct DNS Resolution (cloudflare.com): $dnsMs ms"

# 1.2 Direct TCP Connection Establishment Time (to Port 443)
$tcpTimes = @()
for ($i = 1; $i -le $Samples; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $tcpClient.BeginConnect("1.1.1.1", 443, $null, $null)
        $success = $ar.AsyncWaitHandle.WaitOne(3000, $false)
        $sw.Stop()
        if ($success) {
            $tcpClient.EndConnect($ar)
            $tcpTimes += $sw.ElapsedMilliseconds
        }
    } catch {
        $sw.Stop()
    } finally {
        $tcpClient.Close()
    }
}

if ($tcpTimes.Count -gt 0) {
    $avgTcp = ($tcpTimes | Measure-Object -Average).Average
    $minTcp = ($tcpTimes | Measure-Object -Minimum).Minimum
    $maxTcp = ($tcpTimes | Measure-Object -Maximum).Maximum
    Write-Host "  - Direct TCP Handshake (1.1.1.1:443): avg=[$([math]::Round($avgTcp,1)) ms], min=[$minTcp ms], max=[$maxTcp ms] ($($tcpTimes.Count)/$Samples success)"
} else {
    Write-Host "  - Direct TCP Handshake: FAILED (All probes timed out)" -ForegroundColor Yellow
}

# 1.3 Direct Packet Loss & Latency (ICMP)
$pingResult = Test-Connection -ComputerName "1.1.1.1" -Count $Samples -ErrorAction SilentlyContinue
if ($pingResult) {
    $pingAvg = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
    $lossPct = (($Samples - $pingResult.Count) / $Samples) * 100
    Write-Host "  - Direct ICMP Latency: $([math]::Round($pingAvg,1)) ms (Packet Loss: $lossPct%)"
} else {
    Write-Host "  - Direct ICMP Ping: 100% loss (or ICMP filtered)" -ForegroundColor Yellow
}

# TIER 2: Local Proxy & Ingress Layer
Write-Host "`n[TIER 2: LOCAL PROXY & TUNNEL LAYER]" -ForegroundColor Cyan

# 2.1 Local Inbound Socket Latency (Port 8080 WS)
$localWsTimes = @()
for ($i = 1; $i -le $Samples; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $c.Connect("127.0.0.1", 8080)
        $sw.Stop()
        $localWsTimes += $sw.ElapsedMilliseconds
    } catch {
        $sw.Stop()
    } finally {
        $c.Close()
    }
}
if ($localWsTimes.Count -gt 0) {
    $avgWs = ($localWsTimes | Measure-Object -Average).Average
    Write-Host "  - Local Xray Inbound (127.0.0.1:8080): avg=[$([math]::Round($avgWs, 1)) ms] (TCP socket accept)"
} else {
    Write-Host "  - Local Xray Inbound 8080: NOT LISTENING" -ForegroundColor Red
}

# 2.2 Cloudflare Edge Round-Trip (with Proper SNI and TLS)
if ($CloudflareDomain -ne "") {
    Write-Host "  - Testing Cloudflare Edge Handshake (https://$CloudflareDomain)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    $cfTimes = @()
    for ($i = 1; $i -le $Samples; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $req = [System.Net.HttpWebRequest]::Create("https://$CloudflareDomain")
            $req.Timeout = 5000
            $req.Method = "HEAD"
            $resp = $req.GetResponse()
            $sw.Stop()
            $cfTimes += $sw.ElapsedMilliseconds
            $resp.Close()
        } catch [System.Net.WebException] {
            $sw.Stop()
            # 404 is valid response from Cloudflare Tunnel root
            if ($_.Response.StatusCode -eq 404 -or $_.Response.StatusCode -eq 400) {
                $cfTimes += $sw.ElapsedMilliseconds
            }
        }
    }
    if ($cfTimes.Count -gt 0) {
        $avgCf = ($cfTimes | Measure-Object -Average).Average
        Write-Host "  - Cloudflare Edge TLS Handshake: avg=[$([math]::Round($avgCf,1)) ms] across $($cfTimes.Count) requests" -ForegroundColor Green
    } else {
        Write-Host "  - Cloudflare Edge TLS Handshake: FAILED or Timed Out" -ForegroundColor Yellow
    }
} else {
    Write-Host "  - Cloudflare Edge Handshake: Skipped (Provide -CloudflareDomain <domain> to test)" -ForegroundColor DarkGray
}

# TIER 3: End-to-End Android Client Measurement
Write-Host "`n[TIER 3: END-TO-END ANDROID CLIENT]" -ForegroundColor Cyan
Write-Host "  [!] STATUS: NOT MEASURED ON SERVER" -ForegroundColor Yellow
Write-Host "  Explanation: End-to-end client metrics (Android radio latency, carrier CGNAT,"
Write-Host "  TCP handshake through tunnel, and YouTube 720p stream buffer health) cannot"
Write-Host "  be simulated truthfully from the server side."
Write-Host "  To benchmark end-to-end:"
Write-Host "  1. Open HAPP on Android."
Write-Host "  2. Run the built-in Real Latency test (⚡ icon) on each profile."
Write-Host "  3. Open fast.com or speedtest.net inside the Android browser with VPN active."

Write-Host "`n============================================================"
Write-Host "  Benchmark complete."
Write-Host "============================================================"
