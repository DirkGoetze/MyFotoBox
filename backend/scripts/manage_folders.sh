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

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
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
create_symlink_to_standard_path_log_0001="INFO: Symlink erstellt: %s -> %s"

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

    log "$(printf "$create_symlink_to_standard_path_log_0001" "$standard_path" "$actual_path")"
    return 0
}

# _create_directory
create_directory_debug_0001="INFO: Verzeichnis '%s' existiert nicht, wird erstellt"
create_directory_debug_0002="ERROR: Fehler beim Erstellen von '%s'"
create_directory_debug_0003="WARN: Warnung! <chown> '%s:%s' für '%s' fehlgeschlagen, Eigentümer nicht geändert"
create_directory_debug_0004="WARN: Warnung! <chmod> '%s' für '%s' fehlgeschlagen, Berechtigungen nicht geändert"
create_directory_debug_0005="INFO: Verzeichnis '%s' erfolgreich vorbereitet"
create_directory_log_0001="Kein Verzeichnis angegeben"
create_directory_log_0002="Fehler beim Erstellen des Verzeichnisses %s"
create_directory_log_0003="Verzeichnis %s wurde erstellt"
create_directory_log_0004="Fehler beim Setzen der Berechtigungen für %s"
create_directory_log_0005="Verzeichnis %s erfolgreich vorbereitet"
create_directory_log_0006="Verzeichnis %s konnte nicht korrekt vorbereitet werden"

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
    local mode="${4:-$DEFAULT_MODE_FOLDER}"

    # Prüfung der Parameter
    if ! check_param "$dir" "dir"; then return 1; fi

    # Verzeichnis erstellen, falls es nicht existiert
    if [ ! -d "$dir" ]; then
        debug "$(printf "$create_directory_debug_0001" "$dir")"
        mkdir -p "$dir" || {
            log "$(printf "$create_directory_log_0002" "$dir")"
            debug "$(printf "$create_directory_debug_0002" "$dir")"
            return 1
        }
        log "$(printf "$create_directory_log_0003" "$dir")"
    fi

    # Berechtigungen setzen
    chown "$user:$group" "$dir" 2>/dev/null || {
        log "$(printf "$create_directory_log_0004" "$dir")"
        debug "$(printf "$create_directory_debug_0003" "$user" "$group" "$dir")"
        # Fehler beim chown ist kein kritischer Fehler
    }

    chmod "$mode" "$dir" 2>/dev/null || {
        log "$(printf "$create_directory_log_0004" "$dir")"
        debug "$(printf "$create_directory_debug_0004" "$mode" "$dir")"
        # Fehler beim chmod ist kein kritischer Fehler
    }

    # Überprüfen, ob das Verzeichnis existiert und lesbar ist
    if [ -d "$dir" ] && [ -r "$dir" ]; then
        log "$(printf "$create_directory_log_0005" "$dir")"
        debug "$(printf "$create_directory_debug_0005" "$dir")"
        return 0
    else
        log "$(printf "$create_directory_log_0006" "$dir")"
        return 1
    fi
}

# _get_folder_path
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
get_folder_path_log_0001="Kein gültiger Pfad für die Ordnererstellung verfügbar"

_get_folder_path() {
    # -----------------------------------------------------------------------
    # _get_folder_path
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
    log "$get_folder_path_log_0001" "get_folder_path"
    return 1
}

# ===========================================================================
# Get- und Set-Funktionen für die Ordnerstruktur des Projektes
# ===========================================================================

# get_install_dir
get_install_dir_debug_0001="INFO: Ermittle Installations-Verzeichnis"
get_install_dir_debug_0002="SUCCESS: Verwendete für Installations-Verzeichnis \$INSTALL_DIR: '%s'"
get_install_dir_debug_0003="SUCCESS: Verwendeter Pfad für Installations-Verzeichnis: '%s'"
get_install_dir_debug_0004="ERROR: Alle Pfade für Installations-Verzeichnis fehlgeschlagen"

get_install_dir() {
    # -----------------------------------------------------------------------
    # get_install_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Installationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    local path_system="/opt/fotobox"
    local path_default="/opt/fotobox"
    local path_fallback="/usr/local/fotobox"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_install_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${INSTALL_DIR+x}" ] && [ -n "$INSTALL_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_install_dir_debug_0002" "$INSTALL_DIR")"
        echo "$INSTALL_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Deaktiviere Fallback Order(0) und das Erzeugen von Symlink (0)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 0 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_install_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${INSTALL_DIR+x}" ] || [ -z "$INSTALL_DIR" ] || [ "$dir" != "$INSTALL_DIR" ]; then
            INSTALL_DIR="$dir"
            export INSTALL_DIR
        fi
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall das aktuelle Verzeichnis verwenden
    debug "$get_install_dir_debug_0004"
    return 1
}

# ---------------------------------------------------------------------------
# Backend-Verzeichnis
# ---------------------------------------------------------------------------

# get_backend_dir
get_backend_dir_debug_0001="INFO: Ermittle Backend-Verzeichnis"
get_backend_dir_debug_0002="SUCCESS: Verwendete für Backend-Verzeichnis \$BACKEND_DIR: %s"
get_backend_dir_debug_0003="SUCCESS: Verwendeter Pfad für Backend-Verzeichnis: %s"
get_backend_dir_debug_0004="ERROR: Alle Pfade für Backend-Verzeichnis fehlgeschlagen"

get_backend_dir() {
    # -----------------------------------------------------------------------
    # get_backend_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Backend-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    : "${INSTALL_DIR:=$(get_install_dir)}"
    # Pfade für Backend-Verzeichnis
    local dir
    local path_system="$INSTALL_DIR/backend"
    local path_default="$INSTALL_DIR/backend"
    local path_fallback="$INSTALL_DIR/backend"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_backend_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${BACKEND_DIR+x}" ] && [ -n "$BACKEND_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_backend_dir_debug_0002" "$BACKEND_DIR")"
        echo "$BACKEND_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_backend_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${BACKEND_DIR+x}" ] || [ -z "$BACKEND_DIR" ] || [ "$dir" != "$BACKEND_DIR" ]; then
            BACKEND_DIR="$dir"
            export BACKEND_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_backend_dir_debug_0004"
    echo ""
    return 1
}

# get_script_dir
get_script_dir_debug_0001="INFO: Ermittle Backend-Skript-Verzeichnis"
get_script_dir_debug_0002="SUCCESS: Verwendete für Backend-Skript-Verzeichnis \$SCRIPT_DIR: %s"
get_script_dir_debug_0003="SUCCESS: Verwendeter Pfad für Backend-Skript-Verzeichnis: %s"
get_script_dir_debug_0004="ERROR: Alle Pfade für Backend-Skript-Verzeichnis fehlgeschlagen"

get_script_dir() {
    # -----------------------------------------------------------------------
    # get_script_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Backend-Skript-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKEND_DIR gesetzt ist
    : "${BACKEND_DIR:=$(get_backend_dir)}"
    # Pfade für Backend-Skript-Verzeichnis
    local dir
    local path_system="$BACKEND_DIR/scripts"
    local path_default="$BACKEND_DIR/scripts"
    local path_fallback="$BACKEND_DIR/scripts"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_script_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${SCRIPT_DIR+x}" ] && [ -n "$SCRIPT_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_script_dir_debug_0002" "$SCRIPT_DIR")"
        echo "$SCRIPT_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_script_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${SCRIPT_DIR+x}" ] || [ -z "$SCRIPT_DIR" ] || [ "$dir" != "$SCRIPT_DIR" ]; then
            SCRIPT_DIR="$dir"
            export SCRIPT_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_script_dir_debug_0004"
    echo ""
    return 1
}

# get_venv_dir
get_venv_dir_debug_0001="INFO: Ermittle 'Python Virtual Environment' Verzeichnis"
get_venv_dir_debug_0002="SUCCESS: Verwendete für 'Python Virtual Environment' Verzeichnis \$BACKEND_VENV_DIR: %s"
get_venv_dir_debug_0003="SUCCESS: Verwendeter Pfad für 'Python Virtual Environment' Verzeichnis: %s"
get_venv_dir_debug_0004="ERROR: Alle Pfade für 'Python Virtual Environment' Verzeichnis fehlgeschlagen"

get_venv_dir() {
    # -----------------------------------------------------------------------
    # get_venv_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Python Virtual Environment zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKEND_DIR gesetzt ist
    : "${BACKEND_DIR:=$(get_backend_dir)}"
    # Pfade für zum Python Virtual Environment-Verzeichnis
    local dir
    local path_system="$BACKEND_DIR/venv"
    local path_default="$BACKEND_DIR/venv"
    local path_fallback="$BACKEND_DIR/venv"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_venv_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${BACKEND_VENV_DIR+x}" ] && [ -n "$BACKEND_VENV_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_venv_dir_debug_0002" "$BACKEND_VENV_DIR")"
        echo "$BACKEND_VENV_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 0 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_venv_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${BACKEND_VENV_DIR+x}" ] || [ -z "$BACKEND_VENV_DIR" ] || [ "$dir" != "$BACKEND_VENV_DIR" ]; then
            BACKEND_VENV_DIR="$dir"
            export BACKEND_VENV_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_venv_dir_debug_0004"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Backup-Verzeichnisse
# ---------------------------------------------------------------------------

# get_backup_dir
get_backup_dir_debug_0001="INFO: Ermittle Backup-Verzeichnis"
get_backup_dir_debug_0002="SUCCESS: Verwende für Backup-Verzeichnis \$BACKUP_DIR : %s"
get_backup_dir_debug_0003="SUCCESS: Verwendeter Pfad für Backup-Verzeichnis: %s"
get_backup_dir_debug_0004="ERROR: Alle Pfade für Backup-Verzeichnis fehlgeschlagen"

get_backup_dir() {
    # -----------------------------------------------------------------------
    # get_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    : "${INSTALL_DIR:=$(get_install_dir)}"
    # Pfade für Backup-Verzeichnis
    local dir
    local path_system="$INSTALL_DIR/backup"
    local path_default="$INSTALL_DIR/backup"
    local path_fallback="$INSTALL_DIR/backup"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_backup_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${BACKUP_DIR+x}" ] && [ -n "$BACKUP_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_backup_dir_debug_0002" "$BACKUP_DIR")"
        echo "$BACKUP_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_backup_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${BACKUP_DIR+x}" ] || [ -z "$BACKUP_DIR" ] || [ "$dir" != "$BACKUP_DIR" ]; then
            BACKUP_DIR="$dir"
            export BACKUP_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_backup_dir_debug_0004"
    echo ""
    return 1
}

# get_data_backup_dir
get_data_backup_dir_debug_0001="INFO: Ermittle Daten-Backup-Verzeichnis"
get_data_backup_dir_debug_0002="SUCCESS: Verwende für Daten-Backup-Verzeichnis \$BACKUP_DIR_DATA: %s"
get_data_backup_dir_debug_0003="SUCCESS: Verwendeter Pfad für Daten-Backup-Verzeichnis: %s"
get_data_backup_dir_debug_0004="ERROR: Alle Pfade für Daten-Backup-Verzeichnis fehlgeschlagen"
get_data_backup_dir() {
    # -----------------------------------------------------------------------
    # get_data_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Daten-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKUP_DIR gesetzt ist
    : "${BACKUP_DIR:=$(get_backup_dir)}"
    # Pfade für Daten-Backup-Verzeichnis
    local dir
    local path_system="$BACKUP_DIR/data"
    local path_default="$BACKUP_DIR/data"
    local path_fallback="$BACKUP_DIR/data"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_data_backup_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${BACKUP_DIR_DATA+x}" ] && [ -n "$BACKUP_DIR_DATA" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_data_backup_dir_debug_0002" "$BACKUP_DIR_DATA")"
        echo "$BACKUP_DIR_DATA"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_data_backup_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${BACKUP_DIR_DATA+x}" ] || [ -z "$BACKUP_DIR_DATA" ] || [ "$dir" != "$BACKUP_DIR_DATA" ]; then
            BACKUP_DIR_DATA="$dir"
            export BACKUP_DIR_DATA
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_data_backup_dir_debug_0004"
    echo ""
    return 1
}

# get_nginx_backup_dir
get_nginx_backup_dir_debug_0001="INFO: Ermittle NGINX-Backup-Verzeichnis"
get_nginx_backup_dir_debug_0002="SUCCESS: Verwende für NGINX-Backup-Verzeichnis \$BACKUP_DIR_NGINX: %s"
get_nginx_backup_dir_debug_0003="SUCCESS: Verwendeter Pfad für NGINX-Backup-Verzeichnis: %s"
get_nginx_backup_dir_debug_0004="ERROR: Alle Pfade für NGINX-Backup-Verzeichnis fehlgeschlagen"

get_nginx_backup_dir() {
    # -----------------------------------------------------------------------
    # get_nginx_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum NGINX-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKUP_DIR gesetzt ist
    : "${BACKUP_DIR:=$(get_backup_dir)}"
    # Pfade für NGINX-Backup-Verzeichnis
    local dir
    local path_system="$BACKUP_DIR/nginx"
    local path_default="$BACKUP_DIR/nginx"
    local path_fallback="$BACKUP_DIR/nginx"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_nginx_backup_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${BACKUP_DIR_NGINX+x}" ] && [ -n "$BACKUP_DIR_NGINX" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_backup_dir_debug_0002" "$BACKUP_DIR_NGINX")"
        echo "$BACKUP_DIR_NGINX"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_backup_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${BACKUP_DIR_NGINX+x}" ] || [ -z "$BACKUP_DIR_NGINX" ] || [ "$dir" != "$BACKUP_DIR_NGINX" ]; then
            BACKUP_DIR_NGINX="$dir"
            export BACKUP_DIR_NGINX
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_nginx_backup_dir_debug_0004"
    echo ""
    return 1
}

# get_https_backup_dir
get_https_backup_dir_debug_0001="INFO: Ermittle https-Backup-Verzeichnis"
get_https_backup_dir_debug_0002="SUCCESS: Verwende für https-Backup-Verzeichnis \$BACKUP_DIR_HTTPS: %s"
get_https_backup_dir_debug_0003="SUCCESS: Verwendeter Pfad für https-Backup-Verzeichnis: %s"
get_https_backup_dir_debug_0004="ERROR: Alle Pfade für https-Backup-Verzeichnis fehlgeschlagen"

get_https_backup_dir() {
    # -----------------------------------------------------------------------
    # get_https_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum https-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKUP_DIR gesetzt ist
    : "${BACKUP_DIR:=$(get_backup_dir)}"
    # Pfade für https-Backup-Verzeichnis
    local dir
    local path_system="$BACKUP_DIR/https"
    local path_default="$BACKUP_DIR/https"
    local path_fallback="$BACKUP_DIR/https"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_https_backup_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${BACKUP_DIR_HTTPS+x}" ] && [ -n "$BACKUP_DIR_HTTPS" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_https_backup_dir_debug_0002" "$BACKUP_DIR_HTTPS")"
        echo "$BACKUP_DIR_HTTPS"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_https_backup_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${BACKUP_DIR_HTTPS+x}" ] || [ -z "$BACKUP_DIR_HTTPS" ] || [ "$dir" != "$BACKUP_DIR_HTTPS" ]; then
            BACKUP_DIR_HTTPS="$dir"
            export BACKUP_DIR_HTTPS
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_https_backup_dir_debug_0004"
    echo ""
    return 1
}

# get_systemd_backup_dir
get_systemd_backup_dir_debug_0001="INFO: Ermittle systemd-Backup-Verzeichnis"
get_systemd_backup_dir_debug_0002="SUCCESS: Verwende für systemd-Backup-Verzeichnis \$BACKUP_DIR_SYSTEMD: %s"
get_systemd_backup_dir_debug_0003="SUCCESS: Verwendeter Pfad für systemd-Backup-Verzeichnis: %s"
get_systemd_backup_dir_debug_0004="ERROR: Alle Pfade für systemd-Backup-Verzeichnis fehlgeschlagen"

get_systemd_backup_dir() {
    # -----------------------------------------------------------------------
    # get_systemd_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum systemd-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass BACKUP_DIR gesetzt ist
    : "${BACKUP_DIR:=$(get_backup_dir)}"
    # Pfade für systemd-Backup-Verzeichnis
    local dir
    local path_system="$BACKUP_DIR/systemd"
    local path_default="$BACKUP_DIR/systemd"
    local path_fallback="$BACKUP_DIR/systemd"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_systemd_backup_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${BACKUP_DIR_SYSTEMD+x}" ] && [ -n "$BACKUP_DIR_SYSTEMD" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_systemd_backup_dir_debug_0002" "$BACKUP_DIR_SYSTEMD")"
        echo "$BACKUP_DIR_SYSTEMD"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_systemd_backup_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${BACKUP_DIR_SYSTEMD+x}" ] || [ -z "$BACKUP_DIR_SYSTEMD" ] || [ "$dir" != "$BACKUP_DIR_SYSTEMD" ]; then
            BACKUP_DIR_SYSTEMD="$dir"
            export BACKUP_DIR_SYSTEMD
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_systemd_backup_dir_debug_0004"
    echo ""
    return 1
}   

# ---------------------------------------------------------------------------
# Konfigurations-Verzeichnis
# ---------------------------------------------------------------------------

# get_config_dir
get_config_dir_debug_0001="INFO: Ermittle Konfigurations-Verzeichnis"
get_config_dir_debug_0002="SUCCESS: Verwende für Konfigurations-Verzeichnis \$CONF_DIR: %s"
get_config_dir_debug_0003="SUCCESS: Verwendeter Pfad für Konfigurations-Verzeichnis: %s"
get_config_dir_debug_0004="ERROR: Alle Pfade für Konfigurations-Verzeichnis fehlgeschlagen"

get_config_dir() {
    # -----------------------------------------------------------------------
    # get_config_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Konfigurationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    : "${INSTALL_DIR:=$(get_install_dir)}"
    # Pfade für Konfigurationsverzeichnis
    local dir
    local path_system="$INSTALL_DIR/conf"
    local path_default="$INSTALL_DIR/conf"
    local path_fallback="/etc/fotobox"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_config_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${CONF_DIR+x}" ] && [ -n "$CONF_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_config_dir_debug_0002" "$CONF_DIR")"
        echo "$CONF_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_config_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${CONF_DIR+x}" ] || [ -z "$CONF_DIR" ] || [ "$dir" != "$CONF_DIR" ]; then
            CONF_DIR="$dir"
            export CONF_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_config_dir_debug_0004"
    echo ""
    return 1
}

# get_camera_conf_dir
get_camera_conf_dir_debug_0001="INFO: Ermittle Kamera-Konfigurations-Verzeichnis"
get_camera_conf_dir_debug_0002="SUCCESS: Verwende für Kamera-Konfigurations-Verzeichnis \$CONF_DIR_CAMERA: %s"
get_camera_conf_dir_debug_0003="SUCCESS: Verwendeter Pfad für Kamera-Konfigurations-Verzeichnis: %s"
get_camera_conf_dir_debug_0004="ERROR: Alle Pfade für Kamera-Konfigurations-Verzeichnis fehlgeschlagen"

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
    # Sicherstellen, dass CONF_DIR gesetzt ist
    : "${CONF_DIR:=$(get_config_dir)}"
    # Pfade für Kamera-Konfigurationsverzeichnis
    local dir
    local path_system="$CONF_DIR/cameras"
    local path_default="$CONF_DIR/cameras"
    local path_fallback="$CONF_DIR/cameras"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_camera_conf_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${CONF_DIR_CAMERA+x}" ] && [ -n "$CONF_DIR_CAMERA" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_camera_conf_dir_debug_0002" "$CONF_DIR_CAMERA")"
        echo "$CONF_DIR_CAMERA"
        return 0
    fi

    # Verwende die in 'lib_core' definierten Pfade
    # (inkl. Fallback im Systemordner und Erzeugen von Symlink)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_camera_conf_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${CONF_DIR_CAMERA+x}" ] || [ -z "$CONF_DIR_CAMERA" ] || [ "$dir" != "$CONF_DIR_CAMERA" ]; then
            CONF_DIR_CAMERA="$dir"
            export CONF_DIR_CAMERA
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_camera_conf_dir_debug_0004"
    echo ""
    return 1
}

# get_https_conf_dir
get_https_conf_dir_debug_0001="INFO: Ermittle HTTPS-Konfigurations-Verzeichnis"
get_https_conf_dir_debug_0002="SUCCESS: Verwende für HTTPS-Konfigurations-Verzeichnis \$CONF_DIR_HTTPS: %s"
get_https_conf_dir_debug_0003="SUCCESS: Verwendeter Pfad für HTTPS-Konfigurations-Verzeichnis: %s"
get_https_conf_dir_debug_0004="ERROR: Alle Pfade für HTTPS-Konfigurations-Verzeichnis fehlgeschlagen"

get_https_conf_dir() {
    # -----------------------------------------------------------------------
    # get_https_conf_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum HTTPS-Konfigurationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass CONF_DIR gesetzt ist
    : "${CONF_DIR:=$(get_config_dir)}"
    # Pfade für Backend-Verzeichnis
    local dir
    local path_system="$CONF_DIR/https"
    local path_default="$CONF_DIR/https"
    local path_fallback="/etc/ssl/fotobox"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_https_conf_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${CONF_DIR_HTTPS+x}" ] && [ -n "$CONF_DIR_HTTPS" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_https_conf_dir_debug_0002" "$CONF_DIR_HTTPS")"
        echo "$CONF_DIR_HTTPS"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_https_conf_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${CONF_DIR_HTTPS+x}" ] || [ -z "$CONF_DIR_HTTPS" ] || [ "$dir" != "$CONF_DIR_HTTPS" ]; then
            CONF_DIR_HTTPS="$dir"
            export CONF_DIR_HTTPS
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_https_conf_dir_debug_0004"
    echo ""
    return 1
}

# get_nginx_conf_dir
get_nginx_conf_dir_debug_0001="INFO: Ermittle NGINX-Konfigurations-Verzeichnis (Modus: %s)"
get_nginx_conf_dir_debug_0002="SUCCESS: Verwendeter Pfad für NGINX-Konfigurations-Verzeichnis: %s"
get_nginx_conf_dir_debug_0003="ERROR: Alle Pfade für NGINX-Konfigurations-Verzeichnis fehlgeschlagen"

get_nginx_conf_dir() {
    # -----------------------------------------------------------------------
    # get_nginx_conf_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum NGINX-Konfigurationsverzeichnis zurück
    # Funktion: Gibt den Pfad zum Originalfotos-Verzeichnis zurück
    # Parameter: $1 - Modus der WEB-Server Konfiguration, mögliche Werte:
    # .........  'external'  = Eigene Konfiguration im Projekt Ordner
    # .........  'internal'  = Integration in bestehende Konfig 
    # .........  'activated' = Aktivierte Konfiguration
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local conf_mode="${1:-external}" # Standard: 'external' für eigene Konfiguration
    # Sicherstellen, dass CONF_DIR gesetzt ist
    : "${CONF_DIR:=$(get_config_dir)}"
    # Pfade für Konfigurations-Verzeichnis
    local dir
    # Standard-Pfade für NGINX-Konfiguration bei Integration der eigenen
    # Einstellungen in einen existierenden WEB-Server
    local path_system="/etc/nginx"
    local path_system_internal="$path_system/sites-available"
    # Standard-Pfade für NGINX-Konfiguration bei eigener Konfigurations-
    # .........  Datei im Conf-Verzeichnis, wird per Symlink aufgerufen
    local path_default="$CONF_DIR/nginx"
    local path_default_external="$CONF_DIR/nginx"
    # Standard-Pfad für die aktivierte NGINX-Konfiguration
    local path_activated="$path_system/sites-enabled"

    # Prüfen, ob CONF_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$(printf "$get_nginx_conf_dir_debug_0001" "$conf_mode")"

    # Bestimmen des Ordnerpfads basierend auf dem Konfigurationsmodus
    case "$conf_mode" in
        "external")
            # Verwende die für diesen Ordner definierten Pfade
            # Deaktiviere Fallback Order(0) und Erzeugen von Symlink (0)
            dir=$(_get_folder_path "$path_default_external" "$path_default" "$path_default_external" 0 0)
            ;;
        "internal")
            # Verwende die für diesen Ordner definierten Pfade
            # Deaktiviere Fallback Order(0) und Erzeugen von Symlink (0)
            dir=$(_get_folder_path "$path_system_internal" "$path_system" "$path_system_internal" 0 0)
            ;;
        "activated")
            # Verwende die für diesen Ordner definierten Pfade
            # Deaktiviere Fallback Order(0) und Erzeugen von Symlink (0)
            dir=$(_get_folder_path "$path_activated" "$path_activated" "$path_activated" 0 0)
            ;;
        *)
            # Verwende die für diesen Ordner definierten Pfade
            # Deaktiviere Fallback Order(0) und Erzeugen von Symlink (0)
            dir=$(_get_folder_path "$path_default_external" "$path_default" "$path_default_external" 0 0)
            ;;
    esac

    # Wenn der Pfad erfolgreich ermittelt wurde, gebe ihn zurück
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_conf_dir_debug_0002" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${CONF_DIR_NGINX+x}" ] || [ -z "$CONF_DIR_NGINX" ] || [ "$dir" != "$CONF_DIR_NGINX" ]; then
            CONF_DIR_NGINX="$dir"
            export CONF_DIR_NGINX
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_nginx_conf_dir_debug_0003"
    echo ""
    return 1
}

# get_template_dir
get_template_dir_debug_0001="INFO: Ermittle Template-Verzeichnis"
get_template_dir_debug_0002="SUCCESS: Verwende für Template-Verzeichnis \$CONF_DIR_TEMPLATES : %s"
get_template_dir_debug_0003="SUCCESS: Verwendeter Pfad für Template-Verzeichnis: %s"
get_template_dir_debug_0004="INFO: Modulname: '%s', prüfe Verzeichniseignung"
get_template_dir_debug_0005="SUCCESS: Verwendeter Pfad für Modul-spezifisches Template-Verzeichnis: %s"
get_template_dir_debug_0006="ERROR: Alle Pfade für Template-Verzeichnis fehlgeschlagen"
get_template_dir_debug_0007="ERROR: Fehler beim Erstellen des Modul-spezifisches Verzeichnisses: %s, Fallback auf Basis-Verzeichnis: %s"

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
    # Sicherstellen, dass CONF_DIR gesetzt ist
    : "${CONF_DIR:=$(get_config_dir)}"
    local dir
    local path_system="$CONF_DIR/templates"
    local path_default="$CONF_DIR/templates"
    local path_fallback="$CONF_DIR/templates"
        
    # Eröffnungsmeldung im Debug Modus
    debug "$get_template_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${CONF_DIR_TEMPLATES+x}" ] && [ -n "$CONF_DIR_TEMPLATES" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_template_dir_debug_0002" "$CONF_DIR_TEMPLATES")"
        dir="$CONF_DIR_TEMPLATES"
    else
        # Verwende die für diesen Ordner definierten Pfade
        # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
        dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)

        # Basis-Verzeichnis konnte nicht erzeugt werden
        if [ -z "$dir" ]; then
            debug "$(printf "$get_template_dir_debug_0006")"
            echo ""
            return 1
        fi

        # System-Variable aktualisieren, wenn nötig
        if [ -n "$dir" ]; then
            if [ -z "${CONF_DIR_TEMPLATES+x}" ] || [ -z "$CONF_DIR_TEMPLATES" ] || [ "$dir" != "$CONF_DIR_TEMPLATES" ]; then
                CONF_DIR_TEMPLATES="$dir"
                export CONF_DIR_TEMPLATES
            fi
        fi
    fi
    
    # Wenn kein Modulname übergeben wurde, gib das Basis-Verzeichnis zurück
    if [ -z "$modul_name" ]; then
        debug "$(printf "$get_template_dir_debug_0003" "$dir")"
        echo "$dir"
        return 0
    fi

    # Modul-Name validieren und bereinigen
    debug "$(printf "$get_template_dir_debug_0004" "$modul_name")"
    
    # Verwende die Helferfunktion für die Bereinigung
    local clean_modul_name=$(_get_clean_foldername "$modul_name")

    # Erstellt das Modul-Unterverzeichnis
    # Stellen Sie sicher, dass dir keine abschließenden Slashes hat
    dir=${dir%/}        
    local modul_dir="${dir}/${clean_modul_name}"

     if _create_directory "$modul_dir"; then
        debug "$(printf "$get_template_dir_debug_0005" "$modul_dir")"
        echo "$modul_dir"
        return 0
    else
        debug "$(printf "$get_template_dir_debug_0007" "$modul_dir" "$dir")"
        # Fallback auf das Basis-Verzeichnis bei Fehler
        debug "$(printf "$get_template_dir_debug_0003" "$dir")"
        echo "$dir"
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Daten-Verzeichnis
# ---------------------------------------------------------------------------

# get_data_dir
get_data_dir_debug_0001="INFO: Ermittle Daten-Verzeichnis"
get_data_dir_debug_0002="SUCCESS: Verwende für Daten-Verzeichnis \$DATA_DIR: %s"
get_data_dir_debug_0003="SUCCESS: Verwendeter Pfad für Daten-Verzeichnis: %s"
get_data_dir_debug_0004="ERROR: Alle Pfade für Daten-Verzeichnis fehlgeschlagen"

get_data_dir() {
    # -----------------------------------------------------------------------
    # get_data_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Datenverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Datenverzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    : "${INSTALL_DIR:=$(get_install_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$INSTALL_DIR/data"
    local path_default="$INSTALL_DIR/data"
    local path_fallback="/var/lib/fotobox"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_data_dir_debug_0001" 

     # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${DATA_DIR+x}" ] && [ -n "$DATA_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_data_dir_debug_0002" "$DATA_DIR")"
        echo "$DATA_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und deaktiviere Erzeugen von Symlink (0)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 0)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_data_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${DATA_DIR+x}" ] || [ -z "$DATA_DIR" ] || [ "$dir" != "$DATA_DIR" ]; then
            DATA_DIR="$dir"
            export DATA_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_data_dir_debug_0004"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Frontend-Verzeichnis
# ---------------------------------------------------------------------------

# get_frontend_dir
get_frontend_dir_debug_0001="INFO: Ermittle Frontend-Verzeichnis"
get_frontend_dir_debug_0002="SUCCESS: Verwende für Frontend-Verzeichnis \$FRONTEND_DIR: %s"
get_frontend_dir_debug_0003="SUCCESS: Verwendeter Pfad für Frontend-Verzeichnis: %s"
get_frontend_dir_debug_0004="ERROR: Alle Pfade für Frontend-Verzeichnis fehlgeschlagen"

get_frontend_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Frontend-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    : "${INSTALL_DIR:=$(get_install_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$INSTALL_DIR/frontend"
    local path_default="$INSTALL_DIR/frontend"
    local path_fallback="/var/www/html/fotobox"
        
    # Eröffnungsmeldung im Debug Modus
    debug "$get_frontend_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR+x}" ] && [ -n "$FRONTEND_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_frontend_dir_debug_0002" "$FRONTEND_DIR")"
        echo "$FRONTEND_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${FRONTEND_DIR+x}" ] || [ -z "$FRONTEND_DIR" ] || [ "$dir" != "$FRONTEND_DIR" ]; then
            FRONTEND_DIR="$dir"
            export FRONTEND_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_dir_debug_0004"
    echo ""
    return 1
}

# get_frontend_css_dir
get_frontend_css_dir_debug_0001="INFO: Ermittle Frontend-CSS-Verzeichnis"
get_frontend_css_dir_debug_0002="SUCCESS: Verwende für Frontend-CSS-Verzeichnis \$FRONTEND_DIR_CSS: %s"
get_frontend_css_dir_debug_0003="SUCCESS: Verwendeter Pfad für Frontend-CSS-Verzeichnis: %s"
get_frontend_css_dir_debug_0004="ERROR: Alle Pfade für Frontend-CSS-Verzeichnis fehlgeschlagen"

get_frontend_css_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_css_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum CSS-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass FRONTEND_DIR gesetzt ist
    : "${FRONTEND_DIR:=$(get_frontend_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$FRONTEND_DIR/css"
    local path_default="$FRONTEND_DIR/css"
    local path_fallback="$FRONTEND_DIR/css"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_frontend_css_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR_CSS+x}" ] && [ -n "$FRONTEND_DIR_CSS" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_frontend_css_dir_debug_0002" "$FRONTEND_DIR_CSS")"
        echo "$FRONTEND_DIR_CSS"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_css_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${FRONTEND_DIR_CSS+x}" ] || [ -z "$FRONTEND_DIR_CSS" ] || [ "$dir" != "$FRONTEND_DIR_CSS" ]; then
            FRONTEND_DIR_CSS="$dir"
            export FRONTEND_DIR_CSS
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_css_dir_debug_0004"
    echo ""
    return 1
}

# get_frontend_fonts_dir
get_frontend_fonts_dir_debug_0001="INFO: Ermittle Frontend-Fonts-Verzeichnis"
get_frontend_fonts_dir_debug_0002="SUCCESS: Verwende für Frontend-Fonts-Verzeichnis \$FRONTEND_DIR_FONTS: %s"
get_frontend_fonts_dir_debug_0003="SUCCESS: Verwendeter Pfad für Frontend-Fonts-Verzeichnis: %s"
get_frontend_fonts_dir_debug_0004="ERROR: Alle Pfade für Frontend-Fonts-Verzeichnis fehlgeschlagen"

get_frontend_fonts_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_fonts_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Fonts-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass FRONTEND_DIR gesetzt ist
    : "${FRONTEND_DIR:=$(get_frontend_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$FRONTEND_DIR/fonts"
    local path_default="$FRONTEND_DIR/fonts"
    local path_fallback="$FRONTEND_DIR/fonts"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_frontend_fonts_dir_debug_0001" 

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR_FONTS+x}" ] && [ -n "$FRONTEND_DIR_FONTS" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_frontend_fonts_dir_debug_0002" "$FRONTEND_DIR_FONTS")"
        echo "$FRONTEND_DIR_FONTS"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_fonts_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${FRONTEND_DIR_FONTS+x}" ] || [ -z "$FRONTEND_DIR_FONTS" ] || [ "$dir" != "$FRONTEND_DIR_FONTS" ]; then
            FRONTEND_DIR_FONTS="$dir"
            export FRONTEND_DIR_FONTS
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_fonts_dir_debug_0004"
    echo ""
    return 1
}

# get_frontend_js_dir
get_frontend_js_dir_debug_0001="INFO: Ermittle Frontend-JavaScript-Verzeichnis"
get_frontend_js_dir_debug_0002="SUCCESS: Verwende für Frontend-JavaScript-Verzeichnis \$FRONTEND_DIR_JS: %s"
get_frontend_js_dir_debug_0003="SUCCESS: Verwendeter Pfad für Frontend-JavaScript-Verzeichnis: %s"
get_frontend_js_dir_debug_0004="ERROR: Alle Pfade für Frontend-JavaScript-Verzeichnis fehlgeschlagen"

get_frontend_js_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_js_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum JavaScript-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass FRONTEND_DIR gesetzt ist
    : "${FRONTEND_DIR:=$(get_frontend_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$FRONTEND_DIR/js"
    local path_default="$FRONTEND_DIR/js"
    local path_fallback="$FRONTEND_DIR/js"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_frontend_js_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR_JS+x}" ] && [ -n "$FRONTEND_DIR_JS" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_frontend_js_dir_debug_0002" "$FRONTEND_DIR_JS")"
        echo "$FRONTEND_DIR_JS"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_js_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${FRONTEND_DIR_JS+x}" ] || [ -z "$FRONTEND_DIR_JS" ] || [ "$dir" != "$FRONTEND_DIR_JS" ]; then
            FRONTEND_DIR_JS="$dir"
            export FRONTEND_DIR_JS
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_js_dir_debug_0004"
    echo ""
    return 1
}

# get_photos_dir
get_photos_dir_debug_0001="INFO: Ermittle Fotos-Verzeichnis"
get_photos_dir_debug_0002="SUCCESS: Verwende für Fotos-Verzeichnis \$FRONTEND_DIR_PHOTOS: %s"
get_photos_dir_debug_0003="SUCCESS: Verwendeter Pfad für Fotos-Verzeichnis: %s"
get_photos_dir_debug_0004="ERROR: Alle Pfade für Fotos-Verzeichnis fehlgeschlagen"

get_photos_dir() {
    # -----------------------------------------------------------------------
    # get_photos_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Fotos-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass FRONTEND_DIR gesetzt ist
    : "${FRONTEND_DIR:=$(get_frontend_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$FRONTEND_DIR/photos"
    local path_default="$FRONTEND_DIR/photos"
    local path_fallback="$FRONTEND_DIR/photos"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_photos_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR_PHOTOS+x}" ] && [ -n "$FRONTEND_DIR_PHOTOS" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_photos_dir_debug_0002" "$FRONTEND_DIR_PHOTOS")"
        echo "$FRONTEND_DIR_PHOTOS"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_photos_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${FRONTEND_DIR_PHOTOS+x}" ] || [ -z "$FRONTEND_DIR_PHOTOS" ] || [ "$dir" != "$FRONTEND_DIR_PHOTOS" ]; then
            FRONTEND_DIR_PHOTOS="$dir"
            export FRONTEND_DIR_PHOTOS
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_photos_dir_debug_0004"
    echo ""
    return 1
}

# get_photos_originals_dir
get_photos_originals_dir_debug_0001="INFO: Ermittle Original-Fotos-Verzeichnis"
get_photos_originals_dir_debug_0002="SUCCESS: Verwende für Original-Fotos-Verzeichnis \$FRONTEND_DIR_PHOTOS_ORIGINAL: %s"
get_photos_originals_dir_debug_0003="SUCCESS: Verwendeter Pfad für Original-Fotos-Verzeichnis: %s"
get_photos_originals_dir_debug_0004="INFO: Eventname: '%s', prüfe Verzeichniseignung"
get_photos_originals_dir_debug_0005="SUCCESS: Verwendeter Pfad für Event-spezifisches Original-Fotos-Verzeichnis: %s"
get_photos_originals_dir_debug_0006="ERROR: Alle Pfade für Original-Fotos-Verzeichnis fehlgeschlagen"
get_photos_originals_dir_debug_0007="ERROR: Fehler beim Erstellen des Event-spezifischen Verzeichnisses: %s, Fallback auf Basis-Verzeichnis: %s"

get_photos_originals_dir() {
    # -----------------------------------------------------------------------
    # get_photos_originals_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Originalfotos-Verzeichnis zurück
    # Parameter: $1 - (Optional) Name des Events
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local event_name="${1:-}"
    # Sicherstellen, dass FRONTEND_DIR_PHOTOS gesetzt ist
    : "${FRONTEND_DIR_PHOTOS:=$(get_photos_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$FRONTEND_DIR_PHOTOS/original"
    local path_default="$FRONTEND_DIR_PHOTOS/original"
    local path_fallback="$FRONTEND_DIR_PHOTOS/original"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_photos_originals_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR_PHOTOS_ORIGINAL+x}" ] && [ -n "$FRONTEND_DIR_PHOTOS_ORIGINAL" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_photos_originals_dir_debug_0002" "$FRONTEND_DIR_PHOTOS_ORIGINAL")"
        dir="$FRONTEND_DIR_PHOTOS_ORIGINAL"
    else
        # Verwende die für diesen Ordner definierten Pfade
        # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
        dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    

        # Basis-Verzeichnis konnte nicht erzeugt werden
        if [ -z "$dir" ]; then
            debug "$(printf "$get_photos_originals_dir_debug_0006")"
            echo ""
            return 1
        fi

        # System-Variable aktualisieren, wenn nötig
        if [ -n "$dir" ]; then
            if [ -z "${FRONTEND_DIR_PHOTOS_ORIGINAL+x}" ] || [ -z "$FRONTEND_DIR_PHOTOS_ORIGINAL" ] || [ "$dir" != "$FRONTEND_DIR_PHOTOS_ORIGINAL" ]; then
                FRONTEND_DIR_PHOTOS_ORIGINAL="$dir"
                export FRONTEND_DIR_PHOTOS_ORIGINAL
            fi
        fi
    fi

    # Wenn kein Eventname übergeben wurde, gib das Basis-Verzeichnis zurück
    if [ -z "$event_name" ]; then
        debug "$(printf "$get_photos_originals_dir_debug_0003" "$dir")"
        echo "$dir"
        return 0
    fi

    # Event-Name validieren und bereinigen
    debug "$(printf "$get_photos_originals_dir_debug_0004" "$event_name")"
    
    # Verwende die Helferfunktion für die Bereinigung
    local clean_event_name=$(_get_clean_foldername "$event_name")
    
    # Erstelle das Event-Unterverzeichnis
    # Stellen Sie sicher, dass dir keine abschließenden Slashes hat
    dir=${dir%/}        
    local event_dir="${dir}/${clean_event_name}"

    if _create_directory "$event_dir"; then
        debug "$(printf "$get_photos_originals_dir_debug_0005" "$event_dir")"
        echo "$event_dir"
        return 0
    else
        debug "$(printf "$get_photos_originals_dir_debug_0007" "$event_dir" "$dir")"
        # Fallback auf das Basis-Verzeichnis bei Fehler
        debug "$(printf "$get_photos_originals_dir_debug_0003" "$dir")"
        echo "$dir"
        return 0
    fi
}

# get_photos_gallery_dir
get_photos_gallery_dir_debug_0001="INFO: Ermittle Galerie(Thumbnail)-Verzeichnis"
get_photos_gallery_dir_debug_0002="SUCCESS: Verwende für Galerie(Thumbnail)-Verzeichnis \$FRONTEND_DIR_PHOTOS_THUMBNAILS: %s"
get_photos_gallery_dir_debug_0003="SUCCESS: Verwendeter Pfad für Galerie(Thumbnail)-Verzeichnis: %s"
get_photos_gallery_dir_debug_0004="INFO: Eventname: '%s', prüfe Verzeichniseignung"
get_photos_gallery_dir_debug_0005="SUCCESS: Verwendeter Pfad für Event-spezifisches Galerie(Thumbnail)-Verzeichnis: %s"
get_photos_gallery_dir_debug_0006="ERROR: Alle Pfade für Galerie(Thumbnail)-Verzeichnis fehlgeschlagen"
get_photos_gallery_dir_debug_0007="ERROR: Fehler beim Erstellen des Event-spezifischen Verzeichnisses: %s, Fallback auf Basis-Verzeichnis: %s"

get_photos_gallery_dir() {
    # -----------------------------------------------------------------------
    # get_photos_gallery_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Galerie(Thumbnail)-Verzeichnis zurück
    # Parameter: $1 - (Optional) Name des Events
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local event_name="${1:-}"
    # Sicherstellen, dass FRONTEND_DIR_PHOTOS gesetzt ist
    : "${FRONTEND_DIR_PHOTOS:=$(get_photos_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$FRONTEND_DIR_PHOTOS/gallery"
    local path_default="$FRONTEND_DIR_PHOTOS/gallery"
    local path_fallback="$FRONTEND_DIR_PHOTOS/gallery"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_photos_gallery_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR_PHOTOS_THUMBNAILS+x}" ] && [ -n "$FRONTEND_DIR_PHOTOS_THUMBNAILS" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_photos_originals_dir_debug_0002" "$FRONTEND_DIR_PHOTOS_THUMBNAILS")"
        dir="$FRONTEND_DIR_PHOTOS_THUMBNAILS"
    else
        # Verwende die für diesen Ordner definierten Pfade
        # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
        dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    

        # Basis-Verzeichnis konnte nicht erzeugt werden
        if [ -z "$dir" ]; then
            debug "$(printf "$get_photos_gallery_dir_debug_0006")"
            echo ""
            return 1
        fi

        if [ -n "$dir" ]; then
            if [ -z "${FRONTEND_DIR_PHOTOS_THUMBNAILS+x}" ] || [ -z "$FRONTEND_DIR_PHOTOS_THUMBNAILS" ] || [ "$dir" != "$FRONTEND_DIR_PHOTOS_THUMBNAILS" ]; then
                FRONTEND_DIR_PHOTOS_THUMBNAILS="$dir"
                export FRONTEND_DIR_PHOTOS_THUMBNAILS
            fi
        fi
    fi

    # Wenn kein Eventname übergeben wurde, gib das Basis-Verzeichnis zurück
    if [ -z "$event_name" ]; then
        debug "$(printf "$get_photos_gallery_dir_debug_0003" "$dir")"
        echo "$dir"
        return 0
    fi

    # Event-Name validieren und bereinigen
    debug "$(printf "$get_photos_gallery_dir_debug_0004" "$event_name")"
    
    # Verwende die Helferfunktion für die Bereinigung
    local clean_event_name=$(_get_clean_foldername "$event_name")
    
    # Erstelle das Event-Unterverzeichnis
    # Stellen Sie sicher, dass dir keine abschließenden Slashes hat
    dir=${dir%/}        
    local event_dir="${dir}/${clean_event_name}"

     if _create_directory "$event_dir"; then
        debug "$(printf "$get_photos_gallery_dir_debug_0005" "$event_dir")"
        echo "$event_dir"
        return 0
    else
        debug "$(printf "$get_photos_gallery_dir_debug_0007" "$event_dir" "$dir")"
        # Fallback auf das Basis-Verzeichnis bei Fehler
        debug "$(printf "$get_photos_gallery_dir_debug_0003" "$dir")"
        echo "$dir"
        return 0
    fi
}

# get_frontend_picture_dir
get_frontend_picture_dir_debug_0001="INFO: Ermittle Frontend-Bilder-Verzeichnis"
get_frontend_picture_dir_debug_0002="SUCCESS: Verwende für Frontend-Bilder-Verzeichnis \$FRONTEND_DIR_PICTURE: %s"
get_frontend_picture_dir_debug_0003="SUCCESS: Verwendeter Pfad für Frontend-Bilder-Verzeichnis: %s"
get_frontend_picture_dir_debug_0004="ERROR: Alle Pfade für Frontend-Bilder-Verzeichnis fehlgeschlagen"

get_frontend_picture_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_picture_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Bilder-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass FRONTEND_DIR gesetzt ist
    : "${FRONTEND_DIR:=$(get_frontend_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$FRONTEND_DIR/picture"
    local path_default="$FRONTEND_DIR/picture"
    local path_fallback="$FRONTEND_DIR/picture"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_frontend_picture_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${FRONTEND_DIR_PICTURE+x}" ] && [ -n "$FRONTEND_DIR_PICTURE" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_frontend_picture_dir_debug_0002" "$FRONTEND_DIR_PICTURE")"
        echo "$FRONTEND_DIR_PICTURE"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_frontend_picture_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${FRONTEND_DIR_PICTURE+x}" ] || [ -z "$FRONTEND_DIR_PICTURE" ] || [ "$dir" != "$FRONTEND_DIR_PICTURE" ]; then
            FRONTEND_DIR_PICTURE="$dir"
            export FRONTEND_DIR_PICTURE
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_frontend_picture_dir_debug_0004"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Log-Verzeichnis
# ---------------------------------------------------------------------------

# get_log_dir
get_log_dir_debug_0001="INFO: Ermittle Log-Verzeichnis"
get_log_dir_debug_0002="SUCCESS: Verwende für Log-Verzeichnis \$LOG_DIR: '%s'"
get_log_dir_debug_0003="SUCCESS: Verwendeter Pfad für Log-Verzeichnis: %s"
get_log_dir_debug_0004="ERROR: Alle Pfade für Log-Verzeichnis fehlgeschlagen"

get_log_dir() {
    # ------------------------------------------------------------------------------
    # get_log_dir
    # ------------------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Log-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # ------------------------------------------------------------------------------
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    : "${INSTALL_DIR:=$(get_install_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$INSTALL_DIR/log"
    local path_default="$INSTALL_DIR/log"
    local path_fallback="/var/log/fotobox"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_log_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${LOG_DIR+x}" ] && [ -n "$LOG_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_log_dir_debug_0002" "$LOG_DIR")"
        echo "$LOG_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        # Erfolg: Pfad existiert und ist les-/schreibbar
        debug "$(printf "$get_log_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren
        LOG_DIR="$dir"
        export LOG_DIR
        # Log-Verzeichnis zurückgeben
        echo "$dir"
        return 0
    fi

    debug "$get_log_dir_debug_0004"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Temp-Verzeichnis
# ---------------------------------------------------------------------------

# get_tmp_dir
get_tmp_dir_debug_0001="INFO: Ermittle temporäres Verzeichnis"
get_tmp_dir_debug_0002="SUCCESS: Verwende für temporäres Verzeichnis \$TMP_DIR: %s"
get_tmp_dir_debug_0003="SUCCESS: Verwendeter Pfad für temporäres Verzeichnis: %s"
get_tmp_dir_debug_0004="ERROR: Alle Pfade für temporäres Verzeichnis fehlgeschlagen"

get_tmp_dir() {
    # -----------------------------------------------------------------------
    # get_tmp_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum temporären Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    : "${INSTALL_DIR:=$(get_install_dir)}"
    # Pfade für Daten-Verzeichnis
    local dir
    local path_system="$INSTALL_DIR/tmp"
    local path_default="$INSTALL_DIR/tmp"
    local path_fallback="/tmp/fotobox"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_tmp_dir_debug_0001"

    # Prüfen, ob Systemvariable bereits gesetzt ist
    if [ "${TMP_DIR+x}" ] && [ -n "$TMP_DIR" ]; then
        # Systemvariable wurde bereits ermittelt, diese zurückgeben
        debug "$(printf "$get_tmp_dir_debug_0002" "$TMP_DIR")"
        echo "$TMP_DIR"
        return 0
    fi

    # Verwende die für diesen Ordner definierten Pfade
    # Aktiviere Fallback Order(1) und Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)    
    if [ -n "$dir" ]; then
        debug "$(printf "$get_tmp_dir_debug_0003" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${TMP_DIR+x}" ] || [ -z "$TMP_DIR" ] || [ "$dir" != "$TMP_DIR" ]; then
            TMP_DIR="$dir"
            export TMP_DIR
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_tmp_dir_debug_0004"
    echo ""
    return 1
}

# ---------------------------------------------------------------------------
# Verzeichnis Struktur für das Projekt sicherstellen
# ---------------------------------------------------------------------------

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

    # -> Backend Verzeichnisse prüfen
    get_backend_dir >/dev/null || return 1
    get_script_dir >/dev/null || return 1

    # -> Backup Verzeichnis
    get_backup_dir >/dev/null || return 1

    # -> Config Verzeichnisse prüfen
    get_config_dir >/dev/null || return 1
    get_camera_conf_dir >/dev/null || return 1
    get_template_dir >/dev/null || return 1
    get_template_dir "backup" >/dev/null || return 1
    get_template_dir "camera" >/dev/null || return 1
    get_template_dir "nginx" >/dev/null || return 1
    get_template_dir "systemd" >/dev/null || return 1

    # -> Daten Verzeichnis prüfen
    get_data_dir >/dev/null || return 1

    # -> Frontend Verzeichnisse prüfen
    get_frontend_dir >/dev/null || return 1
    get_frontend_css_dir >/dev/null || true
    get_frontend_js_dir >/dev/null || true
    get_frontend_fonts_dir >/dev/null || true
    get_frontend_picture_dir >/dev/null || true

    # -> Log Verzeichni prüfen
    get_log_dir >/dev/null || return 1
    
    # Fotos-Verzeichnisstruktur
    get_photos_dir >/dev/null || return 1
    get_photos_originals_dir >/dev/null || return 1
    get_photos_gallery_dir >/dev/null || return 1
    
    # NGINX-Verzeichnisstruktur
    get_nginx_conf_dir >/dev/null || return 1
    get_nginx_backup_dir >/dev/null || return 1

    # HTTPS-Verzeichnisstruktur
    get_https_conf_dir >/dev/null || return 1
    #get_https_backup_dir >/dev/null || return 1

    # Kamera-Verzeichnisstruktur
    get_camera_conf_dir >/dev/null || return 1
    #get_script_dir >/dev/null || return 1

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
    local path_system="/usr/sbin/nginx"
    local path_default="/usr/sbin/nginx"
    local path_fallback="/usr/sbin/nginx"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_nginx_systemdir_debug_0001"

    # Verwende die für diesen Ordner definierten Pfade
    # Deaktiviere Fallback Order(0) und das Erzeugen von Symlink (0)
    dir="$path_system" # $(_get_folder_path "$path_system" "$path_default" "$path_fallback" 0 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_systemdir_debug_0002" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${SYSTEM_PATH_NGINX+x}" ] || [ -z "$SYSTEM_PATH_NGINX" ] || [ "$dir" != "$SYSTEM_PATH_NGINX" ]; then
            SYSTEM_PATH_NGINX="$dir"
            export SYSTEM_PATH_NGINX
        fi
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
    # Funktion.: Gibt den Pfad zum systemd-Systemverzeichnis zurück
    # Parameter: $1 - Optional: Das Systemverzeichnis (Standard: 0)
    # ..........      Wenn '1', wird das Systemverzeichnis verwendet.
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    # Sicherstellen, dass CONF_DIR gesetzt ist
    : "${CONF_DIR:=$(get_config_dir)}"
    local system_dir="${1:-0}"

    # Pfade zu möglichen systemd-Systemverzeichnis
    local dir
    local path_system="/etc/systemd/system"
    local path_default="$CONF_DIR/systemd"
    local path_fallback="/etc/systemd/system"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_systemd_systemdir_debug_0001"

    # Verwende die für diesen Ordner definierten Pfade
    # Deaktiviere Fallback Order(0) und das Erzeugen von Symlink (0)
    # Wenn system_dir '1' ist, wird das Systemverzeichnis verwendet
    if [ "$system_dir" -eq 1 ]; then
        dir=$(_get_folder_path "$path_system" "$path_system" "$path_fallback" 0 0)
    else
        dir=$(_get_folder_path "$path_default" "$path_default" "$path_fallback" 0 0)
    fi

    if [ -n "$dir" ]; then
        debug "$(printf "$get_systemd_systemdir_debug_0002" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${SYSTEM_PATH_SYSTEMD+x}" ] || [ -z "$SYSTEM_PATH_SYSTEMD" ] || [ "$dir" != "$SYSTEM_PATH_SYSTEMD" ]; then
            SYSTEM_PATH_SYSTEMD="$dir"
            export SYSTEM_PATH_SYSTEMD
        fi
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
    # Sicherstellen, dass CONF_DIR gesetzt ist
    : "${CONF_DIR:=$(get_config_dir)}"
    # Pfade zu möglichen systemd-Systemverzeichnis
    local dir
    local path_system="/etc/ssl"
    local path_default="$CONF_DIR/ssl"
    local path_fallback="/etc/ssl"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_ssl_systemdir_debug_0001"

    # Verwende die für diesen Ordner definierten Pfade
    # Deaktiviere Fallback Order(1) und das Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_ssl_systemdir_debug_0002" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${SYSTEM_PATH_SSL+x}" ] || [ -z "$SYSTEM_PATH_SSL" ] || [ "$dir" != "$SYSTEM_PATH_SSL" ]; then
            SYSTEM_PATH_SSL="$dir"
            export SYSTEM_PATH_SSL
        fi
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
    # Sicherstellen, dass SYSTEM_PATH_SSL gesetzt ist
    : "${SYSTEM_PATH_SSL:=$(get_ssl_systemdir)}"
    # Pfade zu möglichen systemd-Systemverzeichnis
    local dir
    local path_system="/etc/ssl/certs"
    local path_default="$SYSTEM_PATH_SSL/certs"
    local path_fallback="/etc/ssl/certs"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_ssl_cert_systemdir_debug_0001"

    # Verwende die für diesen Ordner definierten Pfade
    # Deaktiviere Fallback Order(1) und das Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_ssl_cert_systemdir_debug_0002" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${SYSTEM_PATH_SSL_CERTS+x}" ] || [ -z "$SYSTEM_PATH_SSL_CERTS" ] || [ "$dir" != "$SYSTEM_PATH_SSL_CERTS" ]; then
            SYSTEM_PATH_SSL_CERTS="$dir"
            export SYSTEM_PATH_SSL_CERTS
        fi
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
    # Sicherstellen, dass SYSTEM_PATH_SSL gesetzt ist
    : "${SYSTEM_PATH_SSL:=$(get_ssl_systemdir)}"
    # Pfade zu möglichen systemd-Systemverzeichnis
    local dir
    local path_system="/etc/ssl/private"
    local path_default="$SYSTEM_PATH_SSL/private"
    local path_fallback="/etc/ssl/private"

    # Eröffnungsmeldung im Debug Modus
    debug "$get_ssl_key_systemdir_debug_0001"

    # Verwende die für diesen Ordner definierten Pfade
    # Deaktiviere Fallback Order(1) und das Erzeugen von Symlink (1)
    dir=$(_get_folder_path "$path_system" "$path_default" "$path_fallback" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_ssl_key_systemdir_debug_0002" "$dir")"
        # System-Variable aktualisieren, wenn nötig
        if [ -z "${SYSTEM_PATH_SSL_KEY+x}" ] || [ -z "$SYSTEM_PATH_SSL_KEY" ] || [ "$dir" != "$SYSTEM_PATH_SSL_KEY" ]; then
            SYSTEM_PATH_SSL_KEY="$dir"
            export SYSTEM_PATH_SSL_KEY
        fi
        echo "$dir"
        return 0
    fi

    debug "$get_ssl_key_systemdir_debug_0003"
    echo ""
    return 1
}
