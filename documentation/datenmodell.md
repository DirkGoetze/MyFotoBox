# Datenmodell der Fotobox

Dieses Dokument beschreibt die Struktur der Datenbanktabellen und -felder, die in der Fotobox-Anwendung verwendet werden.

## Datenbanktabelle: `settings`

Die Tabelle `settings` speichert alle Konfigurationswerte und Einstellungen der Fotobox-Anwendung in einem Key-Value-Format.

### Schema:

| Spalte   | Typ     | Beschreibung                         |
|----------|---------|--------------------------------------|
| `key`    | TEXT    | Primärschlüssel, Name der Einstellung |
| `value`  | TEXT    | Wert der Einstellung                 |

### Wichtige Einstellungsschlüssel:

| Schlüssel (key)       | Beschreibung                                 | Format/Beispiel            |
|-----------------------|----------------------------------------------|----------------------------|
| `config_password`     | Admin-Passwort (Bcrypt-Hash)                 | Hash                       |
| `event_name`          | Name des aktuellen Events                    | Text                       |
| `event_date`          | Datum des Events                             | YYYY-MM-DD                 |
| `camera_mode`         | Kamera-Modus                                 | "auto", "manual"          |
| `resolution_width`    | Bildbreite in Pixeln                        | Numerisch (z.B. 1920)     |
| `resolution_height`   | Bildhöhe in Pixeln                          | Numerisch (z.B. 1080)     |
| `storage_path`        | Pfad für die Fotospeicherung                | Pfad                      |
| `show_splash`         | Ob der Splashscreen angezeigt werden soll    | "0" (aus) oder "1" (an)  |
| `photo_timer`         | Countdown vor der Fotoaufnahme in Sekunden   | Numerisch (z.B. 5)       |
| `gallery_timeout_ms`  | Timeout für die Galerie in Millisekunden     | Numerisch (z.B. 60000)   |
| `color_mode`          | Farbschema der Weboberfläche                | "auto", "light", "dark"   |

## SQLite-Datenbank

Die Datenbank `fotobox_settings.db` wird im Verzeichnis `data/` gespeichert und enthält die oben beschriebene Tabelle. Sie wird automatisch erstellt, wenn sie noch nicht vorhanden ist.

## Codebeispiel zur Datenbankinitialisierung:

```python
import sqlite3
import os

DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')

# Stelle sicher, dass das Verzeichnis existiert
os.makedirs(DB_DIR, exist_ok=True)

# Verbindung zur Datenbank herstellen und Tabelle erstellen
conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
conn.commit()
conn.close()
```

**Stand:** 10. Juni 2025
