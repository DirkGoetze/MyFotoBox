#!/bin/bash
# ---------------------------------------------------------------------------
# manage_folders.sh
# ---------------------------------------------------------------------------
# Funktion: Zentrale Verwaltung der Ordnerstruktur für die Fotobox.
# ......... Stellt einheitliche Pfad-Getter bereit und erstellt Ordner bei 
# ......... Bedarf. Nach Policy müssen alle Skripte Pfade konsistent 
# ......... verwalten und sicherstellen, dass Ordner mit den korrekten  
# ......... Berechtigungen existieren.
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
MANAGE_FOLDERS_LOADED=0
# ===========================================================================

# ===========================================================================
# Globale Konstanten (Vorgaben und Defaults für die Installation)
# ===========================================================================
# Die meisten globalen Konstanten werden bereits durch lib_core.sh gesetzt.
# bereitgestellt. Hier definieren wir nur Konstanten, die noch nicht durch 
# lib_core.sh gesetzt wurden oder die speziell für die Installation 
# überschrieben werden müssen.
# ---------------------------------------------------------------------------
# Standardpfade und Fallback-Pfade werden in lib_core.sh zentral definiert
# Nutzer- und Ordnereinstellungen werden ebenfalls in lib_core.sh zentral 
# verwaltet
# ---------------------------------------------------------------------------

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
# System-Dateipfade mit Standardorten
SYSTEM_PATH_NGINX="/etc/nginx/sites-available"
SYSTEM_PATH_SYSTEMD="/etc/systemd/system"
SYSTEM_PATH_SSL="/etc/ssl"
SYSTEM_PATH_SSL_CERT="/etc/ssl/certs"
SYSTEM_PATH_SSL_KEY="/etc/ssl/private"
# ---------------------------------------------------------------------------
# Lokale Aliase für bessere Lesbarkeit
: "${USER:=$DEFAULT_USER}"
: "${GROUP:=$DEFAULT_GROUP}"
: "${MODE:=$DEFAULT_MODE}"
# ---------------------------------------------------------------------------
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt
# ---------------------------------------------------------------------------

# ===========================================================================
# Private Hilfsfunktionen 
# ===========================================================================

# _get_clean_foldername
get_clean_foldername_debug_0001="INFO: Bereinige Name '%s' für Verwendung als Verzeichnisname"
get_clean_foldername_debug_0002="INFO: Name wurde zu '%s' bereinigt"
get_clean_foldername_debug_0003="WARN: Bereinigter Name wäre leer, verwende Standardnamen: %s"

_get_clean_foldername() {
    # -----------------------------------------------------------------------
    # _get_clean_foldername
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
    debug "$(printf "$get_clean_foldername_debug_0001" "$input_name")"
    
    # Prüfen, ob ein Name übergeben wurde
    if [ -z "$input_name" ]; then
        debug "$(printf "$get_clean_foldername_debug_0003" "$default_name")"
        echo "$default_name"
        return 0
    fi
    
    # Die Bereinigungslogik in einzelne Schritte aufteilen für bessere Nachvollziehbarkeit
    # 1. Nur erlaubte Zeichen beibehalten 
    local filtered_name
    filtered_name=$(echo "$input_name" | tr -d "[:cntrl:][:punct:]" | tr -s "[:space:]" "_")
    debug "Schritt 1 (Filterung): '$filtered_name'"
    
    # 2. Führende und nachfolgende Unterstriche entfernen
    local clean_name
    clean_name=$(echo "$filtered_name" | sed 's/^[_]*//;s/[_]*$//')
    debug "Schritt 2 (Trimming): '$clean_name'"
        
    # Wenn der bereinigte Name leer ist, verwende den Standardnamen
    if [ -z "$clean_name" ]; then
        debug "$(printf "$get_clean_foldername_debug_0003" "$default_name")"
        echo "$default_name"
        return 0
    fi
    
    debug "$(printf "$get_clean_foldername_debug_0002" "$clean_name")"
    echo "$clean_name"
    return 0
}

# create_symlink_to_standard_path
create_symlink_to_standard_path_debug_0001="WARN: Standard-Pfad und tatsächlicher Pfad sind identisch"
create_symlink_to_standard_path_debug_0002="ERROR: Keine Schreibrechte im übergeordneten Verzeichnis"
create_symlink_to_standard_path_debug_0003="INFO: Entferne vorhandenes Verzeichnis"
create_symlink_to_standard_path_debug_0004="ERROR: Verzeichnis konnte nicht entfernt werden, möglicherweise nicht leer"
create_symlink_to_standard_path_debug_0005="INFO: Symlink zeigt auf %s, wird auf %s geändert"
create_symlink_to_standard_path_debug_0006="ERROR: Konnte vorhandenen Symlink nicht entfernen"
create_symlink_to_standard_path_debug_0007="INFO: Symlink existiert bereits und zeigt auf das korrekte Ziel"
create_symlink_to_standard_path_debug_0008="ERROR: Eine Datei existiert bereits am Standard-Pfad"
create_symlink_to_standard_path_debug_0009="INFO: Erstelle Symlink von %s zu %s"
create_symlink_to_standard_path_debug_0010="ERROR: Fehler beim Erstellen des Symlinks"
# create_symlink_to_standard_path_log_0001="INFO: Symlink erstellt: %s -> %s"

_create_symlink_to_standard_path() {
    # -----------------------------------------------------------------------
    # _create_symlink_to_standard_path
    # -----------------------------------------------------------------------
    # Funktion: Erstellt einen Symlink vom Standard-Pfad zum tatsächlich
    # ......... verwendeten Fallback-Pfad. Dies hilft bei der Navigation und
    # ......... sorgt für eine konsistente Verzeichnisstruktur.
    # Parameter: $1 - Standard-Pfad, an dem der Symlink erstellt werden soll
    # .........  $2 - Tatsächlich verwendeter Pfad, auf den der Symlink zeigen soll
    # Rückgabe.: 0 - Erfolg (Symlink wurde erstellt oder existiert bereits korrekt)
    # .........  1 - Fehler (Symlink konnte nicht erstellt werden)
    # Extras...: Prüft Schreibrechte und aktualisiert vorhandene Symlinks bei Bedarf
    # -----------------------------------------------------------------------
    local standard_path="$1"
    local actual_path="$2"
    
    # Überprüfung der Parameter
    if ! check_param "$standard_path" "standard_path"; then return 1; fi
    if ! check_param "$actual_path" "actual_path"; then return 1; fi
    
    # Wenn die Pfade identisch sind, kein Symlink nötig
    if [ "$standard_path" = "$actual_path" ]; then
        debug "$create_symlink_to_standard_path_debug_0001: $standard_path"
        return 0
    fi
    
    # Prüfe, ob wir Zugriff auf das übergeordnete Verzeichnis haben
    local parent_dir
    parent_dir=$(dirname "$standard_path")
    if [ ! -w "$parent_dir" ]; then
        debug "$create_symlink_to_standard_path_debug_0002: $parent_dir"
        return 1
    fi

    # Prüfen, ob am Standard-Pfad bereits etwas existiert
    if [ -e "$standard_path" ]; then
        # Falls es ein reguläres Verzeichnis ist, entfernen (mit Vorsicht)
        if [ -d "$standard_path" ] && [ ! -L "$standard_path" ]; then
            debug "$create_symlink_to_standard_path_debug_0003: $standard_path"
            # Es ist sicherer, nur leere Verzeichnisse zu entfernen
            rmdir "$standard_path" 2>/dev/null || {
                debug "$create_symlink_to_standard_path_debug_0004: $standard_path"
                return 1
            }
        # Falls es ein Symlink auf einen anderen Pfad ist, aktualisieren
        elif [ -L "$standard_path" ]; then
            local current_target
            current_target=$(readlink -f "$standard_path")
            if [ "$current_target" != "$actual_path" ]; then
                debug "$(printf "$create_symlink_to_standard_path_debug_0005" "$current_target" "$actual_path")"
                rm -f "$standard_path" 2>/dev/null || {
                    debug "$create_symlink_to_standard_path_debug_0006: $standard_path"
                    return 1
                }
            else
                # Symlink zeigt bereits auf das richtige Ziel
                debug "$create_symlink_to_standard_path_debug_0007: $actual_path"
                return 0
            fi
        # Falls es eine reguläre Datei ist, abbrechen
        elif [ -f "$standard_path" ]; then
            debug "$create_symlink_to_standard_path_debug_0008: $standard_path"
            return 1
        fi
    fi
    
    # Symlink erstellen
    debug "$(printf "$create_symlink_to_standard_path_debug_0009" "$standard_path" "$actual_path")"
    ln -sf "$actual_path" "$standard_path" || {
        debug "$create_symlink_to_standard_path_debug_0010"
        return 1
    }

    # log "$(printf "$create_symlink_to_standard_path_log_0001" "$standard_path" "$actual_path")" "create_symlink_to_standard_path"
    return 0
}

# _create_directory
create_directory_debug_0001="INFO: Verzeichnis '%s' existiert nicht, wird erstellt"
create_directory_debug_0002="ERROR: Fehler beim Erstellen von '%s'"
create_directory_debug_0003="WARN: Warnung! <chown> '%s:%s' für '%s' fehlgeschlagen, Eigentümer nicht geändert"
create_directory_debug_0004="WARN: Warnung! <chmod> '%s' für '%s' fehlgeschlagen, Berechtigungen nicht geändert"
create_directory_debug_0005="INFO: Verzeichnis '%s' erfolgreich vorbereitet"
# create_directory_log_0001="ERROR: create_directory: Kein Verzeichnis angegeben"
# create_directory_log_0002="ERROR: Fehler beim Erstellen des Verzeichnisses %s"
# create_directory_log_0003="INFO: Verzeichnis %s wurde erstellt"
# create_directory_log_0004="WARN: Fehler beim Setzen der Berechtigungen für %s"
# create_directory_log_0005="INFO: Verzeichnis %s erfolgreich vorbereitet"
# create_directory_log_0006="ERROR: Verzeichnis %s konnte nicht korrekt vorbereitet werden"

_create_directory() {
    # -----------------------------------------------------------------------
    # _create_directory
    # -----------------------------------------------------------------------
    # Funktion: Erstellt ein Verzeichnis mit den korrekten Berechtigungen, 
    # .........  wenn es noch nicht existiert
    # Parameter: $1 - Pfad des zu erstellenden Verzeichnisses
    # .........  $2 - (Optional) Benutzername, Standard: "fotobox"
    # .........  $3 - (Optional) Gruppe, Standard: "fotobox"
    # .........  $4 - (Optional) Berechtigungen, Standard: "755"
    # Rückgabe.: 0 - Erfolg (Verzeichnis existiert und hat korrekte Berechtigungen)
    # .........  1 - Fehler (Verzeichnis konnte nicht erstellt werden)
    # Extras...: Fehler beim chown oder chmod werden als Warnung behandelt
    # -----------------------------------------------------------------------
    local dir="$1"
    local user="${2:-$DEFAULT_USER}"
    local group="${3:-$DEFAULT_GROUP}"
    local mode="${4:-$DEFAULT_MODE}"

    # Prüfung der Parameter
    if ! check_param "$dir" "dir"; then return 1; fi

    # Verzeichnis erstellen, falls es nicht existiert
    if [ ! -d "$dir" ]; then
        debug "$(printf "$_create_directory_debug_0001" "$dir")" "CLI" "_create_directory"
        mkdir -p "$dir" || {
            # log "$(printf "$create_directory_log_0002" "$dir")" "create_directory"
            debug "$(printf "$create_directory_debug_0002" "$dir")" "CLI" "_create_directory"
            return 1
        }
        # log "$(printf "$create_directory_log_0003" "$dir")"
    fi

    # Berechtigungen setzen
    chown "$user:$group" "$dir" 2>/dev/null || {
        # log "$(printf "$create_directory_log_0004" "$dir")" "create_directory"
        debug "$(printf "$create_directory_debug_0003" "$user" "$group" "$dir")" "CLI" "_create_directory"
        # Fehler beim chown ist kein kritischer Fehler
    }

    chmod "$mode" "$dir" 2>/dev/null || {
        # log "$(printf "$create_directory_log_0004" "$dir")" "create_directory"
        debug "$(printf "$create_directory_debug_0004" "$mode" "$dir")" "CLI" "_create_directory"
        # Fehler beim chmod ist kein kritischer Fehler
    }

    # Überprüfen, ob das Verzeichnis existiert und lesbar ist
    if [ -d "$dir" ] && [ -r "$dir" ]; then
        # log "$(printf "$create_directory_log_0005" "$dir")" "create_directory"
        debug "$(printf "$create_directory_debug_0005" "$dir")" "CLI" "_create_directory"
        return 0
    else
        # log "$(printf "$create_directory_log_0006" "$dir")" "create_directory"
        return 1
    fi
}

# get_folder_path
get_folder_path_debug_0001="INFO: Prüfe Ordner-Pfade: Systempfad='%s', Standardpfad='%s', Fallbackpfad='%s'"
get_folder_path_debug_0002="INFO: Systempfad (Exist, Rights und User) prüfen ('%s')"
get_folder_path_debug_0003="SUCCESS: Systempfad ok, verwende Systempfad ('%s')"
get_folder_path_debug_0004="INFO: Standardpfad (Exist, Rights und User) prüfen ('%s')"
get_folder_path_debug_0005="SUCCESS: Standardpfad ok, verwende Standardpfad ('%s')"
get_folder_path_debug_0006="INFO: Fallback-Pfad (Exist, Rights und User) prüfen ('%s')"
get_folder_path_debug_0007="SUCCESS: Fallback-Pfad ok, verwende Fallback-Pfad ('%s')"
get_folder_path_debug_0008="INFO: Versuche Symlink von '%s' nach '%s' zu erstellen"
get_folder_path_debug_0009="WARN: Symlink-Erstellung fehlgeschlagen, möglicherweise kein Schreibzugriff im übergeordneten Verzeichnis"
get_folder_path_debug_0010="INFO: Verwende Root-Verzeichnis als letzten Fallback: '%s'"
get_folder_path_debug_0011="SUCCESS: Root-Verzeichnis ok, verwende Root-Verzeichnis: '%s'"
get_folder_path_debug_0012="ERROR: Kein gültiger Pfad für die Ordnererstellung verfügbar, alle Versuche fehlgeschlagen"
# get_folder_path_log_0001="ERROR: Kein gültiger Pfad für die Ordnererstellung verfügbar"

get_folder_path() {
    # -----------------------------------------------------------------------
    # get_folder_path
    # -----------------------------------------------------------------------
    # Funktion: Hilfsfunktion zum Ermitteln und Erstellen eines Ordners mit 
    # .........  Fallback-Logik. Erstellt zusätzlich einen Symlink vom
    # .........  Standard-Pfad zum tatsächlich verwendeten Pfad, wenn möglich.
    # Parameter: $1 - System-Pfad oder bereits definierter Pfad
    # .........  $2 - Standard-Pfad aus lib_core.sh
    # .........  $3 - Fallback-Pfad (falls Standard-Pfad nicht verfügbar)
    # .........  $4 - (Optional) Fallback zum Projekthauptverzeichnis (1=ja, 0=nein, Default: 1)
    # .........  $5 - (Optional) Symlink erstellen (1=ja, 0=nein, Default: 1)
    # Rückgabe.: Den Pfad zum verfügbaren Ordner oder leeren String bei Fehler
    # Extras...: Implementiert eine mehrschichtige Fallback-Strategie
    # -----------------------------------------------------------------------
    local systemdef_path="$1" 
    local standard_path="$2"
    local fallback_path="$3"
    local use_root_fallback="${4:-1}" # Standard: Ja, Root-Fallback verwenden
    local create_symlink="${5:-1}"    # Standard: Ja, Symlink erstellen
    local actual_path=""

    # Überprüfung der Parameter
    if ! check_param "$systemdef_path" "systemdef_path"; then return 1; fi
    if ! check_param "$standard_path" "standard_path"; then return 1; fi
    if ! check_param "$fallback_path" "fallback_path"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$get_folder_path_debug_0001" "$systemdef_path" "$standard_path" "$fallback_path")"

    # Prüfen, ob Systempfad bereits gesetzt ist (z.B. vom install.sh)
    debug "$(printf "$get_folder_path_debug_0002" "$systemdef_path")"
    if _create_directory "$systemdef_path"; then
        debug "$(printf "$get_folder_path_debug_0003" "$systemdef_path")"
        echo "$systemdef_path"
        return 0
    fi

    # Prüfen ob der Standardpfad existiert oder erzeugt werden kann
    debug "$(printf "$get_folder_path_debug_0004" "$standard_path")"
    if _create_directory "$standard_path"; then
        debug "$(printf "$get_folder_path_debug_0005" "$standard_path")"
        echo "$standard_path"
        return 0
    else
        # Versuchen, den Fallback-Pfad zu verwenden
        debug "$(printf "$get_folder_path_debug_0006" "$standard_path")"
        if _create_directory "$fallback_path"; then
            debug "$(printf "$get_folder_path_debug_0007" "$fallback_path")"
            actual_path="$fallback_path"
            
            # Wenn gewünscht und möglich, einen Symlink vom Standard-Pfad zum Fallback erstellen
            if [ "$create_symlink" -eq 1 ]; then
                debug "$(printf "$get_folder_path_debug_0008" "$standard_path" "$fallback_path")"
                _create_symlink_to_standard_path "$standard_path" "$fallback_path" || {
                    debug "$get_folder_path_debug_0009"
                }
            fi
        fi
    fi
    
    if [ -n "$actual_path" ]; then
        echo "$actual_path"
        return 0
    fi

    # Wenn alle Versuche fehlschlagen, eine Fehlermeldung im Log ausgeben
    debug "$(printf "$get_folder_path_debug_0012")"
    # log "$get_folder_path_log_0001" "get_folder_path"
    return 1
}

# ===========================================================================
# Get- und Set-Funktionen für die Ordnerstruktur des Projektes
# ===========================================================================

# get_install_dir
get_install_dir_debug_0001="INFO: Ermittle Installations-Verzeichnis"
get_install_dir_debug_0002="SUCCESS: Verwendeter Pfad für Installations-Verzeichnis: %s"
get_install_dir_debug_0003="Alle Pfade für Installations-Verzeichnis fehlgeschlagen, verwende aktuelles Verzeichnis"

get_install_dir() {
    # -----------------------------------------------------------------------
    # get_install_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Installationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
        
    # Prüfen, ob INSTALL_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_install_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    dir=$(get_folder_path "$INSTALL_DIR" "$DEFAULT_DIR_INSTALL" "$FALLBACK_DIR_INSTALL" 0 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_install_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall das aktuelle Verzeichnis verwenden
    debug "$get_install_dir_debug_0003"
    echo "$(pwd)/fotobox"
    return 0
}

# ---------------------------------------------------------------------------
# Backend-Verzeichnis
# ---------------------------------------------------------------------------

# get_backend_dir
get_backend_dir_debug_0001="INFO: Ermittle Backend-Verzeichnis"
get_backend_dir_debug_0002="SUCCESS: Verwendeter Pfad für Backend-Verzeichnis: %s"
get_backend_dir_debug_0003="ERROR: Alle Pfade für Backend-Verzeichnis fehlgeschlagen"

get_backend_dir() {
    # -----------------------------------------------------------------------
    # get_backend_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Backend-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
        
    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_backend_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$BACKEND_DIR" "$DEFAULT_DIR_BACKEND" "$FALLBACK_DIR_BACKEND" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_backend_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_backend_dir_debug_0003"
    echo ""
    return 1
}

# get_script_dir
get_script_dir_debug_0001="INFO: Ermittle Backend-Skript-Verzeichnis"
get_script_dir_debug_0002="SUCCESS: Verwendeter Pfad für Backend-Skript-Verzeichnis: %s"
get_script_dir_debug_0003="ERROR: Alle Pfade für Backend-Skript-Verzeichnis fehlgeschlagen"

get_script_dir() {
    # -----------------------------------------------------------------------
    # get_script_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Backend-Skript-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # HINWEIS: Diese Funktion verwendet nun die zentrale Definition von SCRIPT_DIR aus lib_core.sh
    
    # Prüfen, ob SCRIPT_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_script_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$SCRIPT_DIR" "$DEFAULT_DIR_BACKEND_SCRIPTS" "$FALLBACK_DIR_BACKEND_SCRIPTS" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_script_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_script_dir_debug_0003"
    echo ""
    return 1
}

# set_script_permissions
set_script_permissions_debug_0001="ERROR: Skript-Verzeichnis %s existiert nicht"
set_script_permissions_debug_0002="INFO: Setze Ausführbarkeitsrechte für %s/*.sh"
set_script_permissions_debug_0003="SUCCESS: Ausführbarkeitsrechte erfolgreich gesetzt"

set_script_permissions() {
    # -----------------------------------------------------------------------
    # set_script_permissions
    # -----------------------------------------------------------------------
    # Funktion: Setzt Ausführbarkeitsrechte für alle Skripte im Script-Verzeichnis
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = Verzeichnis existiert nicht
    # -----------------------------------------------------------------------
    local script_dir
    
    # Verwende die neue einheitliche get_script_dir Funktion
    script_dir=$(get_script_dir)
    
    if [ ! -d "$script_dir" ]; then
        debug "$(printf "$set_script_permissions_debug_0001" "$script_dir")" "CLI" "set_script_permissions"
        return 1
    fi
    
    debug "$(printf "$set_script_permissions_debug_0002" "$script_dir")" "CLI" "set_script_permissions"
    chmod +x "$script_dir"/*.sh 2>/dev/null || true
    
    debug "$set_script_permissions_debug_0003" "CLI" "set_script_permissions"
    return 0
}

# get_venv_dir
get_venv_dir_debug_0001="INFO: Ermittle 'Python Virtual Environment' Verzeichnis"
get_venv_dir_debug_0002="SUCCESS: Verwendeter Pfad für 'Python Virtual Environment' Verzeichnis: %s"
get_venv_dir_debug_0003="ERROR: Alle Pfade für 'Python Virtual Environment' Verzeichnis fehlgeschlagen"

get_venv_dir() {
    # -----------------------------------------------------------------------
    # get_venv_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Python Virtual Environment zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    
    debug "$get_venv_dir_debug_0001"
    
    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$BACKEND_VENV_DIR" "$DEFAULT_DIR_BACKEND_VENV" "$FALLBACK_DIR_BACKEND_VENV" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_venv_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi
    
    debug "$get_venv_dir_debug_0003"
    echo ""
    return 1
}

# get_python_path
get_python_path_debug_0001="INFO: Ermittle Pfad zum Python-Interpreter"
get_python_path_debug_0002="SUCCESS: Verwendeter Pfad zum Python-Interpreter: %s"
get_python_path_debug_0003="ERROR: Ermittlung des Python-Interpreter fehlgeschlagen. Python scheint nicht installiert zu sein!"

get_python_path() {
    # -----------------------------------------------------------------------
    # get_python_path
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Python-Interpreter zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Python-Interpreter oder leerer String bei Fehler
    # -----------------------------------------------------------------------
 
    # Eröffnungsmeldung
    debug "$get_python_path_debug_0001"
    
    # Python-Interpreter-Pfad ermitteln und setzen
    if [ -x "$DEFAULT_DIR_PYTHON" ]; then
        # Verwende Standard-Python-Pfad, wenn ausführbar
        : "${PYTHON_EXEC:=$DEFAULT_DIR_PYTHON}"
        debug "$(printf "$get_python_path_debug_0002" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    elif [ -x "$FALLBACK_DIR_PYTHON" ]; then
        # Verwende Fallback-Python-Pfad, wenn ausführbar
        : "${PYTHON_EXEC:=$FALLBACK_DIR_PYTHON}"
        debug "$(printf "$get_python_path_debug_0002" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    elif command -v python3 &>/dev/null; then
        # Verwende System-Python3, wenn verfügbar
        : "${PYTHON_EXEC:=$(command -v python3)}"
        debug "$(printf "$get_python_path_debug_0002" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    elif command -v python &>/dev/null; then
        # Verwende System-Python, als letzten Fallback
        : "${PYTHON_EXEC:=$(command -v python)}"
        debug "$(printf "$get_python_path_debug_0002" "$PYTHON_EXEC")"
        echo "$PYTHON_EXEC"
        return 0
    else
        # Fehlerfall: Kein Python gefunden
        debug "$get_python_path_debug_0003" "CLI" "get_python_path"
        echo ""
        return 1
    fi
}

# get_pip_path
get_pip_path_debug_0001="INFO: Ermittle Pfad zur pip-Binary"
get_pip_path_debug_0002="SUCCESS: Verwende Unix/Linux pip-Pfad: %s"
get_pip_path_debug_0003="SUCCESS: Verwende Windows pip-Pfad: %s"
get_pip_path_debug_0004="SUCCESS: Verwende Python-Modul für pip: %s -m pip"
get_pip_path_debug_0005="INFO: Kein pip im venv gefunden, fallback auf System-pip"
get_pip_path_debug_0006="SUCCESS: Verwende System-pip: %s"
get_pip_path_debug_0007="ERROR: Keine pip-Installation gefunden"

get_pip_path() {
    # -----------------------------------------------------------------------
    # get_pip_path
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zur pip-Binary im Virtual Environment zurück
    # Parameter: keine
    # Rückgabe: Pfad zur pip-Binary oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    debug "$get_pip_path_debug_0001"
    
    # 1. Prüfe, ob PIP_EXEC bereits korrekt gesetzt ist
    if [ -n "$PIP_EXEC" ] && [ -f "$PIP_EXEC" ] && [ -x "$PIP_EXEC" ]; then
        debug "$(printf "$get_pip_path_debug_0002" "$PIP_EXEC")"
        echo "$PIP_EXEC"
        return 0
    fi
    
    # 2. Hole venv_dir mit bestehender Funktion
    local venv_dir
    venv_dir=$(get_venv_dir)
    
    # 3. Prüfe Standard-Unix/Linux-Pfade im venv
    local pip_path="${venv_dir}/bin/pip3"
    if [ -f "$pip_path" ] && [ -x "$pip_path" ]; then
        debug "$(printf "$get_pip_path_debug_0002" "$pip_path")"
        echo "$pip_path"
        return 0
    fi
    
    pip_path="${venv_dir}/bin/pip"
    if [ -f "$pip_path" ] && [ -x "$pip_path" ]; then
        debug "$(printf "$get_pip_path_debug_0002" "$pip_path")"
        echo "$pip_path"
        return 0
    fi
    
    # 4. Prüfe Windows-Pfade im venv (für WSL oder Cygwin)
    pip_path="${venv_dir}/Scripts/pip.exe"
    if [ -f "$pip_path" ] && [ -x "$pip_path" ]; then
        debug "$(printf "$get_pip_path_debug_0003" "$pip_path")"
        echo "$pip_path"
        return 0
    fi
    
    # 5. Fallback: Python-Module pip verwenden
    local python_path
    python_path=$(get_python_path)
    
    if [ -n "$python_path" ] && [ -f "$python_path" ] && [ -x "$python_path" ]; then
        # Prüfen, ob das Python-Modul pip verfügbar ist
        if "$python_path" -c "import pip" &>/dev/null; then
            debug "$(printf "$get_pip_path_debug_0004" "$python_path")"
            echo "$python_path -m pip"
            return 0
        fi
    fi
    
    # 6. Systemweite pip-Installation prüfen
    debug "$get_pip_path_debug_0005"
    
    if command -v pip3 &>/dev/null; then
        pip_path=$(command -v pip3)
        debug "$(printf "$get_pip_path_debug_0006" "$pip_path")"
        echo "$pip_path"
        return 0
    fi
    
    if command -v pip &>/dev/null; then
        pip_path=$(command -v pip)
        debug "$(printf "$get_pip_path_debug_0006" "$pip_path")"
        echo "$pip_path"
        return 0
    fi
    
    # 7. Keine pip-Installation gefunden
    debug "$get_pip_path_debug_0007"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Backup-Verzeichnisse
# ---------------------------------------------------------------------------

# get_backup_dir
get_backup_dir_debug_0001="INFO: Ermittle Backup-Verzeichnis"
get_backup_dir_debug_0002="SUCCESS: Verwendeter Pfad für Backup-Verzeichnis: %s"
get_backup_dir_debug_0003="ERROR: Alle Pfade für Backup-Verzeichnis fehlgeschlagen"

get_backup_dir() {
    # -----------------------------------------------------------------------
    # get_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKUP_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_backup_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$BACKUP_DIR" "$DEFAULT_DIR_BACKUP" "$FALLBACK_DIR_BACKUP" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_backup_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_backup_dir_debug_0003"
    echo ""
    return 1
}

# get_nginx_backup_dir
get_nginx_backup_dir_debug_0001="INFO: Ermittle NGINX-Backup-Verzeichnis"
get_nginx_backup_dir_debug_0002="SUCCESS: Verwendeter Pfad für NGINX-Backup-Verzeichnis: %s"
get_nginx_backup_dir_debug_0003="ERROR: Alle Pfade für NGINX-Backup-Verzeichnis fehlgeschlagen"

get_nginx_backup_dir() {
    # -----------------------------------------------------------------------
    # get_nginx_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum NGINX-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKUP_DIR_NGINX bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_nginx_backup_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$BACKUP_DIR_NGINX" "$DEFAULT_DIR_BACKUP_NGINX" "$FALLBACK_DIR_BACKUP_NGINX" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_backup_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_nginx_backup_dir_debug_0003"
    echo ""
    return 1
}

# get_https_backup_dir
get_https_backup_dir_debug_0001="INFO: Ermittle https-Backup-Verzeichnis"
get_https_backup_dir_debug_0002="SUCCESS: Verwendeter Pfad für https-Backup-Verzeichnis: %s"
get_https_backup_dir_debug_0003="ERROR: Alle Pfade für https-Backup-Verzeichnis fehlgeschlagen"

get_https_backup_dir() {
    # -----------------------------------------------------------------------
    # get_https_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum https-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKUP_DIR_HTTPS bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_https_backup_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$BACKUP_DIR_HTTPS" "$DEFAULT_DIR_BACKUP_HTTPS" "$FALLBACK_DIR_BACKUP_HTTPS" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_https_backup_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_https_backup_dir_debug_0003"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Konfigurations-Verzeichnis
# ---------------------------------------------------------------------------

# get_config_dir
get_config_dir_debug_0001="INFO: Ermittle Konfigurations-Verzeichnis"
get_config_dir_debug_0002="SUCCESS: Verwendeter Pfad für Konfigurations-Verzeichnis: %s"
get_config_dir_debug_0003="ERROR: Alle Pfade für Konfigurations-Verzeichnis fehlgeschlagen"

get_config_dir() {
    # -----------------------------------------------------------------------
    # get_config_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Konfigurationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob CONF_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_config_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$CONF_DIR" "$DEFAULT_DIR_CONF" "$FALLBACK_DIR_CONF" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_config_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_config_dir_debug_0003"
    echo ""
    return 1
}

# get_camera_conf_dir
get_camera_conf_dir_debug_0001="INFO: Ermittle Kamera-Konfigurations-Verzeichnis"
get_camera_conf_dir_debug_0002="SUCCESS: Verwendeter Pfad für Kamera-Konfigurations-Verzeichnis: %s"
get_camera_conf_dir_debug_0003="ERROR: Alle Pfade für Kamera-Konfigurations-Verzeichnis fehlgeschlagen"

get_camera_conf_dir() {
    # -----------------------------------------------------------------------
    # get_camera_conf_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Kamera-Konfigurationsverzeichnis zurück
    # .........  und stellt sicher, dass es existiert
    # Parameter: keine
    # Rückgabe.: Pfad zum Verzeichnis oder leerer String bei Fehler
    # Extras...: Erstellt bei Bedarf einen Symlink vom Standardpfad
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob CONF_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_camera_conf_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$CONF_DIR_CAMERA" "$DEFAULT_DIR_CONF_CAMERA" "$FALLBACK_DIR_CONF_CAMERA" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_camera_conf_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_camera_conf_dir_debug_0003"
    echo ""
    return 1
}

# get_https_conf_dir
get_https_conf_dir_debug_0001="INFO: Ermittle HTTPS-Konfigurations-Verzeichnis"
get_https_conf_dir_debug_0002="SUCCESS: Verwendeter Pfad für HTTPS-Konfigurations-Verzeichnis: %s"
get_https_conf_dir_debug_0003="ERROR: Alle Pfade für HTTPS-Konfigurations-Verzeichnis fehlgeschlagen"

get_https_conf_dir() {
    # -----------------------------------------------------------------------
    # get_https_conf_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum HTTPS-Konfigurationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob CONF_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_https_conf_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$CONF_DIR_HTTPS" "$DEFAULT_DIR_CONF_HTTPS" "$FALLBACK_DIR_CONF_HTTPS" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_https_conf_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_https_conf_dir_debug_0003"
    echo ""
    return 1
}

# get_nginx_conf_dir
get_nginx_conf_dir_debug_0001="INFO: Ermittle NGINX-Konfigurations-Verzeichnis"
get_nginx_conf_dir_debug_0002="SUCCESS: Verwendeter Pfad für NGINX-Konfigurations-Verzeichnis: %s"
get_nginx_conf_dir_debug_0003="ERROR: Alle Pfade für NGINX-Konfigurations-Verzeichnis fehlgeschlagen"

get_nginx_conf_dir() {
    # -----------------------------------------------------------------------
    # get_nginx_conf_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum NGINX-Konfigurationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob CONF_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_nginx_conf_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$CONF_DIR_NGINX" "$DEFAULT_DIR_CONF_NGINX" "$FALLBACK_DIR_CONF_NGINX" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_conf_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_nginx_conf_dir_debug_0003"
    echo ""
    return 1
}

# get_template_dir
get_template_dir_debug_0001="INFO: Ermittle Template-Verzeichnis"
get_template_dir_debug_0002="SUCCESS: Verwendeter Pfad für Template-Verzeichnis: %s"
get_template_dir_debug_0003="INFO: Modulname: '%s', prüfe Verzeichniseignung"
get_template_dir_debug_0004="SUCCESS: Verwendeter Pfad für Modul-spezifisches Template-Verzeichnis: %s"
get_template_dir_debug_0005="ERROR: Alle Pfade für Template-Verzeichnis fehlgeschlagen"
get_template_dir_debug_0006="ERROR: Fehler beim Erstellen des Modul-spezifisches Verzeichnisses: %s, Fallback auf Basis-Verzeichnis: %s"

get_template_dir() {
    # -----------------------------------------------------------------------
    # get_template_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zu einem Template-Verzeichnis in der konfigurierten
    # ......... Template-Struktur zurück.
    # Parameter: $1 - (Optional) Name des Moduls (Unterverzeichnis im templates-Ordner)
    # .......... Wenn nicht angegeben, wird der Pfad zum Template-Basisordner zurückgegeben
    # Rückgabe.: Pfad zum Template-Verzeichnis oder zum Template-Basisordner bei fehlendem Modul-Parameter
    # .......... Exit-Code 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local modul_name="${1:-}"
    local dir
        
    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_template_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$CONF_DIR_TEMPLATES" "$DEFAULT_DIR_CONF_TEMPLATES" "$FALLBACK_DIR_CONF_TEMPLATES" 1 1)

    # Basis-Verzeichnis konnte nicht erzeugt werden
    if [ -z "$dir" ]; then
        debug "$(printf "$get_template_dir_debug_0005")"
        echo ""
        return 1
    fi

    # Wenn kein Eventname übergeben wurde, gib das Basis-Verzeichnis zurück
    if [ -z "$modul_name" ]; then
        debug "$(printf "$get_template_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    # Event-Name validieren und bereinigen
    debug "$(printf "$get_template_dir_debug_0003" "$modul_name")"
    
    # Verwende die Helferfunktion für die Bereinigung
    local clean_modul_name=$(_get_clean_foldername "$modul_name")
    
    # Erstelle das Event-Unterverzeichnis
    # Stellen Sie sicher, dass dir keine abschließenden Slashes hat
    dir=${dir%/}        
    local modul_dir="${dir}/${clean_modul_name}"

     if _create_directory "$modul_dir"; then
        debug "$(printf "$get_template_dir_debug_0004" "$modul_dir")"
        echo "$modul_dir"
        return 0
    else
        debug "$(printf "$get_template_dir_debug_0006" "$modul_dir" "$dir")"
        # Fallback auf das Basis-Verzeichnis bei Fehler
        debug "$(printf "$get_template_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Daten-Verzeichnis
# ---------------------------------------------------------------------------

# get_data_dir
get_data_dir_debug_0001="INFO: Ermittle Daten-Verzeichnis"
get_data_dir_debug_0002="SUCCESS: Verwendeter Pfad für Daten-Verzeichnis: %s"
get_data_dir_debug_0003="ERROR: Alle Pfade für Daten-Verzeichnis fehlgeschlagen"

get_data_dir() {
    # -----------------------------------------------------------------------
    # get_data_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Datenverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Datenverzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_data_dir_debug_0001" 

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$DATA_DIR" "$DEFAULT_DIR_DATA" "$FALLBACK_DIR_DATA" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_data_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_data_dir_debug_0003"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Frontend-Verzeichnis
# ---------------------------------------------------------------------------

# get_frontend_dir
get_frontend_dir_debug_0001="INFO: Ermittle Frontend-Verzeichnis"
get_frontend_dir_debug_0002="SUCCESS: Verwendeter Pfad für Frontend-Verzeichnis: %s"
get_frontend_dir_debug_0003="ERROR: Alle Pfade für Frontend-Verzeichnis fehlgeschlagen"

get_frontend_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Frontend-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
        
    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_frontend_dir_debug_0001" "CLI" "get_backend_dir"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_DIR" "$DEFAULT_DIR_FRONTEND" "$FALLBACK_DIR_FRONTEND" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_dir_debug_0003"
    echo ""
    return 1
}

# get_frontend_css_dir
get_frontend_css_dir_debug_0001="INFO: Ermittle Frontend-CSS-Verzeichnis"
get_frontend_css_dir_debug_0002="SUCCESS: Verwendeter Pfad für Frontend-CSS-Verzeichnis: %s"
get_frontend_css_dir_debug_0003="ERROR: Alle Pfade für Frontend-CSS-Verzeichnis fehlgeschlagen"

get_frontend_css_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_css_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum CSS-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_frontend_css_dir_debug_0001" "CLI" "get_backend_dir"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_CSS_DIR" "$DEFAULT_DIR_FRONTEND_CSS" "$FALLBACK_DIR_FRONTEND_CSS" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_css_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_css_dir_debug_0003"
    echo ""
    return 1
}

# get_frontend_fonts_dir
get_frontend_fonts_dir_debug_0001="INFO: Ermittle Frontend-Fonts-Verzeichnis"
get_frontend_fonts_dir_debug_0002="SUCCESS: Verwendeter Pfad für Frontend-Fonts-Verzeichnis: %s"
get_frontend_fonts_dir_debug_0003="ERROR: Alle Pfade für Frontend-Fonts-Verzeichnis fehlgeschlagen"

get_frontend_fonts_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_fonts_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Fonts-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob FRONTEND_FONTS_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_frontend_fonts_dir_debug_0001" 

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_FONTS_DIR" "$DEFAULT_DIR_FRONTEND_FONTS" "$FALLBACK_DIR_FRONTEND_FONTS" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_fonts_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_fonts_dir_debug_0003"
    echo ""
    return 1
}

# get_frontend_js_dir
get_frontend_js_dir_debug_0001="INFO: Ermittle Frontend-JavaScript-Verzeichnis"
get_frontend_js_dir_debug_0002="SUCCESS: Verwendeter Pfad für Frontend-JavaScript-Verzeichnis: %s"
get_frontend_js_dir_debug_0003="ERROR: Alle Pfade für Frontend-JavaScript-Verzeichnis fehlgeschlagen"

get_frontend_js_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_js_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum JavaScript-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_frontend_js_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_JS_DIR" "$DEFAULT_DIR_FRONTEND_JS" "$FALLBACK_DIR_FRONTEND_JS" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_js_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_js_dir_debug_0003"
    echo ""
    return 1
}

# get_photos_dir
get_photos_dir_debug_0001="INFO: Ermittle Fotos-Verzeichnis"
get_photos_dir_debug_0002="SUCCESS: Verwendeter Pfad für Fotos-Verzeichnis: %s"
get_photos_dir_debug_0003="ERROR: Alle Pfade für Fotos-Verzeichnis fehlgeschlagen"

get_photos_dir() {
    # -----------------------------------------------------------------------
    # get_photos_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Fotos-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_photos_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_PHOTOS_DIR" "$DEFAULT_DIR_FRONTEND_PHOTOS" "$FALLBACK_DIR_FRONTEND_PHOTOS" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_photos_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_photos_dir_debug_0003"
    echo ""
    return 1
}

# get_photos_originals_dir
get_photos_originals_dir_debug_0001="INFO: Ermittle Original-Fotos-Verzeichnis"
get_photos_originals_dir_debug_0002="SUCCESS: Verwendeter Pfad für Original-Fotos-Verzeichnis: %s"
get_photos_originals_dir_debug_0003="INFO: Eventname: '%s', prüfe Verzeichniseignung"
get_photos_originals_dir_debug_0004="SUCCESS: Verwendeter Pfad für Event-spezifisches Original-Fotos-Verzeichnis: %s"
get_photos_originals_dir_debug_0005="ERROR: Alle Pfade für Original-Fotos-Verzeichnis fehlgeschlagen"
get_photos_originals_dir_debug_0006="ERROR: Fehler beim Erstellen des Event-spezifischen Verzeichnisses: %s, Fallback auf Basis-Verzeichnis: %s"

get_photos_originals_dir() {
    # -----------------------------------------------------------------------
    # get_photos_originals_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Originalfotos-Verzeichnis zurück
    # Parameter: $1 - (Optional) Name des Events
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local event_name="${1:-}"
    local dir
        
    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_photos_originals_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_PHOTOS_ORIGINAL_DIR" "$DEFAULT_DIR_FRONTEND_PHOTOS_ORIGINAL" "$FALLBACK_DIR_FRONTEND_PHOTOS_ORIGINAL" 1 1)    

    # Basis-Verzeichnis konnte nicht erzeugt werden
    if [ -z "$dir" ]; then
        debug "$(printf "$get_photos_originals_dir_debug_0005")"
        echo ""
        return 1
    fi

    # Wenn kein Eventname übergeben wurde, gib das Basis-Verzeichnis zurück
    if [ -z "$event_name" ]; then
        debug "$(printf "$get_photos_originals_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    # Event-Name validieren und bereinigen
    debug "$(printf "$get_photos_originals_dir_debug_0003" "$event_name")"
    
    # Verwende die Helferfunktion für die Bereinigung
    local clean_event_name=$(_get_clean_foldername "$event_name")
    
    # Erstelle das Event-Unterverzeichnis
    # Stellen Sie sicher, dass dir keine abschließenden Slashes hat
    dir=${dir%/}        
    local event_dir="${dir}/${clean_event_name}"

    if _create_directory "$event_dir"; then
        debug "$(printf "$get_photos_originals_dir_debug_0004" "$event_dir")"
        echo "$event_dir"
        return 0
    else
        debug "$(printf "$get_photos_originals_dir_debug_0006" "$event_dir" "$dir")"
        # Fallback auf das Basis-Verzeichnis bei Fehler
        debug "$(printf "$get_photos_originals_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi
}

# get_photos_gallery_dir
get_photos_gallery_dir_debug_0001="INFO: Ermittle Galerie(Thumbnail)-Verzeichnis"
get_photos_gallery_dir_debug_0002="SUCCESS: Verwendeter Pfad für Galerie(Thumbnail)-Verzeichnis: %s"
get_photos_gallery_dir_debug_0003="INFO: Eventname: '%s', prüfe Verzeichniseignung"
get_photos_gallery_dir_debug_0004="SUCCESS: Verwendeter Pfad für Event-spezifisches Galerie(Thumbnail)-Verzeichnis: %s"
get_photos_gallery_dir_debug_0005="ERROR: Alle Pfade für Galerie(Thumbnail)-Verzeichnis fehlgeschlagen"
get_photos_gallery_dir_debug_0006="ERROR: Fehler beim Erstellen des Event-spezifischen Verzeichnisses: %s, Fallback auf Basis-Verzeichnis: %s"

get_photos_gallery_dir() {
    # -----------------------------------------------------------------------
    # get_photos_gallery_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Galerie(Thumbnail)-Verzeichnis zurück
    # Parameter: $1 - (Optional) Name des Events
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local event_name="${1:-}"
    local dir
        
    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_photos_gallery_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_PHOTOS_THUMBNAILS_DIR" "$DEFAULT_DIR_FRONTEND_PHOTOS_THUMBNAILS" "$FALLBACK_DIR_FRONTEND_PHOTOS_THUMBNAILS" 1 1)

    # Basis-Verzeichnis konnte nicht erzeugt werden
    if [ -z "$dir" ]; then
        debug "$(printf "$get_photos_gallery_dir_debug_0005")"
        echo ""
        return 1
    fi

    # Wenn kein Eventname übergeben wurde, gib das Basis-Verzeichnis zurück
    if [ -z "$event_name" ]; then
        debug "$(printf "$get_photos_gallery_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    # Event-Name validieren und bereinigen
    debug "$(printf "$get_photos_gallery_dir_debug_0003" "$event_name")"
    
    # Verwende die Helferfunktion für die Bereinigung
    local clean_event_name=$(_get_clean_foldername "$event_name")
    
    # Erstelle das Event-Unterverzeichnis
    # Stellen Sie sicher, dass dir keine abschließenden Slashes hat
    dir=${dir%/}        
    local event_dir="${dir}/${clean_event_name}"

     if _create_directory "$event_dir"; then
        debug "$(printf "$get_photos_gallery_dir_debug_0004" "$event_dir")"
        echo "$event_dir"
        return 0
    else
        debug "$(printf "$get_photos_gallery_dir_debug_0006" "$event_dir" "$dir")"
        # Fallback auf das Basis-Verzeichnis bei Fehler
        debug "$(printf "$get_photos_gallery_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi
}

# get_frontend_picture_dir
get_frontend_picture_dir_debug_0001="INFO: Ermittle Frontend-Bilder-Verzeichnis"
get_frontend_picture_dir_debug_0002="SUCCESS: Verwendeter Pfad für Frontend-Bilder-Verzeichnis: %s"
get_frontend_picture_dir_debug_0003="ERROR: Alle Pfade für Frontend-Bilder-Verzeichnis fehlgeschlagen"

get_frontend_picture_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_picture_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Bilder-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_frontend_picture_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$FRONTEND_PICTURE_DIR" "$DEFAULT_DIR_FRONTEND_PICTURE" "$FALLBACK_DIR_FRONTEND_PICTURE" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_picture_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_picture_dir_debug_0003"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Log-Verzeichnis
# ---------------------------------------------------------------------------

# get_log_dir
get_log_dir_debug_0001="INFO: Ermittle Log-Verzeichnis"
get_log_dir_debug_0002="SUCCESS: Verwendeter Pfad für Log-Verzeichnis: %s"
get_log_dir_debug_0003="ERROR: Alle Pfade für Log-Verzeichnis fehlgeschlagen"

get_log_dir() {
    # ------------------------------------------------------------------------------
    # get_log_dir
    # ------------------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Log-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # ------------------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_log_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$LOG_DIR" "$DEFAULT_DIR_LOG" "$FALLBACK_DIR_LOG" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_log_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_log_dir_debug_0003"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Temp-Verzeichnis
# ---------------------------------------------------------------------------

# get_tmp_dir
get_tmp_dir_debug_0001="INFO: Ermittle temporäres Verzeichnis"
get_tmp_dir_debug_0002="SUCCESS: Verwendeter Pfad für temporäres Verzeichnis: %s"
get_tmp_dir_debug_0003="ERROR: Alle Pfade für temporäres Verzeichnis fehlgeschlagen"

get_tmp_dir() {
    # -----------------------------------------------------------------------
    # get_tmp_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum temporären Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_tmp_dir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(get_folder_path "$TMP_DIR" "$DEFAULT_DIR_TMP" "$FALLBACK_DIR_TMP" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_tmp_dir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_tmp_dir_debug_0003"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Verzeichnis Struktur für das Projekt sicherstellen
# ---------------------------------------------------------------------------

# ensure_folder_structure
ensure_folder_structure_debug_0001="INFO: Stelle sicher, dass alle notwendigen Verzeichnisse existieren"
ensure_folder_structure_debug_0002="SUCCESS: Ordnerstruktur erfolgreich erstellt"

ensure_folder_structure() {
    # -----------------------------------------------------------------------
    # ensure_folder_structure
    # -----------------------------------------------------------------------
    # Funktion: Stellt sicher, dass die gesamte Ordnerstruktur existiert
    # .........  und alle erforderlichen Verzeichnisse angelegt sind
    # Parameter: keine
    # Rückgabe.: 0 = Erfolg
    # .........  1 = Fehler bei einem kritischen Verzeichnis
    # Extras...: Erstellt Hauptverzeichnisse, Unterverzeichnisse und setzt Berechtigungen
    # -----------------------------------------------------------------------
    debug "$ensure_folder_structure_debug_0001"
    
    # Hauptverzeichnisse erstellen
    get_install_dir >/dev/null || return 1
    get_backup_dir >/dev/null || return 1
    get_config_dir >/dev/null || return 1
    get_data_dir >/dev/null || return 1
    get_frontend_dir >/dev/null || return 1
    get_log_dir >/dev/null || return 1
    
    # Frontend-Unterverzeichnisse erstellen
    get_frontend_css_dir >/dev/null || true
    get_frontend_js_dir >/dev/null || true
    get_frontend_fonts_dir >/dev/null || true
    get_frontend_picture_dir >/dev/null || true
    
    # Fotos-Verzeichnisstruktur
    get_photos_dir >/dev/null || return 1
    get_photos_originals_dir >/dev/null || return 1
    get_photos_gallery_dir >/dev/null || return 1
    
    # NGINX-Verzeichnisstruktur
    get_nginx_conf_dir >/dev/null || return 1
    get_nginx_backup_dir >/dev/null || return 1

    # HTTPS-Verzeichnisstruktur
    get_https_conf_dir >/dev/null || return 1
    get_https_backup_dir >/dev/null || return 1

    # Kamera-Verzeichnisstruktur
    get_camera_conf_dir >/dev/null || return 1
    get_script_dir >/dev/null || return 1

    # Setze Ausführbarkeitsrechte für Skripte
    set_script_permissions || true
    
    debug "$ensure_folder_structure_debug_0002"
    return 0
}

# ===========================================================================
# Get- und Set-Funktionen für Systempfade
# ===========================================================================

# get_nginx_systemdir
get_nginx_systemdir_debug_0001="INFO: Ermittle NGINX-Systemverzeichnis"
get_nginx_systemdir_debug_0002="SUCCESS: Verwendeter Pfad für NGINX-Systemverzeichnis: %s"
get_nginx_systemdir_debug_0003="ERROR: Alle Pfade für NGINX-Systemverzeichnis fehlgeschlagen"

get_nginx_systemdir() {
    # -----------------------------------------------------------------------
    # get_nginx_systemdir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum NGINX-Systemverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_nginx_systemdir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade oder das Konfigurationsverzeichnis
    dir=$(get_folder_path "$SYSTEM_PATH_NGINX" "$DEFAULT_DIR_CONF_NGINX" "$FALLBACK_DIR_CONF_NGINX" 1 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_systemdir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_nginx_systemdir_debug_0003"
    echo ""
    return 1
}

# get_systemd_systemdir
get_systemd_systemdir_debug_0001="INFO: Ermittle systemd-Verzeichnis"
get_systemd_systemdir_debug_0002="SUCCESS: Verwendeter Pfad für systemd-Verzeichnis: %s"
get_systemd_systemdir_debug_0003="ERROR: Alle Pfade für systemd-Verzeichnis fehlgeschlagen"

get_systemd_systemdir() {
    # -----------------------------------------------------------------------
    # get_systemd_systemdir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum systemd-Systemverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
   local dir

    # Prüfen, ob BACKEND_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_systemd_systemdir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade oder das Konfigurationsverzeichnis
    dir=$(get_folder_path "$SYSTEM_PATH_SYSTEMD" "$DEFAULT_DIR_CONF_SYSTEMD" "$FALLBACK_DIR_CONF_SYSTEMD" 1 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_systemd_systemdir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_systemd_systemdir_debug_0003"
    echo ""
    return 1
}

# get_ssl_systemdir
get_ssl_systemdir_debug_0001="INFO: Ermittle SSL-Verzeichnis"
get_ssl_systemdir_debug_0002="SUCCESS: Verwendeter Pfad für SSL-Verzeichnis: %s"
get_ssl_systemdir_debug_0003="ERROR: Alle Pfade für SSL-Verzeichnis fehlgeschlagen"

get_ssl_systemdir() {
    # -----------------------------------------------------------------------
    # get_ssl_systemdir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum SSL-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob SYSTEM_PATH_SSL bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_ssl_systemdir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade oder das Konfigurationsverzeichnis
    dir=$(get_folder_path "$SYSTEM_PATH_SSL" "$DEFAULT_DIR_CONF_SSL" "$FALLBACK_DIR_CONF_SSL" 1 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_ssl_systemdir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_ssl_systemdir_debug_0003"
    echo ""
    return 1
}

# get_ssl_cert_systemdir
get_ssl_cert_systemdir_debug_0001="INFO: Ermittle SSL-Zertifikate-Systemverzeichnis"
get_ssl_cert_systemdir_debug_0002="SUCCESS: Verwendeter Pfad für SSL-Zertifikate-Systemverzeichnis: %s"
get_ssl_cert_systemdir_debug_0003="ERROR: Alle Pfade für SSL-Zertifikate-Systemverzeichnis fehlgeschlagen"

get_ssl_cert_systemdir() {
    # -----------------------------------------------------------------------
    # get_ssl_cert_systemdir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum SSL-Zertifikate-Systemverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob SYSTEM_PATH_SSL_CERT bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_ssl_cert_systemdir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade oder das Konfigurationsverzeichnis
    dir=$(get_folder_path "$SYSTEM_PATH_SSL_CERT" "$DEFAULT_DIR_CONF_SSL_CERTS" "$FALLBACK_DIR_CONF_SSL_CERTS" 1 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_ssl_cert_systemdir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_ssl_cert_systemdir_debug_0003"
    echo ""
    return 1
}

# get_ssl_key_systemdir
get_ssl_key_systemdir_debug_0001="INFO: Ermittle SSL-Schlüssel-Systemverzeichnis"
get_ssl_key_systemdir_debug_0002="SUCCESS: Verwendeter Pfad für SSL-Schlüssel-Systemverzeichnis: %s"
get_ssl_key_systemdir_debug_0003="ERROR: Alle Pfade für SSL-Schlüssel-Systemverzeichnis fehlgeschlagen"

get_ssl_key_systemdir() {
    # -----------------------------------------------------------------------
    # get_ssl_key_systemdir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum SSL-Schlüsseldateien-Systemverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir

    # Prüfen, ob SYSTEM_PATH_SSL_KEY bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_ssl_key_systemdir_debug_0001"

    # Verwende die in 'lib_core' definierten Pfade oder das Konfigurationsverzeichnis
    dir=$(get_folder_path "$SYSTEM_PATH_SSL_KEY" "$DEFAULT_DIR_CONF_SSL_KEYS" "$FALLBACK_DIR_CONF_SSL_KEYS" 1 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_ssl_key_systemdir_debug_0002" "$dir")"
        echo "$dir"
        return 0
    fi

    debug "$get_ssl_key_systemdir_debug_0003"
    echo ""
    return 1
}

if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Das Skript wurde mit source geladen
    # Lösche interne Funktionen aus dem globalen Namespace
    unset -f _get_clean_foldername
    unset -f _create_symlink_to_standard_path
    unset -f _create_directory
    # unset -f _get_folder_path
fi
