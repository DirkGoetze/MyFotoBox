
# Script zur Umschaltung des Testmodus für die Fotobox
# Im Testmodus werden alle Cache-Header-Einstellungen aktiviert
# um das Testen ohne Browser-Cache-Probleme zu ermöglichen

param(
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Status
)

$envFile = Join-Path $PSScriptRoot ".env"

function Get-TestModeStatus {
    if (Test-Path $envFile) {
        $content = Get-Content $envFile -ErrorAction SilentlyContinue
        $testMode = $content | Where-Object { $_ -match "FOTOBOX_TEST_MODE=(.*)" } | ForEach-Object { $matches[1] }
        if ($testMode -eq $null) {
            return $true  # Standard ist true, wenn nicht definiert
        }
        return $testMode.ToLower() -eq "true"
    }
    return $true  # Standard ist true, wenn .env nicht existiert
}

function Set-TestModeStatus {
    param([bool]$Enabled)
    
    $envContent = @()
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile | Where-Object { -not ($_ -match "FOTOBOX_TEST_MODE=") }
    }
    
    $envContent += "FOTOBOX_TEST_MODE=$($Enabled.ToString().ToLower())"
    $envContent | Set-Content $envFile
    
    # Nginx neu laden, falls systemctl verfügbar ist
    try {
        $nginxExists = Get-Command systemctl -ErrorAction SilentlyContinue
        if ($nginxExists) {
            Write-Host "Reloading Nginx configuration..."
            Invoke-Expression "systemctl reload nginx"
        }
    } catch {
        # Ignorieren, falls systemctl nicht verfügbar ist (z.B. unter Windows)
    }
    
    # Flask-Server neu starten, falls systemctl verfügbar ist
    try {
        $serviceExists = Get-Command systemctl -ErrorAction SilentlyContinue
        if ($serviceExists) {
            Write-Host "Restarting Fotobox service..."
            Invoke-Expression "systemctl restart fotobox-backend"
        }
    } catch {
        # Ignorieren, falls systemctl nicht verfügbar ist
    }
}

# Hauptlogik
if ($Enable) {
    Set-TestModeStatus $true
    Write-Host "Testmodus wurde AKTIVIERT. Cache-Kontrolle ist aktiv."
    Write-Host "Browser-Caching ist deaktiviert für einfacheres Testen."
}
elseif ($Disable) {
    Set-TestModeStatus $false
    Write-Host "Testmodus wurde DEAKTIVIERT. Cache-Kontrolle ist inaktiv."
    Write-Host "Browser-Caching ist aktiviert für bessere Performance."
}
elseif ($Status -or (-not $Enable -and -not $Disable)) {
    $currentStatus = Get-TestModeStatus
    if ($currentStatus) {
        Write-Host "Testmodus ist aktiv. Cache-Kontrolle ist aktiviert."
    } else {
        Write-Host "Testmodus ist inaktiv. Cache-Kontrolle ist deaktiviert."
    }
}

Write-Host ""
Write-Host "Nutzung:"
Write-Host "  .\toggle_test_mode.ps1 -Enable    # Aktiviert den Testmodus"
Write-Host "  .\toggle_test_mode.ps1 -Disable   # Deaktiviert den Testmodus"
Write-Host "  .\toggle_test_mode.ps1 -Status    # Zeigt den aktuellen Status"
Write-Host ""
Write-Host "Hinweis: Nach Änderung des Testmodus kann es erforderlich sein,"
Write-Host "den Browser-Cache manuell zu leeren oder den Browser neu zu starten."
