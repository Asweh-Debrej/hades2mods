<#
.SYNOPSIS
    Build paket Thunderstore (.zip) dengan tcli. Zip bisa di-import ke r2modman
    (Settings > Import local mod) untuk menguji paket persis seperti yang akan dirilis.
.EXAMPLE
    tools\build.ps1                      # semua paket
    tools\build.ps1 -Package *Poms*      # satu paket
#>
[CmdletBinding()]
param([string[]]$Package)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$packages = Get-Packages $Package
if ($packages.Count -eq 0) { throw "Tidak ada paket yang cocok." }

$zips = @()
foreach ($pkg in $packages) {
    Write-Step "$($pkg.Guid) $($pkg.Version)"
    $zips += Invoke-TcliBuild $pkg
}

Write-Host ""
Write-Host "Hasil build:" -ForegroundColor Green
$zips | ForEach-Object { Write-Host "  $_" }
