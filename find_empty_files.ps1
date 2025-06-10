# PowerShell-Skript zum Finden leerer Dateien im Projekt
# Erstellt am 11. Juni 2025

Write-Host "Suche nach leeren Dateien im Fotobox2-Projekt..." -ForegroundColor Cyan

# Pfad zum Projektverzeichnis
$projectPath = $PSScriptRoot

# Array fuer gefundene leere Dateien
$emptyFiles = @()

# Alle Dateien im Projekt durchsuchen (ohne .git-Ordner)
Get-ChildItem -Path $projectPath -Recurse -File | 
    Where-Object { 
        $_.DirectoryName -notlike "*\.git*" -and 
        $_.Length -eq 0 
    } | 
    ForEach-Object {
        $emptyFiles += [PSCustomObject]@{
            Pfad = $_.FullName
            Groesse = $_.Length
            LetzteAenderung = $_.LastWriteTime
        }
    }

# Ergebnisse ausgeben
if ($emptyFiles.Count -gt 0) {
    Write-Host "`nEs wurden $($emptyFiles.Count) leere Dateien gefunden:" -ForegroundColor Yellow
    $emptyFiles | Format-Table -AutoSize
    
    # Optionale Loeschabfrage fuer jede Datei
    foreach ($file in $emptyFiles) {
        $confirm = Read-Host "Moechten Sie die leere Datei '$($file.Pfad)' loeschen? (j/n)"
        if ($confirm -eq 'j') {
            Remove-Item -Path $file.Pfad -Force
            Write-Host "Datei geloescht: $($file.Pfad)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "`nEs wurden keine leeren Dateien gefunden." -ForegroundColor Green
}

Write-Host "`nDie Suche nach leeren Dateien wurde abgeschlossen." -ForegroundColor Cyan
