# Dokumentation: Hybrider Ladeansatz für Shell-Module

## Übersicht

Dieses Dokument beschreibt den hybriden Ladeansatz für Shell-Module im Fotobox2-Projekt, der ab Juni 2025 implementiert wurde. Der Ansatz optimiert die Ressourcennutzung und Stabilität der Shell-Skripte je nach Ausführungskontext.

## Lademodi

Das System unterstützt zwei Lademodi, die durch die Variable `MODULE_LOAD_MODE` gesteuert werden:

- **Modus 0 (Default)**: Module werden bei Bedarf einzeln geladen (für laufenden Webserver-Betrieb)
- **Modus 1**: Alle Module werden sofort geladen (für Installation/Update/Deinstallation)

## Funktionsweise

### Zentrale Steuerung durch lib_core.sh

Die `lib_core.sh` ist das Herzstück des Modulsystems und stellt folgende Funktionen bereit:

- `bind_resource`: Bindet eine einzelne Ressource ein (mit Schutz vor rekursiven Aufrufen)
- `load_core_resources`: Lädt alle Kernressourcen auf einmal
- `load_module`: Lädt ein spezifisches Modul oder alle Module (abhängig vom MODULE_LOAD_MODE)

### Verwendung in Modulen

Module sollten nach diesem Muster aufgebaut sein:

```bash
#!/bin/bash
# Guard für dieses Management-Skript
MANAGE_MODULNAME_LOADED=0

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

# Lade alle Basis-Ressourcen
if [ ! -f "$BASH_DIR/lib_core.sh" ]; then
    echo "KRITISCHER FEHLER: Zentrale Bibliothek lib_core.sh nicht gefunden!" >&2
    exit 1
fi

source "$BASH_DIR/lib_core.sh"

# Hybrides Ladeverhalten
if [ "${MODULE_LOAD_MODE:-0}" -eq 1 ]; then
    # Bei Installation/Update alle Module laden
    load_core_resources || {
        echo "KRITISCHER FEHLER: Die Kernressourcen konnten nicht geladen werden." >&2
        exit 1
    }
else
    # Im normalen Betrieb nur benötigte Module laden
    load_module "modul1" || { echo "Fehler beim Laden von modul1"; exit 1; }
    load_module "modul2" || { echo "Fehler beim Laden von modul2"; exit 1; }
    # ...usw.
fi

# ... Modulcode ...

# Markiere dieses Modul als geladen
MANAGE_MODULNAME_LOADED=1
```

### Python-Integration

Python-Skripte, die auf Shell-Module zugreifen, sollten in `app.py` oder anderen Backend-Skripten so konfiguriert werden:

```python
import os
import subprocess

def call_bash_function(module_name, function_name, *args):
    """
    Ruft eine Bash-Funktion aus einem Modul auf
    
    Args:
        module_name: Name des Moduls ohne .sh (z.B. "manage_folders")
        function_name: Name der aufzurufenden Funktion
        *args: Argumente für die Funktion
    """
    # Für normale Webserver-Operationen verwenden wir den Einzelladevorgänge
    bash_cmd = f"source /opt/fotobox/backend/scripts/lib_core.sh && " \
               f"load_module {module_name} && {function_name} {' '.join(args)}"
               
    result = subprocess.run(['bash', '-c', bash_cmd], 
                           capture_output=True, text=True)
    return result.stdout.strip()

def call_bash_function_install_mode(module_name, function_name, *args):
    """
    Ruft eine Bash-Funktion im Installations-/Update-Modus auf
    
    Für Installations-, Update- oder Deinstallationsoperationen
    """
    bash_cmd = f"export MODULE_LOAD_MODE=1 && " \
               f"source /opt/fotobox/backend/scripts/lib_core.sh && " \
               f"load_module {module_name} && {function_name} {' '.join(args)}"
               
    result = subprocess.run(['bash', '-c', bash_cmd], 
                           capture_output=True, text=True)
    return result.stdout.strip()
```

## Vorteile dieses Ansatzes

1. **Optimale Performance**:
   - Im laufenden Webserver-Betrieb werden nur die tatsächlich benötigten Module geladen
   - Nach Beendigung des Python-Prozesses wird der Speicher freigegeben

2. **Maximale Stabilität**:
   - Für kritische Operationen (Installation/Update) werden alle Module vollständig geladen
   - Feste Ladereihenfolge bei Installationen verhindert Probleme mit Abhängigkeiten

3. **Flexibilität**:
   - Der Lademodus kann je nach Bedarf umgeschaltet werden
   - Der Ansatz ist abwärtskompatibel mit bestehenden Skripten

## Abhängigkeitsstruktur

Bei bedarfsgesteuertem Laden sollte folgende Abhängigkeitsstruktur beachtet werden:

1. `lib_core.sh` (wird immer zuerst geladen)
2. `manage_folders.sh` (wird von fast allen Modulen benötigt)
3. `manage_logging.sh` (wird von fast allen Modulen benötigt)
4. Weitere Module nach Bedarf

## Fehlerbehandlung

- Fehlgeschlagene Ladevorgänge im Modus 1 (Installation/Update) gelten als kritische Fehler
- Im Modus 0 (bedarfsgesteuert) sollten Module entsprechende Fallbacks bereitstellen
