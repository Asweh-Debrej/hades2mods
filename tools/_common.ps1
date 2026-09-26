# Shared helpers for the workspace tools. Dot-source this file: . "$PSScriptRoot\_common.ps1"
# Written for Windows PowerShell 5.1 (no ternary / null-coalescing operators).

$script:WorkspaceRoot = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) { Write-Host "    [ok] $Message" -ForegroundColor Green }
function Write-Warn2([string]$Message) { Write-Host "    [!]  $Message" -ForegroundColor Yellow }

function Get-WorkspaceConfig {
    $path = Join-Path $script:WorkspaceRoot 'workspace.json'
    $cfg = Get-Content $path -Raw | ConvertFrom-Json
    $cfg.r2modmanGameDir = [Environment]::ExpandEnvironmentVariables($cfg.r2modmanGameDir)
    $cfg.gamePath = [Environment]::ExpandEnvironmentVariables($cfg.gamePath)
    return $cfg
}

function Get-ProfileRoot([string]$ProfileName) {
    $cfg = Get-WorkspaceConfig
    if (-not $ProfileName) { $ProfileName = $cfg.devProfile }
    return Join-Path $cfg.r2modmanGameDir "profiles\$ProfileName\ReturnOfModding"
}

function Read-TomlPackageValue([string]$TomlText, [string]$Key) {
    # Only reads simple `key = "value"` lines; enough for the [package] section of thunderstore.toml
    $match = [regex]::Match($TomlText, "(?m)^\s*$Key\s*=\s*""([^""]*)""")
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

# Returns every Thunderstore package (folder containing thunderstore.toml) under the configured roots.
# -Filter matches against the package name, GUID, or folder path (wildcards allowed).
function Get-Packages([string[]]$Filter) {
    $cfg = Get-WorkspaceConfig
    $packages = @()
    foreach ($rootName in $cfg.packageRoots) {
        $rootPath = Join-Path $script:WorkspaceRoot $rootName
        if (-not (Test-Path $rootPath)) { continue }
        $tomls = Get-ChildItem $rootPath -Recurse -Filter 'thunderstore.toml' -File |
            Where-Object { $_.FullName -notmatch '\\(build|\.git|node_modules)\\' }
        foreach ($toml in $tomls) {
            $text = Get-Content $toml.FullName -Raw
            $dir = $toml.DirectoryName
            $namespace = Read-TomlPackageValue $text 'namespace'
            $name = Read-TomlPackageValue $text 'name'
            $packages += [pscustomobject]@{
                Dir       = $dir
                RelDir    = $dir.Substring($script:WorkspaceRoot.Length + 1)
                Namespace = $namespace
                Name      = $name
                Version   = Read-TomlPackageValue $text 'versionNumber'
                Guid      = "$namespace-$name"
                HasSrc    = Test-Path (Join-Path $dir 'src')
                HasData   = Test-Path (Join-Path $dir 'data')
            }
        }
    }
    if ($Filter) {
        $packages = $packages | Where-Object {
            $pkg = $_
            @($Filter | Where-Object { $pkg.Name -like $_ -or $pkg.Guid -like $_ -or $pkg.RelDir -like "*$_*" }).Count -gt 0
        }
    }
    return @($packages)
}

function Assert-Tcli {
    if (-not (Get-Command tcli -ErrorAction SilentlyContinue)) {
        $toolsDir = Join-Path $env:USERPROFILE '.dotnet\tools'
        if (Test-Path (Join-Path $toolsDir 'tcli.exe')) {
            $env:PATH = "$env:PATH;$toolsDir"
        } else {
            throw "tcli belum terpasang. Jalankan tools\setup.ps1 dulu."
        }
    }
}

# Runs `tcli build` inside the package folder and returns the path of the produced zip.
function Invoke-TcliBuild($Package) {
    Assert-Tcli
    Push-Location $Package.Dir
    try {
        # tcli is chatty; only show its output when the build fails
        $output = & cmd /c "tcli build 2>&1"
        if ($LASTEXITCODE -ne 0) {
            # a freshly written zip is sometimes still locked (e.g. by the antivirus): retry once
            Start-Sleep -Seconds 3
            $output = & cmd /c "tcli build 2>&1"
        }
        if ($LASTEXITCODE -ne 0) {
            $output | Out-Host
            throw "tcli build gagal untuk $($Package.Guid)"
        }
    } finally {
        Pop-Location
    }
    $zip = Join-Path $Package.Dir "build\$($Package.Guid)-$($Package.Version).zip"
    if (-not (Test-Path $zip)) { throw "Zip hasil build tidak ditemukan: $zip" }
    return $zip
}

function Test-IsLink([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

# Removes a junction/symlink WITHOUT touching the folder it points to.
function Remove-Link([string]$Path) {
    if (Test-IsLink $Path) { [IO.Directory]::Delete($Path, $false) }
}

function New-Junction([string]$Link, [string]$Target) {
    if (Test-Path $Link) {
        if (Test-IsLink $Link) {
            Remove-Link $Link
        } else {
            throw "Sudah ada folder asli di $Link (bukan link). Hapus/uninstall dulu lewat r2modman."
        }
    }
    $parent = Split-Path -Parent $Link
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding $false))
}

# Draws a simple 256x256 placeholder icon (Thunderstore requires exactly 256x256 PNG).
function New-PlaceholderIcon([string]$Path, [string]$Label, [string]$ColorA = '#3b1f5c', [string]$ColorB = '#c2410c') {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object Drawing.Bitmap 256, 256
    $g = [Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = 'AntiAlias'
        $g.TextRenderingHint = 'AntiAliasGridFit'
        $rect = New-Object Drawing.Rectangle 0, 0, 256, 256
        $brush = New-Object Drawing.Drawing2D.LinearGradientBrush $rect, ([Drawing.ColorTranslator]::FromHtml($ColorA)), ([Drawing.ColorTranslator]::FromHtml($ColorB)), 45.0
        $g.FillRectangle($brush, $rect)
        $font = New-Object Drawing.Font 'Segoe UI', 30, ([Drawing.FontStyle]::Bold)
        $format = New-Object Drawing.StringFormat
        $format.Alignment = 'Center'
        $format.LineAlignment = 'Center'
        $layout = New-Object Drawing.RectangleF 8, 8, 240, 240
        $g.DrawString($Label, $font, [Drawing.Brushes]::White, $layout, $format)
        $bmp.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $g.Dispose()
        $bmp.Dispose()
    }
}
