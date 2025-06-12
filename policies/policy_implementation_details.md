# Detaillierte Implementierungsrichtlinie für Fotobox2

Dieses Dokument erweitert die bestehende Code-Strukturierungs-Policy mit konkreten Implementierungsrichtlinien für jedes Modul. Es dient als Referenz für Entwickler bei der Umsetzung der neuen Struktur.

## Systemmodule (`manage_*`)

### manage_update.js / manage_update.py

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `checkForUpdates()` | Prüft auf verfügbare Updates | `Promise<UpdateInfo>` |
| `getUpdateStatus()` | Liefert aktuellen Update-Status | `Promise<StatusObject>` |
| `installUpdate()` | Installiert verfügbares Update | `Promise<boolean>` |
| `rollbackUpdate()` | Setzt fehlgeschlagenes Update zurück | `Promise<boolean>` |
| `getVersionInfo()` | Liefert Informationen zur aktuellen Version | `VersionInfo` |
| `scheduleUpdate()` | Plant automatisches Update | `Promise<boolean>` |

### manage_auth.js / manage_auth.py

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `isPasswordSet()` | Prüft, ob ein Passwort gesetzt ist | `Promise<boolean>` |
| `validatePassword()` | Validiert eingegebenes Passwort | `Promise<boolean>` |
| `setPassword()` | Setzt neues Passwort | `Promise<boolean>` |
| `changePassword()` | Ändert bestehendes Passwort | `Promise<boolean>` |
| `getLoginStatus()` | Gibt aktuellen Login-Status zurück | `Promise<StatusObject>` |
| `logout()` | Meldet Benutzer ab | `Promise<void>` |

### manage_settings.js / manage_settings.py

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `loadSettings()` | Lädt alle Einstellungen | `Promise<SettingsObject>` |
| `loadSingleSetting()` | Lädt eine einzelne Einstellung | `Promise<any>` |
| `updateSettings()` | Aktualisiert mehrere Einstellungen | `Promise<boolean>` |
| `updateSingleSetting()` | Aktualisiert eine einzelne Einstellung | `Promise<boolean>` |
| `validateSettings()` | Validiert Einstellungen | `Promise<ValidationResult>` |
| `resetToDefaults()` | Setzt Einstellungen auf Standardwerte zurück | `Promise<boolean>` |

### manage_database.js / manage_database.py

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `connect()` | Stellt Verbindung zur Datenbank her | `Promise<Connection>` |
| `query()` | Führt Abfrage aus | `Promise<QueryResult>` |
| `insert()` | Fügt Daten ein | `Promise<InsertResult>` |
| `update()` | Aktualisiert Daten | `Promise<UpdateResult>` |
| `delete()` | Löscht Daten | `Promise<DeleteResult>` |
| `checkIntegrity()` | Prüft Datenbankintegrität | `Promise<IntegrityResult>` |

### manage_filesystem.js / manage_files.py

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `getImageList()` | Ruft Liste der Bilder ab | `Promise<ImageList>` |
| `saveImage()` | Speichert ein Bild | `Promise<SaveResult>` |
| `deleteImage()` | Löscht ein Bild | `Promise<boolean>` |
| `getFileInfo()` | Liefert Metadaten zu einer Datei | `Promise<FileInfo>` |
| `createDirectory()` | Erstellt ein Verzeichnis | `Promise<boolean>` |
| `checkDiskSpace()` | Prüft verfügbaren Speicherplatz | `Promise<SpaceInfo>` |

### manage_logging.js / manage_logging.py

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `log()` | Loggt eine Nachricht | `void` |
| `error()` | Loggt einen Fehler | `void` |
| `warn()` | Loggt eine Warnung | `void` |
| `debug()` | Loggt Debug-Informationen | `void` |
| `getLogs()` | Ruft Logs ab | `Promise<LogEntries>` |
| `clearLogs()` | Löscht Logs | `Promise<boolean>` |

### manage_api.js

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `apiGet()` | GET-Request an Backend | `Promise<Response>` |
| `apiPost()` | POST-Request an Backend | `Promise<Response>` |
| `apiPut()` | PUT-Request an Backend | `Promise<Response>` |
| `apiDelete()` | DELETE-Request an Backend | `Promise<Response>` |
| `handleApiError()` | Fehlerbehandlung für API-Aufrufe | `Promise<void>` |
| `setApiBaseUrl()` | Setzt Basis-URL für API | `void` |

### manage_camera.js / manage_camera.py

| Funktionalität | Beschreibung | Schnittstelle |
|----------------|-------------|--------------|
| `initCamera()` | Initialisiert Kamera | `Promise<CameraStatus>` |
| `takePhoto()` | Nimmt ein Foto auf | `Promise<PhotoResult>` |
| `getPreview()` | Liefert Kamera-Vorschau | `Stream` |
| `applyCameraSettings()` | Wendet Kameraeinstellungen an | `Promise<boolean>` |
| `getCameraStatus()` | Ruft Kamerastatus ab | `Promise<CameraStatus>` |
| `closeCameraSession()` | Schließt Kamerasession | `Promise<boolean>` |

## Seitenspezifische Module

### index.js

| Funktionalität | Beschreibung |
|----------------|-------------|
| `initStartPage()` | Initialisiert Startseite |
| `setupEventListeners()` | Richtet Event-Listener ein |
| `handleNavigation()` | Behandelt Navigation |
| `updateStatusIndicators()` | Aktualisiert Statusindikatoren |

### gallery.js

| Funktionalität | Beschreibung |
|----------------|-------------|
| `initGallery()` | Initialisiert Galerie |
| `displayImages()` | Zeigt Bilder an |
| `setupGalleryNavigation()` | Richtet Galerienavigation ein |
| `handleImageSelection()` | Behandelt Bildauswahl |
| `applyImageFilters()` | Wendet Bildfilter an |

### settings.js

| Funktionalität | Beschreibung |
|----------------|-------------|
| `initSettingsUI()` | Initialisiert Einstellungs-UI |
| `bindSettingsEvents()` | Bindet Ereignisse für Einstellungen |
| `updateSettingsDisplay()` | Aktualisiert Einstellungsanzeige |
| `validateSettingsInput()` | Validiert Einstellungseingaben |

### install.js

| Funktionalität | Beschreibung |
|----------------|-------------|
| `initInstallUI()` | Initialisiert Installations-UI |
| `displayInstallSteps()` | Zeigt Installationsschritte an |
| `handleInstallProgress()` | Behandelt Installationsfortschritt |
| `finalizeInstallation()` | Schließt Installation ab |

### capture.js

| Funktionalität | Beschreibung |
|----------------|-------------|
| `initCaptureInterface()` | Initialisiert Aufnahme-Interface |
| `setupCaptureButtons()` | Richtet Aufnahme-Buttons ein |
| `displayCountdown()` | Zeigt Countdown an |
| `showCapturePreview()` | Zeigt Aufnahmevorschau an |
| `applyImageEffects()` | Wendet Bildeffekte an |

## Gemeinsam genutzte Module

### ui_components.js

| Funktionalität | Beschreibung |
|----------------|-------------|
| `showNotification()` | Zeigt Benachrichtigung an |
| `showDialog()` | Zeigt Dialog an |
| `createProgressBar()` | Erstellt Fortschrittsbalken |
| `createToggleSwitch()` | Erstellt Umschalter |
| `createTabInterface()` | Erstellt Tab-Interface |

### utils.js

| Funktionalität | Beschreibung |
|----------------|-------------|
| `formatDate()` | Formatiert Datum |
| `debounce()` | Verzögert Funktionsaufrufe |
| `throttle()` | Drosselt Funktionsaufrufe |
| `parseQueryString()` | Analysiert Query-String |
| `generateUUID()` | Generiert UUID |

## Implementierungsrichtlinien

1. **Modulare Struktur**: Jedes Modul sollte eine klare Verantwortlichkeit haben und nur verwandte Funktionalitäten enthalten.

2. **Asynchrone Kommunikation**: Alle Funktionen, die mit dem Backend kommunizieren, sollten Promises zurückgeben und asynchron sein.

3. **Fehlerbehandlung**: Jedes Modul sollte seine Fehler angemessen behandeln und gegebenenfalls an den Aufrufer weitergeben.

4. **Dokumentation**: Jede Funktion sollte mit JSDoc (Frontend) bzw. Docstrings (Backend) dokumentiert werden.

5. **Tests**: Für jedes Modul sollten Unit-Tests geschrieben werden, die alle öffentlichen Funktionen abdecken.

6. **Konsistenter Stil**: Der Kodierungsstil sollte im gesamten Projekt konsistent sein. Verwenden Sie ESLint für JavaScript und einen entsprechenden Linter für Python.

## Abhängigkeitsstruktur

```
Frontend:
└── Seitenspezifische Module (index.js, gallery.js, ...)
    └── UI-Komponenten (ui_components.js)
    └── Systemmodule (manage_*.js)
        └── API-Modul (manage_api.js)
            └── Backend-Kommunikation

Backend:
└── API-Endpoints
    └── Systemmodule (manage_*.py)
        └── Datenbankzugriff (manage_database.py)
        └── Dateisystem (manage_files.py)
```

Diese Implementierungsrichtlinie dient als detaillierte Referenz für die Entwicklung und Migration des Fotobox2-Projekts gemäß der Code-Strukturierungs-Policy.
