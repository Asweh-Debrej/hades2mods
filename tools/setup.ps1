<#
.SYNOPSIS
    Setup workspace modding Hades II. Aman dijalankan berulang kali.
.DESCRIPTION
    - Validasi path game dan profil r2modman (workspace.json)
    - Install Thunderstore CLI (tcli) sebagai dotnet global tool
    - Ambil definisi Lua Hell2Modding (rom.*) ke .defs/
    - Buat junction reference/game-scripts dan reference/game-data (read-only, untuk search)
    - Generate .luarc.json untuk Lua Language Server (autocomplete)
    Jalankan ulang setelah install library baru di profil r2modman.
#>
[CmdletBinding()]
param(
    # Profil r2modman yang library-nya dipakai untuk autocomplete (default: devProfile di workspace.json)
    [string]$ProfileName
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$ws = Get-WorkspaceConfig
$root = $script:WorkspaceRoot
if (-not $ProfileName) { $ProfileName = $ws.devProfile }

Write-Step "Path game"
$scripts = Join-Path $ws.gamePath 'Content\Scripts'
if (-not (Test-Path $scripts)) { throw "Script game tidak ditemukan di $scripts. Perbaiki gamePath di workspace.json." }
Write-Ok $ws.gamePath

Write-Step "Thunderstore CLI (tcli)"
try { Assert-Tcli } catch {
    & dotnet tool install -g tcli | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Gagal install tcli (butuh .NET SDK)." }
    Assert-Tcli
}
# tcli prints its version to stderr; capture it through cmd so PowerShell 5.1 doesn't treat it as an error
Write-Ok ((& cmd /c "tcli --version 2>&1") -join ' ')

Write-Step "Definisi Lua Hell2Modding (.defs/Hell2Modding)"
$defs = Join-Path $root '.defs\Hell2Modding'
if (Test-Path (Join-Path $defs '.git')) {
    & git -C $defs pull --quiet
} else {
    & git clone --quiet --depth 1 --filter=blob:none --sparse https://github.com/SGG-Modding/Hell2Modding.git $defs
    & git -C $defs sparse-checkout set docs/lua
}
if ($LASTEXITCODE -ne 0) { throw "Gagal mengambil definisi Hell2Modding." }
Write-Ok $defs

Write-Step "Referensi game (reference/, read-only)"
New-Junction (Join-Path $root 'reference\game-scripts') $scripts
New-Junction (Join-Path $root 'reference\game-data') (Join-Path $ws.gamePath 'Content\Game')
Write-Ok "reference\game-scripts, reference\game-data"

Write-Step "Profil r2modman '$ProfileName'"
$profileRoot = Get-ProfileRoot $ProfileName
$plugins = Join-Path $profileRoot 'plugins'
$library = @()
if (Test-Path $plugins) {
    $installed = Get-ChildItem $plugins -Directory | Select-Object -ExpandProperty Name
    $required = 'LuaENVY-ENVY', 'SGG_Modding-ModUtil', 'SGG_Modding-ReLoad', 'SGG_Modding-Chalk'
    $recommended = 'SGG_Modding-Hades2GameDef', 'SGG_Modding-SeerSuite', 'PonyWarrior-PonyMenu'
    foreach ($name in $required) {
        if ($installed -contains $name) { Write-Ok $name } else { Write-Warn2 "$name BELUM terpasang (wajib)" }
    }
    foreach ($name in $recommended) {
        if ($installed -contains $name) { Write-Ok $name } else { Write-Warn2 "$name belum terpasang (disarankan untuk dev)" }
    }
    # Library = every installed plugin except our own linked packages (avoids duplicate definitions)
    $library = Get-ChildItem $plugins -Directory |
        Where-Object { $_.Name -notlike "$($ws.namespace)-*" } |
        ForEach-Object { $_.FullName }
} else {
    Write-Warn2 "Profil belum ada: $profileRoot"
    Write-Warn2 "Buat profil '$ProfileName' di r2modman (Hades II), install PonyMenu + SeerSuite + Hades2GameDef, lalu jalankan ulang script ini."
}

Write-Step ".luarc.json (Lua Language Server)"
$library += (Join-Path $defs 'docs\lua')
$library += $scripts
$luarc = [ordered]@{
    '$schema'                     = 'https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json'
    'runtime.version'             = 'Lua 5.2'
    'workspace.library'           = @($library | ForEach-Object { $_ -replace '\\', '/' })
    'workspace.ignoreDir'         = @('reference', '.defs', 'build')
    'workspace.checkThirdParty'   = $false
    'workspace.preloadFileSize'   = 2000
    'workspace.maxPreload'        = 10000
    'diagnostics.libraryFiles'    = 'Disable'
    'diagnostics.globals'         = @(
        'rom', '_PLUGIN', 'public', 'private', 'import', 'import_all', 'import_as_fallback', 'import_as_shared', 'export',
        'game', 'modutil', 'chalk', 'reload', 'config', 'mod', 'sjson', 'core',
        'ImGui', 'ImGuiCond', 'ImGuiTableFlags', 'ImGuiWindowFlags'
    )
}
Write-Utf8NoBom (Join-Path $root '.luarc.json') ($luarc | ConvertTo-Json -Depth 5)
Write-Ok "$($library.Count) folder library"

Write-Host ""
Write-Host "Setup selesai. Langkah berikut: tools\link.ps1 (hubungkan mod ke profil '$ProfileName')." -ForegroundColor Green
