<#
.SYNOPSIS
    Uji offline tanpa membuka game: cek syntax semua file Lua (Lua 5.2) dan uji logika mod
    terhadap fungsi asli dari script game (tests\*.py, via lupa).
    Membuat .venv (Python) sekali di root workspace.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$root = $script:WorkspaceRoot
$venvPython = Join-Path $root '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Step "Membuat .venv + install lupa (sekali saja)"
    & python -m venv (Join-Path $root '.venv')
    & $venvPython -m pip install --quiet --disable-pip-version-check lupa
    if ($LASTEXITCODE -ne 0) { throw "Gagal install lupa" }
}

$failed = @()
Write-Step "Syntax Lua"
& $venvPython (Join-Path $root 'tests\check_lua_syntax.py')
if ($LASTEXITCODE -ne 0) { $failed += 'syntax' }

foreach ($test in Get-ChildItem (Join-Path $root 'tests') -Filter 'test_*.py') {
    Write-Step $test.BaseName
    & $venvPython $test.FullName
    if ($LASTEXITCODE -ne 0) { $failed += $test.BaseName }
}

Write-Host ""
if ($failed.Count -gt 0) { throw "Gagal: $($failed -join ', ')" }
Write-Host "Semua uji lulus." -ForegroundColor Green
