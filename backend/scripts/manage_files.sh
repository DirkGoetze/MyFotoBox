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
# Im Testmodus wird die strikte Abhängigkeitsprüfung deaktiviert
if [ "${MANAGE_FOLDERS_LOADED:-0}" -eq 0 ] && [ "${TEST_MODE:-0}" -ne 1 ]; then
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
CONFIG_FILE_EXT_FIREWALL=".rules"
CONFIG_FILE_EXT_SSH=".ssh"
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt
# ---------------------------------------------------------------------------

# ===========================================================================
# Hauptfunktionen für die Ermittlung von Projekt Dateipfaden
# ===========================================================================

# get_config_file
get_config_file_debug_0001="Ermittle Pfad zu Konfigurationsdatei für Kategorie %s, Name %s"
get_config_file_debug_0002="Konfigurationsordner für Kategorie %s: %s"
get_config_file_debug_0003="Vollständiger Konfigurationspfad: %s/%s%s"
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
    local file_ext=""

    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$category" "category"; then return 1; fi
    if ! check_param "$name" "name"; then return 1; fi

    debug "$(printf "$get_config_file_debug_0001" "$category" "$name")" "CLI" "get_config_file"

    # Bestimmen des Ordnerpfads basierend auf der Kategorie
    case "$category" in
        "nginx")
            folder_path="$("$manage_folders_sh" get_nginx_conf_dir)"
            file_ext=".conf"
            ;;
        "camera")
            folder_path="$("$manage_folders_sh" get_camera_conf_dir)"
            file_ext=".json"
            ;;
        "system")
            folder_path="$("$manage_folders_sh" get_conf_dir)"
            file_ext=".inf"
            ;;
        *)
          log "$(printf "$get_config_file_log_0001" "$category")" "get_config_file" "manage_files"
          debug "$(printf "$get_config_file_log_0001" "$category")" "get_config_file" "manage_files"
          echo ""
          return 1
          ;;
    esac
    debug "$(printf "$get_config_file_debug_0002" "$category" "$folder_path")" "CLI" "get_config_file"

    # Rückgabe des vollständigen Pfads zur Konfigurationsdatei
    debug "$(printf "$get_config_file_debug_0003" "$folder_path" "$name" "$file_ext")" "CLI" "get_config_file"
    echo "${folder_path}/${name}${file_ext}"
    return 0
}

# get_template_file
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
            extension="$CONFIG_FILE_EXT_NGINX" 
            ;;
        "systemd")
            extension="$CONFIG_FILE_EXT_SYSTEMD"
            ;;
        "ssl_cert")
            extension="$CONFIG_FILE_EXT_SSL_CERT"
            ;;
        "ssl_key")
            extension="$CONFIG_FILE_EXT_SSL_KEY"
            ;;
        "backup_meta")
            extension="$CONFIG_FILE_EXT_BACKUP_META"
            ;;
        "firewall")
            extension="$CONFIG_FILE_EXT_FIREWALL"
            ;;
        "ssh")
            extension="$CONFIG_FILE_EXT_SSH"
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

# get_log_file
get_log_file_debug_0001="Ermittle Log-Datei für Komponente: %s"

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

    debug "$(printf "$get_log_file_debug_0001" "$component")" "CLI" "get_log_file"

    # Verzeichnis abrufen und Dateinamen generieren
    log_dir="$("$manage_folders_sh" get_log_dir)"
    echo "${log_dir}/$(date +%Y-%m-%d)_${component}.log"
}

# get_temp_file
get_temp_file_debug_0001="Generiere temporären Dateinamen mit Präfix '%s' und Suffix '%s'"

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

    debug "$(printf "$get_temp_file_debug_0001" "$prefix" "$suffix")" "CLI" "get_temp_file"

    # Temporäres Verzeichnis abrufen und Dateinamen generieren
    temp_dir="$("$manage_folders_sh" get_temp_dir)"
    echo "${temp_dir}/${prefix}_$(date +%Y%m%d%H%M%S)_$RANDOM$suffix"
}

# get_backup_file
get_backup_file_debug_0001="Ermittle Backup-Datei für Komponente: %s"

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

    debug "$(printf "$get_backup_file_debug_0001" "$component")" "CLI" "get_backup_file"

    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$component" "component"; then return 1; fi
    
    # Backup-Verzeichnis abrufen und Dateinamen generieren
    backup_dir="$("$manage_folders_sh" get_backup_dir)"
    echo "${backup_dir}/$(date +%Y-%m-%d)_${component}${extension}"
}

# get_backup_meta_file
get_backup_meta_file_debug_0001="Ermittle Backup-Metadaten-Datei für Komponente: %s"

get_backup_meta_file() {
    # -----------------------------------------------------------------------
    # get_backup_meta_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Backup-Metadaten-Datei zurück
    # Parameter: $1 - Komponente die eine Backup-Datei anlegen möchte
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local component="$1"
    local backup_dir

    debug "$(printf "$get_backup_meta_file_debug_0001" "$component")" "CLI" "get_backup_meta_file"

    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$component" "component"; then return 1; fi
    
    # Backup-Verzeichnis abrufen und Dateinamen generieren
    backup_dir="$("$manage_folders_sh" get_backup_dir)"
    echo "${backup_dir}/$(date +%Y-%m-%d)_${component}.meta.json"
}

# get_image_file
get_image_file_debug_0001="Ermittle Bilddatei für Typ: %s, Name: %s"
get_image_file_debug_0002="Unbekannter Bildtyp: %s"

get_image_file() {
    # -----------------------------------------------------------------------
    # get_image_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Bilddatei zurück
    # Parameter: $1 - Der Typ des Bildes (z.B. "original", "thumbnail")
    #            $2 - Der Dateiname (ohne Erweiterung)
    # Rückgabewert: Der vollständige Pfad zur Bilddatei
    # -----------------------------------------------------------------------
    local type="$1"    # z.B. "original", "thumbnail"
    local filename="$2"
    local folder_path
    
    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$type" "type"; then return 1; fi
    if ! check_param "$filename" "filename"; then return 1; fi

    debug "$(printf "$get_image_file_debug_0001" "$type" "$filename")" "CLI" "get_image_file"

    # Bild-Verzeichnis abrufen
    case "$type" in
        "original")
            folder_path="$("$manage_folders_sh" get_photos_dir)"
            ;;
        "thumbnail")
            folder_path="$("$manage_folders_sh" get_thumbnails_dir)"
            ;;
        *)
            debug "$(printf "$get_image_file_debug_0002" "$type")" "CLI" "get_image_file"
            log "$(printf "$get_image_file_debug_0002" "$type")" "get_image_file"
            return 1
            ;;
    esac
    
    # Dateinamen generieren
    echo "${folder_path}/${filename}"
}

# ===========================================================================
# Hauptfunktionen für die Ermittlung von System-Dateipfaden
# ===========================================================================

# get_system_file
get_system_file_debug_0001="Ermittle Systemdatei für Typ: %s, Name: %s"
get_system_file_debug_0002="Systemverzeichnis für %s: %s"
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

    debug "$(printf "$get_system_file_debug_0001" "$file_type" "$name")" "CLI" "get_system_file"

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
            file_ext="$CONFIG_FILE_EXT_NGINX"
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
            file_ext="$CONFIG_FILE_EXT_SYSTEMD"
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
            file_ext="$CONFIG_FILE_EXT_SSL_CERT"
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
            file_ext="$CONFIG_FILE_EXT_SSL_KEY"
            ;;
        *)
            log "$(printf "$get_system_file_log_0009" "$file_type")" "get_config_file" "manage_files"
            debug "$(printf "$get_system_file_log_0009" "$file_type")" "get_config_file" "manage_files"
            return 1
            ;;
    esac

    # Debug-Ausgabe des Systemordners
    debug "$(printf "$get_system_file_debug_0002" "$file_type" "$system_folder")" "CLI" "get_system_file"

    # Rückgabe des vollständigen Pfads zur Systemdatei
    echo "${system_folder}/${name}${file_ext}"
    return 0
}

# ===========================================================================
# Allgeme Dateiverwaltungsfunktionen
# ===========================================================================

# file_exists
file_exists_debug_0001="Überprüfe, ob Datei existiert: %s"
file_exists_debug_0002="INFO: Datei existiert bereits: %s"
file_exists_debug_0003="INFO: Datei existiert nicht: %s"
file_exists_log_0001="INFO: Datei existiert bereits: %s"
file_exists_log_0002="INFO: Datei existiert nicht: %s"

file_exists() {
    # -----------------------------------------------------------------------
    # file_exists
    # -----------------------------------------------------------------------
    # Funktion: Überprüft, ob eine Datei existiert
    # Parameter: $1 - Der Pfad zur Datei
    # Rückgabewert: 0 wenn die Datei existiert, 1 wenn nicht
    # -----------------------------------------------------------------------
    local file_path="$1"
    
    # Überprüfen, ob der Dateipfad angegeben ist
    if ! check_param "$file_path" "file_path"; then return 1; fi
    
    debug "$(printf "$file_exists_debug_0001" "$file_path")" "CLI" "file_exists"
 
    # Überprüfen, ob die Datei existiert
    if [ -f "$file_path" ]; then
        debug "$(printf "$file_exists_debug_0002" "$file_path")" "CLI" "file_exists"
        log "$(printf "$file_exists_log_0001" "$file_path")" "get_image_file"
        return 0
    else
        debug "$(printf "$file_exists_debug_0003" "$file_path")" "CLI" "file_exists"
        log "$(printf "$file_exists_log_0002" "$file_path")" "get_image_file"
        return 1
    fi
}

# create_empty_file
create_empty_file_debug_0001="Erstelle leere Datei: %s"
create_empty_file_log_0001="INFO: Datei existiert bereits: %s"
create_empty_file_log_0002="INFO: Datei wurde erstellt: %s"
create_empty_file_log_0003="ERROR: Konnte Datei nicht erstellen: %s"

create_empty_file() {
    # -----------------------------------------------------------------------
    # create_empty_file
    # -----------------------------------------------------------------------
    # Funktion: Erstellt eine leere Datei, wenn sie nicht existiert
    # Parameter: $1 - Der Pfad zur Datei, die erstellt werden soll
    # Rückgabewert: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local full_filename="$1"

    # Überprüfen, ob der Dateipfad angegeben ist
    if ! check_param "$full_filename" "file_path"; then return 1; fi

    # Debug-Ausgabe des Dateipfads
    debug "$(printf "$create_empty_file_debug_0001" "$full_filename")" "CLI" "create_empty_file"

    # Überprüfen, ob die Datei bereits existiert
    if file_exists "$full_filename"; then
        log "$(printf "$create_empty_file_log_0001" "$full_filename")" "create_empty_file"
        return 0
    fi
  
    # Verzeichnis für die Datei erstellen
    "$manage_folders_sh" create_directory "$(dirname "$full_filename")"
    touch "$full_filename"

    if [ $? -eq 0 ]; then
        log "$(printf "$create_empty_file_log_0002" "$full_filename")" "create_empty_file"
        return 0
    else
        log "$(printf "$create_empty_file_log_0003" "$full_filename")" "create_empty_file"
        return 1
    fi
}

# ===========================================================================
# Abschluss: Markiere dieses Modul als geladen
# ===========================================================================
MANAGE_FILES_LOADED=1
