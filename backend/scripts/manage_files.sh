#!/bin/bash
# ---------------------------------------------------------------------------
# manage_files.sh
# ---------------------------------------------------------------------------
# Funktion: Zentrale Stelle für alle Dateipfad-Operationen
# ......... Stellt einheitliche Dateipfad-Getter bereit und arbeitet eng
# ......... mit manage_folders.sh zusammen, das die Ordnerpfade verwaltet.
# ......... Nach Policy müssen alle Skripte Dateien konsistent benennen
# ......... und Pfadermittlungsfunktionen von diesem Modul nutzen.
# ---------------------------------------------------------------------------
# HINWEIS: Dieses Skript ist Bestandteil der Backend-Logik und darf nur im
# Unterordner 'backend/scripts/' abgelegt werden 
# ---------------------------------------------------------------------------
# POLICY-HINWEIS: Dieses Skript ist ein reines Funktions-/Modulskript und 
# enthält keine main()-Funktion mehr. Die Nutzung als eigenständiges 
# CLI-Programm ist nicht vorgesehen. Die Policy zur main()-Funktion gilt nur 
# für Hauptskripte.
# ---------------------------------------------------------------------------
# DEPENDENCY: Dieses Skript nutzt Funktionen aus manage_folders.sh, 
# insbesondere die Verzeichnis-Getter. Die manage_folders.sh muss VOR diesem
# Skript geladen werden!
# ---------------------------------------------------------------------------

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_FILES_LOADED=0

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

# Textausgaben für das gesamte Skript
manage_files_log_0001="KRITISCHER FEHLER: Zentrale Bibliothek lib_core.sh nicht gefunden!"
manage_files_log_0002="Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch."
manage_files_log_0003="KRITISCHER FEHLER: Die Kernressourcen konnten nicht geladen werden."
manage_files_log_0004="KRITISCHER FEHLER: Erforderliches Modul manage_folders.sh nicht geladen!"

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ ! -f "$BASH_DIR/lib_core.sh" ]; then
    echo "$manage_files_log_0001" >&2
    echo "$manage_files_log_0002" >&2
    exit 1
fi

source "$BASH_DIR/lib_core.sh"

# Hybrides Ladeverhalten: 
# Bei MODULE_LOAD_MODE=1 (Installation/Update) werden alle Module geladen
# Bei MODULE_LOAD_MODE=0 (normaler Betrieb) werden Module individuell geladen
if [ "${MODULE_LOAD_MODE:-0}" -eq 1 ]; then
    load_core_resources || {
        echo "$manage_files_log_0003" >&2
        echo "$manage_files_log_0002" >&2
        exit 1
    }
fi

# Prüfe, ob die benötigte manage_folders.sh geladen ist
if [ "${MANAGE_FOLDERS_LOADED:-0}" -eq 0 ]; then
    echo "$manage_files_log_0004" >&2
    echo "$manage_files_log_0002" >&2
    exit 1
fi
# ===========================================================================

# ===========================================================================
# Globale Konstanten
# ===========================================================================
# Die meisten globalen Konstanten werden bereits durch lib_core.sh gesetzt.
# Hier definieren wir nur Konstanten, die noch nicht durch 
# lib_core.sh gesetzt wurden oder die speziell für dieses Modul benötigt werden.
# ---------------------------------------------------------------------------
# Standardpfade und Fallback-Pfade werden in lib_core.sh zentral definiert
# Nutzer- und Ordnereinstellungen werden ebenfalls in lib_core.sh zentral 
# verwaltet
# ---------------------------------------------------------------------------

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
# Standard-Dateierweiterungen für verschiedene Dateitypen
CONFIG_FILE_EXT_NGINX=".conf"
CONFIG_FILE_EXT_CAMERA=".json"
CONFIG_FILE_EXT_SYSTEM=".inf"
CONFIG_FILE_EXT_SYSTEMD=".service"
CONFIG_FILE_EXT_SSL_CERT=".crt"
CONFIG_FILE_EXT_SSL_KEY=".key"
CONFIG_FILE_EXT_BACKUP_META=".meta.json"
CONFIG_FILE_EXT_LOG=".log"
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# System-Dateipfade mit Standardorten
SYSTEM_PATH_NGINX="/etc/nginx/sites-available"
SYSTEM_PATH_SYSTEMD="/etc/systemd/system"
SYSTEM_PATH_SSL_CERT="/etc/ssl/certs"
SYSTEM_PATH_SSL_KEY="/etc/ssl/private"
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Textausgaben für das gesamte Skript (Internationalisierung)
manage_files_error_0001="FEHLER: Kategorie nicht angegeben"
manage_files_error_0002="FEHLER: Name nicht angegeben"
manage_files_error_0003="FEHLER: Unbekannte Dateikategorie: %s"
manage_files_error_0004="FEHLER: Dateityp nicht angegeben"
manage_files_error_0005="FEHLER: Unbekannter Dateityp: %s"
manage_files_error_0006="FEHLER: Komponente nicht angegeben"
manage_files_error_0007="FEHLER: Dateipfad nicht angegeben"
manage_files_error_0008="FEHLER: Konnte Verzeichnis nicht erstellen: %s"

manage_files_info_0001="Dateipfad erstellt: %s"
manage_files_info_0002="Datei existiert bereits: %s"
manage_files_info_0003="Datei erstellt: %s"
# ---------------------------------------------------------------------------

# Textkonstanten
TEXT_UNKNOWN_CATEGORY="Unbekannte Kategorie"
TEXT_TEMPLATE_PATH_ERROR="Fehler beim Abrufen des Template-Pfades für"
# ===========================================================================

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

log_message() {
    # -----------------------------------------------------------------------
    # log_message
    # -----------------------------------------------------------------------
    # Funktion: Adapterfunktion für Logging, die zwischen direktem CLI-Aufruf
    # ......... und Modulaufruf unterscheidet. Bei direktem CLI-Aufruf wird
    # ......... die log_message-Funktion direkt aufgerufen. Bei der Nutzung
    # ......... werden die Standard-Logging-Funktionen aus manage_logging.sh 
    # ......... genutzt
    # -----------------------------------------------------------------------
    local level="$1"
    local message="$2"
    
    case "$level" in
        "debug")
            debug "$message" "Files" "manage_files"
            ;;
        "info")
            info "$message" "Files" "manage_files"
            ;;
        "error")
            error "$message" "Files" "manage_files"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# check_param
check_param_log_0001="ERROR: Parameter nicht angegeben: %s"

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

    # Überprüfen, ob ein Parameter übergeben wurde
    if [ -z "$param" ]; then
        log "$(printf "$check_param_log_0001" "$param_name")" "check_param" "manage_files"
        debug "$(printf "$check_param_log_0001" "$param_name")" "check_param" "manage_files"
        return 1
    fi
  
    return 0
}

# ===========================================================================
# Hauptfunktionen für die Ermittlung von Dateipfaden
# ===========================================================================

# get_config_file
get_config_file_log_0001="ERROR: Unbekannte Kategorie: %s"

get_config_file() {
    # -----------------------------------------------------------------------
    # get_config_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Konfigurationsdatei zurück
    # Parameter: $1 - Die Kategorie der Konfigurationsdatei
    # .........  $2 - Der Name der Konfigurationsdatei (ohne Erweiterung)
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local category="$1"
    local name="$2"
    local folder_path

    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$category" "category"; then return 1; fi
    if ! check_param "$name" "name"; then return 1; fi
    
    # Bestimmen des Ordnerpfads basierend auf der Kategorie
    case "$category" in
        "nginx")
            folder_path="$("$manage_folders_sh" get_nginx_conf_dir)"
            echo "${folder_path}/${name}.conf"
            ;;
        "camera")
            folder_path="$("$manage_folders_sh" get_camera_conf_dir)"
            echo "${folder_path}/${name}.json"
            ;;
        "system")
          folder_path="$("$manage_folders_sh" get_conf_dir)"
          echo "${folder_path}/${name}.inf"
          ;;
        *)
          log "$(printf "$get_config_file_log_0001" "$category")" "get_config_file" "manage_files"
          debug "$(printf "$get_config_file_log_0001" "$category")" "get_config_file" "manage_files"
          return 1
          ;;
    esac
}

# get_system_file
get_system_file_log_0001="ERROR: Konnte Nginx-Systemverzeichnis nicht ermitteln"
get_system_file_log_0002="ERROR: Leeres Ergebnis beim Ermitteln des Nginx-Systemverzeichnisses"
get_system_file_log_0003="ERROR: Konnte systemd-Systemverzeichnis nicht ermitteln"
get_system_file_log_0004="ERROR: Leeres Ergebnis beim Ermitteln des systemd-Systemverzeichnisses"
get_system_file_log_0005="ERROR: Konnte SSL-Zertifikat-Systemverzeichnis nicht ermitteln"
get_system_file_log_0006="ERROR: Leeres Ergebnis beim Ermitteln des SSL-Zertifikat-Systemverzeichnisses"
get_system_file_log_0007="ERROR: Konnte SSL-Schlüssel-Systemverzeichnis nicht ermitteln"
get_system_file_log_0008="ERROR: Leeres Ergebnis beim Ermitteln des SSL-Schlüssel-Systemverzeichnisses"
get_system_file_log_0009="ERROR: Unbekannter Dateityp: %s"

get_system_file() {
    # -----------------------------------------------------------------------
    # get_system_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer System-Konfigurationsdatei zurück
    # ......... Diese Funktion ist speziell für Systemdateien wie Nginx,
    # ......... Systemd-Dienste und SSL-Zertifikate gedacht.
    # Parameter: $1 - Der Typ der Konfigurationsdatei
    # .........  $2 - Der Name der Konfigurationsdatei (ohne Erweiterung)
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local file_type="$1"
    local name="$2"
    local file_ext="conf"
    local system_folder
  
    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$file_type" "file_type"; then return 1; fi
    if ! check_param "$name" "name"; then return 1; fi
  
    # Bestimmen des Ordnerpfads basierend auf dem Dateityp
    case "$file_type" in
        "nginx")
            # Pfad für Nginx-Konfigurationsdateien
            system_folder=$("$manage_folders_sh" get_nginx_systemdir)
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0001" "get_system_file" "manage_files"
                debug "$get_system_file_log_0001" "get_system_file" "manage_files"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0002" "get_system_file" "manage_files" 
                debug "$get_system_file_log_0002" "get_system_file" "manage_files"
                return 1
            fi
            file_ext="conf"
            ;;
        "systemd")
            # Pfad für Systemd-Dienste
            system_folder=$("$manage_folders_sh" get_systemd_systemdir)
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0003" "get_system_file" "manage_files"
                debug "$get_system_file_log_0003" "get_system_file" "manage_files"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0004" "get_system_file" "manage_files"
                debug "$get_system_file_log_0004" "get_system_file" "manage_files"
                return 1
            fi
            file_ext="service"
            ;;
        "ssl_cert")
            # Pfad für SSL-Zertifikate
            system_folder=$("$manage_folders_sh" get_ssl_cert_systemdir)
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0005" "get_system_file" "manage_files"
                debug "$get_system_file_log_0005" "get_system_file" "manage_files"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0006" "get_system_file" "manage_files"
                debug "$get_system_file_log_0006" "get_system_file" "manage_files"
                return 1
            fi
            file_ext="crt"
            ;;
        "ssl_key")
            # Pfad für SSL-Schlüsseldateien
            system_folder=$("$manage_folders_sh" get_ssl_key_systemdir)
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0007" "get_system_file" "manage_files"
                debug "$get_system_file_log_0007" "get_system_file" "manage_files"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0008" "get_system_file" "manage_files"
                debug "$get_system_file_log_0008" "get_system_file" "manage_files"
                return 1
            fi
            file_ext="key"
            ;;
        *)
            log "$(printf "$get_system_file_log_0009" "$file_type")" "get_config_file" "manage_files"
            debug "$(printf "$get_system_file_log_0009" "$file_type")" "get_config_file" "manage_files"
            return 1
            ;;
    esac
    
    # Rückgabe des vollständigen Pfads zur Systemdatei
    echo "${system_folder}/${name}.${file_ext}"
    return 0
}

get_log_file() {
    # -----------------------------------------------------------------------
    # get_log_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Log-Datei zurück
    # Parameter: $1 - Komponente die eine Log-Datei anlegen möchte
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local component="${1:-fotobox}"
    local log_dir
  
    # Verzeichnis abrufen und Dateinamen generieren
    log_dir="$("$manage_folders_sh" get_log_dir)"
    echo "${log_dir}/$(date +%Y-%m-%d)_${component}.log"
}

get_temp_file() {
    # -----------------------------------------------------------------------
    # get_temp_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer temporären Datei zurück
    # Parameter: $1 - Präfix für den Dateinamen (optional) 
    #            $2 - Suffix für die Dateierweiterung (optional)
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local prefix="${1:-fotobox}"  # Standard-Präfix ist "fotobox"
    local suffix="${2:-.tmp}"     # Standard-Suffix ist .tmp
    local temp_dir
        
    # Temporäres Verzeichnis abrufen und Dateinamen generieren
    temp_dir="$("$manage_folders_sh" get_temp_dir)"
    echo "${temp_dir}/${prefix}_$(date +%Y%m%d%H%M%S)_$RANDOM$suffix"
}

get_backup_file() {
    # -----------------------------------------------------------------------
    # get_backup_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Backup-Datei zurück
    # Parameter: $1 - Komponente die eine Backup-Datei anlegen möchte
    #            $2 - Suffix für die Dateierweiterung (optional)
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local component="$1"
    local extension="${2:-.zip}"  # Default: .zip
    local backup_dir
    
    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$component" "component"; then return 1; fi
    
    # Backup-Verzeichnis abrufen und Dateinamen generieren
    backup_dir="$("$manage_folders_sh" get_backup_dir)"
    echo "${backup_dir}/$(date +%Y-%m-%d)_${component}${extension}"
}

get_backup_meta_file() {
    # -----------------------------------------------------------------------
    # get_backup_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Backup-Metadaten-Datei zurück
    # Parameter: $1 - Komponente die eine Backup-Datei anlegen möchte
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local component="$1"
    local backup_dir
    
    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$component" "component"; then return 1; fi
    
    # Backup-Verzeichnis abrufen und Dateinamen generieren
    backup_dir="$("$manage_folders_sh" get_backup_dir)"
    echo "${backup_dir}/$(date +%Y-%m-%d)_${component}.meta.json"
}

# Gibt den Pfad zu einer Template-Datei zurück
get_template_file_debug_0001="Ermittle Pfad zu Template-Datei für Modul %s, Name %s"
get_template_file_debug_0002="Template-Basisverzeichnis: %s"
get_template_file_debug_0003="Dateiendung für Modul %s: %s"
get_template_file_debug_0004="Vollständiger Template-Pfad: %s"
get_template_file_log_0001="ERROR: Unbekannte Modul-Kategorie: %s"
get_template_file_log_0002="ERROR: Template-Pfad konnte nicht ermittelt werden: %s/%s"
get_template_file_log_0003="INFO: Template-Datei gefunden: %s"

get_template_file() {
    # -----------------------------------------------------------------------
    # get_template_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Template-Datei zurück
    # Parameter: $1 - Modulname
    # .........  $2 - Template-Name
    # Rückgabewert: Der vollständige Pfad zur Datei oder leerer String bei Fehler
    # .......... Exit-Code 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local modul="$1"
    local name="$2"
    
    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$modul" "modul"; then return 1; fi
    if ! check_param "$name" "name"; then return 1; fi
    
    debug "$(printf "$get_template_file_debug_0001" "$modul" "$name")" "CLI" "get_template_file"
    
    # Ermitteln des Template-Basisordners für das Modul
    local template_dir
    template_dir="$("$manage_folders_sh" get_template_dir "$modul")"
    
    if [ $? -ne 0 ] || [ -z "$template_dir" ]; then
        log "$(printf "$get_template_file_log_0002" "$modul" "$name")" "get_template_file"
        return 1
    fi
    
    debug "$(printf "$get_template_file_debug_0002" "$template_dir")" "CLI" "get_template_file"
    
    # Dateiendung basierend auf dem Modul festlegen
    local extension=""
    case "$modul" in
        "nginx")
            extension=".conf"
            ;;
        "systemd")
            extension=".service"
            ;;
        "ssl_cert")
            extension=".crt"
            ;;
        "ssl_key")
            extension=".key"
            ;;
        "backup_meta")
            extension=".meta.json"
            ;;
        "firewall")
            extension=".rules"
            ;;
        "ssh")
            extension=".ssh"
            ;;
        "html"|"js"|"css")
            extension=".$modul"  # Verwende den Modulnamen direkt als Dateiendung
            ;;
        *)
            # Für andere Module keine spezifische Endung hinzufügen
            # Wir nehmen an, dass der Name bereits die korrekte Endung enthält
            extension=""
            ;;
    esac
    
    debug "$(printf "$get_template_file_debug_0003" "$modul" "$extension")" "CLI" "get_template_file"
    
    # Vollständigen Pfad zur Template-Datei erstellen
    local template_path
    if [ -n "$extension" ]; then
        template_path="${template_dir}/${name}${extension}"
    else
        template_path="${template_dir}/${name}"
    fi
    
    debug "$(printf "$get_template_file_debug_0004" "$template_path")" "CLI" "get_template_file"
    
    # Überprüfen, ob der Pfad gültig ist (keine Fehlerprüfung, ob die Datei existiert)
    if [ -z "$template_path" ]; then
        log "$(printf "$get_template_file_log_0002" "$modul" "$name")" "get_template_file"
        return 1
    fi
    
    log "$(printf "$get_template_file_log_0003" "$template_path")" "get_template_file"
    echo "$template_path"
    return 0
}

# Gibt den Pfad zu einer Bilddatei zurück
get_image_file() {
    local type="$1"    # z.B. "original", "thumbnail"
    local filename="$2"
    local folder_path
    
    if ! check_param "$type" "type"; then return 1; fi
    if ! check_param "$filename" "filename"; then return 1; fi
    
    case "$type" in
        "original")
            folder_path="$("$manage_folders_sh" get_photos_dir)"
            ;;
        "thumbnail")
            folder_path="$("$manage_folders_sh" get_thumbnails_dir)"
            ;;
        *)
            log_message error "$TEXT_UNKNOWN_CATEGORY: $type"
            return 1
            ;;
    esac
    
    echo "${folder_path}/${filename}"
}

# -----------------------------------------------
# DATEIVERWALTUNGSFUNKTIONEN
# -----------------------------------------------

# Prüft, ob eine Datei existiert
file_exists() {
    local file_path="$1"
    
    if ! check_param "$file_path" "file_path"; then return 1; fi
    
    if [ -f "$file_path" ]; then
        return 0
    else
        return 1
    fi
}

# Erstellt eine leere Datei
create_empty_file() {
    local file_path="$1"
    if ! check_param "$file_path" "file_path"; then return 1; fi
  
    if file_exists "$file_path"; then
        log_message "info" "$(printf "$manage_files_info_0002" "$file_path")"
        return 0
    fi
  
    # Verzeichnis für die Datei erstellen
    "$manage_folders_sh" create_directory "$(dirname "$file_path")"
    touch "$file_path"
  
    if [ $? -eq 0 ]; then
        log_message "info" "$(printf "$manage_files_info_0003" "$file_path")"
        return 0
    else
        log_message "error" "Konnte Datei nicht erstellen: $file_path"
        return 1
    fi
}

# ===========================================================================
# Abschluss: Markiere dieses Modul als geladen
# ===========================================================================
MANAGE_FILES_LOADED=1
