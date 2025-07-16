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
LOG_FILE_EXT_DEFAULT=".log"
TMP_FILE_EXT_DEFAULT=".tmp"
DB_FILE_EXT_DEFAULT=".db"
BACKUP_FILE_EXT_DEFAULT=".bak" #'.zip' ist nicht mehr Standard, da wir keine ZIP-Backups mehr machen.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt
# ---------------------------------------------------------------------------

# _get_file_name
_get_file_name_debug_0001="INFO: Prüfung der Datei: '%s'"
_get_file_name_debug_0002="INFO: Verzeichnispfad zur Datei: %s"
_get_file_name_debug_0003="INFO: Zusammengesetzter Dateiname: %s%s"
_get_file_name_debug_0004="INFO: Prüfung der Datei (exist, read, write, rights) :'%s'"
_get_file_name_debug_0005="ERROR: Fehler beim Erstellen von '%s'"
_get_file_name_debug_0006="WARN: Warnung! <chown> '%s:%s' für '%s' fehlgeschlagen, Eigentümer nicht geändert"
_get_file_name_debug_0007="WARN: Warnung! <chmod> '%s' für '%s' fehlgeschlagen, Berechtigungen nicht geändert"
_get_file_name_debug_0008="SUCCESS: Prüfung erfolgreich für Datei: '%s'"
_get_file_name_debug_0009="ERROR: Datei '%s' nicht gefunden oder nicht lesbar/beschreibbar"

_get_file_name() {
    # -----------------------------------------------------------------------
    # _get_file_name
    # -----------------------------------------------------------------------
    # Funktion....: Gibt nach Prüfung auf Vorhandensein, Beschreibbarkeit und
    # ............  Lese/Schreibrechten den vollständigen Dateipfad zurück.
    # Parameter...: $1 - Name der Datei
    # ............  $2 - (Optional) Dateiendung (Standard: leer)
    # ............  $3 - (Optional) Pfad, in dem die Datei gesucht wird
    # ............  $4 - (Optional) Nutzername, der die Datei besitzen soll
    # ............  $5 - (Optional) Gruppenname, der die Datei besitzen soll
    # ............  $6 - (Optional) Modus (Rechte) der Datei (Standard: 664)
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
    if ! check_param "$name" "name"; then 
        echo ""
        return 1
    fi

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$_get_file_name_debug_0001" "$name")"

    # Prüfen ob der Pfad übergeben wurde
    if [ -z "$path" ]; then
        # Wenn kein Pfad angegeben ist, Standardpfad verwenden
        path="$(get_config_dir)"
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
        touch "$full_path" 2>/dev/null || {
            # Fehler beim Erstellen der Datei, Debug-Ausgabe
            debug "$(printf "$_get_file_name_debug_0005" "$full_path")"
            echo ""
            return 1
        }
        # wenn erzeugen erfolgreich, User, Lese- und Schreibrechte setzen
        chmod "$mode" "$full_path" 2>/dev/null || {
            debug "$(printf "$_get_file_name_debug_0006" "$user" "$group" "$full_path")"
            # Fehler beim chmod ist kein kritischer Fehler
        }
        chown "$user":"$group" "$full_path" 2>/dev/null || {
            debug "$(printf "$_get_file_name_debug_0007" "$mode" "$full_path")"
            # Fehler beim chown ist kein kritischer Fehler
        }
    fi

    # Überprüfen, ob die Datei existiert und lesbar/beschreibbar ist
    if [ -r "$full_path" ] && [ -w "$full_path" ]; then
        # Debug-Ausgabe des vollständigen Pfads
        debug "$(printf "$_get_file_name_debug_0008" "$full_path")"
        echo "$full_path"
        return 0
    else
        # Fehlerausgabe, wenn die Datei nicht lesbar oder beschreibbar ist
        debug "$(printf "$_get_file_name_debug_0009" "$full_path")"
        echo ""
        return 1
    fi
}

# ===========================================================================
# Hauptfunktionen für die Ermittlung von Dateinamen im Projekt
# ===========================================================================

# get_data_file
get_data_file_debug_0001="INFO: Ermittle SQLite-Datenbankdatei"
get_data_file_debug_0002="SUCCESS: Verwende für DB-Datei \$DB_FILENAME: '%s'"
get_data_file_debug_0003="INFO: Genutzter Verzeichnispfad zur SQLite-Datenbankdatei: '%s'"
get_data_file_debug_0004="SUCCESS: Vollständiger Pfad zur SQLite-Datenbankdatei: '%s'"
get_data_file_debug_0005="ERROR: SQLite-Datenbankdatei nicht gefunden oder nicht lesbar/beschreibbar"

get_data_file() {
    # -----------------------------------------------------------------------
    # get_data_file
    # -----------------------------------------------------------------------
    # Funktion.: Gibt den Pfad zu einer SQLite-Datenbankdatei zurück
    # Parameter: keine
    # Rückgabe.: Der vollständige Name, inklusive Pfad zur Datei
    # .........  Exit-Code-> 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local folder_path                         # Pfad zum Konfigurationsordner
    local file_name                           # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$get_data_file_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${DB_FILENAME+x}" ] && [ -n "$DB_FILENAME" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_data_file_debug_0002" "$DB_FILENAME")"
        echo "$DB_FILENAME"
        return 0
    fi

    # Festlegen der Bestandteile für den Dateinamen
    file_name="fotobox"
    file_ext="$DB_FILE_EXT_DEFAULT"
    folder_path="$(get_data_dir)"
    debug "$(printf "$get_data_file_debug_0003" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_data_file_debug_0004" "$full_filename")"
        echo "$full_filename"
        return 0
    else
        # Fehlerfall
        debug "$get_data_file_debug_0005"
        return 1
    fi
}

# get_config_file
get_config_file_debug_0001="INFO: Ermittle Name der Projekt Konfigurationsdatei"
get_config_file_debug_0002="INFO: Verwende für Konfigurationsdatei \$CONFIG_FILENAME: '%s'"
get_config_file_debug_0003="INFO: Genutzter Verzeichnispfad zur Konfigurationsdatei: '%s'"
get_config_file_debug_0004="SUCCESS: Vollständiger Pfad zur Konfigurationsdatei: '%s'"
get_config_file_debug_0005="ERROR: Konfigurationsdatei nicht gefunden oder nicht lesbar/beschreibbar"

# TODO: Diese Funktion kann nach vollständiger Migration der Konfiguration zur SQLite-Datenbank entfernt werden.
# Die Funktion wird durch die Funktionen in manage_settings.sh (get_config_value) ersetzt.
get_config_file() {
    # -----------------------------------------------------------------------
    # get_config_file
    # -----------------------------------------------------------------------
    # Funktion : Gibt den Pfad zu einer Projekt-Konfigurationsdatei zurück
    # Parameter: keine
    # Rückgabe : Der vollständige Name, inklusive Pfad zur Datei
    # .........  Exit-Code-> 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local folder_path                         # Pfad zum Konfigurationsordner
    local file_name                           # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$get_config_file_debug_0001")"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${CONFIG_FILENAME+x}" ] && [ -n "$CONFIG_FILENAME" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_config_file_debug_0002" "$CONFIG_FILENAME")"
        echo "$CONFIG_FILENAME"
        return 0
    fi

    # Festlegen der Bestandteile für den Dateinamen
    file_name="fotobox"
    file_ext="$CONFIG_FILE_EXT_DEFAULT"
    folder_path="$(get_config_dir)"
    debug "$(printf "$get_config_file_debug_0003" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_config_file_debug_0004" "$full_filename")"
        # System-Variable aktualisieren
        CONFIG_FILENAME="$full_filename"
        export CONFIG_FILENAME
        # Vollständigen Pfad zurückgeben
        echo "$full_filename"
        return 0
    else
        # Fehlerfall
        debug "$get_config_file_debug_0005"
        return 1
    fi
}

# get_log_file
get_log_file_debug_0001="INFO: Ermittle Log-Datei: %s"
get_log_file_debug_0002="SUCCESS: Verwende für Log-Datei \$LOG_FILENAME: '%s'"
get_log_file_debug_0003="INFO: Genutzter Verzeichnispfad zur Log-Datei: '%s'"
get_log_file_debug_0004="SUCCESS: Vollständiger Pfad zur Log-Datei: '%s'"
get_log_file_debug_0005="ERROR: Log-Datei nicht gefunden oder nicht lesbar/beschreibbar"

get_log_file() {
    # -----------------------------------------------------------------------
    # get_log_file
    # -----------------------------------------------------------------------
    # Funktion : Gibt den Pfad zu einer Log-Datei zurück
    # Parameter: Keine
    # Rückgabe : Der vollständige Name, inklusive Pfad zur Datei
    # .........  Exit-Code-> 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local folder_path                         # Pfad zum Konfigurationsordner
    local file_name                           # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$get_log_file_debug_0001")"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${LOG_FILENAME+x}" ] && [ -n "$LOG_FILENAME" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_log_file_debug_0002" "$LOG_FILENAME")"
        echo "$LOG_FILENAME"
        return 0
    fi

    # Festlegen der Bestandteile für den Dateinamen
    file_name="$(date +%Y-%m-%d)_fotobox"
    file_ext="$LOG_FILE_EXT_DEFAULT"
    folder_path="$(get_log_dir)"
    debug "$(printf "$get_log_file_debug_0003" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_log_file_debug_0004" "$full_filename")"
        # System-Variable aktualisieren
        LOG_FILENAME="$full_filename"
        export LOG_FILENAME
        # Vollständigen Pfad zurückgeben
        echo "$full_filename"
        return 0
    fi

    # Fehlerfall
    debug "$get_log_file_debug_0005"
    return 1
}

# get_requirements_system_file
get_requirements_system_file_debug_0001="INFO: Ermittle System-Requirements-Datei"
get_requirements_system_file_debug_0002="SUCCESS: Verwende für Systempaket-Anforderungen-Datei : '%s'"
get_requirements_system_file_debug_0003="INFO: Genutzter Verzeichnispfad zur Systempaket-Anforderungen-Datei: '%s'"
get_requirements_system_file_debug_0004="SUCCESS: Vollständiger Pfad zur Systempaket-Anforderungen-Datei: '%s'"
get_requirements_system_file_debug_0005="ERROR: Systempaket-Anforderungen-Datei nicht gefunden oder nicht lesbar/beschreibbar"

get_requirements_system_file() {
    # -----------------------------------------------------------------------
    # get_requirements_system_file
    # -----------------------------------------------------------------------
    # Funktion : Gibt den Pfad zur Systempaket-Anforderungen-Datei zurück
    # Parameter: Keine
    # Rückgabe : Der vollständige Name, inklusive Pfad zur Datei
    # .........  Exit-Code-> 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local folder_path                         # Pfad zum Konfigurationsordner
    local file_name                           # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$get_requirements_system_file_debug_0001")"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${REQUIREMENTS_SYSTEM_FILENAME+x}" ] && [ -n "$REQUIREMENTS_SYSTEM_FILENAME" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_requirements_system_file_debug_0002" "$REQUIREMENTS_SYSTEM_FILENAME")"
        echo "$REQUIREMENTS_SYSTEM_FILENAME"
        return 0
    fi

    # Festlegen der Bestandteile für den Dateinamen
    file_name="requirements_system"
    file_ext="$CONFIG_FILE_EXT_SYSTEM"
    folder_path="$(get_config_dir)"
    debug "$(printf "$get_requirements_system_file_debug_0003" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_requirements_system_file_debug_0004" "$full_filename")"
        # System-Variable aktualisieren
        REQUIREMENTS_SYSTEM_FILENAME="$full_filename"
        export REQUIREMENTS_SYSTEM_FILENAME
        # Vollständigen Pfad zurückgeben
        echo "$full_filename"
        return 0
    fi

    # Fehlerfall
    debug "$get_requirements_system_file_debug_0005"
    return 1
}

get_requirements_python_file_debug_0001="INFO: Ermittle Python-Requirements-Datei"
get_requirements_python_file_debug_0002="SUCCESS: Verwende für Python-Requirements-Datei : '%s'"
get_requirements_python_file_debug_0003="INFO: Genutzter Verzeichnispfad zur Python-Requirements-Datei: '%s'"
get_requirements_python_file_debug_0004="SUCCESS: Vollständiger Pfad zur Python-Requirements-Datei: '%s'"
get_requirements_python_file_debug_0005="ERROR: Python-Requirements-Datei nicht gefunden oder nicht lesbar/beschreibbar"

get_requirements_python_file() {
    # -----------------------------------------------------------------------
    # get_requirements_python_file
    # -----------------------------------------------------------------------
    # Funktion : Gibt den Pfad zur Python-Requirements-Datei zurück
    # Parameter: Keine
    # Rückgabe : Der vollständige Name, inklusive Pfad zur Datei
    # .........  Exit-Code-> 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local folder_path                         # Pfad zum Konfigurationsordner
    local file_name                           # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$get_requirements_python_file_debug_0001")"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${REQUIREMENTS_PYTHON_FILENAME+x}" ] && [ -n "$REQUIREMENTS_PYTHON_FILENAME" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_requirements_python_file_debug_0002" "$REQUIREMENTS_PYTHON_FILENAME")"
        echo "$REQUIREMENTS_PYTHON_FILENAME"
        return 0
    fi

    # Festlegen der Bestandteile für den Dateinamen
    file_name="requirements_python"
    file_ext="$CONFIG_FILE_EXT_SYSTEM"
    folder_path="$(get_config_dir)"
    debug "$(printf "$get_requirements_python_file_debug_0003" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_requirements_python_file_debug_0004" "$full_filename")"
        # System-Variable aktualisieren
        REQUIREMENTS_PYTHON_FILENAME="$full_filename"
        export REQUIREMENTS_PYTHON_FILENAME
        # Vollständigen Pfad zurückgeben
        echo "$full_filename"
        return 0
    fi

    # Fehlerfall
    debug "$get_requirements_python_file_debug_0005"
    return 1
}

# get_tmp_file
get_tmp_file_debug_0001="INFO: Ermittle temporäre Datei: %s"
get_tmp_file_debug_0002="INFO: Genutzter Verzeichnispfad zur temporären Datei: '%s'"
get_tmp_file_debug_0003="SUCCESS: Vollständiger Pfad zur temporären Datei: '%s'"
get_tmp_file_debug_0004="ERROR: Temporäre Datei nicht gefunden oder nicht lesbar/beschreibbar"

get_tmp_file() {
    # -----------------------------------------------------------------------
    # get_tmp_file
    # -----------------------------------------------------------------------
    # Funktion : Gibt den Pfad zu einer temporären Datei zurück
    # Parameter: keine
    # Rückgabe : Der vollständige Name, inklusive Pfad zur Datei
    # .........  Exit-Code-> 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local folder_path                         # Pfad zum Konfigurationsordner
    local file_name                           # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename

    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$get_tmp_file_debug_0001")"

    # Festlegen der Bestandteile für den Dateinamen
    file_name="fotobox_$(date +%Y%m%d%H%M%S)_$RANDOM"
    file_ext="$TMP_FILE_EXT_DEFAULT"
    folder_path="$(get_tmp_dir)"
    debug "$(printf "$get_tmp_file_debug_0002" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_tmp_file_debug_0003" "$full_filename")"
        echo "$full_filename"
        return 0
    else
        # Fehlerfall
        debug "$get_tmp_file_debug_0004"
        return 1
    fi
}

# get_template_file
get_template_file_debug_0001="INFO: Ermittle Template-Datei für Modul '%s': '%s'"
get_template_file_debug_0002="INFO: Genutzter Verzeichnispfad zur Template-Datei: '%s'"
get_template_file_debug_0003="SUCCESS: Vollständiger Pfad zur Template-Datei: '%s'"
get_template_file_debug_0004="ERROR: Template-Datei nicht gefunden oder nicht lesbar/beschreibbar"

get_template_file() {
    # -----------------------------------------------------------------------
    # get_template_file
    # -----------------------------------------------------------------------
    # Funktion : Gibt den Pfad zu einer Template-Datei zurück
    # Parameter: $1 - Modulname (z.B. nginx, systemd, ssl_cert, etc.)
    # .........  $2 - Template-Name (z.B. default, example, etc.)
    # ..........      Die Extension wird basierend auf dem Modultyp gesetzt.
    # Rückgabe : Der vollständige Name, inklusive Pfad zur Datei
    # .........  Exit-Code-> 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local modul="$1"
    local folder_path                         # Basispfad zum Templateordner
    local file_name="$2"                      # Name der Konfigurationsdatei
    local file_ext                            # Standard-Dateiendung
    local full_filename
    
    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$modul" "modul"; then return 1; fi
    if ! check_param "$file_name" "file_name"; then return 1; fi
    
    # Eröffnungsmeldung für die Debug-Ausgabe
    debug "$(printf "$get_template_file_debug_0001" "$modul" "$file_name")"

    # Festlegen der Bestandteile für den Dateinamen
    # Dateiendung basierend auf dem Modul festlegen
    local file_ext=""
    case "$modul" in
        "nginx")            file_ext="$CONFIG_FILE_EXT_NGINX"
                            folder_path="$(get_template_dir "$modul")" ;;
        "systemd")          file_ext="$CONFIG_FILE_EXT_SYSTEMD"
                            folder_path="$(get_template_dir "$modul")" ;;
        "ssl_cert")         file_ext="$CONFIG_FILE_EXT_SSL_CERT"
                            folder_path="$(get_template_dir "ssl")" ;;
        "ssl_key")          file_ext="$CONFIG_FILE_EXT_SSL_KEY"
                            folder_path="$(get_template_dir "ssl")" ;;
        "backup_meta")      file_ext="$CONFIG_FILE_EXT_BACKUP_META"
                            folder_path="$(get_template_dir "backup")" ;;
        "firewall")         file_ext="$CONFIG_FILE_EXT_FIREWALL"
                            folder_path="$(get_template_dir "$modul")" ;;
        "ssh")              file_ext="$CONFIG_FILE_EXT_SSH"
                            folder_path="$(get_template_dir "$modul")" ;;
        # Verwende den Modulnamen direkt als Dateiendung
        "html"|"js"|"css")  file_ext=".$modul" 
                            folder_path="$(get_template_dir "$modul")";; 
        # Für andere Module keine spezifische Endung hinzufügen
        # Wir nehmen an, dass der Name bereits die korrekte Endung enthält
        *)                  file_ext=".$modul.tmpl"
                            folder_path="$(get_template_dir "$modul")" ;;
    esac
    debug "$(printf "$get_tmp_file_debug_0002" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        # Erfolg: Datei existiert und ist les-/schreibbar
        debug "$(printf "$get_tmp_file_debug_0003" "$full_filename")"
        echo "$full_filename"
        return 0
    else
        # Fehlerfall
        debug "$get_tmp_file_debug_0004"
        return 1
    fi
}

# get_config_file_nginx
get_config_file_nginx_debug_0001="INFO: Ermittle Name der Nginx Konfigurationsdatei"
get_config_file_nginx_debug_0002="INFO: Genutzter Verzeichnispfad zur Nginx Konfigurationsdatei: '%s'"
get_config_file_nginx_debug_0003="SUCCESS: Vollständiger Pfad zur Nginx Konfigurationsdatei: '%s'"
get_config_file_nginx_debug_0004="ERROR: Nginx Konfigurationsdatei nicht gefunden oder nicht lesbar/beschreibbar"

get_config_file_nginx() {
    # -----------------------------------------------------------------------
    # get_config_file_nginx
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Nginx-Konfigurationsdatei zurück
    # Parameter: $1 - Modus der WEB-Server Konfiguration, mögliche Werte:
    # .........  'external'  = Eigene Konfiguration im Projekt Ordner
    # .........  'internal'  = Integration in bestehende Konfig 
    # .........  'activated' = Aktivierte Konfiguration
    # Rückgabewert: Der vollständige Name, inklusive Pfad zur Datei
    # -----------------------------------------------------------------------
    local conf_mode="${1:-external}"    # Standard: 'external' 
    local folder_path                   # Pfad zum Nginx-Konfigurationsordner
    local file_name                     # Name der Nginx-Konfigurationsdatei
    local file_ext                      # Standard-Dateiendung
    local full_filename

    debug "$(printf "$get_config_file_nginx_debug_0001")"

    # Festlegen der Bestandteile für den Dateinamen
    case "$conf_mode" in
        "external")
            # Externe Konfiguration im Projekt Ordner
            folder_path="$(get_config_dir "external")"
            file_name="fotobox_nginx"
            file_ext="$CONFIG_FILE_EXT_NGINX"
            ;;
        "internal")
            # Interne Konfiguration, Integration in bestehende Nginx-Konfig
            folder_path="$(get_nginx_conf_dir "internal")"
            file_name="default"
            file_ext=""
            ;;
        "activated")
            # Aktivierte Konfiguration, z.B. für aktivierte Sites
            folder_path="$(get_nginx_conf_dir "activated")"
            file_name="fotobox_nginx"
            file_ext="$CONFIG_FILE_EXT_NGINX"
            ;;
        *)
            # Fallback auf externe Konfiguration
            folder_path="$(get_config_dir)"
            conf_mode="external"
            file_ext="$CONFIG_FILE_EXT_NGINX"
            ;;
    esac
    debug "$(printf "$get_config_file_nginx_debug_0002" "$folder_path")"

    # Zusammensetzen des vollständigen Dateinamens erfolgreich
    full_filename="$(_get_file_name "$file_name" "$file_ext" "$folder_path")"
    if [ $? -eq 0 ] && [ -n "$full_filename" ]; then
        debug "$(printf "$get_config_file_nginx_debug_0003" "$full_filename")"
        echo "$full_filename"
        return 0
    else
        debug "$get_config_file_nginx_debug_0004"
        return 1
    fi
}

# get_backup_file
get_backup_file_debug_0001="Ermittle Backup-Datei für Komponente: %s"
get_backup_file_debug_0002="Extrahierter Dateiname: %s, Endung: %s"

get_backup_file() {
    # -----------------------------------------------------------------------
    # get_backup_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einer Backup-Datei zurück
    # Parameter: $1 - Komponente die eine Backup-Datei anlegen möchte
    #            $2 - Vollständiger Pfad zur Quelldatei (optional)
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local component="$1"
    local src_file="${2:-$1}"         # Optional: Quell-Datei für den Backup
    local default_ext="$BACKUP_FILE_EXT_DEFAULT"           # Standard-Endung 

    # Debug-Ausgabe eröffnen
    debug "$(printf "$get_backup_file_debug_0001" "$component")"

    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$component" "component"; then return 1; fi
    
    # Dateinamen ohne Pfad extrahieren (nur Basename)
    local basename=$(basename "$src_file")
    
    # Dateiendung extrahieren (letzter Teil nach dem Punkt)
    local extension=""
    if [[ "$basename" == *.* ]]; then
        extension=".${basename##*.}"  # Extrahiert alles nach dem letzten Punkt
        basename="${basename%.*}"     # Entfernt die Endung vom Basename
    else
        # Keine Endung gefunden, verwende Default
        extension="$default_ext"
    fi

    debug "$(printf "$get_backup_file_debug_0002" "$basename" "$extension")"

    # Je nach Komponente den richtigen Backup-Ordner verwenden
    local backup_dir
    case "$component" in
        "photos"|"videos"|"thumbnails")
            # Für Fotos, Videos und Thumbnails den Daten-Backup-Ordner verwenden
            backup_dir="$(get_backup_dir)/$(_get_clean_foldername "$component")"
            ;;
        "data")
            # Für Daten-Backups den Daten-Backup-Ordner verwenden
            backup_dir="$(get_data_backup_dir)"
            ;;
        "nginx")
            # Für Nginx-Konfigurationen den Nginx-Backup-Ordner verwenden
            backup_dir="$(get_nginx_backup_dir)"
            ;;
        "https")
            # Für HTTPS-Zertifikate den HTTPS-Backup-Ordner verwenden
            backup_dir="$(get_https_backup_dir)"
            ;;
        "systemd")
            # Für Systemd-Konfigurationen den Systemd-Backup-Ordner verwenden
            backup_dir="$(get_systemd_backup_dir)"
            ;;
        *)
            # Für andere Komponenten den allgemeinen Backup-Ordner verwenden
            backup_dir="$(get_backup_dir)"
            ;;
    esac

    # Dateinamen generieren und mit Backup-Verzeichnis kombinieren
    echo "${backup_dir}/$(date +%Y-%m-%d_%H-%M-%S)_${basename}${extension}"
}

# get_backup_meta_file
get_backup_meta_file_debug_0001="Ermittle Backup-Metadaten-Datei für Komponente: %s"

get_backup_meta_file() {
    # -----------------------------------------------------------------------
    # get_backup_meta_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Namen einer Backup-Metadaten-Datei zurück
    # Parameter: $1 - Der vollständige Pfad der Backup-Datei
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local src_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$(printf "$get_backup_meta_file_debug_0001" "$src_file")"

    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$src_file" "src_file"; then return 1; fi

    # Backup-Verzeichnis abrufen und Dateinamen generieren
    backup_dir="$("$MANAGE_FOLDERS_SH" get_backup_dir)"
    echo "${src_file}.meta.json"
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

# get_python_cmd
get_python_cmd_debug_0001="INFO: Ermittle Pfad zum Python-Interpreter"
get_python_cmd_debug_0002="SUCCESS: Verwende für Python-Interpreter \$PYTHON_EXEC: %s"
get_python_cmd_debug_0003="SUCCESS: Verwende Standard-Python-Pfad: %s"
get_python_cmd_debug_0004="SUCCESS: Verwende Fallback-Python-Pfad: %s"
get_python_cmd_debug_0005="SUCCESS: Verwendeter als Fallback System-Python3 zum Python-Interpreter: %s"
get_python_cmd_debug_0006="SUCCESS: Verwendeter als Fallback System-Python zum Python-Interpreter: %s"
get_python_cmd_debug_0007="ERROR: Ermittlung des Python-Interpreter fehlgeschlagen. Python scheint nicht installiert zu sein!"

get_python_cmd() {
    # -----------------------------------------------------------------------
    # get_python_cmd
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Python-Interpreter zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Python-Interpreter oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKEND_VENV_DIR gesetzt ist
    : "${BACKEND_VENV_DIR:=$(get_venv_dir)}"
    # Pfade für zum Python-Interpreter-Verzeichnis
    local path_default="$BACKEND_VENV_DIR/bin/python3"
    local path_fallback="$BACKEND_VENV_DIR/bin/python"

    # Prüfen, ob PYTHON_EXEC bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_python_cmd_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${PYTHON_EXEC+x}" ] && [ -n "$PYTHON_EXEC" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_python_cmd_debug_0002" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    fi
    debug "INFO: Suche PYTHON Interpreter im VENV: $path_default und $path_fallback"

    # Python-Interpreter-Pfad ermitteln und setzen
    if [ -x "$path_default" ]; then
        # Verwende Standard-Python-Pfad, wenn ausführbar
        PYTHON_EXEC="$path_default"
        export PYTHON_EXEC
        debug "$(printf "$get_python_cmd_debug_0003" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    elif [ -x "$path_fallback" ]; then
        # Verwende Fallback-Python-Pfad, wenn ausführbar
        PYTHON_EXEC="$path_fallback"
        export PYTHON_EXEC
        debug "$(printf "$get_python_cmd_debug_0004" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    elif command -v python3 &>/dev/null; then
        # Verwende System-Python3, wenn verfügbar
        PYTHON_EXEC="$(command -v python3)"
        export PYTHON_EXEC
        debug "$(printf "$get_python_cmd_debug_0005" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    elif command -v python &>/dev/null; then
        # Verwende System-Python, als letzten Fallback
        PYTHON_EXEC="$(command -v python)"
        export PYTHON_EXEC
        debug "$(printf "$get_python_cmd_debug_0006" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    else
        # Fehlerfall: Kein Python gefunden
        PYTHON_EXEC=""
        debug "$get_python_cmd_debug_0007"
        echo ""
        return 1
    fi
}

# get_pip_cmd
get_pip_cmd_debug_0001="INFO: Ermittle Pfad zur pip-Binary"
get_pip_cmd_debug_0002="SUCCESS: Verwende bereits gesetzten PIP_EXEC: %s"
get_pip_cmd_debug_0003="SUCCESS: Verwende Unix/Linux pip3-Pfad: %s"
get_pip_cmd_debug_0004="SUCCESS: Verwende Unix/Linux pip-Pfad: %s"
get_pip_cmd_debug_0005="SUCCESS: Verwende Python-Modul für pip: %s -m pip"
get_pip_cmd_debug_0006="INFO: Kein pip im venv gefunden, fallback auf System-pip"
get_pip_cmd_debug_0007="SUCCESS: Verwende System-pip3: %s"
get_pip_cmd_debug_0008="SUCCESS: Verwende System-pip: %s"
get_pip_cmd_debug_0009="ERROR: Keine pip-Installation gefunden"

get_pip_cmd() {
    # -----------------------------------------------------------------------
    # get_pip_cmd
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Python-Paketmanager pip im Virtual 
    # ........  Environment zurück
    # Parameter: keine
    # Rückgabe: Pfad zur pip-Binary oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKEND_VENV_DIR gesetzt ist
    : "${BACKEND_VENV_DIR:=$(get_venv_dir)}"
    local pip_cmd
    local python_cmd

    debug "$get_pip_cmd_debug_0001"

    # 1. Prüfe, ob PIP_EXEC bereits korrekt gesetzt ist
    if [ -n "${PIP_EXEC:-}" ] && [ -f "$PIP_EXEC" ] && [ -x "$PIP_EXEC" ]; then
        debug "$(printf "$get_pip_cmd_debug_0002" "$PIP_EXEC")"
        echo "$PIP_EXEC"
        return 0
    fi    

    # 2. Prüfe Standard-Unix/Linux-Pfade im venv
    pip_cmd="${BACKEND_VENV_DIR}/bin/pip3"
    if [ -f "$pip_cmd" ] && [ -x "$pip_cmd" ]; then
        PIP_EXEC="$pip_cmd"
        export PIP_EXEC
        debug "$(printf "$get_pip_cmd_debug_0003" "$pip_cmd")"
        echo "$pip_cmd"
        return 0
    fi

    pip_cmd="${BACKEND_VENV_DIR}/bin/pip"
    if [ -f "$pip_cmd" ] && [ -x "$pip_cmd" ]; then
        PIP_EXEC="$pip_cmd"
        export PIP_EXEC
        debug "$(printf "$get_pip_cmd_debug_0004" "$pip_cmd")"
        echo "$pip_cmd"
        return 0
    fi

    # 3. Fallback: Python-Module pip verwenden
    # python_cmd=$(get_python_cmd)

    #if [ -n "$python_cmd" ] && [ -f "$python_cmd" ] && [ -x "$python_cmd" ]; then
    #    # Prüfen, ob das Python-Modul pip verfügbar ist
    #    if "$python_cmd" -c "import pip" &>/dev/null; then
    #        debug "$(printf "$get_pip_cmd_debug_0005" "$python_cmd")"
    #        PIP_EXEC="$python_cmd -m pip"
    #        export PIP_EXEC
    #        echo "$PIP_EXEC"
    #        return 0
    #    fi
    #fi

    # 4. Systemweite pip-Installation prüfen
    # debug "$get_pip_cmd_debug_0006"

    #if command -v pip3 &>/dev/null; then
    #    pip_cmd=$(command -v pip3)
    #    debug "$(printf "$get_pip_cmd_debug_0007" "$pip_cmd")"
    #    PIP_EXEC="$pip_cmd"
    #    export PIP_EXEC
    #    echo "$PIP_EXEC"
    #    return 0
    #fi

    #if command -v pip &>/dev/null; then
    #    pip_cmd=$(command -v pip)
    #    debug "$(printf "$get_pip_cmd_debug_0008" "$pip_cmd")"
    #    PIP_EXEC="$pip_cmd"
    #    export PIP_EXEC
    #    echo "$PIP_EXEC"
    #    return 0
    #fi

    # 5. Keine pip-Installation gefunden
    debug "$get_pip_cmd_debug_0009"
    echo ""
    return 1
}

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
    # .........  $3 - Optional: Das Systemverzeichnis (Standard: 0)
    # ..........      Wenn '1', wird das Systemverzeichnis verwendet.
    # Rückgabewert: Der vollständige Pfad zur Datei
    # -----------------------------------------------------------------------
    local file_type="$1"
    local name="$2"
    local system_dir="${3:-0}"  
    local file_ext="conf"
    local system_folder
  
    # Überprüfen, ob die erforderlichen Parameter angegeben sind
    if ! check_param "$file_type" "file_type"; then return 1; fi
    if ! check_param "$name" "name"; then return 1; fi

    debug "$(printf "$get_system_file_debug_0001" "$file_type" "$name")"

    # Bestimmen des Ordnerpfads basierend auf dem Dateityp
    case "$file_type" in
        "nginx")
            # Pfad für Nginx-Konfigurationsdateien
            system_folder=$(get_nginx_systemdir)
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0001"
                debug "$get_system_file_log_0001"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0002"
                debug "$get_system_file_log_0002"
                return 1
            fi
            file_ext="$CONFIG_FILE_EXT_NGINX"
            ;;
        "systemd")
            # Pfad für Systemd-Dienste
            system_folder=$(get_systemd_systemdir "$system_dir")
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0003"
                debug "$get_system_file_log_0003"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0004"
                debug "$get_system_file_log_0004"
                return 1
            fi
            file_ext="$CONFIG_FILE_EXT_SYSTEMD"
            ;;
        "ssl_cert")
            # Pfad für SSL-Zertifikate
            system_folder=$(get_ssl_cert_systemdir)
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0005"
                debug "$get_system_file_log_0005"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0006"
                debug "$get_system_file_log_0006"
                return 1
            fi
            file_ext="$CONFIG_FILE_EXT_SSL_CERT"
            ;;
        "ssl_key")
            # Pfad für SSL-Schlüsseldateien
            system_folder=$(get_ssl_key_systemdir)
            if [ $? -ne 0 ]; then
                log "$get_system_file_log_0007"
                debug "$get_system_file_log_0007"
                return 1
            fi

            # Prüfe, ob ein nicht-leeres Ergebnis zurückgegeben wurde
            if [ -z "$system_folder" ]; then
                log "$get_system_file_log_0008"
                debug "$get_system_file_log_0008"
                return 1
            fi
            file_ext="$CONFIG_FILE_EXT_SSL_KEY"
            ;;
        *)
            log "$(printf "$get_system_file_log_0009" "$file_type")"
            debug "$(printf "$get_system_file_log_0009" "$file_type")"
            return 1
            ;;
    esac

    # Debug-Ausgabe des Systemordners
    debug "$(printf "$get_system_file_debug_0002" "$file_type" "$system_folder")"

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
