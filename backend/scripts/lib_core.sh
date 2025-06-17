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

# ===========================================================================
# Zentrale Konstanten für das gesamte Fotobox-System
# ===========================================================================
# Primäre Pfaddefinitionen (Single Source of Truth)
DEFAULT_INSTALL_DIR="/opt/fotobox"
DEFAULT_BASH_DIR="$DEFAULT_INSTALL_DIR/backend/scripts"
DEFAULT_BACKUP_DIR="$DEFAULT_INSTALL_DIR/backup"
DEFAULT_CONF_DIR="$DEFAULT_INSTALL_DIR/conf"
DEFAULT_DATA_DIR="$DEFAULT_INSTALL_DIR/data"
DEFAULT_LOG_DIR="$DEFAULT_INSTALL_DIR/log"
DEFAULT_FRONTEND_DIR="$DEFAULT_INSTALL_DIR/frontend"

# Fallback-Pfade für den Fall, dass Standardpfade nicht verfügbar sind
FALLBACK_INSTALL_DIR="/var/lib/fotobox"
FALLBACK_BASH_DIR="/var/lib/fotobox/backend/scripts"
FALLBACK_DATA_DIR="/var/lib/fotobox/data"
FALLBACK_BACKUP_DIR="/var/backups/fotobox"
FALLBACK_LOG_DIR="/var/log/fotobox"
FALLBACK_LOG_DIR_2="/tmp/fotobox"
FALLBACK_LOG_DIR_3="."
FALLBACK_FRONTEND_DIR="/var/www/html/fotobox"
FALLBACK_CONF_DIR="/etc/fotobox"

# Initialisiere Runtime-Variablen mit den Standardwerten
: "${INSTALL_DIR:=$DEFAULT_INSTALL_DIR}"
: "${BASH_DIR:=$DEFAULT_BASH_DIR}"
: "${BACKUP_DIR:=$DEFAULT_BACKUP_DIR}"
: "${CONF_DIR:=$DEFAULT_CONF_DIR}"
: "${DATA_DIR:=$DEFAULT_DATA_DIR}"
: "${LOG_DIR:=$DEFAULT_LOG_DIR}"
: "${FRONTEND_DIR:=$DEFAULT_FRONTEND_DIR}"

# Farbkonstanten für Ausgaben (Shell-ANSI)
# ------------------------------------------------------------------------------
# HINWEIS: Für Shellskripte gilt zusätzlich:
# - Fehlerausgaben immer in Rot
# - Ausgaben zu auszuführenden Schritten in Gelb
# - Erfolgsmeldungen in Dunkelgrün
# - Aufforderungen zur Nutzeraktion in Blau
# - Alle anderen Ausgaben nach Systemstandard
# Siehe Funktionsbeispiele und DOKUMENTATIONSSTANDARD.md
# ------------------------------------------------------------------------------
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

# Benutzer- und Berechtigungseinstellungen
DEFAULT_USER="fotobox"
DEFAULT_GROUP="fotobox"
DEFAULT_MODE="755"

# Port-Einstellungen
DEFAULT_HTTP_PORT=80
DEFAULT_HTTPS_PORT=443

# Konfigurationsdatei
DEFAULT_CONFIG_FILE="$DEFAULT_CONF_DIR/fotobox-config.ini"

# Backend Service 
SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"
SYSTEMD_DST="/etc/systemd/system/fotobox-backend.service"

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Standardwerte für Guard-Variablen festlegen
: "${MANAGE_FOLDERS_LOADED:=0}"
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
    # Funktion: Prüfung und Einbindung externer Skript-Ressourcen
    # Parameter: $1 = Name der Guard-Variable (z.B. "MANAGE_FOLDERS_LOADED")
    # .........  $2 = Pfad zur Ressource (z.B. "$BASH_DIR")
    # .........  $3 = Name der benötigten Ressource (z.B. "manage_folders.sh")
    # Rückgabe: 0 = OK, 1 = Ressource nicht verfügbar, 2 = Verzeichnis nicht verfügbar
    # -----------------------------------------------------------------------
    local guard_var_name="$1"
    local resource_path="$2"
    local resource_name="$3"
    
    # Direkte Ausgabe für Debugging-Zwecke (auch ohne Debug-Flag)
    echo "TRACE: bind_resource für $guard_var_name ($resource_name) gestartet" >&2
    
    debug_output "bind_resource: Versuche Ressource zu laden - Guard: $guard_var_name, Pfad: $resource_path, Name: $resource_name"
    
    # Prüfen, ob die Ressource bereits geladen ist
    if [ "$(eval echo \$$guard_var_name)" -ne 0 ]; then
        echo "TRACE: Ressource $resource_name bereits geladen" >&2
        debug_output "bind_resource: Ressource '$resource_name' bereits geladen (Guard: $guard_var_name = $(eval echo \$$guard_var_name))"
        return 0  # Bereits geladen, alles OK
    fi
    
    # Prüfung des Ressourcen-Verzeichnisses
    if [ ! -d "$resource_path" ]; then
        echo "TRACE: Verzeichnis $resource_path nicht gefunden" >&2
        debug_output "bind_resource: Fehler - Verzeichnis '$resource_path' nicht gefunden"
        echo "Fehler: Verzeichnis '$resource_path' nicht gefunden."
        return 2  # Verzeichnis nicht gefunden
    fi
    
    if [ ! -r "$resource_path" ]; then
        echo "TRACE: Verzeichnis $resource_path nicht lesbar" >&2
        debug_output "bind_resource: Fehler - Verzeichnis '$resource_path' nicht lesbar"
        echo "Fehler: Verzeichnis '$resource_path' nicht lesbar."
        return 2  # Verzeichnis nicht lesbar
    fi
    
    # Pfad zur Ressource zusammensetzen
    local resource_file="$resource_path/$resource_name"
    echo "TRACE: Versuche Datei zu laden: $resource_file" >&2
    debug_output "bind_resource: Vollständiger Ressourcen-Pfad: $resource_file"
    
    # Prüfen, ob die Ressource existiert und ausführbar ist
    if [ ! -f "$resource_file" ]; then
        echo "TRACE: Datei $resource_file existiert nicht" >&2
        debug_output "bind_resource: Fehler - Die Datei '$resource_file' existiert nicht"
        echo "Fehler: Die Datei '$resource_file' existiert nicht."
        return 1  # Ressource nicht gefunden
    fi
    
    if [ ! -r "$resource_file" ]; then
        echo "TRACE: Datei $resource_file ist nicht lesbar" >&2
        debug_output "bind_resource: Fehler - Die Datei '$resource_file' ist nicht lesbar"
        echo "Fehler: Die Datei '$resource_file' ist nicht lesbar."
        return 1  # Ressource nicht lesbar
    fi
    
    # Ressource laden
    echo "TRACE: Lade Ressource $resource_file" >&2
    debug_output "bind_resource: Lade Ressource '$resource_file'"
    source "$resource_file"
    local source_result=$?
    echo "TRACE: Laden von $resource_file abgeschlossen mit Status $source_result" >&2
    debug_output "bind_resource: Laden von '$resource_file' abgeschlossen mit Status: $source_result"
    
    # Guard-Variable auf "geladen" setzen (1)
    eval "$guard_var_name=1"
    echo "TRACE: Guard-Variable $guard_var_name auf 1 gesetzt" >&2
    debug_output "bind_resource: Guard-Variable $guard_var_name auf 1 (geladen) gesetzt"
    
    return 0  # Erfolgreich geladen
}

chk_resources() {
    # -----------------------------------------------------------------------
    # Funktion: Prüfung und Einbindung aller benötigten Skript-Ressourcen
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = mind. eine Ressource fehlt oder ist nicht nutzbar
    # -----------------------------------------------------------------------
    local result=0
    
    debug_output "chk_resources: Starte Prüfung aller benötigten Ressourcen"
    
    # 1. manage_folders.sh einbinden
    debug_output "chk_resources: Versuche manage_folders.sh einzubinden"
    bind_resource "MANAGE_FOLDERS_LOADED" "$BASH_DIR" "manage_folders.sh"
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
    
    # 2. manage_logging.sh einbinden
    debug_output "chk_resources: Versuche manage_logging.sh einzubinden"
    bind_resource "MANAGE_LOGGING_LOADED" "$BASH_DIR" "manage_logging.sh"
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
            debug_output "print_prompt (Fallback): $*"
            if [ "${UNATTENDED:-0}" -eq 0 ]; then
                echo -e "\n${COLOR_BLUE}$*${COLOR_RESET}\n"
            fi
            log "PROMPT: $*"
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
    
    # 3. manage_nginx.sh einbinden
    debug_output "chk_resources: Versuche manage_nginx.sh einzubinden"
    bind_resource "MANAGE_NGINX_LOADED" "$BASH_DIR" "manage_nginx.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_nginx.sh"
        echo "Fehler: manage_nginx.sh konnte nicht geladen werden."
        result=1
    fi

    # 4. manage_https.sh einbinden
    debug_output "chk_resources: Versuche manage_https.sh einzubinden"
    bind_resource "MANAGE_HTTPS_LOADED" "$BASH_DIR" "manage_https.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_https.sh"
        echo "Fehler: manage_https.sh konnte nicht geladen werden."
        result=1
    fi

    # 5. manage_firewall.sh einbinden
    debug_output "chk_resources: Versuche manage_firewall.sh einzubinden"
    bind_resource "MANAGE_FIREWALL_LOADED" "$BASH_DIR" "manage_firewall.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_firewall.sh"
        echo "Fehler: manage_firewall.sh konnte nicht geladen werden."
        result=1
    fi

    # 6. manage_python_env.sh einbinden
    debug_output "chk_resources: Versuche manage_python_env.sh einzubinden"
    bind_resource "MANAGE_PYTHON_ENV_LOADED" "$BASH_DIR" "manage_python_env.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_python_env.sh"
        echo "Fehler: manage_python_env.sh konnte nicht geladen werden."
        result=1
    fi

    # 7. manage_sql.sh einbinden
    debug_output "chk_resources: Versuche manage_sql.sh einzubinden"
    bind_resource "MANAGE_SQL_LOADED" "$BASH_DIR" "manage_sql.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_sql.sh"
        echo "Fehler: manage_sql.sh konnte nicht geladen werden."
        result=1
    fi

    # 8. manage_backend_service.sh einbinden
    debug_output "chk_resources: Versuche manage_backend_service.sh einzubinden"
    bind_resource "MANAGE_BACKEND_SERVICE_LOADED" "$BASH_DIR" "manage_backend_service.sh"
    if [ $? -ne 0 ]; then
        debug_output "chk_resources: Fehler beim Laden von manage_backend_service.sh"
        echo "Fehler: manage_backend_service.sh konnte nicht geladen werden."
        result=1
    fi

    debug_output "chk_resources: Prüfung aller Ressourcen abgeschlossen mit Ergebnis: $result"
    return $result
}

load_core_resources() {
    # -----------------------------------------------------------------------
    # Funktion: Lädt alle Kernressourcen für ein Skript
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = mind. eine Ressource fehlt oder ist nicht nutzbar
    # -----------------------------------------------------------------------
    echo "TRACE: load_core_resources wird ausgeführt" >&2
    debug_output "load_core_resources: Starte das Laden aller Kernressourcen"
    
    # Direkt chk_resources aufrufen ohne Zuweisung (könnte Probleme verursachen)
    echo "TRACE: Rufe chk_resources direkt auf" >&2
    chk_resources
    local status=$?
    
    echo "TRACE: chk_resources abgeschlossen mit Status $status" >&2
    debug_output "load_core_resources: Laden aller Kernressourcen abgeschlossen mit Status: $status"
    return $status
}

# ===========================================================================
# Markiere diese Bibliothek als geladen
LIB_CORE_LOADED=1

