<#
.SYNOPSIS
    Ikuti log Hell2Modding secara live (LogOutput.log di profil r2modman).
.EXAMPLE
    tools\tail-log.ps1                    # semua baris
    tools\tail-log.ps1 -Match AswehDebrej # hanya baris yang mengandung teks ini (regex)
#>
[CmdletBinding()]
param(
    [string]$ProfileName,
    [string]$Match,
    [int]$Tail = 40
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$log = Join-Path (Get-ProfileRoot $ProfileName) 'LogOutput.log'
if (-not (Test-Path $log)) { throw "Log belum ada: $log (jalankan game modded sekali dulu)" }
Write-Host "Mengikuti $log  (Ctrl+C untuk berhenti)" -ForegroundColor DarkGray

if ($Match) {
    Get-Content $log -Tail $Tail -Wait | Where-Object { $_ -match $Match }
} else {
    Get-Content $log -Tail $Tail -Wait
}
