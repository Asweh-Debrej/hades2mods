<#
.SYNOPSIS
    Buat paket Thunderstore baru dari skeleton tools\templates\package (turunan template resmi v0.10.0).
.EXAMPLE
    # Mod baru (satu repo per mod, layout template resmi)
    tools\new-package.ps1 -Path mods\my-mod -Name My_Mod `
        -Description "Short description with the words players search for." `
        -WebsiteUrl https://github.com/Asweh-Debrej/my-mod
.EXAMPLE
    # Paket payung tanpa kode (hanya dependency)
    tools\new-package.ps1 -Path mods\x\packages\all -Name X -Description "..." -NoCode -Dependency AswehDebrej-X_A=1.0.0
#>
[CmdletBinding()]
param(
    # Folder paket, relatif ke root workspace
    [Parameter(Mandatory)] [string]$Path,
    # Nama Thunderstore: hanya a-z A-Z 0-9 _ (PERMANEN setelah rilis)
    [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z0-9_]+$')] [string]$Name,
    # Maks 250 karakter; dipakai pencarian Thunderstore
    [Parameter(Mandatory)] [ValidateLength(1, 250)] [string]$Description,
    [string]$WebsiteUrl = '',
    # Dependency tambahan, format Namespace-Nama=versi
    [string[]]$Dependency = @(),
    [string[]]$Category = @('mods'),
    # Paket library: pertahankan def.lua untuk mendokumentasikan API publik
    [switch]$Library,
    # Paket tanpa kode (payung/modpack): tanpa src/ dan tanpa dependency dasar
    [switch]$NoCode,
    [string]$IconLabel
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$ws = Get-WorkspaceConfig
$target = Join-Path $script:WorkspaceRoot $Path
if (Test-Path $target) { throw "Folder sudah ada: $target" }

$baseDependencies = [ordered]@{
    'Hell2Modding-Hell2Modding' = '1.0.112'
    'LuaENVY-ENVY'              = '1.2.1'
    'SGG_Modding-ModUtil'       = '4.0.1'
    'SGG_Modding-ReLoad'        = '1.0.3'
    'SGG_Modding-Chalk'         = '2.1.2'
}
$depLines = @()
if (-not $NoCode) {
    foreach ($key in $baseDependencies.Keys) { $depLines += "$key = ""$($baseDependencies[$key])""" }
}
foreach ($dep in $Dependency) {
    $parts = $dep.Split('=')
    if ($parts.Count -ne 2) { throw "Format dependency salah: '$dep' (harus Namespace-Nama=versi)" }
    $depLines += "$($parts[0].Trim()) = ""$($parts[1].Trim())"""
}

$srcCopy = ''
if (-not $NoCode) {
    $srcCopy = "`n[[build.copy]]`nsource = ""./src""`ntarget = ""./plugins""`n"
}

$tokens = @{
    '{{NAMESPACE}}'    = $ws.namespace
    '{{NAME}}'         = $Name
    '{{GUID}}'         = "$($ws.namespace)-$Name"
    '{{DISPLAY_NAME}}' = $Name.Replace('_', ' ')
    '{{DESCRIPTION}}'  = $Description.Replace('"', '\"')
    '{{WEBSITE_URL}}'  = $WebsiteUrl
    '{{DEPENDENCIES}}' = ($depLines -join "`n")
    '{{SRC_COPY}}'     = $srcCopy
    '{{CATEGORIES}}'   = (($Category | ForEach-Object { """$_""" }) -join ', ')
    '{{YEAR}}'         = (Get-Date).Year.ToString()
}

Write-Step "Membuat $($ws.namespace)-$Name di $Path"
$skeleton = Join-Path $PSScriptRoot 'templates\package'
$parent = Split-Path -Parent $target
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
Copy-Item $skeleton $target -Recurse
if ($NoCode) { Remove-Item (Join-Path $target 'src') -Recurse -Force }
elseif (-not $Library) { Remove-Item (Join-Path $target 'src\def.lua') -Force }

Get-ChildItem $target -Recurse -File | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName)
    foreach ($token in $tokens.Keys) { $text = $text.Replace($token, $tokens[$token]) }
    Write-Utf8NoBom $_.FullName $text
}

if (-not $IconLabel) { $IconLabel = $Name.Replace('_', "`n") }
New-PlaceholderIcon (Join-Path $target 'icon.png') $IconLabel
Write-Ok "icon.png placeholder (256x256) - daftarkan paket di tools\icons\icons.json lalu jalankan tools\icons.ps1"

Write-Host ""
Write-Host "Selesai. Berikutnya: isi README.md, tulis kode di src\, lalu tools\link.ps1 -Package $Name" -ForegroundColor Green
