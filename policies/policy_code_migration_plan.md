# Migrationsplan für Code-Strukturierung

Diese Datei enthält eine detaillierte Analyse und einen Migrationsplan für die Umstrukturierung des Frontend-Codes gemäß der neuen Code-Strukturierungs-Policy.

## Aktuelle Struktur vs. Zielstruktur

Die folgende Tabelle zeigt, welche Funktionen aus den aktuellen JavaScript-Dateien in welche neuen Module migriert werden sollen:

| Aktuelle Datei | Funktion | Ziel-Modul |
|---------------|----------|------------|
| `splash.js` | `checkForUpdates()` | `manage_update.js` |
| `splash.js` | `checkPasswordSet()` | `manage_auth.js` |
| `splash.js` | Animationslogik | `splash.js` (bleibt) |
| `install.js` | Passwort-Speicherung | `manage_auth.js` |
| `install.js` | UI-Ereignishandling | `install.js` (bleibt) |
| `settings.js` | `loadSettings()` | `manage_settings.js` |
| `settings.js` | `checkForUpdates()` | `manage_update.js` |
| `settings.js` | `installUpdate()` | `manage_update.js` |
| `settings.js` | UI-Ereignishandling | `settings.js` (bleibt) |
| `settings.js` | `setupPasswordValidation()` | `manage_auth.js` |
| `live-settings-update.js` | `updateSingleSetting()` | `manage_settings.js` |
| `live-settings-update.js` | `validateField()` | `manage_settings.js` |
| `live-settings-update.js` | UI-Feedback (Benachrichtigungen) | `ui_components.js` |
| `live-settings-update.js` | `setupPasswordFieldUpdates()` | `manage_auth.js` |
| `gallery.js` | API-Aufrufe für Bilddaten | `manage_filesystem.js` |
| `gallery.js` | Galerie-UI und Navigation | `gallery.js` (bleibt) |
| `main.js` | Datum/Zeit-Anzeige | `main.js` (bleibt) |
| `main.js` | Menü-Handling | `ui_components.js` |

## Neue Module und ihre Verantwortlichkeiten

### manage_update.js

Verantwortlich für alle Aspekte des Update-Prozesses:
- Update-Prüfung
- Update-Installation
- Version-Vergleich
- Update-Statusanzeige

### manage_auth.js

Zentrale Verwaltung für Authentifizierung und Berechtigungen:
- Passwort-Validierung
- Passwort-Speicherung
- Passwort-Überprüfung
- Login-Status-Management

### manage_settings.js

Verwaltet alle Einstellungen der Anwendung:
- Einstellungen laden
- Einstellungen speichern
- Standardwerte setzen
- Einstellungen validieren

### manage_database.js (Frontend)

Interface für Datenbankoperationen:
- Datenabfragen
- Statusprüfung
- Fehlerbehandlung bei Datenbankzugriffen

### manage_filesystem.js

Zugriff auf Dateisystemoperationen:
- Bilderdateien laden
- Dateien speichern
- Verzeichnisoperationen

### ui_components.js

Gemeinsame UI-Komponenten:
- Benachrichtigungen
- Dialoge
- Menüs
- Fortschrittsanzeigen

## Umsetzungsplan

1. **Phase 1: Module erstellen**
   - Grundlegende Struktur für neue Module anlegen
   - API-Signaturen definieren

2. **Phase 2: Kernfunktionen migrieren**
   - `manage_auth.js` implementieren
   - `manage_update.js` implementieren
   - `manage_settings.js` implementieren

3. **Phase 3: Bestehende Dateien anpassen**
   - Funktionsaufrufe umleiten
   - Doppelte Funktionalität entfernen
   - Tests für neue Struktur schreiben

4. **Phase 4: UI-Komponenten extrahieren**
   - Gemeinsam genutzte UI-Komponenten identifizieren
   - In `ui_components.js` verschieben

5. **Phase 5: Dokumentation und Abschluss**
   - Code-Dokumentation aktualisieren
   - Entwicklerhandbuch erweitern
   - Abschlussprüfung und Konsistenzcheck

## Vorteile der neuen Struktur

1. **Verbesserte Wartbarkeit**
   - Klare Trennung von Verantwortlichkeiten
   - Weniger Codeduplizierung
   - Einfachere Fehlerdiagnose

2. **Effizientere Entwicklung**
   - Modulare Updates möglich
   - Parallele Entwicklung an verschiedenen Modulen
   - Wiederverwendung von Code

3. **Bessere Testbarkeit**
   - Isolierte Testung von Modulen
   - Klare Abhängigkeiten
   - Einfachere Mocktests

4. **Konsistenz mit Backend**
   - Ähnliche Strukturierung zwischen Backend und Frontend
   - Gleiche Benennungskonventionen
   - Vereinfachtes Verständnis der Gesamtarchitektur
