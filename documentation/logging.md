# Logging-System der Fotobox2

Das Logging-System der Fotobox2 bietet eine zentrale Möglichkeit, Ereignisse, Fehler und Debugging-Informationen zu protokollieren und zu speichern.

## Übersicht

Das Logging-System besteht aus zwei Hauptkomponenten:

1. **Backend-Logging** (`manage_logging.py`): Protokolliert Server-seitige Ereignisse in Dateien und in einer SQLite-Datenbank
2. **Frontend-Logging** (`manage_logging.js`): Ermöglicht das Logging von Client-Ereignissen, die an den Server gesendet werden

## Log-Levels

Das System unterstützt vier Standard-Log-Levels:

- **DEBUG**: Detaillierte Informationen, nützlich für die Fehlersuche
- **INFO**: Allgemeine Informationen über den normalen Betriebsablauf
- **WARN** / **WARNING**: Warnungen über mögliche Probleme, die keine unmittelbare Aktion erfordern
- **ERROR**: Fehler, die eine Funktionalität beeinträchtigen können

## Verwendung im Code

### Backend (Python)

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

### Frontend (JavaScript)

Das Frontend-Logging ist so konfiguriert, dass es Logs sowohl in der Browser-Konsole als auch an den Server sendet:

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

## Zugriff auf Logs

### Log-Dateien

Die Log-Dateien werden im Verzeichnis `/opt/fotobox/log` oder alternativ in `/var/log/fotobox` (falls `/opt/fotobox/log` nicht beschreibbar ist) gespeichert:

- `YYYY-MM-DD_fotobox.log`: Allgemeine Logs
- `fotobox_debug.log`: Detaillierte Debug-Logs

### Log-Rotation

Die Log-Dateien werden täglich rotiert und komprimiert:

- Aktuelle Logs: `YYYY-MM-DD_fotobox.log`
- Ältere Logs: `YYYY-MM-DD_fotobox.log.1`, `YYYY-MM-DD_fotobox.log.2.gz`, usw.

Es werden maximal 5 rotierte Log-Dateien aufbewahrt.

### Datenbank-Logs

Alle Logs werden auch in einer SQLite-Datenbank gespeichert:

- Pfad: `/opt/fotobox/data/fotobox_logs.db`
- Tabelle: `logs`

## Log-Analyse

Für IT-Personal stehen mehrere Möglichkeiten zur Analyse der Logs zur Verfügung:

1. **Direkte Dateianalyse**:

   ```bash
   # Aktuelle Logs ansehen
   tail -f /opt/fotobox/log/$(date +%Y-%m-%d)_fotobox.log
   
   # Fehler in den Logs suchen
   grep ERROR /opt/fotobox/log/$(date +%Y-%m-%d)_fotobox.log
   ```

2. **Datenbank-Abfrage**:

   ```bash
   # SQLite-Konsole öffnen
   sqlite3 /opt/fotobox/data/fotobox_logs.db
   
   # Letzte 20 Fehler-Logs abfragen
   SELECT timestamp, message, context FROM logs WHERE level='ERROR' ORDER BY timestamp DESC LIMIT 20;
   ```

## Hinweise

- Bei Speicherplatzproblemen sollte man regelmäßig alte Logs löschen
- Die Debug-Logs enthalten detailliertere Informationen und können bei Problemdiagnosen hilfreich sein
- In produktiven Umgebungen ist das Log-Level standardmäßig auf INFO gesetzt
