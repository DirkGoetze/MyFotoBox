# Entwicklerhandbuch: Fotobox2

Dieses Entwicklerhandbuch dokumentiert die technische Struktur, Architektur und Best Practices für die Entwicklung des Fotobox2-Projekts. Es dient als Referenz für alle Entwickler, die am Projekt arbeiten oder neue Module implementieren möchten.

## Inhaltsverzeichnis

1. [Projektstruktur](#1-projektstruktur)
2. [Modulare Architektur](#2-modulare-architektur)
3. [Frontend-Entwicklung](#3-frontend-entwicklung)
4. [Backend-Entwicklung](#4-backend-entwicklung)
5. [Datenbankverwaltung](#5-datenbankverwaltung)
6. [Migration von Legacy-Code](#6-migration-von-legacy-code)
7. [Testen und Qualitätssicherung](#7-testen-und-qualitätssicherung)
8. [Versionierung und Deployment](#8-versionierung-und-deployment)
9. [Weitere Ressourcen](#9-weitere-ressourcen)
10. [Logging-System](#10-logging-system)
11. [Netzwerkkonfiguration](#11-netzwerkkonfiguration)
12. [Deinstallationssystem](#12-deinstallationssystem)
13. [Dokumentationsstandards](#13-dokumentationsstandards)

## 1. Projektstruktur

Das Fotobox2-Projekt folgt einer klaren Ordnerstruktur, um die Wartbarkeit und Erweiterbarkeit zu gewährleisten:

```bash
fotobox2/
├── backend/           # Python-Backend mit API-Endpunkten und Systemfunktionen
│   ├── api_*.py       # API-Endpunkte
│   ├── manage_*.py    # Module für verschiedene Systemfunktionen
│   ├── utils.py       # Hilfsfunktionen
│   └── scripts/       # Hilfsskripte
├── frontend/          # Frontend-Dateien
│   ├── *.html         # HTML-Seiten
│   ├── js/            # JavaScript-Dateien
│   │   ├── manage_*.js # Systemmodule 
│   │   ├── ui_components.js # UI-Komponenten
│   │   └── utils.js   # Hilfsfunktionen
│   ├── css/           # Stylesheets
│   └── photos/        # Foto-Ausgabeordner
├── conf/              # Konfigurations- und Abhängigkeitsdateien
├── documentation/     # Dokumentation
├── policies/          # Entwicklungsrichtlinien
└── tests/             # Test-Skripte und Tools
```

Die Ordnerstruktur wird dynamisch vom System erstellt und verwaltet durch das zentrale Ordnerverwaltungssystem (`manage_folders.sh` und `manage_folders.py`).

## 2. Modulare Architektur

### 2.1 Frontend-Module

Die Frontend-Architektur ist modular aufgebaut und folgt dem Prinzip der Trennung von Verantwortlichkeiten:

#### Systemmodule (`manage_*.js`)

| Modul | Verantwortlichkeit |
|-------|-------------------|
| `manage_update.js` | Update-Prüfung, Installation, Versionsvergleich |
| `manage_auth.js` | Authentifizierung, Passwortverwaltung |
| `manage_settings.js` | Einstellungsverwaltung |
| `manage_filesystem.js` | Dateisystem-Operationen |
| `manage_database.js` | Datenbankoperationen |
| `manage_api.js` | API-Kommunikation mit Backend |
| `manage_logging.js` | Client-seitiges Logging |
| `manage_ui.js` | Seitenübergreifende UI-Steuerung |

#### UI-Komponenten

Die Datei `ui_components.js` enthält wiederverwendbare UI-Komponenten wie:

- Benachrichtigungsmodule
- Dialoge
- Fortschrittsanzeigen
- Gemeinsam genutzte Animationen

#### Hilfsmodule

- `constants.js`: Anwendungsweite Konstanten
- `i18n.js`: Internationalisierung
- `theming.js`: Theming und Farbschemaverwaltung
- `utils.js`: Allgemeine Hilfsfunktionen

### 2.2 Backend-Module

Die Backend-Architektur folgt einem ähnlichen modularen Ansatz:

#### API-Endpunkte (`api_*.py`)

Jeder API-Endpunkt hat eine klar definierte Verantwortlichkeit und verwendet die entsprechenden Systemmodule.

#### Systemmodule (`manage_*.py`)

| Modul | Verantwortlichkeit |
|-------|-------------------|
| `manage_update.py` | Update-Prozesse, Versionierung |
| `manage_auth.py` | Authentifizierung, Benutzer- und Passwortverwaltung |
| `manage_settings.py` | Einstellungsverwaltung |
| `manage_files.py` | Dateisystem-Operationen |
| `manage_database.py` | Datenbankverwaltung |
| `manage_logging.py` | Logging-Funktionen |
| `manage_camera.py` | Kamera-Steuerung |
| `manage_folders.py` | Ordnerverwaltung |

## 3. Frontend-Entwicklung

### 3.1 Neue Module erstellen

Um ein neues Frontend-Modul zu erstellen, folgen Sie dieser Struktur:

```javascript
/**
 * @file manage_module.js
 * @description Beschreibung des Moduls
 * @module manage_module
 */

// Abhängigkeiten importieren
import { log, error } from './manage_logging.js';
import { apiGet, apiPost } from './manage_api.js';

// Private Variablen und Funktionen
const privateVar = 'someValue';

function privateFunction() {
    // Implementierung
}

// Öffentliche API-Funktionen
export async function publicFunction() {
    try {
        // Implementierung
        log('Operation erfolgreich');
        return result;
    } catch (err) {
        error('Fehler in publicFunction', err);
        throw err;
    }
}

// Initialisierung (falls nötig)
function init() {
    // Initialisierungscode
}

// Sofort ausgeführte Funktionen (falls nötig)
(function() {
    init();
})();
```

### 3.2 Best Practices für Frontend-Code

- **Modularisierung**: Ein Modul pro Datei mit klar definierter Verantwortlichkeit
- **Asynchrone Operationen**: Verwenden Sie `async/await` für asynchrone Funktionen
- **Fehlerbehandlung**: Implementieren Sie try/catch-Blöcke für robuste Fehlerbehandlung
- **Logging**: Nutzen Sie `manage_logging.js` für konsistentes Logging
- **API-Kommunikation**: Nutzen Sie `manage_api.js` für alle Backend-Anfragen
- **Dokumentation**: Verwenden Sie JSDoc für die Dokumentation von Funktionen und Modulen

### 3.3 Abhängigkeiten zwischen Modulen

Achten Sie auf die Hierarchie der Abhängigkeiten:

1. Basismodule (`utils.js`, `constants.js`)
2. Infrastrukturmodule (`manage_logging.js`, `manage_api.js`)
3. Funktionsmodule (`manage_auth.js`, `manage_settings.js`, etc.)
4. UI-Module (`ui_components.js`, `manage_ui.js`)
5. Seitenspezifische Module (`gallery.js`, `settings.js`, etc.)

Vermeiden Sie zirkuläre Abhängigkeiten, indem Sie gemeinsame Funktionalitäten in niedrigere Ebenen extrahieren.

## 4. Backend-Entwicklung

### 4.1 Neue Module erstellen

Ein typisches Backend-Modul folgt dieser Struktur:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Modulbeschreibung
"""

# Importe
import os
import sys
from manage_logging import log, error

# Konstanten
MODULE_NAME = "manage_module"

# Hilfsfunktionen
def _internal_function():
    """Interne Funktion - nicht exportiert"""
    pass

# Öffentliche Funktionen
def public_function():
    """
    Beschreibung der Funktion
    
    Returns:
        dict: Ergebnisbeschreibung
    """
    try:
        # Implementierung
        log(f"{MODULE_NAME}: Operation erfolgreich")
        return {"status": "success", "data": result}
    except Exception as e:
        error(f"{MODULE_NAME}: Fehler in public_function", e)
        return {"status": "error", "message": str(e)}

# Initialisierung (falls nötig)
def init():
    """Initialisierungsfunktion"""
    pass

# Hauptfunktion für direkte Ausführung
if __name__ == "__main__":
    init()
```

### 4.2 Best Practices für Backend-Code

- **Modularisierung**: Ein Modul pro Datei mit klar definierter Verantwortlichkeit
- **Fehlerbehandlung**: Implementieren Sie try/except-Blöcke für robuste Fehlerbehandlung
- **Logging**: Nutzen Sie `manage_logging.py` für konsistentes Logging
- **Rückgabeformate**: Verwenden Sie einheitliche JSON-Formate für API-Rückgaben
- **Pfadverwaltung**: Nutzen Sie `manage_folders.py` für alle Verzeichnisoperationen
- **Dokumentation**: Verwenden Sie Docstrings für Funktionen und Module
- **Validierung**: Validieren Sie Eingaben, bevor Sie sie verarbeiten

### 4.3 API-Endpunkt-Struktur

API-Endpunkte (`api_*.py`) sollten minimal sein und die eigentliche Logik an die entsprechenden `manage_*.py`-Module delegieren:

```python
from flask import request, jsonify
from manage_module import public_function

@app.route('/api/module/action', methods=['POST'])
def api_module_action():
    data = request.get_json()
    result = public_function(data)
    return jsonify(result)
```

## 5. Datenbankverwaltung

Das Datenbank-Management-System von Fotobox2 besteht aus zwei Hauptkomponenten:

1. **Backend**: `manage_database.py` - Zentrale Verwaltung aller Datenbankaktivitäten
2. **Frontend**: `manage_database.js` - JavaScript-Schnittstelle zur Kommunikation mit dem Backend

Das System verwendet eine SQLite-Datenbank und bietet Funktionen für:

- Initialisierung und Migration der Datenbank
- CRUD-Operationen (Create, Read, Update, Delete)
- Einstellungsverwaltung
- Integrität und Optimierung

> **Aktualisiert am 12.06.2025**: Beide Module wurden vollständig implementiert und in den Code-Migrationsprozess integriert. Die Module bieten nun eine einheitliche Schnittstelle für alle Datenbankoperationen.

### 5.1 Datenbank-Struktur

Die Datenbank wird im Verzeichnis `data/` gespeichert und enthält folgende Haupttabellen:

1. **settings**: Anwendungseinstellungen als Schlüssel-Wert-Paare
   - `key` (TEXT): Eindeutiger Schlüssel
   - `value` (TEXT): Zugehöriger Wert

2. **image_metadata**: Metadaten zu den gespeicherten Bildern
   - `id` (INTEGER): Eindeutige ID
   - `filename` (TEXT): Dateiname des Bildes
   - `timestamp` (TEXT): Zeitstempel der Aufnahme
   - `tags` (TEXT): Tags und Metadaten als JSON

3. **users**: Benutzerverwaltung
   - `id` (INTEGER): Eindeutige ID
   - `username` (TEXT): Benutzername
   - `password_hash` (TEXT): Gehashtes Passwort
   - `role` (TEXT): Benutzerrolle (z.B. admin, user)

### 5.2 Backend-API (`manage_database.py`)

#### Verbindungsverwaltung

- `connect_db()`: Stellt Verbindung zur Datenbank her

#### Verwaltungsfunktionen

- `init_db()`: Initialisiert die Datenbankstruktur
- `migrate_db()`: Führt Datenbankmigrationen durch
- `cleanup_db()`: Bereinigt temporäre oder alte Daten
- `optimize_db()`: Optimiert die Datenbankstruktur

#### CRUD-Operationen

- `query(sql, params=None)`: Führt eine SQL-Abfrage aus
- `insert(table, data)`: Fügt Daten in eine Tabelle ein
- `update(table, data, condition, params=None)`: Aktualisiert Daten
- `delete(table, condition, params=None)`: Löscht Daten

#### Einstellungsverwaltung

- `get_setting(key, default=None)`: Holt eine Einstellung
- `set_setting(key, value)`: Speichert eine Einstellung

#### Integritätsprüfung

- `check_integrity()`: Überprüft die Datenbankintegrität

### 5.3 Frontend-API (`manage_database.js`)

Das Frontend-Modul bietet eine asynchrone Schnittstelle zum Backend:

#### Grundoperationen

- `query(sql, params = null)`: Führt eine SQL-Abfrage aus
- `insert(table, data)`: Fügt Datensätze ein
- `update(table, data, condition, params = null)`: Aktualisiert Datensätze
- `remove(table, condition, params = null)`: Entfernt Datensätze

#### Frontend-Einstellungsverwaltung

- `getSetting(key, defaultValue = null)`: Holt eine Einstellung mit Fallback-Wert
- `setSetting(key, value)`: Speichert eine Einstellung

#### Systemfunktionen

- `checkIntegrity()`: Überprüft die Datenbankintegrität
- `getStats()`: Holt Statistiken zur Datenbanknutzung

### 5.4 REST-API-Endpunkte

Die Kommunikation zwischen Frontend und Backend erfolgt über REST-API-Endpunkte:

- `POST /api/database/query`: Führt eine Datenbankabfrage aus
- `POST /api/database/insert`: Fügt einen Datensatz ein
- `POST /api/database/update`: Aktualisiert einen Datensatz
- `POST /api/database/delete`: Löscht einen Datensatz
- `GET /api/database/settings/{key}`: Liest eine Einstellung
- `POST /api/database/settings`: Speichert eine Einstellung
- `GET /api/database/check-integrity`: Überprüft die Datenbankintegrität
- `GET /api/database/stats`: Holt Datenbankstatistiken

### 5.5 Beispiele

#### Backend-Beispiel

```python
# Einstellung lesen
user_preference = manage_database.get_setting('theme', 'dark')

# Daten einfügen
result = manage_database.insert('image_metadata', {
    'filename': 'foto_001.jpg',
    'timestamp': '2025-06-12T15:30:00',
    'tags': '{"event": "party", "people": 3}'
})
```

#### Frontend-Beispiel

```javascript
// Einstellung speichern
async function saveUserPreference(theme) {
    const result = await setSetting('theme', theme);
    if (result.success) {
        console.log("Theme gespeichert");
    }
}

// Daten abrufen
async function getImagesByEvent(eventName) {
    const result = await query(
        "SELECT * FROM image_metadata WHERE json_extract(tags, '$.event') = ?",
        [eventName]
    );
    return result.success ? result.data : [];
}
```

### 5.6 Sicherheit

- Alle API-Endpunkte erfordern Authentifizierung (`@manage_auth.require_auth`)
- SQL-Injection-Prävention durch Parameterisierung
- Beschränkter Zugriff für Nicht-Admin-Benutzer auf bestimmte Operationen

### 5.7 Fehlerbehebung

1. **Verbindungsfehler**: Stellen Sie sicher, dass das `data/`-Verzeichnis existiert und Schreibrechte hat
2. **Integritätsfehler**: Führen Sie `manage_database.py check` aus und anschließend `manage_database.py optimize`
3. **Fehlende Tabellen**: Führen Sie `manage_database.py init` aus

### 5.8 Best Practices

1. Vermeiden Sie direkte SQL-Abfragen im Frontend; nutzen Sie stattdessen die Hilfsfunktionen
2. Verwenden Sie Transaktionen für zusammenhängende Operationen
3. Führen Sie regelmäßig Optimierungen durch (`optimize_db()`)
4. Validieren Sie Eingabedaten, bevor sie in die Datenbank geschrieben werden

### 5.9 Entwicklungshinweise

> **WICHTIG**: Die Datenbankmodule wurden für Entwicklung ohne Live-System konzipiert. Gemäß der `policy_development_testing.md` erfolgt die Entwicklung ohne Zugriff auf laufende Instanzen oder Datenbanken. Verwenden Sie die bereitgestellten Mock-Funktionen für alle Tests.

Bei der Entwicklung von Features, die mit der Datenbank interagieren:

1. Erzeugen Sie Mock-Antworten für alle API-Aufrufe
2. Implementieren Sie Unit-Tests mit vordefinierten Test-Datensätzen
3. Dokumentieren Sie alle vorausgesetzten Datenstrukturen

### 5.10 Zukünftige Erweiterungen

- Transaktionsunterstützung
- Erweitertes Schema-Migrations-System
- Backup- und Restore-Funktionen

## 6. Migration von Legacy-Code

Beim Migrieren von Legacy-Code in die neue modulare Struktur:

### 6.1 Migrations-Schrittfolge

1. **Analyse des bestehenden Codes**:
   - Identifizieren Sie Funktionen, die zu Systemmodulen gehören
   - Markieren Sie seitenspezifischen Code

2. **Modul-Gerüst erstellen**:
   - Erstellen Sie die Grundstruktur für das neue Systemmodul

3. **Funktionen migrieren**:
   - Kopieren und refaktorisieren Sie die Funktionen in das neue Modul
   - Überprüfen Sie Abhängigkeiten und passen Sie sie an
   - Implementieren Sie angemessene Fehlerbehandlung

4. **Ursprüngliche Datei anpassen**:
   - Importieren Sie die migrierten Funktionen
   - Entfernen Sie den alten Code

5. **Testen und Validieren**:
   - Testen Sie die Migration gründlich
   - Aktualisieren Sie die Dokumentation

### 6.2 Hilfestellung bei Migrationsherausforderungen

#### Zirkuläre Abhängigkeiten lösen

1. Identifizieren Sie gemeinsam genutzte Funktionalität
2. Extrahieren Sie diese in ein separates Basismodul
3. Importieren Sie dieses Basismodul in beide abhängigen Module

#### Globale Variablen

1. Wandeln Sie globale Variablen in Modulvariablen um
2. Bieten Sie Getter/Setter-Funktionen an
3. Verwenden Sie den Module Pattern für Zustandsverwaltung

#### Eng gekoppelten Code trennen

1. Trennen Sie Geschäftslogik von der UI
2. Definieren Sie klare Schnittstellen zwischen Komponenten
3. Verwenden Sie Callbacks oder Events für die Kommunikation

## 7. Testen und Qualitätssicherung

### 7.1 Testtypen

- **Unit-Tests**: Testen einzelner Funktionen und Module
- **Integrationstests**: Testen der Interaktion zwischen Modulen
- **UI-Tests**: Testen der Benutzeroberfläche
- **End-to-End-Tests**: Testen des Gesamtsystems

### 7.2 Test-Implementierung

Frontend-Tests werden in den jeweiligen `tests/`-Verzeichnissen implementiert und verwenden Jest für JavaScript-Tests.

Backend-Tests werden mit pytest implementiert und folgen dieser Struktur:

```python
def test_function_name():
    # Vorbereitung
    input_data = {"param": "value"}
    
    # Ausführung
    result = function_name(input_data)
    
    # Überprüfung
    assert result["status"] == "success"
    assert "data" in result
```

### 7.3 Kontinuierliche Integration

Alle Änderungen sollten:

1. Die bestehenden Tests bestehen
2. Neue Tests für die Änderungen enthalten
3. Den Coding-Richtlinien entsprechen (ESLint für JS, PEP 8 für Python)

## 8. Versionierung und Deployment

### 8.1 Versionsnummern

Das Projekt folgt Semantic Versioning (SemVer):

- **Major**: Inkompatible API-Änderungen
- **Minor**: Funktionserweiterungen mit Abwärtskompatibilität
- **Patch**: Bugfixes mit Abwärtskompatibilität

### 8.2 Deployment-Prozess

1. Testen auf Entwicklungsumgebung
2. Versionsnummer in `conf/version.inf` aktualisieren
3. Release-Paket erstellen
4. Deployment auf Zielumgebung über das Updatesystem

### 8.3 Update-Kompatibilität

Achten Sie beim Deployment auf:

- Datenbank-Migrationen
- Konfigurationsänderungen
- Abhängigkeiten zu anderen Modulen
- Abwärtskompatibilität oder Upgrade-Pfade

### 8.4 Update-System Architektur

Das Update-System besteht aus zwei Hauptkomponenten:

1. **Backend-Update-Modul (`manage_update.py`)**: Verantwortlich für die serverseitige Update-Logik
2. **Frontend-Update-Modul (`manage_update.js`)**: Bietet die Benutzeroberfläche für den Update-Prozess

#### Update-Prozess im Detail

Das Update-System führt einen mehrstufigen Prozess durch:

1. **Versionsprüfung**: Vergleicht die lokale Version (`conf/version.inf`) mit der aktuellsten verfügbaren Version
2. **Backup-Erstellung**: Erstellt ein vollständiges Backup vor dem Update im Ordner `backup-update-<Datum>`

   ```python
   def create_backup():
       """Erstellt ein vollständiges Backup des aktuellen Systemzustands."""
       timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
       backup_dir = f"backup-update-{timestamp}"
       # Sichern wichtiger Verzeichnisse und Konfigurationsdateien
       return backup_dir
   ```

3. **Projekt-Update**: Aktualisiert den Quellcode (git pull)

   ```python
   def update_source_code():
       """Aktualisiert den Quellcode über Git."""
       try:
           subprocess.run(["git", "pull", "origin", "master"], check=True)
           return True
       except subprocess.CalledProcessError as e:
           log_error(f"Fehler beim Aktualisieren des Quellcodes: {e}")
           return False
   ```

4. **Abhängigkeiten-Update**: Installiert und aktualisiert erforderliche Abhängigkeiten

   ```python
   def update_dependencies():
       """Aktualisiert alle System- und Python-Abhängigkeiten."""
       update_system_dependencies()
       update_python_dependencies()
   ```

5. **Webserver-Konfiguration**: Aktualisiert die NGINX-Konfiguration nach Bedarf
6. **Service-Neustart**: Startet den Backend-Dienst neu
7. **Erreichbarkeitstest**: Überprüft die Verfügbarkeit nach dem Update

#### Abhängigkeiten-Management

Das Abhängigkeiten-Management erfolgt über zwei Konfigurationsdateien:

1. **`conf/requirements_system.inf`**: Definiert erforderliche Betriebssystem-Pakete

   ```ini
   # Format: paket>=version
   nginx>=1.18.0
   python3>=3.8
   python3-pip>=20.0
   ```

2. **`conf/requirements_python.inf`**: Definiert erforderliche Python-Module

   ```ini
   # Format: modul>=version
   Flask>=2.0.0
   Pillow>=8.0.0
   opencv-python>=4.5.0
   ```

Die Überprüfung und Installation erfolgt über diese Funktionen:

```python
def check_system_dependency(package, min_version=None):
    """Prüft, ob ein Systempaket installiert ist und die Mindestversion erfüllt."""
    # Implementierung der Versionsprüfung
    pass

def check_python_dependency(package, min_version=None):
    """Prüft, ob ein Python-Paket installiert ist und die Mindestversion erfüllt."""
    # Implementierung der Versionsprüfung mit pkg_resources
    pass

def install_system_dependencies(packages):
    """Installiert erforderliche Systempakete."""
    # Implementierung mit apt-get oder entsprechenden Paketmanager
    pass

def install_python_dependencies(packages):
    """Installiert erforderliche Python-Pakete."""
    # Implementierung mit pip
    pass
```

#### Fehlerbehandlung beim Update

Das Update-System implementiert eine robuste Fehlerbehandlung:

1. **Rollback bei Fehlern**: Bei kritischen Fehlern wird das zuvor erstellte Backup wiederhergestellt

   ```python
   def rollback_update(backup_dir):
       """Stellt das System aus einem Backup wieder her."""
       # Implementierung der Wiederherstellung
       pass
   ```

2. **Detaillierte Fehlerberichte**: Alle Fehler werden in den Logs dokumentiert und in der UI angezeigt

3. **Unabhängige Teilprozesse**: Das Update ist in unabhängige Phasen unterteilt, sodass ein Fehler in einer Phase nicht den gesamten Prozess gefährdet

#### Frontend-Integration

Die Frontend-Integration erfolgt über `manage_update.js`:

```javascript
// Status des Update-Prozesses abfragen
async function checkUpdateStatus() {
    try {
        const response = await fetch('/api/update/status');
        const data = await response.json();
        updateProgressUI(data.status, data.progress, data.message);
        return data;
    } catch (err) {
        showError('Fehler beim Abrufen des Update-Status', err);
        return { status: 'error', message: err.toString() };
    }
}

// Update starten
async function startUpdate() {
    try {
        showUpdateProgressModal();
        const response = await fetch('/api/update/start', { method: 'POST' });
        const data = await response.json();
        
        if (data.status === 'started') {
            pollUpdateStatus();
            return true;
        } else {
            showError('Update konnte nicht gestartet werden', data.message);
            return false;
        }
    } catch (err) {
        showError('Fehler beim Starten des Updates', err);
        return false;
    }
}

// Update-Status in regelmäßigen Abständen abrufen
function pollUpdateStatus() {
    const intervalId = setInterval(async () => {
        const status = await checkUpdateStatus();
        
        if (['completed', 'failed', 'error'].includes(status.status)) {
            clearInterval(intervalId);
            handleUpdateCompletion(status);
        }
    }, 2000); // Alle 2 Sekunden aktualisieren
}
```

#### API-Endpunkte

Das Backend stellt folgende API-Endpunkte für Updates bereit:

| Endpunkt | Methode | Beschreibung |
|----------|---------|-------------|
| `/api/update/check` | GET | Prüft, ob ein Update verfügbar ist |
| `/api/update/start` | POST | Startet den Update-Prozess |
| `/api/update/status` | GET | Ruft den aktuellen Status des laufenden Updates ab |
| `/api/update/dependencies/check` | GET | Prüft den Status aller Abhängigkeiten |
| `/api/update/dependencies/install` | POST | Installiert fehlende Abhängigkeiten |
| `/api/update/rollback` | POST | Stellt das System aus dem letzten Backup wieder her |

#### Best Practices für Updates

1. **Semantische Versionierung**: Befolgen Sie strikt die Semantische Versionierung (SemVer)
2. **Automatisierte Tests**: Führen Sie automatisierte Tests vor jedem Release durch
3. **Changelogs**: Pflegen Sie detaillierte Changelogs für jede Version
4. **Migrationsskripte**: Erstellen Sie Migrationsskripte für Datenbank- oder Konfigurationsänderungen
5. **Schrittweise Updates**: Unterstützen Sie schrittweise Updates, falls Anwender mehrere Versionen überspringen
6. **Validierung**: Führen Sie umfassende Validierungen vor und nach dem Update durch
7. **Dokumentation**: Dokumentieren Sie alle relevanten Änderungen, die Aufmerksamkeit erfordern können

### 8.5 Installationsskript Architektur

Das Installationsskript (`install.sh`) bildet das Fundament für die Ersteinrichtung der Fotobox-Anwendung und folgt einer modularen Struktur, die Robustheit und Zuverlässigkeit gewährleistet.

#### Kernfunktionen und Verbesserungen

##### Set-Fallback-Security-Settings

Die `set_fallback_security_settings()`-Funktion ist zentral für die Initialisierung des Installationsprozesses und übernimmt:

- Prüfung der Root-Rechte mit frühzeitigem Abbruch bei fehlenden Berechtigungen
- Validierung der Distribution (Debian/Ubuntu-Kompatibilität)
- Erstellung und Verifizierung des Log-Verzeichnisses mit mehrstufigem Fallback-Mechanismus
- Bereitstellung der Fallback-Funktionen für Logging- und Print-Ausgaben

Diese Zentralisierung ermöglicht eine klarere Fehlerbehandlung direkt beim Skriptstart und verhindert unvollständige Installationen durch frühzeitige Erkennung von Problemen.

##### Verzeichnisverwaltung

Die Verzeichnisstruktur wird über ein dediziertes System verwaltet:

- Primär wird `manage_folders.sh` für alle Verzeichnisoperationen verwendet
- Bei Nichtverfügbarkeit wird auf `use_fallback_structure()` zurückgegriffen
- Explizite Prüfung der Schreibrechte durch Test-Dateien für kritische Verzeichnisse
- Standardisierte Fehlerrückgaben für detaillierte Diagnosen

#### Dialog-Funktionen

Die Dialog-Funktionen (`dlg_*`) wurden neu strukturiert:

- `dlg_check_root()` und `dlg_check_distribution()` dienen hauptsächlich der Ausgabe
- Die eigentliche Prüflogik wurde in `set_fallback_security_settings` zentralisiert
- Im Unattended-Modus werden Dialog-Ausgaben unterdrückt und nur ins Log geschrieben
- Alle Funktionen geben standardisierte Fehlercodes zurück

#### Systemanforderungen

Die Datei `conf/requirements_system.inf` definiert alle benötigten Systempakete:

- `python3-ensurepip` wurde entfernt (nicht auf allen Distributionen verfügbar)
- Optionale RealSense-Pakete wurden als Kommentare markiert
- Die Installation prüft Abhängigkeitskonflikte und bietet Lösungswege

#### Unattended-Modus

Der Unattended-Modus (`--unattended` oder `-u`, `--headless`, `headless`, `-q`) bietet folgende Funktionen:

- Automatisches Beantworten aller Rückfragen mit Standardwerten:
  - Portwahl: Standardport 80 wird verwendet (sofern frei)
  - NGINX-Integration: Default-Integration wird automatisch gewählt
  - Paket-Upgrade: Upgrades werden abgelehnt
  - Bei Konflikten: Abbruch mit Log-Eintrag
- Keine Benutzerinteraktion erforderlich
- Status- und Fehlermeldungen werden nur ins Logfile geschrieben
- Ausnahme: Am Ende wird ein Hinweis auf die Logdatei und Weboberfläche ausgegeben

#### Logging-System

Das Logging-System des Installationsskripts bietet:

- Zeitleistenbasierte Protokollierung aller Aktionen
- Standardmäßige Ablage in `/var/log/<datum>_install.log`
- Fallback-Mechanismus für `/tmp` oder aktuelles Verzeichnis
- Tägliche Rotation und Komprimierung älterer Logs

#### Systembenutzer und Berechtigungen

Das Installationsskript erstellt einen dedizierten Systembenutzer `fotobox`:

- Angelegt mit `useradd -r -M -s /usr/sbin/nologin fotobox`
- Kein Home-Verzeichnis (Best Practice für Systemdienste)
- Keine Login-Shell aus Sicherheitsgründen
- Alle relevanten Verzeichnisse erhalten angepasste Berechtigungen

#### Bekannte Einschränkungen

- Auf älteren Systemen können Probleme bei der Kompilierung nativer Python-Erweiterungen auftreten
- Spezielle Hardware (wie Intel RealSense-Kameras) erfordert zusätzliche manuelle Installation

Diese Architektur gewährleistet eine zuverlässige Installation auf unterstützten Systemen und bietet gleichzeitig eine robuste Fehlerbehandlung für nicht standardmäßige Umgebungen.

## 9. Weitere Ressourcen

- [Migrations-Dokumentation](../policies/migration_consolidated.md): Detaillierte Informationen zur Code-Migration
- [Backend-API-Policy](../policies/policy_backend_api.md): Richtlinien für Backend-APIs
- [Frontend-JavaScript-Policy](../policies/policy_frontend_javascript.md): Richtlinien für Frontend-JavaScript
- [Code-Strukturierungs-Policy](../policies/policy_code_structure.md): Richtlinien zur Codestrukturierung

## 10. Logging-System

Das Logging-System der Fotobox2 ist eine zentrale Infrastrukturkomponente, die in allen Teilen der Anwendung zum Einsatz kommt und eine einheitliche Protokollierung von Ereignissen, Fehlern und Debug-Informationen ermöglicht.

### 10.1 Architektur

Das Logging-System besteht aus zwei eng miteinander verzahnten Hauptkomponenten:

1. **Backend-Logging** (`manage_logging.py`): Zuständig für serverseitige Logs und das Speichern von Logs aus dem Frontend
2. **Frontend-Logging** (`manage_logging.js`): Ermöglicht das Protokollieren von Client-Ereignissen und sendet diese bei Bedarf an das Backend

### 10.2 Log-Levels

Das System unterstützt vier Standard-Log-Levels:

| Level | Beschreibung | Typische Verwendung |
|-------|-------------|---------------------|
| DEBUG | Detaillierte Informationen | Technische Details zur Fehlersuche während der Entwicklung |
| INFO | Allgemeine Informationen | Normale Betriebsinformationen (Standard) |
| WARN / WARNING | Warnungen | Potenzielle Probleme, die (noch) keine Funktionseinschränkung verursachen |
| ERROR | Fehler | Probleme, die eine Funktionalität beeinträchtigen |

### 10.3 Backend-Implementation (`manage_logging.py`)

#### Kernfunktionen

```python
import manage_logging

# Einfache Informationsnachricht
manage_logging.log("Ein Benutzer hat sich angemeldet")

# Warnmeldung mit zusätzlichem Kontext
manage_logging.warn("Ungewöhnlicher Anmeldeversuch", 
                  context={"ip": "192.168.1.100"}, 
                  source="auth_module")

# Fehlermeldung mit Exception-Details
try:
    # Fehlerhafter Code
    result = 10 / 0
except Exception as e:
    manage_logging.error("Fehler bei Berechnung", 
                       exception=e,
                       source="calc_module")

# Debug-Information
manage_logging.debug("Detaillierte Laufzeitinformation", 
                   context={"value": 42}, 
                   source="debug_module")
```

#### Konfiguration

Die Backend-Logging-Konfiguration wird in der Datei `backend/manage_logging.py` definiert:

| Parameter | Standardwert | Beschreibung |
|-----------|-------------|-------------|
| LOG_LEVEL | INFO | Minimaler Level für die Protokollierung |
| LOG_FILE | `/opt/fotobox/log/YYYY-MM-DD_fotobox.log` | Pfad zur Hauptlogdatei |
| DEBUG_LOG_FILE | `/opt/fotobox/log/fotobox_debug.log` | Pfad zur Debug-Logdatei |
| LOG_FORMAT | `[%(asctime)s] %(levelname)s: %(message)s` | Format der Logeinträge |
| MAX_LOG_FILES | 5 | Maximale Anzahl rotierter Logdateien |

### 10.4 Frontend-Implementation (`manage_logging.js`)

Das Frontend-Logging ist so konfiguriert, dass es Logs sowohl in der Browser-Konsole als auch an das Backend sendet:

```javascript
import { log, warn, error, debug } from './manage_logging.js';

// Einfache Informationsnachricht
log("Benutzer hat auf Button geklickt");

// Warnmeldung
warn("Formularvalidierung fehlgeschlagen", { field: "email" });

// Fehlermeldung
try {
    // Fehlerhafter Code
    const result = nonExistingVariable + 10;
} catch (err) {
    error("JavaScript-Fehler aufgetreten", err);
}

// Debug-Information
debug("Detaillierte Client-Information", { screenSize: window.innerWidth + "x" + window.innerHeight });
```

### 10.5 Datenspeicherung

#### Dateistruktur

Die Log-Dateien werden in folgenden Verzeichnissen gespeichert:

- Primär: `/opt/fotobox/log/`
- Fallback: `/var/log/fotobox/` (falls das primäre Verzeichnis nicht beschreibbar ist)

#### Datenbank

Alle Logs werden parallel in einer SQLite-Datenbank gespeichert:

- Pfad: `/opt/fotobox/data/fotobox_logs.db`
- Tabelle: `logs`
- Schema:

  ```sql
  CREATE TABLE logs (
      id INTEGER PRIMARY KEY,
      timestamp TEXT,
      level TEXT,
      message TEXT,
      source TEXT,
      context TEXT
  );
  ```

#### Log-Rotation und -Aufbewahrung

- Tägliche Rotation: `YYYY-MM-DD_fotobox.log` → `YYYY-MM-DD_fotobox.log.1`
- Komprimierung älterer Logs (ab `.2`): `YYYY-MM-DD_fotobox.log.2.gz`
- Aufbewahrung von maximal 5 rotierten Logdateien

### 10.6 Analyse und Debugging

Für die Analyse der Logs stehen folgende Methoden zur Verfügung:

#### Direkte Dateianalyse

```bash
# Aktuelle Logs ansehen
tail -f /opt/fotobox/log/$(date +%Y-%m-%d)_fotobox.log

# Fehler in den Logs suchen
grep ERROR /opt/fotobox/log/$(date +%Y-%m-%d)_fotobox.log
```

#### Datenbank-Abfrage

```bash
# SQLite-Konsole öffnen
sqlite3 /opt/fotobox/data/fotobox_logs.db

# Letzte 20 Fehler-Logs abfragen
SELECT timestamp, message, context FROM logs 
WHERE level='ERROR' 
ORDER BY timestamp DESC 
LIMIT 20;
```

### 10.7 Best Practices

- **Einheitlichkeit**: Verwenden Sie konsequent die Log-Funktionen anstelle von `print()` oder `console.log()`
- **Kontextinformationen**: Fügen Sie bei komplexen Operationen immer Kontext hinzu
- **Fehlerbehandlung**: Fangen Sie Exceptions ab und protokollieren Sie sie mit Details
- **Modulangabe**: Verwenden Sie stets den `source`-Parameter für eine klare Zuordnung
- **Log-Level**: Wählen Sie das angemessene Log-Level für jede Nachricht

## 11. Netzwerkkonfiguration

Die Fotobox unterstützt verschiedene Netzwerkkonfigurationen, die es ermöglichen, die Anwendung je nach Einsatzszenario optimal zu betreiben. Dieser Abschnitt erklärt die technischen Details und Implementierungen der verschiedenen Netzwerkszenarien.

### 11.1 Netzwerkarchitektur

Die Netzwerkarchitektur der Fotobox basiert auf einem eingebetteten Webserver (NGINX), der die Weboberfläche bereitstellt und als Reverse-Proxy für die Backend-API fungiert. Die Konfiguration des Webservers wird dynamisch durch das Modul `manage_network.py` verwaltet.

### 11.2 Unterstützte Einsatzszenarien

#### 11.2.1 Standalone-Betrieb (kein Netz)

**Technische Umsetzung:**

- Der Webserver bindet sich nur an die lokale Loopback-Schnittstelle (`127.0.0.1`)
- Kein externer Zugriff möglich
- Minimale Sicherheitsanforderungen
- Keine Konfiguration von CORS notwendig

**Implementierungsdetails:**

```python
# Beispielkonfiguration für Standalone-Betrieb
config = {
    "bind_address": "127.0.0.1",
    "port": 8080,
    "server_name": "localhost",
    "url_path": "/",
    "config_type": "internal",
    "ssl_enabled": False
}
```

**Webserver-Konfiguration:**

```nginx
server {
    listen 127.0.0.1:8080;
    server_name localhost;
    
    location / {
        # Weboberfläche einbinden
    }
    
    location /api/ {
        # Backend-API-Proxy
    }
}
```

#### 11.2.2 Betrieb im lokalen Netzwerk

**Technische Umsetzung:**

- Der Webserver bindet sich an alle verfügbaren Netzwerkschnittstellen (`0.0.0.0`) oder an eine spezifische lokale IP
- Zugriff innerhalb des lokalen Netzwerks möglich
- Basis-Sicherheitsmaßnahmen empfehlenswert
- CORS-Konfiguration für lokales Netzwerk

**Implementierungsdetails:**

```python
# Beispielkonfiguration für lokales Netz
config = {
    "bind_address": "0.0.0.0",  # Alternativ spezifische lokale IP wie "192.168.1.100"
    "port": 80,
    "server_name": "fotobox.local",
    "url_path": "/",
    "config_type": "external",
    "ssl_enabled": False  # Optional True mit selbstsigniertem Zertifikat
}
```

**Webserver-Konfiguration:**

```nginx
server {
    listen 0.0.0.0:80;
    server_name fotobox.local;
    
    # CORS-Header für lokales Netz
    add_header 'Access-Control-Allow-Origin' 'http://*.local';
    
    location / {
        # Weboberfläche einbinden
    }
    
    location /api/ {
        # Backend-API-Proxy mit CORS-Headern
    }
}
```

**Multicast DNS (mDNS/Bonjour):**
Die Fotobox kann unter dem Namen `fotobox.local` via mDNS im lokalen Netzwerk erreichbar gemacht werden:

```python
# mDNS-Service registrieren (Backend-Implementierung)
def register_mdns_service(port):
    try:
        import zeroconf
        # Service-Registration-Code
    except ImportError:
        log.warn("zeroconf nicht installiert, mDNS-Dienst nicht verfügbar")
```

#### 11.2.3 Cloud- oder externer Zugriff

**Technische Umsetzung:**

- Der Webserver bindet sich an alle verfügbaren Netzwerkschnittstellen (`0.0.0.0`)
- Zugriff über das Internet mit entsprechender Portfreigabe/Routing
- Erweiterte Sicherheitsmaßnahmen zwingend erforderlich (HTTPS, Zugriffsbeschränkungen)
- Strikte CORS-Konfiguration für definierte externe Domains

**Implementierungsdetails:**

```python
# Beispielkonfiguration für Cloud/extern
config = {
    "bind_address": "0.0.0.0",
    "port": 443,
    "server_name": "meinefotobox.example.com",
    "url_path": "/",
    "config_type": "external",
    "ssl_enabled": True,
    "ssl_cert_path": "/etc/ssl/certs/fotobox.crt",
    "ssl_key_path": "/etc/ssl/private/fotobox.key"
}
```

**Webserver-Konfiguration:**

```nginx
server {
    listen 0.0.0.0:443 ssl;
    server_name meinefotobox.example.com;
    
    ssl_certificate /etc/ssl/certs/fotobox.crt;
    ssl_certificate_key /etc/ssl/private/fotobox.key;
    
    # Sichere SSL-Konfiguration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    
    # Strikte CORS-Header
    add_header 'Access-Control-Allow-Origin' 'https://meinefotobox.example.com';
    
    # Zusätzliche Sicherheitsheader
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    
    location / {
        # Weboberfläche einbinden
    }
    
    location /api/ {
        # Backend-API-Proxy mit CORS-Headern
        # Auth-Middleware aktivieren
    }
}
```

**Zusätzliche Sicherheitsimplementierung:**

```python
# SSL-Zertifikat mit Let's Encrypt erstellen
def setup_letsencrypt_cert(domain):
    try:
        # Let's Encrypt Certbot aufrufen
        subprocess.run(["certbot", "--nginx", "-d", domain, "--non-interactive", "--agree-tos"], check=True)
        return True
    except subprocess.CalledProcessError:
        log.error(f"Fehler beim Generieren des Let's Encrypt Zertifikats für {domain}")
        return False
```

### 11.3 Übersicht der Netzwerkeinstellungen

| Einstellung        | Standalone (kein Netz) | Lokales Netz         | Cloud/extern         |
|--------------------|------------------------|----------------------|----------------------|
| Bind-Adresse       | 127.0.0.1              | 0.0.0.0 / lokale IP  | 0.0.0.0 / öffentl. IP|
| Port               | beliebig               | anpassbar            | anpassbar            |
| Servername         | optional               | sinnvoll             | sinnvoll             |
| URL-Pfad           | optional               | optional             | optional             |
| Konfigurationstyp  | intern                 | extern/optional      | extern/optional      |
| Status/Validierung | wichtig                | wichtig              | wichtig              |
| HTTPS/SSL          | unwichtig              | optional             | wichtig              |

### 11.4 Netzwerk-Verwaltungsmodul (`manage_network.py`)

Das Modul `manage_network.py` dient zur dynamischen Konfiguration der Netzwerkeinstellungen und enthält folgende Hauptfunktionen:

```python
# Netzwerkkonfigurationen anwenden
def apply_network_config(config):
    # Erstellen der Webserver-Konfiguration basierend auf config-Parametern
    # Neustart des Webservers
    pass

# Netzwerkdiagnose durchführen
def diagnose_network():
    # Netzwerkschnittstellen überprüfen
    # Portverfügbarkeit testen
    # DNS-Auflösung testen
    # Verbindungstest durchführen
    pass

# Hostname/IP-Adresse der Fotobox abrufen
def get_host_info():
    # Hostname, IP-Adressen und Erreichbarkeit ermitteln
    pass
```

### 11.5 Implementierung im Frontend

Das Frontend bietet eine benutzerfreundliche Oberfläche zur Konfiguration der Netzwerkeinstellungen über das Admin-Panel. Die Implementierung befindet sich in der Datei `frontend/js/manage_network.js`:

```javascript
// Netzwerkeinstellungen speichern
async function saveNetworkSettings(config) {
    try {
        const response = await fetch('/api/network/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        });
        
        if (response.ok) {
            showNotification('Netzwerkeinstellungen gespeichert. Der Server wird neu gestartet...');
            // Verbindungstest nach kurzer Verzögerung
            setTimeout(testConnection, 5000);
        } else {
            showError('Fehler beim Speichern der Netzwerkeinstellungen');
        }
    } catch (err) {
        showError('Netzwerkfehler', err);
    }
}

// Netzwerkdiagnose ausführen
async function runNetworkDiagnostics() {
    try {
        const response = await fetch('/api/network/diagnose');
        const results = await response.json();
        displayDiagnosticResults(results);
    } catch (err) {
        showError('Diagnose fehlgeschlagen', err);
    }
}
```

### 11.6 API-Endpunkte

Das Backend stellt folgende API-Endpunkte zur Netzwerkkonfiguration bereit:

| Endpunkt | Methode | Beschreibung |
|----------|---------|-------------|
| `/api/network/config` | GET | Aktuelle Netzwerkkonfiguration abrufen |
| `/api/network/config` | POST | Netzwerkkonfiguration aktualisieren |
| `/api/network/diagnose` | GET | Netzwerkdiagnose durchführen |
| `/api/network/interfaces` | GET | Verfügbare Netzwerkschnittstellen abrufen |
| `/api/network/status` | GET | Aktuellen Netzwerkstatus abrufen |

### 11.7 Best Practices für Entwickler

1. **Sicherheit priorisieren**: Bei externen Installationen immer HTTPS aktivieren
2. **Zugriffsschutz**: Admin-Bereich mit starker Authentifizierung schützen
3. **Netzwerk-Timeouts**: Angemessene Timeouts für Netzwerkoperationen definieren
4. **Robuste Fehlerbehandlung**: Netzwerkfehler gracefully behandeln
5. **Fallback-Mechanismen**: Bei Netzwerkproblemen lokalen Fallback anbieten
6. **Konfigurationstests**: Vor dem Anwenden neuer Konfigurationen Validierung durchführen
7. **Logging**: Relevante Netzwerkänderungen und -probleme protokollieren

---

*Dieses Entwicklerhandbuch wird regelmäßig aktualisiert, um Änderungen an der Projektarchitektur und den Best Practices zu reflektieren.*

## 12. Deinstallationssystem

Die Fotobox bietet eine strukturierte Möglichkeit zur vollständigen Deinstallation über die Weboberfläche. Dieser Abschnitt dokumentiert die technischen Details des Deinstallationsprozesses.

### 12.1 Architektur des Deinstallationssystems

Das Deinstallationssystem besteht aus zwei Hauptkomponenten:

1. **Backend-Deinstallationsmodul** (`manage_uninstall.py`): Verantwortlich für die serverseitige Deinstallationslogik
2. **Frontend-Deinstallationsmodul**: Teil der Administrationsschnittstelle in `settings.html`

### 12.2 Deinstallationsprozess im Detail

Die Deinstallation folgt einem mehrstufigen Prozess:

#### 12.2.1 Datenbackup

Vor der eigentlichen Deinstallation wird ein Backup aller wichtigen Daten erstellt:

```python
def create_uninstall_backup():
    """Erstellt ein Backup aller wichtigen Daten vor der Deinstallation."""
    backup_dir = f"/tmp/fotobox_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    # Verzeichnisstruktur für Backup erstellen
    os.makedirs(f"{backup_dir}/config", exist_ok=True)
    os.makedirs(f"{backup_dir}/data", exist_ok=True)
    os.makedirs(f"{backup_dir}/photos", exist_ok=True)
    
    # Konfiguration sichern
    shutil.copy("/etc/nginx/sites-available/fotobox", f"{backup_dir}/config/")
    shutil.copy("/etc/systemd/system/fotobox-backend.service", f"{backup_dir}/config/")
    
    # Datenbank sichern
    shutil.copy("/opt/fotobox/data/fotobox.db", f"{backup_dir}/data/")
    
    # Fotos sichern
    shutil.copytree("/opt/fotobox/frontend/photos", f"{backup_dir}/photos/", dirs_exist_ok=True)
    
    # Backup als Zip-Archiv komprimieren
    shutil.make_archive(f"{backup_dir}", "zip", backup_dir)
    
    # Temporäres Verzeichnis löschen
    shutil.rmtree(backup_dir)
    
    return f"{backup_dir}.zip"
```

#### 12.2.2 Dienste stoppen

Anschließend werden alle laufenden Dienste gestoppt:

```python
def stop_services():
    """Stoppt alle Fotobox-bezogenen Dienste."""
    try:
        # Backend-Service stoppen
        subprocess.run(["systemctl", "stop", "fotobox-backend"], check=True)
        
        # NGINX neustarten, um die Fotobox-Konfiguration zu deaktivieren
        subprocess.run(["systemctl", "restart", "nginx"], check=True)
        
        return True
    except subprocess.CalledProcessError as e:
        log_error(f"Fehler beim Stoppen der Dienste: {e}")
        return False
```

#### 12.2.3 Systemdienste entfernen

Systemdienstdateien werden entfernt:

```python
def remove_system_services():
    """Entfernt die systemd-Unit für den Backend-Dienst."""
    try:
        # Systemd-Unit deaktivieren
        subprocess.run(["systemctl", "disable", "fotobox-backend"], check=True)
        
        # Systemd-Unit-Datei entfernen
        if os.path.exists("/etc/systemd/system/fotobox-backend.service"):
            os.remove("/etc/systemd/system/fotobox-backend.service")
        
        # Systemd neu laden
        subprocess.run(["systemctl", "daemon-reload"], check=True)
        
        return True
    except (subprocess.CalledProcessError, OSError) as e:
        log_error(f"Fehler beim Entfernen der Systemdienste: {e}")
        return False
```

#### 12.2.4 NGINX-Konfiguration entfernen

Die Webserver-Konfiguration wird entfernt:

```python
def remove_nginx_config():
    """Entfernt die NGINX-Konfiguration für die Fotobox."""
    try:
        # Symlink aus sites-enabled entfernen
        if os.path.exists("/etc/nginx/sites-enabled/fotobox"):
            os.remove("/etc/nginx/sites-enabled/fotobox")
        
        # Konfigurationsdatei aus sites-available entfernen
        if os.path.exists("/etc/nginx/sites-available/fotobox"):
            # Optional: Backup erstellen
            shutil.copy("/etc/nginx/sites-available/fotobox", 
                        "/etc/nginx/sites-available/fotobox.bak")
            os.remove("/etc/nginx/sites-available/fotobox")
        
        # NGINX neustarten
        subprocess.run(["systemctl", "restart", "nginx"], check=True)
        
        return True
    except (subprocess.CalledProcessError, OSError) as e:
        log_error(f"Fehler beim Entfernen der NGINX-Konfiguration: {e}")
        return False
```

#### 12.2.5 Projektdateien entfernen

Das Projektverzeichnis wird komplett gelöscht:

```python
def remove_project_files(project_dir="/opt/fotobox"):
    """Entfernt alle Projektdateien."""
    try:
        if os.path.exists(project_dir) and os.path.isdir(project_dir):
            shutil.rmtree(project_dir)
        return True
    except OSError as e:
        log_error(f"Fehler beim Löschen der Projektdateien: {e}")
        return False
```

#### 12.2.6 Systembenutzer entfernen

Optional wird der Systembenutzer entfernt:

```python
def remove_system_user(username="fotobox"):
    """Entfernt den Systembenutzer und die zugehörige Gruppe."""
    try:
        # Prüfen, ob der Benutzer existiert
        user_exists = subprocess.run(
            ["id", username], 
            stdout=subprocess.DEVNULL, 
            stderr=subprocess.DEVNULL
        ).returncode == 0
        
        if user_exists:
            # Benutzer löschen
            subprocess.run(["userdel", username], check=True)
            
            # Gruppe löschen (falls kein anderer Benutzer in der Gruppe ist)
            subprocess.run(["groupdel", username], 
                          stdout=subprocess.DEVNULL, 
                          stderr=subprocess.DEVNULL)
        
        return True
    except subprocess.CalledProcessError as e:
        log_error(f"Fehler beim Entfernen des Systembenutzers: {e}")
        return False
```

### 12.3 API-Endpunkte

Das Backend stellt folgende API-Endpunkte für die Deinstallation bereit:

| Endpunkt | Methode | Beschreibung |
|----------|---------|-------------|
| `/api/uninstall/backup` | GET | Erstellt ein Backup und gibt den Download-Link zurück |
| `/api/uninstall/start` | POST | Startet den Deinstallationsprozess |
| `/api/uninstall/status` | GET | Ruft den aktuellen Status des Deinstallationsprozesses ab |
| `/api/uninstall/confirm` | POST | Bestätigt die Deinstallation (zweiter Bestätigungsschritt) |

### 12.4 Frontend-Integration

Die Frontend-Integration erfolgt über die Einstellungsseite (`settings.html`):

```javascript
// Deinstallation starten
async function startUninstallation() {
    try {
        // Bestätigungsdialog anzeigen
        const confirmed = await showConfirmationDialog(
            "Fotobox deinstallieren",
            "Möchten Sie die Fotobox wirklich vollständig deinstallieren? " +
            "Alle Daten und Einstellungen werden gelöscht. " +
            "Dieser Vorgang kann nicht rückgängig gemacht werden.",
            "Deinstallieren", "Abbrechen"
        );
        
        if (!confirmed) return;
        
        // Backup erstellen und Download anbieten
        showProgressModal("Backup wird erstellt...");
        const backupResponse = await fetch('/api/uninstall/backup');
        const backupData = await backupResponse.json();
        
        if (backupData.success && backupData.backupUrl) {
            await downloadBackup(backupData.backupUrl);
        }
        
        // Zweite Bestätigung nach Backup
        const confirmedAfterBackup = await showConfirmationDialog(
            "Deinstallation fortsetzen",
            "Das Backup wurde erstellt. Möchten Sie mit der Deinstallation fortfahren?",
            "Deinstallation fortsetzen", "Abbrechen"
        );
        
        if (!confirmedAfterBackup) return;
        
        // Deinstallation starten
        showProgressModal("Deinstallation wird durchgeführt...");
        const response = await fetch('/api/uninstall/start', { method: 'POST' });
        const data = await response.json();
        
        if (data.success) {
            showSuccessMessage(
                "Deinstallation abgeschlossen", 
                "Die Fotobox wurde erfolgreich deinstalliert."
            );
        } else {
            showErrorMessage(
                "Fehler bei der Deinstallation", 
                data.message || "Ein unbekannter Fehler ist aufgetreten."
            );
        }
    } catch (err) {
        showErrorMessage("Fehler bei der Deinstallation", err.toString());
    }
}
```

### 12.5 Best Practices für die Deinstallation

1. **Immer Backups erstellen**: Vor der Deinstallation immer ein Backup aller wichtigen Daten erstellen
2. **Mehrstufige Bestätigung**: Mindestens zwei Bestätigungsschritte für den Benutzer implementieren
3. **Detaillierte Logs**: Alle Schritte des Deinstallationsprozesses protokollieren
4. **Fehlerbehandlung**: Robuste Fehlerbehandlung für jeden Schritt implementieren
5. **Übersichtliche Kommunikation**: Den Benutzer über jeden Schritt informieren
6. **Cleanup überprüfen**: Nach der Deinstallation verifizieren, dass alle Komponenten entfernt wurden

## 13. Dokumentationsstandards

Das Fotobox2-Projekt folgt klaren Richtlinien bezüglich der Erstellung und Pflege der Dokumentation. Eine gut strukturierte und aktualisierte Dokumentation ist essenziell für die Wartbarkeit und Erweiterbarkeit des Projekts.

### 13.1 Dokumentationsstruktur

Die Dokumentation ist in zwei Hauptdokumente unterteilt:

1. **Benutzerhandbuch**: Richtet sich an Endbenutzer und Administratoren, mit Fokus auf praktische Anwendung
2. **Entwicklerhandbuch**: Für Entwickler mit technischen Details zur Architektur und Implementierung

Ergänzend zu diesen Dokumenten stehen im `policies/`-Ordner detaillierte Entwicklungsrichtlinien zur Verfügung:

```text
policies/
├── policy_backend_api.md        # Richtlinien für Backend-APIs
├── policy_code_structure.md     # Richtlinien zur Codestruktur
├── policy_docs_standards.md     # Standards für Dokumentationen
├── policy_frontend_javascript.md # Richtlinien für Frontend-JavaScript 
└── ...                          # Weitere Richtlinien
```

### 13.2 Dokumentationsformate

Die Dokumentation verwendet durchgängig Markdown als Format und folgt diesen Konventionen:

1. **Dateistruktur**:
   - Jede Markdown-Datei beginnt mit einem H1-Header als Titel
   - Die Gliederung erfolgt durch H2, H3, etc. Header
   - Jede Datei enthält ein Inhaltsverzeichnis mit Links zu den Abschnitten

2. **Formatierungskonventionen**:
   - Code-Beispiele werden in Codeblöcken mit Sprachspezifikation dargestellt
   - Wichtige Informationen werden als Blockquotes formatiert
   - Listen verwenden einheitliche Symbole (Bindestriche für ungeordnete Listen)
   - Datei- und Ordnernamen werden in Backticks gesetzt (`dateiname.js`)
   - Benutzeroberflächen-Elemente werden in **Fettschrift** dargestellt

3. **Versionsangaben**:
   - Jedes Dokument enthält am Ende ein Datum des letzten Updates
   - Wesentliche Änderungen werden im Text gekennzeichnet (z.B. mit "Aktualisiert am")

### 13.3 Dokumentations-Workflow

Bei der Aktualisierung der Dokumentation ist folgender Workflow einzuhalten:

```python
def update_documentation(feature):
    """
    Workflow für Dokumentationsupdates
    """
    # 1. Relevante Dokumente identifizieren
    documents = identify_affected_documents(feature)
    
    # 2. Änderungen im Branch umsetzen
    for doc in documents:
        update_document(doc, feature)
    
    # 3. Review durch mindestens einen weiteren Entwickler
    request_review(documents)
    
    # 4. Nach Genehmigung zusammenführen
    if approved:
        merge_documentation_changes()
        update_version_date(documents)
```

### 13.4 Best Practices für die Dokumentation

1. **Konsistenz**: Einheitliche Terminologie und Formatierung in der gesamten Dokumentation
2. **Aktualität**: Dokumentationen bei Codeänderungen stets mitaktualisieren
3. **Zielgruppenorientierung**: Benutzerhandbuch für Endanwender verständlich halten; technische Details ins Entwicklerhandbuch
4. **Beispiele**: Konkrete Beispiele für komplexe Konzepte anbieten
5. **Screenshots**: Für UI-bezogene Erklärungen Bildschirmfotos mit Markierungen verwenden
6. **Übersicht**: In langen Dokumenten Orientierungshilfen wie Inhaltsverzeichnisse und klare Überschriften verwenden

### 13.5 Verantwortlichkeiten

Die Pflege der Dokumentation folgt dem Prinzip "Wer entwickelt, dokumentiert":

1. Entwickler, die eine neue Funktion implementieren, sind für die entsprechende Dokumentation verantwortlich
2. Technische Dokumentation wird vom Entwicklungsteam gepflegt
3. Benutzerorientierte Dokumentation kann von Entwicklern oder dediziertem Dokumentationspersonal erstellt werden
4. Jährliche umfassende Review der gesamten Dokumentation durch das Team

---

*Dieses Entwicklerhandbuch wird regelmäßig aktualisiert, um Änderungen an der Projektarchitektur und den Best Practices zu reflektieren.*

**Stand:** 16. Juni 2025
