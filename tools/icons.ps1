<#
.SYNOPSIS
    Generate icon.png (256x256) untuk setiap paket yang terdaftar di tools\icons\icons.json.
.DESCRIPTION
    Art Pom of Power dan simbol god diambil dari file game-mu sendiri (GUI.pkg) lewat deppth2,
    di-extract sekali ke .cache\game-textures (di-gitignore). Bingkai, latar, simbol infinity, dan
    teks digambar oleh tools\icons\make_icons.py.
    God baru di Limitless Poms: tambahkan namanya ke "gods" di icons.json, lalu jalankan ulang.
.EXAMPLE
    tools\icons.ps1
    tools\icons.ps1 -Preview   # juga menulis .cache\icons-preview.png (ukuran 256/64/32 px)
#>
[CmdletBinding()]
param([switch]$Preview)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$root = $script:WorkspaceRoot
$venvPython = Join-Path $root '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Step "Membuat .venv"
    & python -m venv (Join-Path $root '.venv')
}
& $venvPython -c "import PIL, deppth2" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Step "Install Pillow + deppth2 ke .venv"
    & $venvPython -m pip install --quiet --disable-pip-version-check pillow deppth2
    if ($LASTEXITCODE -ne 0) { throw "Gagal install Pillow/deppth2" }
}

Write-Step "Render ikon"
$scriptArgs = @((Join-Path $PSScriptRoot 'icons\make_icons.py'))
if ($Preview) { $scriptArgs += @('--preview', (Join-Path $root '.cache\icons-preview.png')) }
& $venvPython @scriptArgs
if ($LASTEXITCODE -ne 0) { throw "Gagal membuat ikon" }
