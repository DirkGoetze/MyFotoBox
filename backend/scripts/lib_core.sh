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

# Zentrale Definition des Skriptverzeichnisses - wird von allen Modulen verwendet
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

define_module_paths() {
    # -----------------------------------------------------------------------
    # define_module_paths
    # -----------------------------------------------------------------------
    # Funktion: Definiert Konstanten für die Pfade zu allen Modulen für externe Aufrufe
    # Parameter: keine
    # Rückgabewert: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local script_dir="${SCRIPT_DIR:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")}"
    local prefix="manage_"
    local suffix=".sh"
    
    # Stelle sicher, dass SCRIPT_DIR gesetzt ist
    : "${SCRIPT_DIR:=$script_dir}"
    
    debug "Definiere Modulpfade für externe Aufrufe..." "CLI" "define_module_paths"
    
    # Finde alle manage_*.sh Dateien im Skriptverzeichnis
    local module_files
    if [ -d "$SCRIPT_DIR" ]; then
        module_files=$(find "$SCRIPT_DIR" -maxdepth 1 -name "${prefix}*${suffix}" -type f 2>/dev/null)
        
        if [ -z "$module_files" ]; then
            echo "WARNUNG: Keine Module (${prefix}*${suffix}) im Verzeichnis $SCRIPT_DIR gefunden" >&2
            return 1
        fi
        
        # Exportiere einen Pfadvariable für jedes Modul
        for module_path in $module_files; do
            local module_name=$(basename "$module_path" "$suffix")
            local var_name="${module_name}_sh"
            
            # Definiere die Variable global
            eval "$var_name=\"$module_path\""
            export "$var_name"
            
            debug "Modul-Pfad definiert: $var_name=$module_path" "CLI" "define_module_paths"
        done
        
        debug "Alle Modulpfade wurden erfolgreich definiert" "CLI" "define_module_paths"
        return 0
    else
        echo "FEHLER: Skriptverzeichnis $SCRIPT_DIR existiert nicht" >&2
        return 1
    fi
}

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
            echo -e "\033[1;36m  → [DEBUG]\033[0m $message"
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
check_param_debug_0001="Parameterprüfung durch Funktion '%s' in Modul '%s': %s"
check_param_debug_0002="Parameter '%s' in Funktion '%s' des Moduls '%s' ist leer oder nicht gesetzt"
check_param_log_0001="check_param: Parameter '%s' fehlt in Funktion '%s' des Moduls '%s'"

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

    # Debugging-Ausgabe für die Modul-Identifikation
    debug "$(printf "$check_param_debug_0001" "$calling_function" "$module_name" "$param_name")" "CLI" "check_param"

    # Überprüfen, ob ein Parameter übergeben wurde
    if [ -z "$param" ]; then
        # Parameter ist leer oder nicht gesetzt
        debug "$(printf "$check_param_debug_0002" "$param_name" "$calling_function" "$module_name")" "CLI" "check_param"
        log "$(printf "$check_param_log_0001" "$param_name" "$calling_function" "$module_name")" "check_param" "$module_name"
        return 1
    fi
  
    return 0
}

# ===========================================================================
# Zentrale Konstanten für das gesamte Fotobox-System
# ===========================================================================
# Primäre Pfaddefinitionen (Single Source of Truth)
DEFAULT_DIR_INSTALL="/opt/fotobox"
DEFAULT_DIR_BACKEND="$DEFAULT_DIR_INSTALL/backend"
DEFAULT_DIR_BACKEND_SCRIPTS="$DEFAULT_DIR_BACKEND/scripts"
DEFAULT_DIR_BACKEND_VENV="$DEFAULT_DIR_BACKEND/venv"
DEFAULT_DIR_DATA="$DEFAULT_DIR_INSTALL/data"
DEFAULT_DIR_LOG="$DEFAULT_DIR_INSTALL/log"
DEFAULT_DIR_TMP="$DEFAULT_DIR_INSTALL/tmp"
DEFAULT_DIR_BACKUP="$DEFAULT_DIR_INSTALL/backup"
DEFAULT_DIR_BACKUP_NGINX="$DEFAULT_DIR_BACKUP/nginx"
DEFAULT_DIR_BACKUP_HTTPS="$DEFAULT_DIR_BACKUP/https"
DEFAULT_DIR_CONF="$DEFAULT_DIR_INSTALL/conf"
DEFAULT_DIR_CONF_NGINX="$DEFAULT_DIR_CONF/nginx"
DEFAULT_DIR_CONF_TEMPLATES="$DEFAULT_DIR_CONF/templates"
DEFAULT_DIR_CONF_HTTPS="$DEFAULT_DIR_CONF/https"
DEFAULT_DIR_CONF_CAMERA="$DEFAULT_DIR_CONF/cameras"
DEFAULT_DIR_FRONTEND="$DEFAULT_DIR_INSTALL/frontend"

# Fallback-Pfade für den Fall, dass Standardpfade nicht verfügbar sind
FALLBACK_DIR_INSTALL="/var/lib/fotobox"
FALLBACK_DIR_BACKEND="$FALLBACK_DIR_INSTALL/backend"
FALLBACK_DIR_BACKEND_SCRIPTS="$FALLBACK_DIR_INSTALL/backend/scripts"
FALLBACK_DIR_BACKEND_VENV="$FALLBACK_DIR_INSTALL/backend/venv"
FALLBACK_DIR_DATA="$FALLBACK_DIR_INSTALL/data"
FALLBACK_DIR_BACKUP="/var/backups/fotobox"
FALLBACK_DIR_LOG="/var/log/fotobox"
FALLBACK_DIR_LOG_2="/tmp/fotobox"
FALLBACK_DIR_LOG_3="."
FALLBACK_DIR_FRONTEND="/var/www/html/fotobox"
FALLBACK_DIR_CONF="/etc/fotobox"
FALLBACK_DIR_CONF_NGINX="$FALLBACK_DIR_CONF/nginx"
FALLBACK_DIR_CONF_TEMPLATES="$FALLBACK_DIR_CONF/templates"
FALLBACK_DIR_CONF_HTTPS="$FALLBACK_DIR_CONF/https"
FALLBACK_DIR_CONF_CAMERA="$FALLBACK_DIR_CONF/cameras"
FALLBACK_DIR_BACKUP_NGINX="$FALLBACK_DIR_BACKUP/nginx"
FALLBACK_DIR_BACKUP_HTTPS="$FALLBACK_DIR_BACKUP/https"
FALLBACK_DIR_TMP="/tmp/fotobox"

# Initialisiere Runtime-Variablen mit den Standardwerten
: "${INSTALL_DIR:=$DEFAULT_DIR_INSTALL}"
: "${BACKEND_DIR:=$DEFAULT_DIR_BACKEND}"
# BASH_DIR wurde entfernt und durch SCRIPT_DIR ersetzt
: "${BACKEND_VENV_DIR:=$DEFAULT_DIR_BACKEND_VENV}"
: "${BACKUP_DIR:=$DEFAULT_DIR_BACKUP}"
: "${BACKUP_DIR_NGINX:=$DEFAULT_DIR_BACKUP_NGINX}" 
: "${CONF_DIR:=$DEFAULT_DIR_CONF}"
: "${CONF_DIR_NGINX:=$DEFAULT_DIR_CONF_NGINX}"
: "${CONF_DIR_TEMPLATES:=$DEFAULT_DIR_CONF_TEMPLATES}"
: "${DATA_DIR:=$DEFAULT_DIR_DATA}"
: "${LOG_DIR:=$DEFAULT_DIR_LOG}"
: "${FRONTEND_DIR:=$DEFAULT_DIR_FRONTEND}"
: "${TMP_DIR:=$DEFAULT_DIR_TMP}"

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

bind_resource() {
    # -----------------------------------------------------------------------
    # Funktion: Vereinfachte Version zum Laden von Skript-Ressourcen
    # Parameter: $1 = Name der Guard-Variable (z.B. "MANAGE_FOLDERS_LOADED")
    # .........  $2 = Pfad zur Ressource (z.B. "$SCRIPT_DIR")
    # .........  $3 = Name der benötigten Ressource (z.B. "manage_folders.sh")
    # Rückgabe: 0 = OK, 1 = Ressource nicht verfügbar, 2 = Verzeichnis nicht verfügbar
    # -----------------------------------------------------------------------
    local guard_var_name="$1"
    local resource_path="$2"
    local resource_name="$3"
    local resource_file="$resource_path/$resource_name"
    
    # Prüfen, ob die Ressource bereits geladen ist
    if [ "$(eval echo \$$guard_var_name)" -eq 1 ]; then
        debug_output "bind_resource: Ressource '$resource_name' bereits geladen"
        return 0  # Bereits geladen, alles OK
    fi
    
    debug_output "bind_resource: Versuche Ressource zu laden - '$resource_name'"
    
    # Prüfung des Ressourcen-Verzeichnisses
    if [ ! -d "$resource_path" ] || [ ! -r "$resource_path" ]; then
        debug_output "bind_resource: Fehler - Verzeichnis '$resource_path' nicht gefunden oder nicht lesbar"
        echo "Fehler: Verzeichnis '$resource_path' nicht gefunden oder nicht lesbar."
        return 2
    fi
    
    # Prüfen, ob die Ressourcendatei existiert und lesbar ist
    if [ ! -f "$resource_file" ] || [ ! -r "$resource_file" ]; then
        debug_output "bind_resource: Fehler - Die Datei '$resource_file' existiert nicht oder ist nicht lesbar"
        echo "Fehler: Die Datei '$resource_file' existiert nicht oder ist nicht lesbar."
        return 1
    fi
    
    # Ressource laden
    debug_output "bind_resource: Lade Ressource '$resource_file'"
    source "$resource_file"
    local source_result=$?
    
    if [ $source_result -ne 0 ]; then
        debug_output "bind_resource: Fehler beim Laden von '$resource_file' (Status: $source_result)"
        echo "Fehler: Konnte '$resource_name' nicht laden."
        return 1
    fi
    
    # Prüfen ob die Guard-Variable wirklich auf 1 gesetzt wurde (durch das Skript selbst)
    if [ "$(eval echo \$$guard_var_name)" -ne 1 ]; then
        debug_output "bind_resource: Warnung - Das Modul '$resource_name' hat seine Guard-Variable nicht auf 1 gesetzt"
        echo "Warnung: Das Modul '$resource_name' hat seine Guard-Variable nicht auf 1 gesetzt."
        eval "$guard_var_name=1"  # Sicherstellen, dass die Guard-Variable gesetzt ist
    fi
    
    debug_output "bind_resource: Ressource '$resource_name' erfolgreich geladen"
    return 0  # Erfolgreich geladen
}

load_resources() {
    # -----------------------------------------------------------------------
    # Funktion: Prüfung und Einbindung aller benötigten Skript-Ressourcen
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = mind. eine Ressource fehlt oder ist nicht nutzbar
    # -----------------------------------------------------------------------
    local result=0
    
    debug_output "chk_resources: Starte Prüfung aller benötigten Ressourcen"
    
    # 1. manage_folders.sh einbinden
    debug_output "chk_resources: Versuche manage_folders.sh einzubinden"
    bind_resource "MANAGE_FOLDERS_LOADED" "$SCRIPT_DIR" "manage_folders.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_folders.sh, erstelle Fallback-Funktionen"
        echo "Fehler: manage_folders.sh konnte nicht geladen werden."

        # Minimale Implementierung, falls manage_folders.sh nicht verfügbar ist
        get_log_dir() {
            local dir="./logs"
            debug_output "get_log_dir (Fallback): Versuche Logverzeichnis '$dir' zu erstellen"
            
            # Versuche Standardverzeichnis zu erstellen
            mkdir -p "$dir" 2>/dev/null
            
            # Fallback-Mechanismus, wenn Standardverzeichnis nicht erstellt werden kann
            if [ ! -d "$dir" ]; then
                debug_output "get_log_dir (Fallback): Standardverzeichnis '$dir' nicht erstellbar, versuche Alternativen"
                # Fallback 1: Temporäres Verzeichnis
                if [ -w "/tmp" ]; then
                    debug_output "get_log_dir (Fallback): Verwende /tmp/fotobox_logs"
                    echo "Standard-Logverzeichnis nicht verfügbar, nutze /tmp/fotobox_logs" >&2
                    dir="/tmp/fotobox_logs"
                    mkdir -p "$dir" 2>/dev/null
                # Fallback 2: Aktuelles Verzeichnis
                elif [ -w "." ]; then
                    debug_output "get_log_dir (Fallback): Verwende ./fotobox_logs"
                    echo "Standard-Logverzeichnis nicht verfügbar, nutze ./fotobox_logs" >&2
                    dir="./fotobox_logs"
                    mkdir -p "$dir" 2>/dev/null
                else
                    debug_output "get_log_dir (Fallback): Konnte kein schreibbares Logverzeichnis finden"
                    echo "Fehler: Konnte kein schreibbares Logverzeichnis finden oder erstellen." >&2
                    return 1
                fi
            fi
            
            # Teste Schreibrecht für das Logverzeichnis
            debug_output "get_log_dir (Fallback): Teste Schreibrechte für Verzeichnis '$dir'"
            if ! touch "$dir/test_log.tmp" 2>/dev/null; then
                debug_output "get_log_dir (Fallback): Keine Schreibrechte im Verzeichnis '$dir'"
                echo "Fehler: Keine Schreibrechte im Logverzeichnis $dir" >&2
                return 1
            fi
            rm -f "$dir/test_log.tmp" 2>/dev/null
            
            debug_output "get_log_dir (Fallback): Verwende Logverzeichnis '$dir'"
            echo "$dir"
        }

        result=0 # kein Fehler, da Fallback-Funktion vorhanden
        debug_output "chk_resources: Fallback-Funktion für manage_folders.sh wurde erstellt"
    fi
    
    # 2. manage_files.sh einbinden
    debug_output "chk_resources: Versuche manage_files.sh einzubinden"
    bind_resource "MANAGE_FILES_LOADED" "$SCRIPT_DIR" "manage_files.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_files.sh, erstelle Fallback-Funktionen"
        echo "Fehler: manage_files.sh konnte nicht geladen werden."
        result=1
    fi

    # 3. manage_logging.sh einbinden
    debug_output "chk_resources: Versuche manage_logging.sh einzubinden"
    bind_resource "MANAGE_LOGGING_LOADED" "$SCRIPT_DIR" "manage_logging.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_logging.sh, erstelle Fallback-Funktionen"
        echo "Fehler: manage_logging.sh konnte nicht geladen werden."
        
        # Fallback für Logging bereitstellen mit erweiterten Funktionen
        log() {
            local LOG_FILE="$(get_log_dir)/$(date '+%Y-%m-%d')_fotobox.log"
            debug_output "log (Fallback): Schreibe Log in Datei '$LOG_FILE'"

            # Wenn get_log_file verfügbar ist, verwenden wir diese Funktion
            if type get_log_file &>/dev/null; then
                LOG_FILE=$(get_log_file)
                debug_output "log (Fallback): Verwende get_log_file, Logdatei ist nun '$LOG_FILE'"
            fi
            
            if [ -z "$1" ]; then
                # Bei leerem Parameter: Rotation simulieren
                debug_output "log (Fallback): Leerer Parameter, führe Log-Rotation aus"
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
        debug_output "chk_resources: Fallback-Funktionen für manage_logging.sh wurden erstellt"
    fi
    
    # 4. manage_nginx.sh einbinden
    debug_output "chk_resources: Versuche manage_nginx.sh einzubinden"
    bind_resource "MANAGE_NGINX_LOADED" "$SCRIPT_DIR" "manage_nginx.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_nginx.sh"
        echo "Fehler: manage_nginx.sh konnte nicht geladen werden."
        result=1
    fi

    # 5. manage_https.sh einbinden
    debug_output "chk_resources: Versuche manage_https.sh einzubinden"
    bind_resource "MANAGE_HTTPS_LOADED" "$SCRIPT_DIR" "manage_https.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_https.sh"
        echo "Fehler: manage_https.sh konnte nicht geladen werden."
        result=1
    fi

    # 6. manage_firewall.sh einbinden
    debug_output "chk_resources: Versuche manage_firewall.sh einzubinden"
    bind_resource "MANAGE_FIREWALL_LOADED" "$SCRIPT_DIR" "manage_firewall.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_firewall.sh"
        echo "Fehler: manage_firewall.sh konnte nicht geladen werden."
        result=1
    fi

    # 7. manage_python_env.sh einbinden
    debug_output "chk_resources: Versuche manage_python_env.sh einzubinden"
    bind_resource "MANAGE_PYTHON_ENV_LOADED" "$SCRIPT_DIR" "manage_python_env.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_python_env.sh"
        echo "Fehler: manage_python_env.sh konnte nicht geladen werden."
        result=1
    fi

    # 8. manage_sql.sh einbinden
    debug_output "chk_resources: Versuche manage_sql.sh einzubinden"
    bind_resource "MANAGE_SQL_LOADED" "$SCRIPT_DIR" "manage_sql.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_sql.sh"
        echo "Fehler: manage_sql.sh konnte nicht geladen werden."
        result=1
    fi

    # 9. manage_backend_service.sh einbinden
    debug_output "chk_resources: Versuche manage_backend_service.sh einzubinden"
    bind_resource "MANAGE_BACKEND_SERVICE_LOADED" "$SCRIPT_DIR" "manage_backend_service.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_backend_service.sh"
        echo "Fehler: manage_backend_service.sh konnte nicht geladen werden."
        result=1
    fi

    debug_output "chk_resources: Prüfung aller Ressourcen abgeschlossen mit Ergebnis: $result"
    return $result
}

check_module() {
    # -----------------------------------------------------------------------
    # Funktion: Überprüft, ob ein einzelnes Modul korrekt geladen wurde
    # Parameter: $1 - Name der Guard-Variable (z.B. "MANAGE_FOLDERS_LOADED")
    #            $2 - Name des Moduls für die Ausgabe
    # Rückgabe: 0 = OK, 1 = Fehler (nicht geladen)
    # -----------------------------------------------------------------------
    local guard_var="$1"
    local module_name="$2"
    
    if [ "$(eval echo \$$guard_var)" -ne 1 ]; then
        debug_output "check_module: Modul '$module_name' wurde nicht korrekt geladen (${guard_var}=$(eval echo \$$guard_var))"
        return 1
    else
        debug_output "check_module: Modul '$module_name' erfolgreich geladen"
        return 0
    fi
}

check_all_modules_loaded() {
    # -----------------------------------------------------------------------
    # Funktion: Überprüft, ob alle Module korrekt geladen wurden
    # Parameter: keine
    # Rückgabe: 0 = Alles OK, 1 = Mindestens ein Modul fehlerhaft geladen
    # -----------------------------------------------------------------------
    local all_loaded=true
    local module_count=0
    local modules_loaded=0
    local modules_failed=0
    local failed_modules=""
    
    debug_output "check_all_modules_loaded: Prüfe Status aller Module"
    
    # Alle bekannten Module prüfen
    check_module "MANAGE_FOLDERS_LOADED" "manage_folders.sh" || { all_loaded=false; failed_modules+=" manage_folders.sh"; }
    check_module "MANAGE_FILES_LOADED" "manage_files.sh" || { all_loaded=false; failed_modules+=" manage_files.sh"; }
    check_module "MANAGE_LOGGING_LOADED" "manage_logging.sh" || { all_loaded=false; failed_modules+=" manage_logging.sh"; }
    check_module "MANAGE_NGINX_LOADED" "manage_nginx.sh" || { all_loaded=false; failed_modules+=" manage_nginx.sh"; }
    check_module "MANAGE_HTTPS_LOADED" "manage_https.sh" || { all_loaded=false; failed_modules+=" manage_https.sh"; }
    check_module "MANAGE_FIREWALL_LOADED" "manage_firewall.sh" || { all_loaded=false; failed_modules+=" manage_firewall.sh"; }
    check_module "MANAGE_PYTHON_ENV_LOADED" "manage_python_env.sh" || { all_loaded=false; failed_modules+=" manage_python_env.sh"; }
    check_module "MANAGE_SQL_LOADED" "manage_sql.sh" || { all_loaded=false; failed_modules+=" manage_sql.sh"; }
    check_module "MANAGE_BACKEND_SERVICE_LOADED" "manage_backend_service.sh" || { all_loaded=false; failed_modules+=" manage_backend_service.sh"; }
    # Weitere Module hier hinzufügen, wenn sie Teil des Systems sind
    
    # Modulstatistik ausgeben
    for var in $(compgen -v MANAGE_*_LOADED); do
        module_count=$((module_count + 1))
        if [ "${!var}" -eq 1 ]; then
            modules_loaded=$((modules_loaded + 1))
        else
            modules_failed=$((modules_failed + 1))
        fi
    done
    
    debug_output "check_all_modules_loaded: Ergebnis - Gesamt: $module_count, Geladen: $modules_loaded, Fehlerhaft: $modules_failed"
    
    if $all_loaded; then
        if [ "${DEBUG_MOD_GLOBAL:-0}" = "1" ] || [ "${DEBUG_MOD_LOCAL:-0}" = "1" ]; then
            echo -e "${COLOR_GREEN}Alle Module wurden erfolgreich geladen.${COLOR_RESET}"
        fi
        return 0
    else
        echo -e "${COLOR_RED}Folgende Module konnten nicht korrekt geladen werden:${COLOR_RESET}${failed_modules}"
        return 1
    fi
}

# ===========================================================================
# Hauptteil des Skripts: Ressourcen laden und Module überprüfen
# ===========================================================================
# Initialisieren aller Ressourcen
debug_output "load_resources: Initialisiere alle Ressourcen"

# Versuche, alle benötigten Ressourcen zu laden
load_resources
if [ $? -ne 0 ]; then
    debug_output "load_resources: Fehler beim Laden der Ressourcen, Abbruch"
    echo "Fehler: Einige Ressourcen konnten nicht geladen werden. Bitte überprüfen Sie die Fehlermeldungen."
    exit 1
fi

# Definiere Pfade für externe Modulaufrufe
define_module_paths || echo "WARNUNG: Einige Modul-Pfade konnten nicht definiert werden" >&2

# Überprüfen, ob alle Module korrekt geladen wurden
check_all_modules_loaded
