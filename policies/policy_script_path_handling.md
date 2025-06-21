# Richtlinie zur Pfadverwaltung in Shell-Skripten

## Zentrale Definition von Skriptpfadbestimmung

Um Konsistenz und Robustheit in unseren Shell-Skripten zu gewährleisten, wird die folgende Richtlinie für die Verwaltung von Skriptpfaden eingeführt:

### Grundprinzipien

1. **Zentrale Definition**: Die Variable `SCRIPT_DIR` wird ausschließlich in `lib_core.sh` definiert und von allen anderen Skripten importiert.

   ```bash
   # In lib_core.sh:
   SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
   ```

2. **Keine lokalen Überschreibungen**: Module dürfen `SCRIPT_DIR` nicht lokal neu definieren oder überschreiben.

3. **BASH_DIR entfernt**: Die früher parallel verwendete Variable `BASH_DIR` wurde entfernt und alle Referenzen auf `SCRIPT_DIR` umgestellt.

### Verwendung in Modulen

- Alle Module müssen `lib_core.sh` laden, bevor sie `SCRIPT_DIR` verwenden.
- Ressourcenpfade sollen mit `$SCRIPT_DIR/...` definiert werden.
- Für Pfadoperationen sollte, wenn möglich, die Funktion `get_script_dir()` aus `manage_folders.sh` verwendet werden.

### Beispielverwendung

```bash
# RICHTIG:
source "$SCRIPT_DIR/lib_core.sh"
config_file="$SCRIPT_DIR/config/settings.conf"

# FALSCH (nicht neu definieren):
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"  # Dies ist NICHT erlaubt
```

### Testumgebungen

In Test-Skripten, die mehrere Module laden, sollten lokale Testumgebungsvariablen mit einem `TEST_`-Präfix verwendet werden, um Kollisionen mit den in Modulen verwendeten Variablen zu vermeiden:

```bash
# In test_modules.sh:
TEST_SCRIPT_DIR="/path/to/scripts"
export SCRIPT_DIR="$TEST_SCRIPT_DIR"  # Für das initiale Laden von lib_core.sh
```

## Hintergrund und Begründung

Diese Richtlinie wurde eingeführt, um:

- Doppelte und widersprüchliche Definitionen von Skriptpfaden zu vermeiden
- Die Robustheit des Modulsystems zu verbessern
- Konsistenz über verschiedene Ausführungsumgebungen hinweg zu gewährleisten
- Abhängigkeiten zwischen Modulen zu reduzieren
