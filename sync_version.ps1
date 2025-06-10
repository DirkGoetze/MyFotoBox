# PowerShell-Skript zur Synchronisierung der Versionsnummern
# Erstellt: 11. Juni 2025
# Funktion: Liest die offizielle Version aus conf/version.inf und aktualisiert
#           README.md und VERSION-Datei entsprechend

Write-Host "Synchronisiere Versionsnummern im Projekt..." -ForegroundColor Cyan

# Pfade definieren
$projectPath = $PSScriptRoot
$versionInfPath = Join-Path -Path $projectPath -ChildPath "conf\version.inf"
$readmePath = Join-Path -Path $projectPath -ChildPath "README.md"
$versionFilePath = Join-Path -Path $projectPath -ChildPath "VERSION"

# Version aus conf/version.inf lesen
if (Test-Path $versionInfPath) {
    try {
        $officialVersion = Get-Content -Path $versionInfPath -Raw
        $officialVersion = $officialVersion.Trim()
        Write-Host "Offizielle Version aus conf/version.inf: $officialVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "Fehler beim Lesen der Version aus conf/version.inf: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Fehler: Die Datei conf/version.inf wurde nicht gefunden!" -ForegroundColor Red
    exit 1
}

# README.md aktualisieren
if (Test-Path $readmePath) {
    try {
        $readmeContent = Get-Content -Path $readmePath -Raw
        $newReadmeContent = $readmeContent -replace '!\[Version [0-9.]+\]\(https://img\.shields\.io/badge/version-[0-9.]+-orange\)', "![Version $officialVersion](https://img.shields.io/badge/version-$officialVersion-orange)"
        Set-Content -Path $readmePath -Value $newReadmeContent
        Write-Host "README.md mit Version $officialVersion aktualisiert" -ForegroundColor Green
    }
    catch {
        Write-Host "Fehler beim Aktualisieren von README.md: $_" -ForegroundColor Red
    }
}

# VERSION-Datei aktualisieren
try {
    $versionFileContent = @"
# Diese Datei dient nur als Verweis auf die offizielle Versionsdatei
# Die einzige Quelle für die Versionsinformation ist conf/version.inf
#
# Aktuelle Version: $officialVersion
"@
    Set-Content -Path $versionFilePath -Value $versionFileContent
    Write-Host "VERSION-Datei mit Verweis auf $officialVersion aktualisiert" -ForegroundColor Green
}
catch {
    Write-Host "Fehler beim Aktualisieren der VERSION-Datei: $_" -ForegroundColor Red
}

Write-Host "Versionssynchronisierung abgeschlossen." -ForegroundColor Cyan
