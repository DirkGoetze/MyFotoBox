# Datenbankverwaltung in Fotobox2

Diese Dokumentation beschreibt die Datenbankverwaltungsfunktionen in der Fotobox2-Anwendung.

## Übersicht

Das Datenbank-Management-System von Fotobox2 besteht aus zwei Hauptkomponenten:

1. **Backend**: `manage_database.py` - Zentrale Verwaltung aller Datenbankaktivitäten
2. **Frontend**: `manage_database.js` - JavaScript-Schnittstelle zur Kommunikation mit dem Backend

Das System verwendet eine SQLite-Datenbank und bietet Funktionen für:

- Initialisierung und Migration der Datenbank
- CRUD-Operationen (Create, Read, Update, Delete)
- Einstellungsverwaltung
- Integrität und Optimierung

> **Aktualisiert am 12.06.2025**: Beide Module wurden vollständig implementiert und in den Code-Migrationsprozess integriert. Die Module bieten nun eine einheitliche Schnittstelle für alle Datenbankoperationen.

## Datenbank-Struktur

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

## Backend-API (`manage_database.py`)

### Verbindungsverwaltung

- `connect_db()`: Stellt Verbindung zur Datenbank her

### Verwaltungsfunktionen

- `init_db()`: Initialisiert die Datenbankstruktur
- `migrate_db()`: Führt Datenbankmigrationen durch
- `cleanup_db()`: Bereinigt temporäre oder alte Daten
- `optimize_db()`: Optimiert die Datenbankstruktur

### CRUD-Operationen

- `query(sql, params=None)`: Führt eine SQL-Abfrage aus
- `insert(table, data)`: Fügt Daten in eine Tabelle ein
- `update(table, data, condition, params=None)`: Aktualisiert Daten
- `delete(table, condition, params=None)`: Löscht Daten

### Einstellungsverwaltung

- `get_setting(key, default=None)`: Holt eine Einstellung
- `set_setting(key, value)`: Speichert eine Einstellung

### Integritätsprüfung

- `check_integrity()`: Überprüft die Datenbankintegrität

## Frontend-API (`manage_database.js`)

Das Frontend-Modul bietet eine asynchrone Schnittstelle zum Backend:

### Grundoperationen

- `query(sql, params = null)`: Führt eine SQL-Abfrage aus
- `insert(table, data)`: Fügt Datensätze ein
- `update(table, data, condition, params = null)`: Aktualisiert Datensätze
- `remove(table, condition, params = null)`: Entfernt Datensätze

### Frontend-Einstellungsverwaltung

- `getSetting(key, defaultValue = null)`: Holt eine Einstellung mit Fallback-Wert
- `setSetting(key, value)`: Speichert eine Einstellung

### Systemfunktionen

- `checkIntegrity()`: Überprüft die Datenbankintegrität
- `getStats()`: Holt Statistiken zur Datenbanknutzung

## REST-API-Endpunkte

Die Kommunikation zwischen Frontend und Backend erfolgt über REST-API-Endpunkte:

- `POST /api/database/query`: Führt eine Datenbankabfrage aus
- `POST /api/database/insert`: Fügt einen Datensatz ein
- `POST /api/database/update`: Aktualisiert einen Datensatz
- `POST /api/database/delete`: Löscht einen Datensatz
- `GET /api/database/settings/{key}`: Liest eine Einstellung
- `POST /api/database/settings`: Speichert eine Einstellung
- `GET /api/database/check-integrity`: Überprüft die Datenbankintegrität
- `GET /api/database/stats`: Holt Datenbankstatistiken

## Beispiele

### Backend-Beispiel

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

### Frontend-Beispiel

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

## Sicherheit

- Alle API-Endpunkte erfordern Authentifizierung (`@manage_auth.require_auth`)
- SQL-Injection-Prävention durch Parameterisierung
- Beschränkter Zugriff für Nicht-Admin-Benutzer auf bestimmte Operationen

## Fehlerbehebung

1. **Verbindungsfehler**: Stellen Sie sicher, dass das `data/`-Verzeichnis existiert und Schreibrechte hat
2. **Integritätsfehler**: Führen Sie `manage_database.py check` aus und anschließend `manage_database.py optimize`
3. **Fehlende Tabellen**: Führen Sie `manage_database.py init` aus

## Best Practices

1. Vermeiden Sie direkte SQL-Abfragen im Frontend; nutzen Sie stattdessen die Hilfsfunktionen
2. Verwenden Sie Transaktionen für zusammenhängende Operationen
3. Führen Sie regelmäßig Optimierungen durch (`optimize_db()`)
4. Validieren Sie Eingabedaten, bevor sie in die Datenbank geschrieben werden

## Zukünftige Erweiterungen

- Transaktionsunterstützung
- Erweitertes Schema-Migrations-System
- Backup- und Restore-Funktionen

## Entwicklungshinweise

> **WICHTIG**: Die Datenbankmodule wurden für Entwicklung ohne Live-System konzipiert. Gemäß der `policy_development_testing.md` erfolgt die Entwicklung ohne Zugriff auf laufende Instanzen oder Datenbanken. Verwenden Sie die bereitgestellten Mock-Funktionen für alle Tests.

Bei der Entwicklung von Features, die mit der Datenbank interagieren:

1. Erzeugen Sie Mock-Antworten für alle API-Aufrufe
2. Implementieren Sie Unit-Tests mit vordefinierten Test-Datensätzen
3. Dokumentieren Sie alle vorausgesetzten Datenstrukturen

## Aktueller Implementierungsstatus

| Komponente | Status | Hinweise |
|------------|--------|----------|
| Backend API | ✅ Vollständig | Alle Grundfunktionen implementiert |
| Frontend API | ✅ Vollständig | Unterstützt Mock-Daten im Test-Modus |
| REST-Endpunkte | ✅ Vollständig | Alle benötigten Endpunkte verfügbar |

---

Letzte Aktualisierung: 12.06.2025
