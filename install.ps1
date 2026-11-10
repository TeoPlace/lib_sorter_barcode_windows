# Installs or updates lib_sorter_barcode from the GitHub releases. Running it again updates to the
# latest version; it does nothing when the installed one is already the latest.
#
#   irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1 | iex
#
# With options (folder, a specific version, PATH, check only):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1))) -Dir C:\lib\sorter_barcode -AddToPath
#   .\install.ps1 [-Dir <folder>] [-Version 1.1.1] [-AddToPath] [-Check] [-Uninstall]
#
# Default folder: %LOCALAPPDATA%\Programs\sorter_barcode (no administrator rights needed).
# Works with Windows PowerShell 5.1 and PowerShell 7.
param(
    [string]$Dir = (Join-Path $env:LOCALAPPDATA 'Programs\sorter_barcode'),
    [string]$Version = '',
    [switch]$AddToPath,
    [switch]$Check,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = 'TeoPlace/lib_sorter_barcode_windows'
$asset = 'lib_sorter_barcode_windows.zip'
$versionFile = Join-Path $Dir 'VERSION'
$pathEntry = Join-Path $Dir 'bin\x64'

function Get-UserPath { [Environment]::GetEnvironmentVariable('Path', 'User') }

if ($Uninstall) {
    if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
    $p = Get-UserPath
    if ($p -and ($p -split ';' -contains $pathEntry)) {
        [Environment]::SetEnvironmentVariable('Path', (($p -split ';' | Where-Object { $_ -and $_ -ne $pathEntry }) -join ';'), 'User')
    }
    Write-Host "sorter_barcode removed from $Dir"
    return
}

$installed = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { '' }

$api = if ($Version) { "https://api.github.com/repos/$repo/releases/tags/v$Version" } else { "https://api.github.com/repos/$repo/releases/latest" }
$release = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'lib_sorter_barcode-install' }
$target = $release.tag_name -replace '^v', ''

if ($Check) {
    if (-not $installed) { Write-Host "not installed in $Dir; latest version: $target" }
    elseif ($installed -eq $target) { Write-Host "sorter_barcode ${installed}: up to date" }
    else { Write-Host "sorter_barcode $installed installed, $target available: run the script again to update" }
    return
}

if ($installed -eq $target) {
    Write-Host "sorter_barcode $installed is already installed in $Dir"
} else {
    $zipUrl = ($release.assets | Where-Object { $_.name -eq $asset }).browser_download_url
    $sumUrl = ($release.assets | Where-Object { $_.name -eq "$asset.sha256" }).browser_download_url
    if (-not $zipUrl) { throw "release $($release.tag_name) has no $asset" }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("sorter_barcode-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $tmp | Out-Null
    try {
        $zip = Join-Path $tmp $asset
        Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
        if ($sumUrl) {
            $expected = ((Invoke-WebRequest -Uri $sumUrl -UseBasicParsing).Content -split '\s+')[0].Trim().ToLower()
            $actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
            if ($expected -ne $actual) { throw "SHA-256 mismatch for $asset (expected $expected, got $actual)" }
        }
        Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x') -Force
        # replace the whole folder, so files removed in the new version do not stay behind
        if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
        New-Item -ItemType Directory -Force (Split-Path $Dir) | Out-Null
        Move-Item (Join-Path $tmp 'x') $Dir
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($installed) { Write-Host "sorter_barcode updated from $installed to $target in $Dir" }
    else { Write-Host "sorter_barcode $target installed in $Dir" }
}

if ($AddToPath) {
    $p = Get-UserPath
    if (-not ($p -split ';' -contains $pathEntry)) {
        [Environment]::SetEnvironmentVariable('Path', ((@($p -split ';' | Where-Object { $_ }) + $pathEntry) -join ';'), 'User')
        Write-Host "$pathEntry added to the user PATH (open a new terminal)"
    }
}
Write-Host "DLL: $pathEntry\sorter_barcode.dll (32 bit: $Dir\bin\x86)"
