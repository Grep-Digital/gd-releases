#Requires -Version 5.1
<#
.SYNOPSIS
    Set $Build, $KC, $API, and $Access for one of the three published builds.

.DESCRIPTION
    Dot-source so the variables stay in your session.
    Does not start or replace containers.
    Values: base | base-secure | base-pki

.EXAMPLE
    . .\set-build.ps1 -Build base
    . .\set-build.ps1 -Build base-secure
    . .\set-build.ps1 -Build base-pki
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("base", "base-secure", "base-pki")]
    [string]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

switch ($Build) {
    "base" {
        $Access = "direct"
        $KC = "http://localhost:8080"
        $API = "http://localhost:8000"
    }
    "base-secure" {
        $Access = "gateway"
        $KC = "http://localhost:9000"
        $API = "http://localhost:9000"
    }
    "base-pki" {
        $Access = "gateway"
        $KC = "http://localhost:9000"
        $API = "http://localhost:9000"
    }
}

Write-Host ("[set-build] Build={0} Access={1} KC={2} API={3}" -f $Build, $Access, $KC, $API) -ForegroundColor Cyan
Write-Host "[set-build] Dot-source this script. Next: . .\health-build.ps1" -ForegroundColor DarkGray
