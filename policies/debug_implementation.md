# Anleitung zur Implementierung des Debug-Modus in Fotobox-Skripten

## Übersicht

Diese Anleitung beschreibt, wie der Debug-Modus in allen `manage_*.sh` Skripten konsequent umgesetzt werden soll.

## Grundsätzliches Konzept

- Die zentralen Debug-Flags (`DEBUG_MOD_LOCAL` und `DEBUG_MOD_GLOBAL`) sind in `lib_core.sh` definiert
- Jedes Skript definiert sein eigenes lokales `DEBUG_MOD_LOCAL`, das nur für dieses Skript gilt
- `DEBUG_MOD_GLOBAL` überstimmt alle lokalen Einstellungen und aktiviert den Debug-Modus in allen Skripten
- Die eigentliche Debug-Ausgabe erfolgt über die Funktionen in `manage_logging.sh`

## Implementierungsschritte für jedes manage_*.sh Skript

### 1. Lokales Debug-Flag definieren

Fügen Sie nach dem Laden von `lib_core.sh` und vor den Hauptfunktionen die lokale Debug-Variable hinzu:

```bash
# Debug-Modus für dieses Skript (lokales Flag)
# Die globalen Debug-Flags werden in lib_core.sh definiert
DEBUG_MOD_LOCAL=0  # Nur für dieses Skript
```

### 2. Debug-Ausgaben anpassen

Ersetzen Sie alle Vorkommnisse von:

```bash
[ "$DEBUG_MOD" = "1" ] && print_debug "Debug-Nachricht"
```

durch:

```bash
if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
    print_debug "Debug-Nachricht"
fi
```

### 3. Kommandozeilenparameter anpassen

Falls Ihr Skript einen `--debug`-Parameter hat, sollte dieser `DEBUG_MOD_LOCAL` statt `DEBUG_MOD` setzen:

```bash
--debug|-d)
    DEBUG_MOD_LOCAL=1
    shift
    ;;
```

## Verwendung der Debug-Funktionen

### Für einfache Debug-Ausgaben

```bash
if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
    print_debug "Debug-Nachricht"
fi
```

### Für erweiterte Debug-Funktionalität

Verwenden Sie die `debug`-Funktion aus `manage_logging.sh`:

```bash
debug "Detaillierte Debug-Nachricht" "CLI" "funktionsname"
```

## Debug-Modi aktivieren

### Lokalen Debug-Modus aktivieren

```bash
DEBUG_MOD_LOCAL=1 ./script.sh
```

### Globalen Debug-Modus aktivieren (für alle Skripte)

```bash
DEBUG_MOD_GLOBAL=1 ./script.sh
```

## Beispiele

### Beispiel für korrekten Debug-Check

```bash
if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
    print_debug "Port: $port, Host: $host"
fi
```

### Beispiel für die Verwendung der debug-Funktion

```bash
debug "Verarbeite Datei: $file" "CLI"
```
