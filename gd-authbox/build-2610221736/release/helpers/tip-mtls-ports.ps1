#Requires -Version 5.1
<#
.SYNOPSIS
    Quick tip: probe device mTLS :1029 and MQTT :8883 on the host (Base PKI overlay).

.DESCRIPTION
    Reports open or closed. Closed is expected when device listeners are not published.
    Does not enroll certificates. Does not start containers.
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-TcpOpen([int]$Port) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $iar = $c.BeginConnect("127.0.0.1", $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(800, $false)
        if (-not $ok) { $c.Close(); return $false }
        $c.EndConnect($iar) | Out-Null
        $c.Close()
        return $true
    }
    catch {
        return $false
    }
}

Write-Host "[tip-mtls] TCP probe host device listeners (optional on Base PKI)" -ForegroundColor Cyan
foreach ($port in @(1029, 8883)) {
    $state = if (Test-TcpOpen $port) { "open" } else { "closed" }
    Write-Host ("[tip-mtls] {0}={1}" -f $port, $state)
}

Write-Host "[tip-mtls] open = device listeners published. closed = overlay not on this install." -ForegroundColor DarkGray
Write-Host "[tip-mtls] HTTP device-trust scenarios: SCENARIO-TESTING.md S-75..S-83" -ForegroundColor DarkGray
