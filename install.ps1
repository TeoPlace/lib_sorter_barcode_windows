# Installa o aggiorna sorter-barcode (il comando e la libreria) dalle release su GitHub.
# Rilanciato, aggiorna all'ultima versione; se e' gia' l'ultima non fa niente.
#
#   irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1 | iex
#
# Con le opzioni:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1))) -Check
#   .\install.ps1 [-Dir <cartella>] [-Version 1.1.2] [-NoPath] [-Check] [-Uninstall]
#
# Cartella predefinita: %LOCALAPPDATA%\Programs\sorter_barcode (senza diritti di amministratore).
# La cartella bin\x64 va nel PATH dell'utente, cosi' sorter-barcode si lancia da qualunque terminale.
# Funziona con Windows PowerShell 5.1 e PowerShell 7.
param(
    [string]$Dir = (Join-Path $env:LOCALAPPDATA 'Programs\sorter_barcode'),
    [string]$Version = '',
    [switch]$NoPath,
    [switch]$AddToPath,   # 1.1.1: ora il PATH e' il comportamento normale, resta per i comandi gia' scritti
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
    Write-Host "sorter-barcode rimosso da $Dir"
    return
}

$installed = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { '' }

$api = if ($Version) { "https://api.github.com/repos/$repo/releases/tags/v$Version" } else { "https://api.github.com/repos/$repo/releases/latest" }
$release = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'lib_sorter_barcode-install' }
$target = $release.tag_name -replace '^v', ''

if ($Check) {
    if (-not $installed) { Write-Host "sorter-barcode non e' installato in $Dir; ultima versione: $target" }
    elseif ($installed -eq $target) { Write-Host "sorter-barcode ${installed}: e' l'ultima versione" }
    else { Write-Host "sorter-barcode $installed installato, c'e' la ${target}: rilancia il comando di installazione per aggiornare" }
    return
}

if ($installed -eq $target) {
    Write-Host "sorter-barcode $installed e' gia' installato in $Dir"
} else {
    $zipUrl = ($release.assets | Where-Object { $_.name -eq $asset }).browser_download_url
    $sumUrl = ($release.assets | Where-Object { $_.name -eq "$asset.sha256" }).browser_download_url
    if (-not $zipUrl) { throw "la release $($release.tag_name) non contiene $asset" }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("sorter_barcode-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $tmp | Out-Null
    try {
        $zip = Join-Path $tmp $asset
        Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
        if ($sumUrl) {
            # su file: GitHub serve il .sha256 come binario, quindi .Content sarebbero byte
            Invoke-WebRequest -Uri $sumUrl -OutFile "$zip.sha256" -UseBasicParsing
            $expected = ((Get-Content "$zip.sha256" -Raw).Trim() -split '\s+')[0].ToLower()
            $actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
            if ($expected -ne $actual) { throw "SHA-256 diverso per $asset (atteso $expected, trovato $actual)" }
        }
        Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x') -Force
        # si sostituisce tutta la cartella, cosi' i file tolti nella versione nuova non restano
        if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
        New-Item -ItemType Directory -Force (Split-Path $Dir) | Out-Null
        Move-Item (Join-Path $tmp 'x') $Dir
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($installed) { Write-Host "sorter-barcode aggiornato dalla $installed alla $target in $Dir" }
    else { Write-Host "sorter-barcode $target installato in $Dir" }
}

if (-not $NoPath) {
    $p = Get-UserPath
    if (-not ($p -split ';' -contains $pathEntry)) {
        [Environment]::SetEnvironmentVariable('Path', ((@($p -split ';' | Where-Object { $_ }) + $pathEntry) -join ';'), 'User')
        Write-Host "$pathEntry aggiunto al PATH dell'utente"
    }
    # anche in questo terminale, per provarlo subito (davanti, cosi' vince su altre copie)
    if (-not ($env:Path -split ';' -contains $pathEntry)) { $env:Path = "$pathEntry;$env:Path" }
    # il PATH di sistema viene prima di quello dell'utente: un altro sorter-barcode li' vince nei terminali nuovi.
    # Va bene se e' aggiornato (per esempio quello dell'app SorterBarcode); le versioni vecchie non hanno --version.
    $other = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' |
        Where-Object { $_ -and (Test-Path (Join-Path $_ 'sorter-barcode.exe')) } | Select-Object -First 1
    $otherVersion = $null
    if ($other) {
        $ErrorActionPreference = 'Continue'
        $out = & (Join-Path $other 'sorter-barcode.exe') --version 2>$null
        $ErrorActionPreference = 'Stop'
        if ("$out" -match 'sorter-barcode (\d+\.\d+\.\d+)') { $otherVersion = $Matches[1] }
    }
    if ($other -and -not ($otherVersion -and [version]$otherVersion -ge [version]$target)) {
        $what = if ($otherVersion) { "la $otherVersion" } else { 'una versione vecchia' }
        Write-Host "Attenzione: nei terminali nuovi 'sorter-barcode' e' $what in $other (PATH di sistema, viene prima)."
        Write-Host "Per sistemarlo: disinstalla quel programma da Impostazioni > App > App installate, o aggiornalo."
        Write-Host "Intanto:  & '$pathEntry\sorter-barcode.exe' C:\percorso\immagine.bmp"
    } else {
        Write-Host "Per leggere un'immagine:  sorter-barcode C:\percorso\immagine.bmp"
    }
} else {
    Write-Host "Per leggere un'immagine:  & '$pathEntry\sorter-barcode.exe' C:\percorso\immagine.bmp"
}
