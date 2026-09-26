<#
.SYNOPSIS
    Hubungkan (junction) folder src/ paket ke profil r2modman untuk development + hot reload.
.DESCRIPTION
    Untuk tiap paket yang punya src/:
      1. tcli build -> ambil manifest.json dari zip (dibutuhkan r2modman/Hell2Modding untuk urutan load)
      2. salin manifest.json, icon.png, LICENSE, README.md, CHANGELOG.md ke src/ (di-gitignore)
      3. junction  <profil>\ReturnOfModding\plugins\<GUID>       -> src\
         junction  <profil>\ReturnOfModding\plugins_data\<GUID>  -> data\   (kalau ada)
    Junction tidak butuh admin. Edit file di src/ langsung terbaca game (ReLoad me-reload reload.lua).
.EXAMPLE
    tools\link.ps1                         # semua paket, profil dev
    tools\link.ps1 -Package *Hephaestus*   # satu paket
    tools\link.ps1 -Remove                 # lepas semua link (folder sumber aman)
#>
[CmdletBinding()]
param(
    [string]$ProfileName,
    [string[]]$Package,
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$profileRoot = Get-ProfileRoot $ProfileName
if (-not (Test-Path $profileRoot)) {
    throw "Profil r2modman tidak ditemukan: $profileRoot. Buat profilnya di r2modman dulu (lihat docs/04-workflow-dev.md)."
}

$packages = Get-Packages $Package | Where-Object { $_.HasSrc }
if ($packages.Count -eq 0) { throw "Tidak ada paket (dengan src/) yang cocok." }

foreach ($pkg in $packages) {
    Write-Step $pkg.Guid
    $pluginLink = Join-Path $profileRoot "plugins\$($pkg.Guid)"
    $dataLink = Join-Path $profileRoot "plugins_data\$($pkg.Guid)"

    if ($Remove) {
        Remove-Link $pluginLink
        Remove-Link $dataLink
        Write-Ok "link dilepas"
        continue
    }

    $src = Join-Path $pkg.Dir 'src'
    $zip = Invoke-TcliBuild $pkg
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $entry = $archive.GetEntry('manifest.json')
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $src 'manifest.json'), $true)
    } finally {
        $archive.Dispose()
    }
    foreach ($file in 'icon.png', 'LICENSE', 'README.md', 'CHANGELOG.md') {
        $from = Join-Path $pkg.Dir $file
        if (Test-Path $from) { Copy-Item $from (Join-Path $src $file) -Force }
    }

    New-Junction $pluginLink $src
    Write-Ok "plugins\$($pkg.Guid) -> $($pkg.RelDir)\src"
    if ($pkg.HasData) {
        New-Junction $dataLink (Join-Path $pkg.Dir 'data')
        Write-Ok "plugins_data\$($pkg.Guid) -> $($pkg.RelDir)\data"
    }
}

Write-Host ""
if ($Remove) {
    Write-Host "Selesai. Semua link dilepas; folder sumber tidak disentuh." -ForegroundColor Green
} else {
    Write-Host "Selesai. Jalankan game lewat r2modman (profil yang sama) > Start modded." -ForegroundColor Green
}
