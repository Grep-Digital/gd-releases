#Requires -Version 5.1
<#
.SYNOPSIS
    Quick tip: step-ca health inside auth-sandbox-step-ca-1 (Base PKI).

.DESCRIPTION
    Does not print the CA password. Does not start containers.
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "[tip-stepca] Base PKI only - container auth-sandbox-step-ca-1" -ForegroundColor Cyan
$out = docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt 2>&1
Write-Host $out
if ($LASTEXITCODE -ne 0 -or ("$out" -notmatch "ok")) {
    Write-Host "[tip-stepca] FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "[tip-stepca] PASS (ok). Host :9000 is Envoy; step-ca :9000 is inside this container only." -ForegroundColor Green
