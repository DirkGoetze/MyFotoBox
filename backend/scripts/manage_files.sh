#!/bin/bash
# ---------------------------------------------------------------------------
# manage_files.sh
# ---------------------------------------------------------------------------
# Funktion: Zentrale Verwaltung für alle Dateipfad-Operationen
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
#
# HINWEIS: Dieses Skript erfordert lib_core.sh und sollte nie direkt 
# .......  aufgerufen werden.
# ---------------------------------------------------------------------------

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_FILES_LOADED=0
# ===========================================================================

# ===========================================================================
# Globale Konstanten
# ===========================================================================
# Die meisten globalen Konstanten werden bereits durch lib_core.sh gesetzt.
# bereitgestellt. Hier definieren wir nur Konstanten, die noch nicht durch 
# lib_core.sh gesetzt wurden oder die speziell für die Installation 
# überschrieben werden müssen.
# ---------------------------------------------------------------------------
# Standardpfade und Fallback-Pfade werden in manage_folders.sh definiert und
# Nutzer- und Ordnereinstellungen werden dort ebenfalls zentral verwaltet
# ---------------------------------------------------------------------------

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
# Standard-Dateierweiterungen für verschiedene Dateitypen
CONFIG_FILE_EXT_DEFAULT=".ini"
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

# _get_file_name
_get_file_name_debug_0001="INFO: Prüfung der Konfigurationsdatei: '%s'"
_get_file_name_debug_0002="INFO: Verzeichnispfad zur Konfigurationsdatei: %s"
_get_file_name_debug_0003="INFO: Zusammengesetzter Dateiname: %s%s"
_get_file_name_debug_0004="INFO: Prüfung der Konfigurationsdatei (exist, read, write, rights) :'%s'"
_get_file_name_debug_0005="SUCCESS: Prüfung erfolgreich für Konfigurationsdatei: '%s'"
_get_file_name_debug_0006="ERROR: Konfigurationsdatei '%s' nicht gefunden oder nicht lesbar/beschreibbar"

_get_file_name() {
    # -----------------------------------------------------------------------
    # _get_file_name
    # -----------------------------------------------------------------------
    # Funktion....: Gibt nach Prüfung auf Vorhandensein, Beschreibbarkeit und
    # ............  Lese/Schreibrechten den vollständigen Dateipfad zurück.
    # Parameter...: $1 - Name der Datei
    # ............  $2 - (Optional) Dateiendung (Standard: leer)
    # ............  $3 - (Optional) Pfad, in dem die Datei gesucht wird
    # ............  $3 - (Optional) Nutzername, der die Datei besitzen soll
    # ............  $4 - (Optional) Gruppenname, der die Datei besitzen soll
    # ............  $5 - (Optional) Modus (Rechte) der Datei (Standard: 664)
    # Hinweis.....: Wird kein Pfad angegeben, wird als Standard der Pfad für 
    # ............  Einstellungen im Projekt Ordner verwendet. Die Parameter
    # ............  $3, $4 und $5 sind optional und werden auf Standardwerte
    # ............  gesetzt, wenn sie nicht angegeben werden. Sie werden nur
    # ............  verwendet, wenn die Datei neu erstellt wird.
    # Rückgabewert: Der vollständige Name der Datei (inkl. Pfad)
    # -----------------------------------------------------------------------
    local name="$1"                   # Name der Datei
    local ext="${2:-""}"              # Dateiendung (optional, Standard leer)
    local path="${3:-""}"             # Pfad, in dem die Datei gesucht wird
    local user="${4:-$DEFAULT_USER}"
    local group="${5:-$DEFAULT_GROUP}"
    local mode="${6:-$DEFAULT_MODE_FILES}"
    local full_path

    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$name" "name"; then return 1; fi

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$_get_file_name_debug_0001" "$name")"

    # Prüfen ob der Pfad übergeben wurde
    if [ -z "$path" ]; then
        # Wenn kein Pfad angegeben ist, Standardpfad verwenden
        path="$(get_conf_dir)"
    fi
    debug "$(printf "$_get_file_name_debug_0002" "$path")"

    # Zusammenstellen des vollständigen Dateinamen
    debug "$(printf "$_get_file_name_debug_0003" "$name" "$ext")"

    # Alles zusammensetzen und sicherstellen, dass $path keine 
    # abschließenden Slashes hat
    full_path="${path%/}/${name}${ext}"
    debug "$(printf "$_get_file_name_debug_0004" "$full_path")"

    # Die Datei existiert nicht, erzeugen und die Rechte setzen
    if [ ! -f "$full_path" ]; then
        # Datei erzeugen und prüfen ob sie erfolgreich erstellt wurde
        touch "$full_path"
        # wenn erzeugen erfolgreich, User, Lese- und Schreibrechte setzen
        if [ $? -eq 0 ]; then
            chmod "$mode" "$full_path"
            chown "$user":"$group" "$full_path"
        fi
    fi

    # Überprüfen, ob die Datei existiert und lesbar/beschreibbar ist
    if [ -r "$full_path" ] && [ -w "$full_path" ]; then
        # Debug-Ausgabe des vollständigen Pfads
        debug "$(printf "$_get_file_name_debug_0005" "$full_path")"
        echo "$full_path"
        return 0
    else
        # Fehlerausgabe, wenn die Datei nicht lesbar oder beschreibbar ist
        debug "$(printf "$_get_file_name_debug_0006" "$full_path")"
        echo ""
        return 1
    fi
}

# ===========================================================================
# Hauptfunktionen für die Ermittlung von Dateipfaden im Projekt
# ===========================================================================

# get_config_file
get_config_file_debug_0001="INFO: Ermittle Name der Projekt Konfigurationsdatei"
get_config_file_debug_0002="INFO: Genutzter Verzeichnispfad zur Konfigurationsdatei: %s"
get_config_file_debug_0003="SUCCESS: Vollständiger Pfad zur Konfigurationsdatei: %s"
get_config_file_debug_0004="ERROR: Konfigurationsdatei nicht gefunden oder nicht lesbar/beschreibbar"

get_config_file() {
    # -----------------------------------------------------------------------
    # get_config_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Projekt-Konfigurationsdatei zurück
    # Parameter: keine
    # Rückgabewert: Der vollständige Name, inklusive Pfad zur Datei
    # -----------------------------------------------------------------------
    local folder_path                         # Pfad zum Konfigurationsordner
    local file_name                           # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$get_config_file_debug_0001")"

    #  Festlegen der Bestandteile für den Dateinamen
    # Bestimmen des Ordnerpfads (später löschen, wird nur optional benötigt)
    file_name="fotobox"
    file_ext="$CONFIG_FILE_EXT_DEFAULT"
    folder_path="$(get_config_dir)"
    debug "$(printf "$get_config_file_debug_0002" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_config_file_debug_0003" "$full_filename")"
        echo "$full_filename"
        return 0
    else
        # Fehlerfall
        debug "$get_config_file_debug_0004"
        return 1
    fi
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
    template_dir="$("$MANAGE_FOLDERS_SH" get_template_dir "$modul")"
    
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

    echo "$(printf "$get_log_file_debug_0001" "$component")"
    debug "$(printf "$get_log_file_debug_0001" "$component")" "CLI" "get_log_file"

    # Verzeichnis abrufen und Dateinamen generieren
    log_dir="$("$MANAGE_FOLDERS_SH" get_log_dir)"
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
    temp_dir="$("$MANAGE_FOLDERS_SH" get_temp_dir)"
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
    backup_dir="$("$MANAGE_FOLDERS_SH" get_backup_dir)"
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
    backup_dir="$("$MANAGE_FOLDERS_SH" get_backup_dir)"
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
            folder_path="$("$MANAGE_FOLDERS_SH" get_photos_dir)"
            ;;
        "thumbnail")
            folder_path="$("$MANAGE_FOLDERS_SH" get_thumbnails_dir)"
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
            system_folder=$("$MANAGE_FOLDERS_SH" get_nginx_systemdir)
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
            system_folder=$("$MANAGE_FOLDERS_SH" get_systemd_systemdir)
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
            system_folder=$("$MANAGE_FOLDERS_SH" get_ssl_cert_systemdir)
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
            system_folder=$("$MANAGE_FOLDERS_SH" get_ssl_key_systemdir)
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
    "$MANAGE_FOLDERS_SH" create_directory "$(dirname "$full_filename")"
    touch "$full_filename"

    if [ $? -eq 0 ]; then
        log "$(printf "$create_empty_file_log_0002" "$full_filename")" "create_empty_file"
        return 0
    else
        log "$(printf "$create_empty_file_log_0003" "$full_filename")" "create_empty_file"
        return 1
    fi
}
