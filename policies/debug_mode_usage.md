# Verwendung des Debug-Modus im Fotobox2-Projekt

Diese Dokumentation beschreibt, wie der Debug-Modus in Fotobox2 für Entwickler und Systemadministratoren verwendet werden kann.

## Übersicht

Das Fotobox2-Projekt verwendet ein zweistufiges Debug-System:

1. **Lokales Debug**: Spezifisch für ein einzelnes Skript
2. **Globales Debug**: Aktiviert den Debug-Modus in allen Skripten

## Aktivierung des Debug-Modus

### Lokalen Debug-Modus aktivieren

Um den Debug-Modus nur für ein bestimmtes Skript zu aktivieren:

```bash
# Methode 1: Als Umgebungsvariable
DEBUG_MOD_LOCAL=1 ./manage_script.sh

# Methode 2: Mit Parameter (falls vom Skript unterstützt)
./manage_script.sh --debug
```

### Globalen Debug-Modus aktivieren

Um das Debugging systemweit zu aktivieren:

```bash
# Aktiviert Debug-Ausgaben in allen Skripten
DEBUG_MOD_GLOBAL=1 ./manage_script.sh
```

## Debug-Ausgabetypen

Die Fotobox2-Skripte bieten verschiedene Arten von Debug-Ausgaben:

1. **Standard Debug-Ausgaben**: Grundlegende Informationen zu Skript-Operationen
2. **Erweiterte Debug-Ausgaben**: Detaillierte Informationen, Variablenwerte, etc.

### Beispiele für Debug-Ausgaben

```bash
DEBUG: Lade Datei von: /opt/fotobox/data/photo_123.jpg
DEBUG: NGINX Status: running (PID: 1234)
DEBUG: SQL-Abfrage: "SELECT * FROM photos WHERE id=123"
DEBUG: Port: 80, Host: localhost, TLS: aktiviert
```

## Protokollierung von Debug-Informationen

Sie können Debug-Ausgaben in einer Datei speichern:

```bash
DEBUG_MOD_GLOBAL=1 ./install.sh > debug_output.log 2>&1
```

## Häufige Anwendungsfälle

### Fehlerdiagnose bei der Installation

```bash
DEBUG_MOD_GLOBAL=1 ./install.sh
```

### Netzwerk-Konfiguration überprüfen

```bash
DEBUG_MOD_LOCAL=1 ./backend/scripts/manage_nginx.sh --check-config
```

### Firewall-Einstellungen überprüfen

```bash
DEBUG_MOD_LOCAL=1 ./backend/scripts/manage_firewall.sh --status
```

### Python-Umgebung diagnostizieren

```bash
DEBUG_MOD_LOCAL=1 ./backend/scripts/manage_python_env.sh --check
```

## Kombination mit anderen Tools

Der Debug-Modus kann mit anderen Diagnose-Tools kombiniert werden:

```bash
# Debug + Verbose-Modus
DEBUG_MOD_GLOBAL=1 VERBOSE=1 ./install.sh

# Debug + Tracing
DEBUG_MOD_GLOBAL=1 bash -x ./install.sh
```

## Für Entwickler

Wenn Sie neue Funktionen zum Fotobox2-Projekt hinzufügen, beachten Sie diese Debug-Mode-Richtlinien:

1. Fügen Sie Debug-Ausgaben für alle wichtigen Operationen hinzu
2. Verwenden Sie das standardisierte Debug-Pattern:

   ```bash
   if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
       print_debug "Ihre Debug-Nachricht hier"
   fi
   ```

3. Testen Sie Ihre Funktionalität mit aktiviertem Debug-Modus

## Häufige Probleme und Lösungen

1. **Keine Debug-Ausgaben trotz aktiviertem Debug-Modus**
   - Überprüfen Sie, dass das Skript das standardisierte Debug-Pattern verwendet
   - Stellen Sie sicher, dass die Umgebungsvariablen korrekt gesetzt sind

2. **Zu viele Debug-Ausgaben**
   - Verwenden Sie gezielt den lokalen Debug-Modus statt des globalen Modus
   - Filtern Sie die Ausgabe: `DEBUG_MOD_GLOBAL=1 ./script.sh | grep 'NGINX'`

3. **Debug-Ausgaben in Produktionsumgebung**
   - Stellen Sie sicher, dass der Debug-Modus in Produktionssystemen deaktiviert ist
   - Überprüfen Sie mit `env | grep DEBUG` ob Debug-Variablen gesetzt sind

## Siehe auch

- [Debug-Implementierung](./debug_implementation.md) - Details zur technischen Implementierung
- [Logging-System](../documentation/entwicklerhandbuch.md#10-logging-system) - Informationen zum Logging-System
