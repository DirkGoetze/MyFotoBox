#!/bin/bash
# filepath: /opt/fotobox/backend/scripts/lib_core.sh
# ------------------------------------------------------------------------------
# lib_core.sh - Zentrale Bibliotheksfunktionen für alle Fotobox-Skripte
# ------------------------------------------------------------------------------
# Funktion: Grundlegende Funktionen für Ressourceneinbindung, Initialisierung
#           und gemeinsame Hilfsfunktionen, die von allen Skripten benötigt werden.
# ------------------------------------------------------------------------------

# ===========================================================================
# Zentrale Konstanten für das gesamte Fotobox-System
# ===========================================================================
# Zentrale Definition des Skriptverzeichnisses - wird von allen Modulen verwendet
: "${SCRIPT_DIR:="/opt/fotobox/backend/scripts"}"
: "${CONF_DIR:="/opt/fotobox/conf"}"

# Standardwerte für Guard-Variablen festlegen
# ------------------------------------------------------------------------------
#: "${MANAGE_FOLDERS_LOADED:=0}"
: "${MANAGE_FILES_LOADED:=0}"
: "${MANAGE_LOGGING_LOADED:=0}"
: "${MANAGE_DATABASE_LOADED:=0}"
: "${MANAGE_SETTINGS_LOADED:=0}"
: "${MANAGE_NGINX_LOADED:=0}"
: "${MANAGE_HTTPS_LOADED:=0}"
: "${MANAGE_FIREWALL_LOADED:=0}"
: "${MANAGE_PYTHON_ENV_LOADED:=0}"
: "${MANAGE_SQL_LOADED:=0}"
: "${MANAGE_BACKEND_SERVICE_LOADED:=0}"
# ggf. weitere Guard-Variablen hier hinzufügen

# Farbkonstanten für Ausgaben (Shell-ANSI)
# ------------------------------------------------------------------------------
# HINWEIS: Für Shellskripte gilt zusätzlich:
# - Fehlerausgaben immer in Rot
# - Ausgaben zu auszuführenden Schritten in Gelb
# - Erfolgsmeldungen in Dunkelgrün
# - Aufforderungen zur Nutzeraktion in Blau
# - Alle anderen Ausgaben nach Systemstandard
# Siehe Funktionsbeispiele und DOKUMENTATIONSSTANDARD.md
COLOR_RESET="\033[0m"
COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_CYAN="\033[1;36m"
COLOR_GRAY="\033[0;37m"

# Standard-Flags
#: "${DEBUG_MOD:=0}"          # Legacy-Flag (für Kompatibilität mit älteren Skripten)
: "${UNATTENDED:=0}"

# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
: "${DEBUG_MOD_LOCAL:=0}"    # Lokales Debug-Flag für einzelne Skripte
DEBUG_MOD_GLOBAL=0           # Globales Flag, das alle lokalen überstimmt

# Lademodus für Module
# 0 = Bei Bedarf laden (für laufenden Betrieb)
# 1 = Alle Module sofort laden (für Installation/Update/Deinstallation)
#: "${MODULE_LOAD_MODE:=0}"   # Standardmäßig Module nur bei Bedarf laden

# Benutzer- und Berechtigungseinstellungen
DEFAULT_USER="fotobox"
DEFAULT_GROUP="fotobox"
DEFAULT_MODE_FOLDER="755"
DEFAULT_MODE_FILES="664"

# Konfigurationsdatei
DEFAULT_CONFIG_FILE="$CONF_DIR/fotobox-config.ini"

# Backend Service 
SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"
SYSTEMD_DST="/etc/systemd/system/fotobox-backend.service"

# ===========================================================================
# Allgemeine Hilfsfunktionen für alle Skripte
# ===========================================================================

# Hilfsfunktion für Debug-Ausgaben (wird vor dem Laden von manage_logging.sh verwendet)
debug_output() {
    # Diese Funktion entscheidet, ob print_debug (falls geladen) oder echo verwendet wird
    local message="$*"
    
    if [ "${DEBUG_MOD_GLOBAL:-0}" = "1" ] || [ "${DEBUG_MOD_LOCAL:-0}" = "1" ] || [ "${DEBUG_MOD:-0}" = "1" ]; then
        if [ "${MANAGE_LOGGING_LOADED:-0}" = "1" ] && type print_debug &>/dev/null; then
            print_debug "$message"
        else
            echo -e "${COLOR_CYAN}  → [DEBUG output]${COLOR_RESET} $message" >&2
        fi
    fi
}

# Hilfsfunktion für TRACE-Ausgaben (wird nur angezeigt, wenn Debug-Modus aktiv ist)
trace_output() {
    # Diese Funktion gibt TRACE-Ausgaben nur aus, wenn Debug aktiviert ist
    local message="$*"
    
    if [ "${DEBUG_MOD_GLOBAL:-0}" = "1" ] || [ "${DEBUG_MOD_LOCAL:-0}" = "1" ] || [ "${DEBUG_MOD:-0}" = "1" ]; then
        echo "TRACE: $message" >&2
    fi
}

# check_param
check_param_debug_0001="INFO: Parameterprüfung für [%s:%s()] Parameter: %s:%s"
check_param_debug_0002="ERROR: Parameter '%s' in Funktion '%s' des Moduls '%s' ist leer oder nicht gesetzt"
check_param_debug_0003="SUCCESS: Parameter '%s' in Funktion '%s' des Moduls '%s' ist gesetzt"
check_param_log_0001="ERROR: Parameter '%s' in Funktion '%s' des Moduls '%s' ist leer oder nicht gesetzt"

check_param() {
    # -----------------------------------------------------------------------
    # check_param
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob ein Parameter vorhanden ist
    # Parameter: $1 - Der zu prüfende Parameter
    # .........  $2 - Der Name des Parameters (für Fehlermeldung)
    # Rückgabewert: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local param="$1"
    local param_name="$2"
    local calling_function="${FUNCNAME[1]}"  # Name der aufrufenden Funktion
    local calling_file
    local module_name
    
    # Auto-Erkennung des aufrufenden Moduls, 
    # Versuche, den Dateinamen aus BASH_SOURCE zu ermitteln
    if [ -n "${BASH_SOURCE[1]}" ]; then
        calling_file=$(basename "${BASH_SOURCE[1]}")
        # Entferne Dateiendung .sh, falls vorhanden
        module_name="${calling_file%.sh}"
    else
        module_name="lib_core"  # Fallback, wenn BASH_SOURCE nicht verfügbar
    fi
    # Konvertiere in Großbuchstaben für Konsistenz
    module_name=$(echo "$module_name" | tr '[:lower:]' '[:upper:]')

    # Debugging-Ausgabe für die Modul-Identifikation
    debug "$(printf "$check_param_debug_0001" "$module_name" "$calling_function" "$param_name" "$param")"

    # Überprüfen, ob ein Parameter übergeben wurde
    if [ -z "$param" ]; then
        # Parameter ist leer oder nicht gesetzt
        debug "$(printf "$check_param_debug_0002" "$param_name" "$calling_function" "$module_name")"
        log "$(printf "$check_param_log_0001" "$param_name" "$calling_function" "$module_name")"
        return 1
    fi
  
    # Parameter ist gesetzt, Debug-Ausgabe für Erfolg
    debug "$(printf "$check_param_debug_0003" "$param_name" "$calling_function" "$module_name")"
    return 0
}

# chk_is_root
check_is_root_debug_0001="INFO: Prüfe, ob Skript als root ausgeführt wird"
check_is_root_debug_0002="ERROR: Skript muss als root ausgeführt werden"
check_is_root_debug_0003="SUCCESS: Skript wird als root ausgeführt"

check_is_root() {
    # -----------------------------------------------------------------------
    # check_is_root
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das Skript als root ausgeführt wird
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = nicht als root ausgeführt
    # -----------------------------------------------------------------------

    # Debug-Ausgabe eröffnen
    debug_output "$(printf "$check_is_root_debug_0001")"

    if [ "$EUID" -ne 0 ]; then
        # Skript wird nicht als root ausgeführt
        debug_output "$(printf "$check_is_root_debug_0002")"
        return 1
    fi

    # Debug-Ausgabe für Erfolg
    debug_output "$(printf "$check_is_root_debug_0003")"
    return 0
}

# check_distribution
check_distribution_debug_0001="INFO: Prüfe, ob das System auf Debian/Ubuntu basiert"
check_distribution_debug_0002="ERROR: System ist nicht Debian/Ubuntu-basiert"
check_distribution_debug_0003="SUCCESS: System als %s erkannt."

check_distribution() {
    # -----------------------------------------------------------------------
    # check_distribution
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das System auf Debian/Ubuntu basiert
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = nicht Debian/Ubuntu-basiert
    # -----------------------------------------------------------------------

    # Debug-Ausgabe eröffnen
    debug_output "$(printf "$check_distribution_debug_0001")"

    if [ ! -f /etc/os-release ]; then
        # Distribution ist nicht Debian/Ubuntu-basiert
        debug_output "$(printf "$check_distribution_debug_0002")"
        return 1
    fi
    . /etc/os-release
    if [[ ! "$ID" =~ ^(debian|ubuntu|raspbian)$ && ! "$ID_LIKE" =~ (debian|ubuntu) ]]; then
        # Distribution ist nicht Debian/Ubuntu-basiert
        debug_output "$(printf "$check_distribution_debug_0002")"
        return 1
    fi

    # Debug-Ausgabe für Erfolg
    debug_output "$(printf "$check_distribution_debug_0003" "$NAME")"
    return 0
}

# chk_distribution_version
check_distribution_version_debug_0001="INFO: Prüfe, ob die Distribution eine unterstützte Version ist"
check_distribution_version_debug_0002="ERROR: '/etc/os-release' nicht gefunden"
check_distribution_version_debug_0003="SUCCESS: %s (Version %s) wird unterstützt"
check_distribution_version_debug_0004="ERROR: %s (Version %s) wird nicht unterstützt"

check_distribution_version() {
    # -----------------------------------------------------------------------
    # check_distribution_version
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob die Distribution eine unterstützte Version ist
    # Parameter: keine
    # Rückgabe: 0 = unterstützte Version (VERSION_ID wird als globale 
    # ........      Variable gesetzt)
    # ........  1 = /etc/os-release nicht gefunden
    # ........  2 = Version nicht unterstützt
    # -----------------------------------------------------------------------

    # Debug-Ausgabe eröffnen
    debug_output "$(printf "$check_distribution_version_debug_0001")"

    if [ ! -f /etc/os-release ]; then
        export DIST_NAME="Unknown"
        export DIST_VERSION="Unknown"
        # Distribution ist unbekannt oder nicht unterstützt
        debug_output "$(printf "$check_distribution_version_debug_0002")"
        return 1
    fi

    . /etc/os-release
    export DIST_NAME="$NAME"
    export DIST_VERSION="$VERSION_ID"
    case "$VERSION_ID" in
        10|11|12|20.04|22.04)
            # Distributionsversion wird unterstützt
            debug_output "$(printf "$check_distribution_version_debug_0003" "$DIST_NAME" "$DIST_VERSION")"
            return 0
            ;;
        *)
            # Distributionsversion wird nicht unterstützt
            debug_output "$(printf "$check_distribution_version_debug_0004" "$DIST_NAME" "$DIST_VERSION")"
            return 2
            ;;
    esac
}

show_spinner() {
    # -----------------------------------------------------------------------
    # show_spinner
    # -----------------------------------------------------------------------
    # Funktion.: Zeigt eine Animation, solange der übergebene Prozess läuft
    # Parameter: $1 = PID des zu überwachenden Prozesses
    # .........  $2 = Typ des Spinners (optional, default: standard)
    # Rückgabe.: Exit-Code des überwachten Prozesses
    # -----------------------------------------------------------------------
    local pid="$1"
    local spinner_type="${2:-standard}"
    local delay=0.1
    local spinstr=''
    
    # Verschiedene Spinner-Typen
    case "$spinner_type" in
        "dots")
            spinstr="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
            ;;
        "slash")
            spinstr='|/-\'
            ;;
        *)  # Standard-Spinner
            spinstr='|/-\'
            ;;
    esac
    
    local len=${#spinstr}
    local i=0
    
    # Verschiebe Cursor zurück zum Anfang der Zeile
    printf "\r"
    
    # Zeige Spinner, solange der Prozess läuft
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % len ))
        printf "[%s]\r" "${spinstr:$i:1}"
        sleep $delay
    done

     # Warte auf das Ende und liefere den Exit-Code zurück
    wait "$pid"
    local exit_code=$?
    
    # Lösche den Spinner, wenn der Prozess beendet ist
    printf "    \r"
    return $exit_code
}

# ===========================================================================
# Funktionen zur Template-Verarbeitung
# ===========================================================================

# apply_template
apply_template_debug_0001="INFO: Lade Template-Datei '%s' und ersetze Platzhalter"
apply_template_debug_0002="ERROR: Template-Datei '%s' konnte nicht geladen werden"
apply_template_debug_0003="SUCCESS: Template-Datei '%s' erfolgreich verarbeitet"
apply_template_log_0001="Template-Datei nicht gefunden: %s"
apply_template_log_0002="Template-Datei '%s' erfolgreich erstellt"

apply_template() {
    # -----------------------------------------------------------------------
    # apply_template
    # -----------------------------------------------------------------------
    # Funktion: Lädt eine Template-Datei und ersetzt Platzhalter
    # Parameter: $1 = Pfad zur Template-Datei
    #            $2 = Ausgabepfad
    #            Rest: Name-Wert-Paare für Ersetzungen (NAME=value)
    # Rückgabe:  0 = OK, 1 = Template nicht gefunden
    # Seiteneffekte: Schreibt die verarbeitete Template-Datei
    # -----------------------------------------------------------------------
    local template_file="$1"
    local output_file="$2"
    shift 2
    
    # Debug-Ausgabe eröffnen
    debug_output "$(printf "$apply_template_debug_0001" "$template_file")"

    # Prüfe, ob die Template-Datei existiert
    if [ ! -f "$template_file" ]; then
        log "$(printf "$apply_template_log_0001" "$template_file")"
        debug_output "$(printf "$apply_template_debug_0002" "$template_file")"
        return 1
    fi
    
    # Template in Variable laden
    local content
    content=$(cat "$template_file")
    
    # Ersetzungen durchführen
    for pair in "$@"; do
        local name="${pair%%=*}"
        local value="${pair#*=}"
        # Platzhalter im Format {{NAME}} ersetzen
        content=$(echo "$content" | sed "s|{{$name}}|$value|g")
    done
    
    # In Ausgabedatei schreiben
    echo "$content" > "$output_file"
    log "$(printf "$apply_template_log_0002" "$output_file")"
    debug_output "$(printf "$apply_template_debug_0003" "$template_file")"
    return 0
}

# get_config_file
get_config_file_debug_0001="INFO: Suche Wert für Schlüssel '%s'"
get_config_file_debug_0002="ERROR: Konfigurationsdatei konnte nicht ermittelt werden"
get_config_file_debug_0003="INFO: Konfigurationsdatei '%s' gefunden"
get_config_file_debug_0004="SUCCESS: Wert für Schlüssel '%s' ist '%s'"

get_config_value1() {
    # -------------------------------------------------------------------------
    # get_config_value
    # -------------------------------------------------------------------------
    # Funktion.: Liest einen Konfigurationswert aus der Fotobox-Konfiguration
    # Parameter: $1 = Konfigurationsschlüssel
    # Rückgabe.: Wert des Konfigurationsschlüssels oder leerer String
    # -------------------------------------------------------------------------    
    local key="$1"
    local value=""
    local config_file

    debug "$(printf "$get_config_file_debug_0001" "$key")"

    # Konfigurationsdatei ermitteln
    config_file="$(get_config_file)"
    if [ $? -ne 0 ]; then
        debug "$get_config_file_debug_0002"
        return 1
    fi
    debug "$(printf "$get_config_file_debug_0003" "$config_file")"

    # Prüfe, ob die Konfigurationsdatei existiert
    if [ -f "$config_file" ]; then
        # Extrahiere Wert (einfache Version, kann durch komplexere ersetzt werden)
        value=$(grep -E "^$key\s*=" "$config_file" | cut -d '=' -f 2 | tr -d '[:space:]')
    fi

    debug "$(printf "$get_config_file_debug_0004" "$key" "$value")"
    echo "$value"
    return 0
}

# set_config_value
set_config_value_debug_0001="INFO: Setze Wert für Schlüssel '%s' auf '%s'"
set_config_value_debug_0002="ERROR: Konfigurationsdatei konnte nicht ermittelt werden"
set_config_value_debug_0003="INFO: Konfigurationsdatei '%s' gefunden"
set_config_value_debug_0004="INFO: Schlüssel '%s' existiert bereits, aktualisiere Wert"
set_config_value_debug_0005="INFO: Schlüssel '%s' existiert nicht, füge neuen Eintrag hinzu"
set_config_value_debug_0006="ERROR: Fehler beim Schreiben der Konfiguration"
set_config_value_debug_0007="SUCCESS: Wert für Schlüssel '%s' auf '%s' gesetzt"

set_config_value1() {
    # -------------------------------------------------------------------------
    # set_config_value
    # -------------------------------------------------------------------------
    # Funktion.: Schreibt einen Konfigurationswert in die Fotobox-Konfiguration
    # Parameter: $1 = Konfigurationsschlüssel
    # .........  $2 = Zu setzender Wert
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -------------------------------------------------------------------------    
    local key="$1"
    local value="$2"
    local config_file
    local temp_file
    
    # Parameter prüfen
    if ! check_param "$key" "key"; then return 1; fi
    if ! check_param "$value" "value"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$set_config_value_debug_0001" "$key" "$value")"

    # Konfigurationsdatei ermitteln
    config_file="$(get_config_file)"
    if [ $? -ne 0 ]; then
        debug "$set_config_value_debug_0002"
        return 1
    fi
    debug "$(printf "$set_config_value_debug_0003" "$config_file")"

    # Prüfen, ob der Schlüssel bereits existiert
    if grep -q -E "^${key}\s*=" "$config_file"; then
        debug "$(printf "$set_config_value_debug_0004" "$key")"
        # Schlüssel existiert, Wert aktualisieren
        sed -E "s|^(${key}\s*=).*|\1${value}|" "$config_file" > "$temp_file"
    else
        debug "$(printf "$set_config_value_debug_0005" "$key")"
        # Schlüssel existiert nicht, neuen Eintrag hinzufügen
        cat "$config_file" > "$temp_file"
        echo "${key}=${value}" >> "$temp_file"
    fi
    
    # Überprüfe, ob die Datei erfolgreich geschrieben wurde
    if [ $? -ne 0 ]; then
        debug "$set_config_value_debug_0006"
        rm -f "$temp_file"
        return 1
    fi

    debug "$(printf "$set_config_value_debug_0007" "$key" "$value")"
    return 0
}


# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================

# check_module
check_module_debug_0001="[check_module] INFO: Prüfe Modul '%s'"
check_module_debug_0002="[check_module] INFO: Prüfe Guard-Variable"
check_module_debug_0003="[check_module] INFO: Guard-Variable '%s' ist korrekt gesetzt (%s)"
check_module_debug_0004="[check_module] ERROR: Guard-Variable '%s' ist NICHT korrekt gesetzt (%s)"
check_module_debug_0005="[check_module] INFO: Prüfe Pfad-Variable"
check_module_debug_0006="[check_module] INFO: Pfad-Variable '%s' ist korrekt definiert (%s)"
check_module_debug_0007="[check_module] ERROR: Pfad-Variable '%s' ist NICHT korrekt definiert (%s)"
check_module_debug_0008="[check_module] SUCCESS: Modul '%s' wurde korrekt geladen"
check_module_debug_0009="[check_module] ERROR: Datei '%s' wurde nicht gefunden oder ist nicht lesbar. Die Projektstruktur ist beschädigt."

check_module() {
    # -----------------------------------------------------------------------
    # Funktion: Überprüft, ob das übergebene Modul korrekt geladen wurde
    # Parameter: $1 - Dateiname des Moduls
    # Rückgabe: 0 = OK, 
    # ........  1 = Guard-Variable des Moduls ist nicht 1
    # ........  2 = Modul nicht vorhanden / Pfadvariable des Moduls ist 
    # ........      nicht gesetzt
    # -----------------------------------------------------------------------
    local module_name="$1"
    
    # Extrahiere den Basisnamen ohne .sh Endung für die Variablennamen
    local base_name=$(basename "$module_name" .sh)
    
    # Erstelle die Namen für Guard- und Pfadvariable
    local guard_var="${base_name^^}_LOADED"
    local path_var="${base_name^^}_SH"

    # Debug-Ausgabe
    debug_output "$(printf "$check_module_debug_0001" "$(basename "${module_name%.sh}" | tr '[:lower:]' '[:upper:]')")"

    # Prüfe die Dateipräsenz des Moduls
    if [ ! -f "$SCRIPT_DIR/$module_name" ]; then
        debug_output "$(printf "$check_module_debug_0009" "$SCRIPT_DIR/$module_name")"
        return 2  # Modul nicht vorhanden
    fi

    # Prüfe Guard-Variable
    debug_output "$(printf "$check_module_debug_0002")"
    if [ -n "${!guard_var:-}" ] && [ ${!guard_var} -eq 1 ]; then
        debug_output "$(printf "$check_module_debug_0003" "$guard_var" "${!guard_var:-nicht gesetzt}")"
    else
        debug_output "$(printf "$check_module_debug_0004" "$guard_var" "${!guard_var:-nicht gesetzt}")"
        return 1  # Guard nicht OK
    fi

    # Prüfe Pfad-Variable
    debug_output "$(printf "$check_module_debug_0005")"
    if [ -n "${!path_var:-}" ] && [ -f "${!path_var}" ]; then
        debug_output "$(printf "$check_module_debug_0006" "$path_var" "${!path_var}")"
    else
        debug_output "$(printf "$check_module_debug_0007" "$path_var" "${!path_var:-nicht gesetzt}")"
        return 2  # Pfad nicht OK
    fi

    # Wenn wir hier ankommen, sind beide Prüfungen erfolgreich
    debug_output "$(printf "$check_module_debug_0008" "$module_name")"
    return 0  # Erfolg
}

# bind_resource
bind_resource_debug_0001="[bind_resource] INFO: Starte Einbindung der Ressource '%s'"
bind_resource_debug_0002="[bind_resource] INFO: Ressource '%s' bereits geladen, überspringe"
bind_resource_debug_0003="[bind_resource] INFO: Suche Ressourcenverzeichnis: '%s'"
bind_resource_debug_0004="[bind_resource] ERROR: Verzeichnis '%s' nicht gefunden oder nicht lesbar"
bind_resource_debug_0005="[bind_resource] INFO: Versuche Ressource zu finden: '%s'"
bind_resource_debug_0006="[bind_resource] ERROR: Die Datei '%s' existiert nicht oder ist nicht lesbar"
bind_resource_debug_0007="[bind_resource] INFO: Lade '%s'"
bind_resource_debug_0008="[bind_resource] ERROR: Fehler beim Laden von '%s' (Status: %d)"
bind_resource_debug_0009="[bind_resource] INFO: Modul '%s' geladen, Pfad-Variable '%s' gesetzt"
bind_resource_debug_0010="[bind_resource] INFO: Modul '%s' geladen, Guard-Variable '%s' gesetzt"
bind_resource_debug_0011="[bind_resource] ERROR: Fehler - Modul '%s' konnte nicht korrekt geladen werden"
bind_resource_debug_0012="[bind_resource] SUCCESS: Modul '%s' erfolgreich geladen"
bind_resource_debug_0013="[bind_resource] INFO: Ressourcendatei '%s' erfolgreich geladen."
bind_resource_log_0001="[bind_resource] ERROR: Verzeichnis '%s' nicht gefunden oder nicht lesbar"
bind_resource_log_0002="[bind_resource] ERROR: Die Datei '%s' existiert nicht oder ist nicht lesbar"
bind_resource_log_0003="[bind_resource] ERROR: Konnte '%s' nicht laden (Status: %d)"

bind_resource() {
    # -----------------------------------------------------------------------
    # Funktion: Vereinfachte Version zum Laden von Skript-Ressourcen
    # Parameter: $1 = Name der benötigten Ressource (z.B. "manage_folders.sh")
    # Rückgabe: 0 = OK, 1 = Ressource nicht verfügbar, 2 = Verzeichnis nicht verfügbar
    # -----------------------------------------------------------------------
    local resource_name="$1"
    local resource_file="$SCRIPT_DIR/$resource_name"

    if [ -z "$resource_name" ]; then
        echo "Fehler: Ressource-Name ist leer."
        return 1
    fi

    # Prüfen, ob die Ressource bereits geladen ist
    local base_name="${resource_name%.sh}"    
    local guard_var_name="${base_name^^}_LOADED"  # erzwinge Großbuchstaben für Guard-Variable
    # Deaktiviere "unbound variable" Fehler, um Guard-Variable zu prüfen
    local e_was_set
    local u_was_set
    local old_state=$-
    if [[ $old_state == *e* ]]; then e_was_set=1;  else e_was_set=0; fi
    if [[ $old_state == *u* ]]; then u_was_set=1;  else u_was_set=0; fi
    set +u
    set -e

    # Prüfe, ob die Guard-Variable gesetzt ist und den Wert 1 hat
    if [ "$(eval echo \$$guard_var_name)" -eq 1 ]; then
        debug_output "$(printf "$bind_resource_debug_0002" "$base_name")"
        return 0  # Bereits geladen, alles OK
    fi
    # Stelle den ursprünglichen Zustand "unbound variable" Fehler wieder her
    if [ "$u_was_set" -eq 1 ]; then set -u; fi
    if [ "$e_was_set" -eq 1 ]; then set -e; fi

    # Prüfung des Ressourcen-Verzeichnisses
    debug_output "$(printf "$bind_resource_debug_0003" "$SCRIPT_DIR")"
    if [ ! -d "$SCRIPT_DIR" ] || [ ! -r "$SCRIPT_DIR" ]; then
        debug_output "$(printf "$bind_resource_debug_0004" "$SCRIPT_DIR")"
        echo "$(printf "$bind_resource_log_0001" "$SCRIPT_DIR")"
        return 2
    fi
    
    # Prüfen, ob die Ressourcendatei existiert und lesbar ist
    debug_output "$(printf "$bind_resource_debug_0005" "$resource_file")"
    if [ ! -f "$resource_file" ] || [ ! -r "$resource_file" ]; then
        debug_output "$(printf "$bind_resource_debug_0006" "$resource_file")"
        echo "$(printf "$bind_resource_log_0002" "$resource_file")"
        return 1
    fi
    
    # Ressource laden
    debug_output "$(printf "$bind_resource_debug_0007" "${resource_file}")"
    source "$resource_file"
    local source_result=$?    
    if [ $source_result -ne 0 ]; then
        debug_output "$(printf "$bind_resource_debug_0008" "${resource_name%.sh}" "$source_result")"
        echo "$(printf "$bind_resource_log_0003" "${resource_name%.sh}" "$source_result")"
        return 1
    fi
    debug_output "$(printf "$bind_resource_debug_0013" "$resource_name" "$source_result")"

    # Setze die Path-Variable, um den Pfad zur Ressource global verfügbar zu machen
    local path_var="${resource_name%.sh}_sh"
    path_var="${path_var^^}"  # Konvertiere gesamten Variablennamen in Großbuchstaben
    eval "$path_var=\"$resource_file\""
    export "$path_var"  # Exportiere die Variable, damit sie global verfügbar ist
    debug_output "$(printf "$bind_resource_debug_0009" "$(basename "${resource_name%.sh}" | tr '[:lower:]' '[:upper:]')" "$path_var")"

    # Setze die Guard-Variable auf 1, um anzuzeigen, dass die Ressource geladen wurde
    eval "$guard_var_name=1"
    export "$guard_var_name"  # Exportiere die Variable, damit sie global verfügbar ist
    debug_output "$(printf "$bind_resource_debug_0010" "$(basename "${resource_name%.sh}" | tr '[:lower:]' '[:upper:]')" "$guard_var_name")"

    # Prüfe ob das Laden erfolgreich war
    if ! check_module "$resource_name"; then
        debug_output "$(printf "$bind_resource_debug_0011" "$(basename "${resource_name%.sh}" | tr '[:lower:]' '[:upper:]')")"
        echo "$(printf "$bind_resource_log_0003" "${resource_name%.sh}" "$source_result")"
        return 1
    fi

    # Wenn wir hier ankommen, war alles erfolgreich
    debug_output "$(printf "$bind_resource_debug_0012" "$(basename "${resource_name%.sh}" | tr '[:lower:]' '[:upper:]')")"
    return 0  # Erfolgreich geladen
}

# load_resources
load_resources_debug_0001="[load_resources] INFO: Starte Prüfung aller benötigten Ressourcen"
load_resources_debug_0002="[load_resources] Versuche %s einzubinden ..."
load_resources_debug_0003="[load_resources] ERROR: Fehler beim Laden von %s, erstelle Fallback-Funktionen"
load_resources_debug_0004="[load_resources] INFO: Fallback-Funktion für %s wurde erstellt"
load_resources_debug_0005="[load_resources] INFO: Prüfung aller Ressourcen abgeschlossen mit Ergebnis: %d"

load_resources() {
    # -----------------------------------------------------------------------
    # Funktion: Prüfung und Einbindung aller benötigten Skript-Ressourcen
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = mind. eine Ressource fehlt oder ist nicht nutzbar
    # -----------------------------------------------------------------------
    local result=0
    
    # Debug-Ausgabe eröffnen
    debug_output "$(printf "$load_resources_debug_0001")"
    
    # 1. manage_folders.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_folders.sh")"
    bind_resource "manage_folders.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_folders.sh")"

        # Minimale Implementierung, falls manage_folders.sh nicht verfügbar ist
        get_log_dir() {
            local dir="./logs"
            debug_output "[DEBUG] get_log_dir (Fallback): Versuche Logverzeichnis '$dir' zu erstellen"
            
            # Versuche Standardverzeichnis zu erstellen
            mkdir -p "$dir" 2>/dev/null
            
            # Fallback-Mechanismus, wenn Standardverzeichnis nicht erstellt werden kann
            if [ ! -d "$dir" ]; then
                debug_output "[DEBUG] get_log_dir (Fallback): Standardverzeichnis '$dir' nicht erstellbar, versuche Alternativen"
                # Fallback 1: Temporäres Verzeichnis
                if [ -w "/tmp" ]; then
                    debug_output "[DEBUG] get_log_dir (Fallback): Verwende /tmp/fotobox_logs"
                    dir="/tmp/fotobox_logs"
                    mkdir -p "$dir" 2>/dev/null
                # Fallback 2: Aktuelles Verzeichnis
                elif [ -w "." ]; then
                    debug_output "[DEBUG] get_log_dir (Fallback): Verwende ./fotobox_logs"
                    dir="./fotobox_logs"
                    mkdir -p "$dir" 2>/dev/null
                else
                    debug_output "[DEBUG] get_log_dir (Fallback): Konnte kein schreibbares Logverzeichnis finden"
                    return 1
                fi
            fi
            # Erfolgreich erstelltes oder vorhandenes Verzeichnis zurückgeben
            debug_output "[DEBUG] get_log_dir (Fallback): Verwende Logverzeichnis '$dir'"
            echo "$dir"
        }

        result=0 # kein Fehler, da Fallback-Funktion vorhanden
        debug_output "$(printf "$load_resources_debug_0004" "manage_folders.sh")"
    fi
    
    # 2. manage_files.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_files.sh")"
    bind_resource "manage_files.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_files.sh")"
        result=1

        # Fallback-Funktion für manage_files.sh
        get_log_file() {
            local log_file="$(get_log_dir)/$(date '+%Y-%m-%d')_fotobox.log"
            debug_output "[DEBUG] get_log_file (Fallback): Verwende Logdatei '$log_file'"
            
            # Teste Schreibrecht für die Logdatei
            if ! touch "$log_file" 2>/dev/null; then
                debug_output "[DEBUG] get_log_file (Fallback): Keine Schreibrechte für Logdatei '$log_file'"
                return 1
            fi
            
            echo "$log_file"
        }

        result=0 # kein Fehler, da Fallback-Funktion vorhanden
        debug_output "$(printf "$load_resources_debug_0004" "manage_files.sh")"
    fi

    # 3. manage_logging.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_logging.sh")"
    bind_resource "manage_logging.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_logging.sh")"
        echo "Fehler: manage_logging.sh konnte nicht geladen werden."
        
        # Fallback für Logging bereitstellen mit erweiterten Funktionen
        log() {
            local LOG_FILE="$(get_log_dir)/$(date '+%Y-%m-%d')_fotobox.log"
            debug_output "[DEBUG] log (Fallback): Schreibe Log in Datei '$LOG_FILE'"

            # Wenn get_log_file verfügbar ist, verwenden wir diese Funktion
            if type get_log_file &>/dev/null; then
                LOG_FILE=$(get_log_file)
                debug_output "[DEBUG] log (Fallback): Verwende get_log_file, Logdatei ist nun '$LOG_FILE'"
            fi
            
            if [ -z "$1" ]; then
                # Bei leerem Parameter: Rotation simulieren
                debug_output "[DEBUG] log (Fallback): Leerer Parameter, führe Log-Rotation aus"
                touch "$LOG_FILE" 2>/dev/null
                return
            fi
            echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
        }
                
        # Erweiterte Ausgabefunktionen mit konsistenter Formatierung
        print_step() { 
            debug_output "print_step (Fallback): $*"
            echo -e "${COLOR_YELLOW}$*${COLOR_RESET}"
            log "$*"
        }
        
        print_info() { 
            debug_output "print_info (Fallback): $*"
            echo -e "  $*"
            log "$*"
        }
        
        print_success() { 
            debug_output "print_success (Fallback): $*"
            echo -e "${COLOR_GREEN}  → [OK]${COLOR_RESET} $*"
            log "$*"
        }
        
        print_warning() { 
            debug_output "print_warning (Fallback): $*"
            echo -e "${COLOR_YELLOW}  → [WARN]${COLOR_RESET} $*"
            log "$*"
        }
        
        print_error() { 
            debug_output "print_error (Fallback): $*"
            echo -e "${COLOR_RED}  → [ERROR]${COLOR_RESET} $*" >&2
            log "$*"
        }
        
        print_prompt() {
            # Parameter:
            # $1 = Text für die Benutzerabfrage
            # $2 = (optional) Prompt-Typ:
            #      "yn" = Ja/Nein-Abfrage, gibt 0 für Ja und 1 für Nein zurück
            #      "text" = Texteingabe, gibt eingegebenen Text zurück
            #      Standardwert: Nur Anzeige ohne Eingabe
            # $3 = (optional) Default-Wert für Ja/Nein-Abfragen:
            #      "y" = Default ist Ja
            #      "n" = Default ist Nein (Standard)
            
            local prompt_type="${2:-}"
            local default="${3:-n}"
            local prompt_text="$1"
            local prompt_suffix=""
            local answer=""
            
            debug_output "print_prompt (Fallback): $prompt_text [$prompt_type/$default]"
            
            # Wenn unattended-Modus aktiv ist, keine interaktive Abfrage
            if [ "${UNATTENDED:-0}" -eq 1 ]; then
                # Bei Ja/Nein-Abfragen im unattended-Modus immer Nein zurückgeben
                if [ "$prompt_type" = "yn" ]; then
                    return 1
                fi
                return 0
            fi
            
            # Prompt-Suffix je nach Typ anpassen
            if [ "$prompt_type" = "yn" ]; then
                if [ "$default" = "y" ]; then
                    prompt_suffix=" [J/n]"
                else
                    prompt_suffix=" [j/N]"
                fi
            fi
            
            # Prompt ausgeben
            echo -e "\n${COLOR_BLUE}${prompt_text}${prompt_suffix}${COLOR_RESET}"
            
            # Bei Bedarf Benutzereingabe abfragen
            if [ -n "$prompt_type" ]; then
                read -r answer
                
                # Ja/Nein-Abfrage auswerten
                if [ "$prompt_type" = "yn" ]; then
                    log "PROMPT-YN: $prompt_text => $answer"
                    if [ -z "$answer" ]; then
                        # Leere Eingabe: Default-Wert verwenden
                        [ "$default" = "y" ] && return 0 || return 1
                    else
                        # Eingabe auf J/j/Y/y prüfen
                        [[ "$answer" =~ ^([jJ]|[yY])$ ]]
                        return $?
                    fi
                elif [ "$prompt_type" = "text" ]; then
                    log "PROMPT-TEXT: $prompt_text => $answer"
                    # Text zurückgeben (wenn mit eval aufgerufen)
                    echo "$answer"
                fi
            else
                log "PROMPT: $prompt_text"
            fi
        }
        
        print_debug() { 
            debug_output "print_debug (Fallback): $*"
            if [ "${DEBUG_MOD_GLOBAL:-0}" = "1" ] || [ "${DEBUG_MOD_LOCAL:-0}" = "1" ] || [ "${DEBUG_MOD:-0}" = "1" ]; then
                echo -e "${COLOR_CYAN}  → [DEBUG Fallback]${COLOR_RESET} $*" >&2
                log "DEBUG: $*"
            fi
        }

        result=0 # kein Fehler, da Fallback-Funktion vorhanden
        debug_output "$(printf "$load_resources_debug_0004" "manage_logging.sh")"
    fi

    # 4. manage_database.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_database.sh")"
    bind_resource "manage_database.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_database.sh")"
        result=1
    fi

    # 5. manage_settings.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_settings.sh")"
    bind_resource "manage_settings.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_settings.sh")"
        result=1
    fi

    # 6. manage_nginx.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_nginx.sh")"
    bind_resource "manage_nginx.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_nginx.sh")"
        result=1
    fi

    # 7. manage_https.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_https.sh")"
    bind_resource "manage_https.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_https.sh")"
        result=1
    fi

    # 8. manage_firewall.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_firewall.sh")"
    bind_resource "manage_firewall.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_firewall.sh")"
        result=1
    fi

    # 9. manage_python_env.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_python_env.sh")"
    bind_resource "manage_python_env.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_python_env.sh")"
        result=1
    fi

    # 10. manage_backend_service.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_backend_service.sh")"
    bind_resource "manage_backend_service.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_backend_service.sh")"
        result=1
    fi

    debug_output "$(printf "$load_resources_debug_0005" "$result")"
    return $result
}

# ===========================================================================
# Prüfroutinen für einzelne Module
# ===========================================================================
global_seperator_h1="=========================================================================="
global_seperator_h2="--------------------------------------------------------------------------"
global_seperator_h3="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# list_module_functions
list_module_functions_001=" Liste der Funktionen in Modul '%s'"
list_module_functions_002=" Private Funktionen:"
list_module_functions_003=" Öffentliche Funktionen:"

list_module_functions() {
    # -----------------------------------------------------------------------
    # Funktion: Liste alle Funktionen eines Moduls auf
    # Parameter: $1 - Dateiname des Moduls (z.B. "manage_folders.sh")
    # .........  $2 - Optional: "true" zeigt auch private Funktionen an
    # Rückgabe: 0 = OK, 1 = mind. eine Ressource fehlt oder ist nicht nutzbar
    # -----------------------------------------------------------------------
    local module_file="$1"
    local module_name=$(basename "$module_file")
    local show_private=${2:-false}  # Optional: true zeigt private Funktionen an
    
    print_info "$global_seperator_h2"
    print_info "$(printf "$list_module_functions_001" "${module_name^^}")"
    print_info "$global_seperator_h2"

    if [ "$show_private" = "true" ]; then
        # Zuerst private Funktionen anzeigen
        print_info "$global_seperator_h3"
        print_info "$(printf "$list_module_functions_002")"
        print_info "$global_seperator_h3"
        grep -E '^[[:space:]]*(function[[:space:]]+)?_[a-zA-Z0-9_]+\(\)[[:space:]]*\{' "$module_file" | 
          sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)\(\).*/\2/' | 
          sort
        echo ""
    fi
    
    # Öffentliche Funktionen anzeigen
    print_info "$global_seperator_h3"
    print_info "$(printf "$list_module_functions_003")"
    print_info "$global_seperator_h3"
    grep -E '^[[:space:]]*(function[[:space:]]+)?[a-zA-Z0-9_]+\(\)[[:space:]]*\{' "$module_file" | 
      sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_]+)\(\).*/\2/' | 
      grep -v "^_" |
      sort

    echo ""
    return 0  # Erfolgreich
}

# test_modul
test_modul_txt_0001=" Test des Moduls '%s'"
test_modul_txt_0002="Modul-Datei '%s' ist nicht vorhanden oder nicht lesbar!"
test_modul_txt_0003="Modul-Datei...: '%s'"
test_modul_txt_0004="Guard-Variable '%s' ist NICHT korrekt gesetzt (%s)"
test_modul_txt_0005="Guard-Variable: '%s' = '%s'"
test_modul_txt_0006="Pfad-Variable '%s' ist NICHT korrekt definiert (%s)"
test_modul_txt_0007="Pfad-Variable.: '%s' = %s'"
test_modul_txt_0008="Modul '%s' wurde korrekt geladen"

test_modul() {
    # -----------------------------------------------------------------------
    # Funktion: Testet, ob ein Modul korrekt geladen wurde
    # Parameter: $1 - Name des Moduls (z.B. "manage_folders.sh")
    # Rückgabe: 0 = OK, 1 = Modul nicht verfügbar, 2 = Funktion nicht gefunden
    # -----------------------------------------------------------------------
    local module_name="$1"

    # Extrahiere den Basisnamen ohne .sh Endung für die Variablennamen
    local base_name=$(basename "$module_name" .sh)

    # Deaktiviert das sofortige Beenden bei Fehlern. Das Skript läuft weiter, 
    # auch wenn ein Befehl fehlschlägt. Hilfreich, um bewusst mit Fehlern 
    # umzugehen.
    set +e
    # Aktivierten des sofortige Beenden des Skripts, wenn eine nicht 
    # definierte Variable verwendet wird. Dies verhindert subtile Fehler
    # durch Tippfehler in Variablennamen.
    set -u

    # Funktionsstart anzeigen
    print_info "$global_seperator_h1"
    print_info "$(printf "$test_modul_txt_0001" "${base_name^^}")"
    print_info "$global_seperator_h1"

    # Prüfe die Dateipräsenz des Moduls
    local full_path="$SCRIPT_DIR/$module_name"
    if [ ! -f "$full_path" ]; then
        print_error "$(printf "$test_modul_txt_0002" "$full_path")"
        return 2  # Modul nicht vorhanden
    fi
    print_info "$(printf "$test_modul_txt_0003" "$full_path")"

    # Extrahiere den Basisnamen ohne .sh Endung für die Variablennamen
    local base_name=$(basename "$module_name" .sh)

    # Erstelle Namen für die Guardvariable und prüfe Guard-Variable
    local guard_var="${base_name^^}_LOADED"
    if [ -n "${!guard_var:-}" ] && [ ${!guard_var} -eq 1 ]; then
        print_info "$(printf "$test_modul_txt_0005" "$guard_var" "${!guard_var:-nicht gesetzt}")"
    else
        print_error "$(printf "$test_modul_txt_0004" "$guard_var" "${!guard_var:-nicht gesetzt}")"
        return 1  # Guard nicht OK
    fi

    # Erstelle Namen für die Pfadvariable und prüfe Pfad-Variable
    local path_var="${base_name^^}_SH"
    if [ -n "${!path_var:-}" ] && [ -f "${!path_var}" ]; then
        print_info "$(printf "$test_modul_txt_0007" "$path_var" "${!path_var}")"
    else
        print_error "$(printf "$test_modul_txt_0006" "$path_var" "${!path_var:-nicht gesetzt}")"
        return 2  # Pfad nicht OK
    fi

    # Wenn wir hier ankommen, sind beide Prüfungen erfolgreich
    print_success "$(printf "$test_modul_txt_0008" "${base_name^^}")"
    echo ""

    # Liste der Funktionen im Modul anzeigen
    list_module_functions "$full_path" true

    # Test abgeschlossen, deaktiviere Prüfung auf nicht definierte Variablen.
    # Diese werden wieder als leere Strings behandelt.
    set +u
    # Tests abgeschlossen, aktiviert das sofortige Beenden bei Fehlern wieder
    set -e

    # Erfolgreich getestet
    return 0
}

# test_function
test_function_debug_0001="INFO: Test Funktion: %s"
test_function_debug_0002="INFO: Parameter: %s"
test_function_debug_0003="ERROR: Modul nicht verfügbar! Variable: %s, Pfad: %s"
test_function_debug_0004="ERROR: Funktion '%s' wurde nicht gefunden"
test_function_debug_0005="INFO: Funktion '%s' in Modul %s gefunden"
test_function_debug_0006="INFO: Führe Funktion '%s' aus mit Parametern: %s"
test_function_debug_0007="INFO: Führe Funktion '%s' aus"
test_function_debug_0008="INFO: Ausgabe: %s"
test_function_debug_0009="INFO: Rückgabewert: %d"
test_function_txt_0001=" Test der Funktion: %s"
test_function_txt_0002=" Parameter: %s"
test_function_txt_0003="Modul '%s' nicht verfügbar oder Pfad ungültig!"
test_function_txt_0004="Funktion '%s' wurde nicht gefunden!"
test_function_txt_0005="Funktion: '%s' in Modul '%s' gefunden"
test_function_txt_0006="Ausgabe.: %s"
test_function_txt_0007="Rückgabe: %d"
test_function_txt_0008="Ausgabe.: Funktion '%s' hat keine Ausgabe erzeugt."
test_function_txt_0009="Funktion '%s' wurde erfolgreich getestet."

test_function() {
    # Erweiterte Testfunktion für flexible Modulaufrufe und Ergebnisanalyse
    # Parameter verarbeiten
    local module_path_var="$1"        # Name der Modul-Pfad-Variable (z.B. manage_folders_sh)
    local module_path_var_upper="${module_path_var^^}"  # Wandelt nur den Variablennamen in Großbuchstaben um
    local function_name="$2"          # Name der zu testenden Funktion
    local params=("${@:3}")           # Alle weiteren Parameter für die Funktion

    # Deaktiviert das sofortige Beenden bei Fehlern. Das Skript läuft weiter, 
    # auch wenn ein Befehl fehlschlägt. Hilfreich, um bewusst mit Fehlern 
    # umzugehen.
    set +e
    # Aktivierten des sofortige Beenden des Skripts, wenn eine nicht 
    # definierte Variable verwendet wird. Dies verhindert subtile Fehler
    # durch Tippfehler in Variablennamen.
    set -u

    # Meldung über Start des Tests ausgeben
    print_info "$global_seperator_h2"
    print_info "$(printf "$test_function_txt_0001" "$function_name")"
    print_info "$global_seperator_h2"

    # Debug-Ausgabe eröffnen
    debug_output "$(printf "$test_function_debug_0001" "$function_name")"

    # Informationen über den Aufruf, wenn Parameter vorhanden sind
    if [ ${#params[@]} -gt 0 ]; then
        debug_output "$(printf "$test_function_debug_0002" "${params[*]}")"
        print_info "$(printf "$test_function_txt_0002" "${params[*]}")"
        print_info "$global_seperator_h3"
    fi

    # Prüfe, ob das Modul verfügbar ist
    if [ -z "${!module_path_var_upper}" ] || [ ! -f "${!module_path_var_upper}" ]; then
        debug_output "$(printf "$test_function_debug_0003" "$module_path_var_upper" "${!module_path_var_upper:-nicht gesetzt}")" "CLI" "test_function"
        print_error "$(printf "$test_function_txt_0003" "${!module_path_var_upper:-nicht gesetzt}")"
        return 1
    fi

    # Prüfe, ob die Funktion existiert (bereits geladen)
    if ! declare -f "$function_name" > /dev/null 2>&1; then
        debug_output "$(printf "$test_function_debug_0004" "$function_name")"
        print_error "$(printf "$test_function_txt_0004" "$function_name")" &>2
        return 2
    fi

    debug_output "$(printf "$test_function_debug_0005" "$function_name" "$module_path_var_upper")"
    print_info "$(printf "$test_function_txt_0005" "$function_name" "${module_path_var_upper}")"

    # Führe die Funktion aus und erfasse Rückgabewert und Ausgabe
    local output
    local result

    # Führe die Funktion DIREKT mit den übergebenen Parametern aus
    set +e  # Deaktiviere Fehlerabbruch
    if [ ${#params[@]} -gt 0 ]; then
        debug_output "$(printf "$test_function_debug_0006" "$function_name" "${params[*]}")"
        output=$("$function_name" "${params[@]}" 2>&1)
        result=$?
    else
        debug_output "$(printf "$test_function_debug_0007" "$function_name")"
        output=$("$function_name" 2>&1)
        result=$?
    fi
    set -e  # Reaktiviere Fehlerabbruch

    # Rest der Funktion bleibt gleich...
    if [ -n "$output" ]; then
        debug_output "$(printf "$test_function_debug_0008" "$output")"
        debug_output "$(printf "$test_function_debug_0009" "$result")"
        if [ "${DEBUG_MOD_GLOBAL:-0}" = "0" ] && [ "${DEBUG_MOD_LOCAL:-0}" = "0" ]; then
            print_info "$(printf "$test_function_txt_0006" "$output")"
            if [ $result -eq 0 ]; then
                print_success "$(printf "$test_function_txt_0007" "$result")"
            else
                print_warning "$(printf "$test_function_txt_0007" "$result")"
            fi
        fi
    else
        debug_output "$(printf "$test_function_debug_0009" "$result")"
        if [ "${DEBUG_MOD_GLOBAL:-0}" = "0" ] && [ "${DEBUG_MOD_LOCAL:-0}" = "0" ]; then
            # print_info "$(printf "$test_function_txt_0008" "$function_name")"
            if [ $result -eq 0 ]; then
                print_success "$(printf "$test_function_txt_0007" "$result")"
            else
                print_warning "$(printf "$test_function_txt_0007" "$result")"
            fi
        fi
    fi

    # Test abgeschlossen, deaktiviere Prüfung auf nicht definierte Variablen.
    # Diese werden wieder als leere Strings behandelt.
    set +u
    # Tests abgeschlossen, aktiviert das sofortige Beenden bei Fehlern wieder
    set -e

    # Gib den originalen Rückgabewert der getesteten Funktion zurück
    print_success "$(printf "$test_function_txt_0009" "$function_name")"
    echo
    return $result
}

# ============================================================================
# Testfunktionen für lib_core.sh selber
# ============================================================================

# test_lib_core
test_lib_core_debug_0001="INFO: Starte Test für lib_core.sh"
test_lib_core_txt_0001=" Test für das zentrale Modul 'lib_core.sh'"
test_lib_core_txt_0002=" Vorhandene Modul-Dateien im Skriptverzeichnis"

test_lib_core() {
    # -----------------------------------------------------------------------
    # Funktion: Testet die Funktionen in lib_core.sh
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = Fehler bei den Tests
    # -----------------------------------------------------------------------
    # Eröffnungsmeldung im Debug Modus
    debug "$test_lib_core_debug_0001"
    
    # Aktivieren des globalen Debug-Modus für die Tests
    # DEBUG_MOD_GLOBAL=1 

    print_info "$global_seperator_h1"
    print_info "$(printf "$test_lib_core_txt_0001")"
    print_info "$global_seperator_h1"

    # Debug-Ausgabe zum Anzeigen der vorhandenen Modul-Dateien
    local script_dir="/opt/fotobox/backend/scripts"
    print_info "$global_seperator_h2"
    print_info "$(printf "$test_lib_core_txt_0002")"
    print_info "$global_seperator_h2"
    ls -la "$script_dir"
    echo

    # Teste set_config_value
    # test_function "set_config_value" "test_key" "test_value" "/tmp/test_config.conf"
    
    # Teste check_module
    # test_function "check_module" "manage_folders.sh"
    
    # Teste bind_resource
    # test_function "bind_resource" "manage_folders.sh"
    
    # Teste list_module_functions
    # list_module_functions "manage_folders.sh" true
    
    # Tests abgeschlossen, Deaktivieren des globalen Debug-Modus 
    # DEBUG_MOD_GLOBAL=0 

    # Meldung ausgeben
    debug "$test_manage_files_debug_0003"
    return 0
}

# ===========================================================================
# Hauptteil des Skripts: Ressourcen laden und Module überprüfen
# ===========================================================================
# Initialisieren aller Ressourcen
debug_output "lib_core.sh: Initialisieren und Laden aller Ressourcen"

# Versuche, alle benötigten Ressourcen zu laden
load_resources
if [ $? -ne 0 ]; then
    debug_output "lib_core.sh: Fehler beim Laden der Ressourcen, Abbruch"
    echo "Fehler: Einige Ressourcen konnten nicht geladen werden. Bitte überprüfen Sie die Fehlermeldungen."
    exit 1
fi
