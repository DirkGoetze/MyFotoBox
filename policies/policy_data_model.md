# Datenmodell-Policy

Diese Policy definiert die verbindliche Struktur der Datenbanktabellen und -felder, die in der Fotobox-Anwendung verwendet werden und dient als technische Vorgabe für Entwickler.

## Datenbanktabelle: `settings`

Die Tabelle `settings` speichert alle Konfigurationswerte und Einstellungen der Fotobox-Anwendung in einem Key-Value-Format.

### Schema:

| Spalte   | Typ     | Beschreibung                         |
|----------|---------|--------------------------------------|
| `key`    | TEXT    | Primärschlüssel, Name der Einstellung |
| `value`  | TEXT    | Wert der Einstellung                 |

### Definierte Einstellungsschlüssel:

| Schlüssel (key)       | Beschreibung                                 | Format/Beispiel            | Pflichtfeld |
|-----------------------|----------------------------------------------|----------------------------|-------------|
| `config_password`     | Admin-Passwort (Bcrypt-Hash)                 | Hash                       | Ja          |
| `event_name`          | Name des aktuellen Events                    | Text                       | Nein        |
| `event_date`          | Datum des Events                             | YYYY-MM-DD                 | Nein        |
| `camera_mode`         | Kamera-Modus                                 | "auto", "manual"          | Ja          |
| `resolution_width`    | Bildbreite in Pixeln                        | Numerisch (z.B. 1920)     | Ja          |
| `resolution_height`   | Bildhöhe in Pixeln                          | Numerisch (z.B. 1080)     | Ja          |
| `storage_path`        | Pfad für die Fotospeicherung                | Pfad                      | Ja          |
| `show_splash`         | Ob der Splashscreen angezeigt werden soll    | "0" (aus) oder "1" (an)  | Ja          |
| `photo_timer`         | Countdown vor der Fotoaufnahme in Sekunden   | Numerisch (z.B. 5)       | Ja          |
| `gallery_timeout_ms`  | Timeout für die Galerie in Millisekunden     | Numerisch (z.B. 60000)   | Ja          |
| `color_mode`          | Farbschema der Weboberfläche                | "auto", "light", "dark"   | Ja          |

## SQL-Initialisierung

Die Datenbank `fotobox_settings.db` wird im Verzeichnis `data/` gespeichert. Sie muss mit folgendem SQL-Befehl initialisiert werden:

```sql
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY, 
    value TEXT
);
```

Die Initialisierung erfolgt beim ersten Start der Anwendung oder explizit durch das Skript `manage_database.py`.

## Zugriffsmethoden

Der Zugriff auf die Datenbank darf ausschließlich über folgende Methoden erfolgen:

1. Über die API-Endpunkte `/api/settings` (GET/POST)
2. Über die Python-Funktionen in `manage_database.py`

Direkte SQL-Queries außerhalb dieser Methoden sind zu vermeiden.

## Standardwerte

Folgende Standardwerte müssen beim ersten Start gesetzt werden:

```python
default_settings = {
    'camera_mode': 'auto',
    'resolution_width': '1920',
    'resolution_height': '1080',
    'storage_path': './photos',
    'show_splash': '1',
    'photo_timer': '5',
    'gallery_timeout_ms': '60000',
    'color_mode': 'auto'
}
```

## Validierungsregeln

- `config_password`: Muss als Bcrypt-Hash gespeichert werden, niemals im Klartext
- `event_date`: Muss ein gültiges Datum im Format YYYY-MM-DD sein
- `resolution_width`, `resolution_height`: Müssen positive Zahlen sein
- `photo_timer`: Muss eine positive Zahl zwischen 1 und 10 sein
- `gallery_timeout_ms`: Muss mindestens 5000 (5 Sekunden) sein

## Codebeispiel für die Implementierung

```python
import sqlite3
import os
import bcrypt

DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')

# Stelle sicher, dass das Verzeichnis existiert
os.makedirs(DB_DIR, exist_ok=True)

def get_setting(key, default=None):
    """Holt einen Einstellungswert aus der Datenbank"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    cursor.execute("SELECT value FROM settings WHERE key=?", (key,))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else default

def set_setting(key, value):
    """Speichert einen Einstellungswert in der Datenbank"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    cursor.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (key, str(value)))
    conn.commit()
    conn.close()
    return True

def check_password(password):
    """Prüft, ob ein Passwort mit dem gespeicherten Hash übereinstimmt"""
    hash_from_db = get_setting('config_password')
    if not hash_from_db:
        return False
    return bcrypt.checkpw(password.encode(), hash_from_db.encode())
```

**Stand:** 10. Juni 2025

Diese Datenmodell-Policy ist verbindlich für alle Backend-Entwicklungen am Fotobox-Projekt.
