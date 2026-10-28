#Requires -Version 5.1
<#
.SYNOPSIS
    Minimum health checks for the build already set by set-build.ps1.

.DESCRIPTION
    Uses $Build / $KC / $API from the session. Does not print secrets.
    Does not start containers.
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $Build -or -not $KC -or -not $API) {
    Write-Host "[health-build] ERROR: run . .\set-build.ps1 -Build base|base-secure|base-pki first" -ForegroundColor Red
    exit 1
}

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

$failed = 0

Write-Host ("[health-build] Build={0}" -f $Build) -ForegroundColor Cyan

# Postgres
$pg = docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab 2>&1
if ($LASTEXITCODE -eq 0 -and ("$pg" -match "accepting")) {
    Write-Host "[health-build] PASS postgres" -ForegroundColor Green
}
else {
    Write-Host "[health-build] FAIL postgres" -ForegroundColor Red
    $failed++
}

# API health
try {
    $h = Invoke-RestMethod -Uri "$API/authbox/health" -TimeoutSec 5
    if ($h.status -eq "ok") {
        Write-Host ("[health-build] PASS api {0}/authbox/health" -f $API) -ForegroundColor Green
    }
    else {
        Write-Host "[health-build] FAIL api status" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host ("[health-build] FAIL api {0}" -f $_.Exception.Message) -ForegroundColor Red
    $failed++
}

# Keycloak discovery
try {
    $kc = Invoke-WebRequest -Uri "$KC/realms/nexus-test/.well-known/openid-configuration" -UseBasicParsing -TimeoutSec 5
    if ($kc.StatusCode -eq 200) {
        Write-Host ("[health-build] PASS keycloak {0}" -f $KC) -ForegroundColor Green
    }
    else {
        Write-Host "[health-build] FAIL keycloak status" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host ("[health-build] FAIL keycloak {0}" -f $_.Exception.Message) -ForegroundColor Red
    $failed++
}

# Envoy admin
try {
    $en = Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing -TimeoutSec 5
    if ($en.StatusCode -eq 200) {
        Write-Host "[health-build] PASS envoy admin :9901/ready" -ForegroundColor Green
    }
    else {
        Write-Host "[health-build] FAIL envoy admin" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host ("[health-build] FAIL envoy {0}" -f $_.Exception.Message) -ForegroundColor Red
    $failed++
}

# Lab ports: open on base, closed on secure/pki
$lab8000 = Test-TcpOpen 8000
$lab8080 = Test-TcpOpen 8080
if ($Build -eq "base") {
    if ($lab8000 -and $lab8080) {
        Write-Host "[health-build] PASS lab ports :8000 and :8080 open" -ForegroundColor Green
    }
    else {
        Write-Host "[health-build] FAIL lab ports should be open on Base" -ForegroundColor Red
        $failed++
    }
}
else {
    if (-not $lab8000 -and -not $lab8080) {
        Write-Host "[health-build] PASS lab ports :8000 and :8080 unpublished" -ForegroundColor Green
    }
    else {
        Write-Host "[health-build] FAIL lab ports should be unpublished on Base Secure / Base PKI" -ForegroundColor Red
        $failed++
    }
}

# step-ca only on base-pki
if ($Build -eq "base-pki") {
    $ca = docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt 2>&1
    if ($LASTEXITCODE -eq 0 -and ("$ca" -match "ok")) {
        Write-Host "[health-build] PASS step-ca" -ForegroundColor Green
    }
    else {
        Write-Host "[health-build] FAIL step-ca" -ForegroundColor Red
        $failed++
    }
}

if ($failed -gt 0) {
    Write-Host ("[health-build] DONE with {0} failure(s)" -f $failed) -ForegroundColor Red
    exit 1
}
Write-Host "[health-build] DONE all PASS" -ForegroundColor Green
