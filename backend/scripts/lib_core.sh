#!/bin/bash
# filepath: /opt/fotobox/backend/scripts/lib_core.sh
# ------------------------------------------------------------------------------
# lib_core.sh - Zentrale Bibliotheksfunktionen für alle Fotobox-Skripte
# ------------------------------------------------------------------------------
# Funktion: Grundlegende Funktionen für Ressourceneinbindung, Initialisierung
#           und gemeinsame Hilfsfunktionen, die von allen Skripten benötigt werden.
# ------------------------------------------------------------------------------

# Guard für sich selbst
: "${LIB_CORE_LOADED:=0}"
if [ "$LIB_CORE_LOADED" -eq 1 ]; then
    return 0  # Bereits geladen
fi
# Sofort markieren, dass diese Bibliothek geladen wird, um rekursive Probleme zu vermeiden
LIB_CORE_LOADED=1

# ===========================================================================
# Zentrale Konstanten für das gesamte Fotobox-System
# ===========================================================================
# Primäre Pfaddefinitionen (Single Source of Truth)
DEFAULT_DIR_INSTALL="/opt/fotobox"
DEFAULT_DIR_BACKEND="$DEFAULT_DIR_INSTALL/backend"
DEFAULT_DIR_BACKEND_SCRIPTS="$DEFAULT_DIR_BACKEND/scripts"
DEFAULT_DIR_BACKEND_VENV="$DEFAULT_DIR_BACKEND/venv"
DEFAULT_DIR_PYTHON="$DEFAULT_DIR_BACKEND_VENV/bin/python3"
DEFAULT_DIR_PIP="$DEFAULT_DIR_BACKEND_VENV/bin/pip3"
DEFAULT_DIR_BACKUP="$DEFAULT_DIR_INSTALL/backup"
DEFAULT_DIR_BACKUP_NGINX="$DEFAULT_DIR_BACKUP/nginx"
DEFAULT_DIR_BACKUP_HTTPS="$DEFAULT_DIR_BACKUP/https"
DEFAULT_DIR_CONF="$DEFAULT_DIR_INSTALL/conf"
DEFAULT_DIR_CONF_NGINX="$DEFAULT_DIR_CONF/nginx"
DEFAULT_DIR_CONF_TEMPLATES="$DEFAULT_DIR_CONF/templates"
DEFAULT_DIR_CONF_HTTPS="$DEFAULT_DIR_CONF/https"
DEFAULT_DIR_CONF_CAMERA="$DEFAULT_DIR_CONF/cameras"
DEFAULT_DIR_DATA="$DEFAULT_DIR_INSTALL/data"
DEFAULT_DIR_FRONTEND="$DEFAULT_DIR_INSTALL/frontend"
DEFAULT_DIR_FRONTEND_CSS="$DEFAULT_DIR_FRONTEND/css"
DEFAULT_DIR_FRONTEND_FONTS="$DEFAULT_DIR_FRONTEND/fonts"
DEFAULT_DIR_FRONTEND_JS="$DEFAULT_DIR_FRONTEND/js"
DEFAULT_DIR_FRONTEND_PHOTOS="$DEFAULT_DIR_FRONTEND/photos"
DEFAULT_DIR_FRONTEND_PHOTOS_ORIGINAL="$DEFAULT_DIR_FRONTEND_PHOTOS/original"
DEFAULT_DIR_FRONTEND_PHOTOS_THUMBNAILS="$DEFAULT_DIR_FRONTEND_PHOTOS/thumbnails"
DEFAULT_DIR_FRONTEND_PICTURE="$DEFAULT_DIR_FRONTEND/picture"

DEFAULT_DIR_LOG="$DEFAULT_DIR_INSTALL/log"
DEFAULT_DIR_TMP="$DEFAULT_DIR_INSTALL/tmp"

# Fallback-Pfade für den Fall, dass Standardpfade nicht verfügbar sind
FALLBACK_DIR_INSTALL="/var/lib/fotobox"
FALLBACK_DIR_BACKEND="$FALLBACK_DIR_INSTALL/backend"
FALLBACK_DIR_BACKEND_SCRIPTS="$FALLBACK_DIR_INSTALL/backend/scripts"
FALLBACK_DIR_BACKEND_VENV="$FALLBACK_DIR_INSTALL/backend/venv"
FALLBACK_DIR_PYTHON="$DEFAULT_DIR_BACKEND_VENV/bin/python"
FALLBACK_DIR_BACKUP="/var/backups/fotobox"
FALLBACK_DIR_BACKUP_NGINX="$FALLBACK_DIR_BACKUP/nginx"
FALLBACK_DIR_BACKUP_HTTPS="$FALLBACK_DIR_BACKUP/https"
FALLBACK_DIR_CONF="/etc/fotobox"
FALLBACK_DIR_CONF_NGINX="$FALLBACK_DIR_CONF/nginx"
FALLBACK_DIR_CONF_TEMPLATES="$FALLBACK_DIR_CONF/templates"
FALLBACK_DIR_CONF_HTTPS="$FALLBACK_DIR_CONF/https"
FALLBACK_DIR_CONF_CAMERA="$FALLBACK_DIR_CONF/cameras"
FALLBACK_DIR_DATA="$FALLBACK_DIR_INSTALL/data"
FALLBACK_DIR_FRONTEND="/var/www/html/fotobox"
FALLBACK_DIR_FRONTEND_CSS="$FALLBACK_DIR_FRONTEND/css"
FALLBACK_DIR_FRONTEND_FONTS="$FALLBACK_DIR_FRONTEND/fonts"
FALLBACK_DIR_FRONTEND_JS="$FALLBACK_DIR_FRONTEND/js"
FALLBACK_DIR_FRONTEND_PHOTOS="$FALLBACK_DIR_FRONTEND/photos"
FALLBACK_DIR_FRONTEND_PHOTOS_ORIGINAL="$FALLBACK_DIR_FRONTEND_PHOTOS/original"
FALLBACK_DIR_FRONTEND_PHOTOS_THUMBNAILS="$FALLBACK_DIR_FRONTEND_PHOTOS/thumbnails"
FALLBACK_DIR_FRONTEND_PICTURE="$FALLBACK_DIR_FRONTEND/picture"

FALLBACK_DIR_LOG="/var/log/fotobox"
FALLBACK_DIR_LOG_2="/tmp/fotobox"
FALLBACK_DIR_LOG_3="."
FALLBACK_DIR_BACKUP_NGINX="$FALLBACK_DIR_BACKUP/nginx"
FALLBACK_DIR_BACKUP_HTTPS="$FALLBACK_DIR_BACKUP/https"
FALLBACK_DIR_TMP="/tmp/fotobox"

# Initialisiere Runtime-Variablen mit den Standardwerten
: "${INSTALL_DIR:=$DEFAULT_DIR_INSTALL}"
: "${BACKEND_DIR:=$DEFAULT_DIR_BACKEND}"
: "${BACKEND_VENV_DIR:=$DEFAULT_DIR_BACKEND_VENV}"
: "${PYTHON_EXEC:=$DEFAULT_DIR_PYTHON}"
: "${PIP_EXEC:=$DEFAULT_DIR_PIP}"
: "${BACKUP_DIR:=$DEFAULT_DIR_BACKUP}"
: "${BACKUP_DIR_NGINX:=$DEFAULT_DIR_BACKUP_NGINX}"
: "${BACKUP_DIR_HTTPS:=$DEFAULT_DIR_BACKUP_HTTPS}"
: "${CONF_DIR:=$DEFAULT_DIR_CONF}"
: "${CONF_DIR_NGINX:=$DEFAULT_DIR_CONF_NGINX}"
: "${CONF_DIR_HTTPS:=$DEFAULT_DIR_CONF_HTTPS}"
: "${CONF_DIR_CAMERA:=$DEFAULT_DIR_CONF_CAMERA}"
: "${CONF_DIR_TEMPLATES:=$DEFAULT_DIR_CONF_TEMPLATES}"
: "${DATA_DIR:=$DEFAULT_DIR_DATA}"
: "${FRONTEND_DIR:=$DEFAULT_DIR_FRONTEND}"
: "${FRONTEND_CSS_DIR:=$DEFAULT_DIR_FRONTEND_CSS}"
: "${FRONTEND_FONTS_DIR:=$DEFAULT_DIR_FRONTEND_FONTS}"
: "${FRONTEND_JS_DIR:=$DEFAULT_DIR_FRONTEND_JS}"
: "${FRONTEND_PHOTOS_DIR:=$DEFAULT_DIR_FRONTEND_PHOTOS}"
: "${FRONTEND_PHOTOS_ORIGINAL_DIR:=$DEFAULT_DIR_FRONTEND_PHOTOS_ORIGINAL}"
: "${FRONTEND_PHOTOS_THUMBNAILS_DIR:=$DEFAULT_DIR_FRONTEND_PHOTOS_THUMBNAILS}"
: "${FRONTEND_PICTURE_DIR:=$DEFAULT_DIR_FRONTEND_PICTURE}"

: "${LOG_DIR:=$DEFAULT_DIR_LOG}"
: "${TMP_DIR:=$DEFAULT_DIR_TMP}"

# Zentrale Definition des Skriptverzeichnisses - wird von allen Modulen verwendet
: "${SCRIPT_DIR:=$DEFAULT_DIR_BACKEND_SCRIPTS}"

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

# Standard-Flags
: "${DEBUG_MOD:=0}"          # Legacy-Flag (für Kompatibilität mit älteren Skripten)
: "${UNATTENDED:=0}"

# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
: "${DEBUG_MOD_LOCAL:=0}"    # Lokales Debug-Flag für einzelne Skripte
DEBUG_MOD_GLOBAL=1           # Globales Flag, das alle lokalen überstimmt

# Lademodus für Module
# 0 = Bei Bedarf laden (für laufenden Betrieb)
# 1 = Alle Module sofort laden (für Installation/Update/Deinstallation)
: "${MODULE_LOAD_MODE:=0}"   # Standardmäßig Module nur bei Bedarf laden

# Benutzer- und Berechtigungseinstellungen
DEFAULT_USER="fotobox"
DEFAULT_GROUP="fotobox"
DEFAULT_MODE="755"

# Port-Einstellungen
DEFAULT_HTTP_PORT=80
DEFAULT_HTTPS_PORT=443

# Konfigurationsdatei
DEFAULT_CONFIG_FILE="$DEFAULT_DIR_CONF/fotobox-config.ini"

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
            echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} $message"
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
check_param_debug_0001="INFO: Parameterprüfung für [%s:%s()] Parameter: %s"
check_param_debug_0002="ERROR: Parameter '%s' in Funktion '%s' des Moduls '%s' ist leer oder nicht gesetzt"
#check_param_log_0001="check_param: Parameter '%s' fehlt in Funktion '%s' des Moduls '%s'"

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
    debug "$(printf "$check_param_debug_0001" "$module_name" "$calling_function" "$param_name")" "CLI" "check_param"

    # Überprüfen, ob ein Parameter übergeben wurde
    if [ -z "$param" ]; then
        # Parameter ist leer oder nicht gesetzt
        debug "$(printf "$check_param_debug_0002" "$param_name" "$calling_function" "$module_name")" "CLI" "check_param"
        #log "$(printf "$check_param_log_0001" "$param_name" "$calling_function" "$module_name")" "check_param" "$module_name"
        return 1
    fi
  
    return 0
}

# get_clean_foldername
get_clean_foldername_debug_0001="INFO: Bereinige Name '%s' für Verwendung als Verzeichnisname"
get_clean_foldername_debug_0002="INFO: Name wurde zu '%s' bereinigt"
get_clean_foldername_debug_0003="WARN: Bereinigter Name wäre leer, verwende Standardnamen: %s"

get_clean_foldername() {
    # -----------------------------------------------------------------------
    # get_clean_foldername
    # -----------------------------------------------------------------------
    # Funktion: Bereinigt einen String für die Verwendung als Verzeichnisname
    # Parameter: $1 - Zu bereinigender String
    #            $2 - (Optional) Standardname, falls der bereinigte String leer ist
    #                 Default: "YYYY-MM-DD_event"
    # Rückgabe: Bereinigter String als Verzeichnisname geeignet
    # -----------------------------------------------------------------------
    local input_name="$1"
    local default_name="${2:-$(date +%Y-%m-%d)_event}"
    
    # Debug-Ausgabe eröffnen
    debug "$(printf "$get_clean_foldername_debug_0001" "$input_name")" "CLI" "get_clean_foldername"
    
    # Prüfen, ob ein Name übergeben wurde
    if [ -z "$input_name" ]; then
        debug "$(printf "$get_clean_foldername_debug_0003" "$default_name")" "CLI" "get_clean_foldername"
        echo "$default_name"
        return 0
    fi
    
    # 1. Entferne alles außer Buchstaben, Zahlen, Unterstriche, Bindestriche und Punkte
    # 2. Ersetze Leerzeichen durch Unterstriche
    # 3. Entferne führende und nachfolgende Punkte, Bindestriche und Unterstriche
    local clean_name
    clean_name=$(echo "$input_name" | tr -cd 'a-zA-Z0-9_-. ' | tr ' ' '_' | sed 's/^[_.-]*//;s/[_.-]*$//')
    
    # Wenn der bereinigte Name leer ist, verwende den Standardnamen
    if [ -z "$clean_name" ]; then
        debug "$(printf "$get_clean_foldername_debug_0003" "$default_name")" "CLI" "get_clean_foldername"
        echo "$default_name"
        return 0
    fi
    
    debug "$(printf "$get_clean_foldername_debug_0002" "$clean_name")" "CLI" "get_clean_foldername"
    echo "$clean_name"
    return 0
}

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Standardwerte für Guard-Variablen festlegen
: "${MANAGE_FOLDERS_LOADED:=0}"
: "${MANAGE_FILES_LOADED:=0}"
: "${MANAGE_LOGGING_LOADED:=0}"
: "${MANAGE_NGINX_LOADED:=0}"
: "${MANAGE_HTTPS_LOADED:=0}"
: "${MANAGE_FIREWALL_LOADED:=0}"
: "${MANAGE_PYTHON_ENV_LOADED:=0}"
: "${MANAGE_SQL_LOADED:=0}"
: "${MANAGE_BACKEND_SERVICE_LOADED:=0}"
# ggf. weitere Guard-Variablen hier hinzufügen

# check_module
check_module_debug_0001="[check_module] INFO: Prüfe Modul '%s'"
check_module_debug_0002="[check_module] INFO: Prüfe Guard-Variable"
check_module_debug_0003="[check_module] INFO: Guard-Variable '%s' ist korrekt gesetzt (%s)"
check_module_debug_0004="[check_module] ERROR: Guard-Variable '%s' ist NICHT korrekt gesetzt (%s)"
check_module_debug_0005="[check_module] INFO: Prüfe Pfad-Variable"
check_module_debug_0006="[check_module] INFO: Pfad-Variable '%s' ist korrekt definiert (%s)"
check_module_debug_0007="[check_module] ERROR: Pfad-Variable '%s' ist NICHT korrekt definiert (%s)"
check_module_debug_0008="[check_module] SUCCESS: Modul '%s' wurde korrekt geladen"

check_module() {
    # -----------------------------------------------------------------------
    # Funktion: Überprüft, ob das übergebene Modul korrekt geladen wurde
    # Parameter: $1 - Dateiname des Moduls
    # Rückgabe: 0 = OK, 
    # ........  1 = Guard-Variable des Moduls ist nicht 1
    # ........  2 = Pfadvariable des Moduls ist nicht gesetzt
    # -----------------------------------------------------------------------
    local module_name="$1"
    
    # Extrahiere den Basisnamen ohne .sh Endung für die Variablennamen
    local base_name=$(basename "$module_name" .sh)
    
    # Erstelle die Namen für Guard- und Pfadvariable
    local guard_var="${base_name^^}_LOADED"
    local path_var="${base_name^^}_SH"

    # Debug-Ausgabe
    debug_output "$(printf "$check_module_debug_0001" "$(basename "${module_name%.sh}" | tr '[:lower:]' '[:upper:]')")"

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
bind_resource_debug_0005="[bind_resource] INFO: Versuche Ressource zu laden: '%s'"
bind_resource_debug_0006="[bind_resource] ERROR: Die Datei '%s' existiert nicht oder ist nicht lesbar"
bind_resource_debug_0007="[bind_resource] INFO: Lade '%s'"
bind_resource_debug_0008="[bind_resource] ERROR: Fehler beim Laden von '%s' (Status: %d)"
bind_resource_debug_0009="[bind_resource] INFO: Modul '%s' geladen, Pfad-Variable '%s' gesetzt"
bind_resource_debug_0010="[bind_resource] INFO: Modul '%s' geladen, Guard-Variable '%s' gesetzt"
bind_resource_debug_0011="[bind_resource] ERROR: Fehler - Modul '%s' konnte nicht korrekt geladen werden"
bind_resource_debug_0012="[bind_resource] SUCCESS: Modul '%s' erfolgreich geladen"
bind_resource_debug_0013="[bind_resource] ------------------------------------------------------"
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
    if [ "$(eval echo \$$guard_var_name)" -eq 1 ]; then
        debug_output "$(printf "$bind_resource_debug_0002" "$base_name")"
        return 0  # Bereits geladen, alles OK
    fi
        
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
    debug_output "$(printf "$bind_resource_debug_0007" "${resource_name%.sh}")"
    source "$resource_file"
    local source_result=$?
    if [ $source_result -ne 0 ]; then
        debug_output "$(printf "$bind_resource_debug_0008" "${resource_name%.sh}" "$source_result")"
        echo "$(printf "$bind_resource_log_0003" "${resource_name%.sh}" "$source_result")"
        return 1
    fi

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
    debug_output "$(printf "$bind_resource_debug_0013")"
    return 0  # Erfolgreich geladen
}

# load_resources
load_resources_debug_0001="[load_resources] INFO: Starte Prüfung aller benötigten Ressourcen"
load_resources_debug_0002="[load_resources] INFO: Versuche %s einzubinden ..."
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
            log "STEP: $*"
        }
        
        print_info() { 
            debug_output "print_info (Fallback): $*"
            echo -e "  $*"
            log "INFO: $*"
        }
        
        print_success() { 
            debug_output "print_success (Fallback): $*"
            echo -e "${COLOR_GREEN}  → [OK]${COLOR_RESET} $*"
            log "SUCCESS: $*"
        }
        
        print_warning() { 
            debug_output "print_warning (Fallback): $*"
            echo -e "${COLOR_YELLOW}  → [WARN]${COLOR_RESET} $*"
            log "WARNING: $*"
        }
        
        print_error() { 
            debug_output "print_error (Fallback): $*"
            echo -e "${COLOR_RED}  → [ERROR]${COLOR_RESET} $*" >&2
            log "ERROR: $*"
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
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} $*"
                log "DEBUG: $*"
            fi
        }

        result=0 # kein Fehler, da Fallback-Funktion vorhanden
        debug_output "$(printf "$load_resources_debug_0004" "manage_logging.sh")"
    fi
    
    # 4. manage_nginx.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_nginx.sh")"
    bind_resource "manage_nginx.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_nginx.sh")"
        result=1
    fi

    # 5. manage_https.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_https.sh")"
    bind_resource "manage_https.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_https.sh")"
        result=1
    fi

    # 6. manage_firewall.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_firewall.sh")"
    bind_resource "manage_firewall.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_firewall.sh")"
        result=1
    fi

    # 7. manage_python_env.sh einbinden
    debug_output "$(printf "$load_resources_debug_0002" "manage_python_env.sh")"
    bind_resource "manage_python_env.sh"
    if [ $? -ne 0 ]; then
        debug_output "$(printf "$load_resources_debug_0003" "manage_python_env.sh")"
        result=1
    fi

    # 8. manage_backend_service.sh einbinden
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
