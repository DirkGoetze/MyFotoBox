# Erweiterte Dokumentation: Rekursionsschutz im Hybrid-Modul-Ladesystem

## Anti-Rekursions-Mechanismen

Das Ladesystem von Fotobox2 verwendet mehrere Mechanismen, um rekursive Aufrufe zu vermeiden und zuverlässig zu funktionieren.

### 1. Globale Guard-Variablen

Jedes Modul besitzt eine Guard-Variable (z.B. `MANAGE_FOLDERS_LOADED`), die bei erfolgreicher Ladung auf `1` gesetzt wird. Dies verhindert das mehrfache Laden eines Moduls.

### 2. Erkennung rekursiver Module-Ladungen

Die `bind_resource`-Funktion verwendet einen deklarativen Ansatz zur Erkennung von rekursiven Aufrufen:

```bash
# Innerhalb der bind_resource Funktion
# Entferne Sonderzeichen aus dem Ressourcennamen für gültige Variablennamen
local safe_resource_name="${resource_name//[^a-zA-Z0-9_]/_}"
declare -g "BINDING_${safe_resource_name}_IN_PROGRESS"
local binding_in_progress_var="BINDING_${safe_resource_name}_IN_PROGRESS"

if [ "${!binding_in_progress_var}" = "1" ]; then
    # Rekursiver Aufruf erkannt - Schutzmechanismus greift ein
    eval "$guard_var_name=1"  # Ressource als geladen markieren
    return 0
fi

# Markieren, dass diese Ressource gerade geladen wird
eval "${binding_in_progress_var}=1"
```

### 3. Globaler Ladestatus für Kernressourcen

Die `load_core_resources`-Funktion verwendet eine globale Variable `CORE_RESOURCES_LOADING`, um zu verhindern, dass während eines Ladevorgangs erneut alle Ressourcen geladen werden:

```bash
declare -g CORE_RESOURCES_LOADING
    
if [ "${CORE_RESOURCES_LOADING:-0}" -eq 1 ]; then
    # Rekursiver Aufruf erkannt, Laden überspringen
    return 0
fi

# Markieren, dass wir gerade laden
CORE_RESOURCES_LOADING=1
```

### 4. Modulspezifische Ladezustände

Die `load_module`-Funktion verwendet modulspezifische Zustandsvariablen:

```bash
# Entferne Sonderzeichen aus dem Modulnamen für gültige Variablennamen
local safe_module_name="${module_name//[^a-zA-Z0-9_]/_}"
declare -g "LOADING_MODULE_${safe_module_name}"
local module_loading_var="LOADING_MODULE_${safe_module_name}"

if [ "${!module_loading_var:-0}" -ne 1 ]; then
    eval "${module_loading_var}=1"
    # Ressource laden
    eval "${module_loading_var}=0"
else
    # Rekursion erkannt, Laden überspringen
fi
```

### 5. Optimierte Installation

In der Installationsphase werden die Module durch direkten Aufruf von `chk_resources` statt des üblichen `load_core_resources`-Mechanismus geladen, was eine bessere Kontrolle und Fehlerbehebung ermöglicht.

## Debugging des Ladesystems

Das gesamte System unterstützt umfangreiche Debugging-Ausgaben, die über `DEBUG_MOD_GLOBAL=1` aktiviert werden können. Diese Ausgaben helfen bei der Identifizierung von Ladeproblemen.

## Variablennamen-Bereinigung

Da Bash strikte Regeln für gültige Variablennamen hat (nur Buchstaben, Zahlen und Unterstriche sind erlaubt), müssen wir sicherstellen, dass alle dynamisch generierten Variablennamen diese Regeln einhalten. Daher verwenden wir Substitutionen, um ungültige Zeichen zu ersetzen:

```bash
# Aus dem Ressourcennamen (z.B. "manage_folders.sh") einen gültigen Variablennamen machen
local safe_resource_name="${resource_name//[^a-zA-Z0-9_]/_}"
```

Diese Technik wird sowohl in `bind_resource` als auch in `load_module` verwendet, um Fehler wie `declare: »BINDING_manage_folders.sh_IN_PROGRESS«: Ist kein gültiger Bezeichner.` zu vermeiden.

## Erweiterungshinweise

Bei Erweiterung des Modulsystems sollten folgende Punkte beachtet werden:

1. Neue Module müssen eine Guard-Variable in Großbuchstaben mit dem Suffix `_LOADED` definieren
2. Neue Module sollten das hybride Lademusterverhalten implementieren
3. Beim Hinzufügen von Abhängigkeiten zwischen Modulen sollte `load_module` statt direktem `source` verwendet werden
4. Die Standardeinstellung für `MODULE_LOAD_MODE` sollte bei `0` bleiben, um Ressourcen im normalen Betrieb zu schonen
5. Bei der Erzeugung dynamischer Variablennamen müssen ungültige Zeichen gefiltert werden (`${var//[^a-zA-Z0-9_]/_}`)
