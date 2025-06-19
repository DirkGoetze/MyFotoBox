#!/bin/bash
# ---------------------------------------------------------------------------
# manage_folders.sh
# ---------------------------------------------------------------------------
# Funktion: Zentrale Verwaltung der Ordnerstruktur für die Fotobox.
# ......... Stellt einheitliche Pfad-Getter bereit und erstellt Ordner bei 
# ......... Bedarf. Nach Policy müssen alle Skripte Pfade konsistent verwalten 
# ......... und sicherstellen, dass Ordner mit den korrekten Berechtigungen 
# ......... existieren.
# ---------------------------------------------------------------------------
# HINWEIS: Dieses Skript ist Bestandteil der Backend-Logik und darf nur im
# Unterordner 'backend/scripts/' abgelegt werden 
# ---------------------------------------------------------------------------
# POLICY-HINWEIS: Dieses Skript ist ein reines Funktions-/Modulskript und 
# enthält keine main()-Funktion mehr. Die Nutzung als eigenständiges 
# CLI-Programm ist nicht vorgesehen. Die Policy zur main()-Funktion gilt nur 
# für Hauptskripte.
# ---------------------------------------------------------------------------

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_FOLDERS_LOADED=0

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

# Textausgaben für das gesamte Skript
manage_folders_log_0001="KRITISCHER FEHLER: Zentrale Bibliothek lib_core.sh nicht gefunden!"
manage_folders_log_0002="Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch."
manage_folders_log_0003="KRITISCHER FEHLER: Die Kernressourcen konnten nicht geladen werden."

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ ! -f "$BASH_DIR/lib_core.sh" ]; then
    echo "$manage_folders_log_0001" >&2
    echo "$manage_folders_log_0002" >&2
    exit 1
fi

source "$BASH_DIR/lib_core.sh"

# Hybrides Ladeverhalten: 
# Bei MODULE_LOAD_MODE=1 (Installation/Update) werden alle Module geladen
# Bei MODULE_LOAD_MODE=0 (normaler Betrieb) werden Module individuell geladen
if [ "${MODULE_LOAD_MODE:-0}" -eq 1 ]; then
    load_core_resources || {
        echo "$manage_folders_log_0003" >&2
        echo "$manage_folders_log_0002" >&2
        exit 1
    }
fi
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
# Lokale Aliase für bessere Lesbarkeit
: "${USER:=$DEFAULT_USER}"
: "${GROUP:=$DEFAULT_GROUP}"
: "${MODE:=$DEFAULT_MODE}"

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt

# ===========================================================================
# Hilfsfunktionen 
# ===========================================================================

# create_symlink_to_standard_path
create_symlink_to_standard_path_debug_0001="Standard-Pfad und tatsächlicher Pfad sind identisch"
create_symlink_to_standard_path_debug_0002="Keine Schreibrechte im übergeordneten Verzeichnis"
create_symlink_to_standard_path_debug_0003="Entferne vorhandenes Verzeichnis"
create_symlink_to_standard_path_debug_0004="Verzeichnis konnte nicht entfernt werden, möglicherweise nicht leer"
create_symlink_to_standard_path_debug_0005="Symlink zeigt auf %s, wird auf %s geändert"
create_symlink_to_standard_path_debug_0006="Konnte vorhandenen Symlink nicht entfernen"
create_symlink_to_standard_path_debug_0007="Symlink existiert bereits und zeigt auf das korrekte Ziel"
create_symlink_to_standard_path_debug_0008="Eine Datei existiert bereits am Standard-Pfad"
create_symlink_to_standard_path_debug_0009="Erstelle Symlink von %s zu %s"
create_symlink_to_standard_path_debug_0010="Fehler beim Erstellen des Symlinks"
create_symlink_to_standard_path_log_0001="INFO: Symlink erstellt: %s -> %s"

create_symlink_to_standard_path() {
    # -----------------------------------------------------------------------
    # create_symlink_to_standard_path
    # -----------------------------------------------------------------------
    # Funktion: Erstellt einen Symlink vom Standard-Pfad zum tatsächlich
    # .........  verwendeten Fallback-Pfad. Dies hilft bei der Navigation und
    # .........  sorgt für eine konsistente Verzeichnisstruktur.
    # Parameter: $1 - Standard-Pfad, an dem der Symlink erstellt werden soll
    # .........  $2 - Tatsächlich verwendeter Pfad, auf den der Symlink zeigen soll
    # Rückgabe.: 0 - Erfolg (Symlink wurde erstellt oder existiert bereits korrekt)
    # .........  1 - Fehler (Symlink konnte nicht erstellt werden)
    # Extras...: Prüft Schreibrechte und aktualisiert vorhandene Symlinks bei Bedarf
    # -----------------------------------------------------------------------
    local standard_path="$1"
    local actual_path="$2"
    # Wenn die Pfade identisch sind, kein Symlink nötig
    if [ "$standard_path" = "$actual_path" ]; then
        debug "$create_symlink_to_standard_path_debug_0001: $standard_path" "CLI" "create_symlink_to_standard_path"
        return 0
    fi
    
    # Prüfe, ob wir Zugriff auf das übergeordnete Verzeichnis haben
    local parent_dir
    parent_dir=$(dirname "$standard_path")
    if [ ! -w "$parent_dir" ]; then
        debug "$create_symlink_to_standard_path_debug_0002: $parent_dir" "CLI" "create_symlink_to_standard_path"
        return 1
    fi

    # Prüfen, ob am Standard-Pfad bereits etwas existiert
    if [ -e "$standard_path" ]; then
        # Falls es ein reguläres Verzeichnis ist, entfernen (mit Vorsicht)
        if [ -d "$standard_path" ] && [ ! -L "$standard_path" ]; then
            debug "$create_symlink_to_standard_path_debug_0003: $standard_path" "CLI" "create_symlink_to_standard_path"
            # Es ist sicherer, nur leere Verzeichnisse zu entfernen
            rmdir "$standard_path" 2>/dev/null || {
                debug "$create_symlink_to_standard_path_debug_0004: $standard_path" "CLI" "create_symlink_to_standard_path"
                return 1
            }
        # Falls es ein Symlink auf einen anderen Pfad ist, aktualisieren
        elif [ -L "$standard_path" ]; then
            local current_target
            current_target=$(readlink -f "$standard_path")
            if [ "$current_target" != "$actual_path" ]; then
                debug "$(printf "$create_symlink_to_standard_path_debug_0005" "$current_target" "$actual_path")" "CLI" "create_symlink_to_standard_path"
                rm -f "$standard_path" 2>/dev/null || {
                    debug "$create_symlink_to_standard_path_debug_0006: $standard_path" "CLI" "create_symlink_to_standard_path"
                    return 1
                }
            else
                # Symlink zeigt bereits auf das richtige Ziel
                debug "$create_symlink_to_standard_path_debug_0007: $actual_path" "CLI" "create_symlink_to_standard_path"
                return 0
            fi
        # Falls es eine reguläre Datei ist, abbrechen
        elif [ -f "$standard_path" ]; then
            debug "$create_symlink_to_standard_path_debug_0008: $standard_path" "CLI" "create_symlink_to_standard_path"
            return 1
        fi
    fi
    
    # Symlink erstellen
    debug "$(printf "$create_symlink_to_standard_path_debug_0009" "$standard_path" "$actual_path")" "CLI" "create_symlink_to_standard_path"
    ln -sf "$actual_path" "$standard_path" || {
        debug "$create_symlink_to_standard_path_debug_0010" "CLI" "create_symlink_to_standard_path"
        return 1
    }

    log "$(printf "$create_symlink_to_standard_path_log_0001" "$standard_path" "$actual_path")" "create_symlink_to_standard_path"
    return 0
}

# create_directory
create_directory_debug_0001="Kein Verzeichnis angegeben"
create_directory_debug_0002="Verzeichnis %s existiert nicht, wird erstellt"
create_directory_debug_0003="Fehler beim Erstellen von %s"
create_directory_debug_0004="Warnung: chown für %s fehlgeschlagen, fahre fort"
create_directory_debug_0005="Warnung: chmod für %s fehlgeschlagen, fahre fort"
create_directory_debug_0006="Verzeichnis %s erfolgreich vorbereitet"
create_directory_log_0001="ERROR: create_directory: Kein Verzeichnis angegeben"
create_directory_log_0002="ERROR: Fehler beim Erstellen des Verzeichnisses %s"
create_directory_log_0003="INFO: Verzeichnis %s wurde erstellt"
create_directory_log_0004="WARN: Fehler beim Setzen der Berechtigungen für %s"
create_directory_log_0005="INFO: Verzeichnis %s erfolgreich vorbereitet"
create_directory_log_0006="ERROR: Verzeichnis %s konnte nicht korrekt vorbereitet werden"

create_directory() {
    # -----------------------------------------------------------------------
    # create_directory
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
    if [ -z "$dir" ]; then
        log "$create_directory_log_0001" "create_directory"
        debug "$create_directory_debug_0001" "CLI" "create_directory"
        return 1
    fi

    # Verzeichnis erstellen, falls es nicht existiert
    if [ ! -d "$dir" ]; then
        debug "$(printf "$create_directory_debug_0002" "$dir")" "CLI" "create_directory"
        mkdir -p "$dir" || {
            log "$(printf "$create_directory_log_0002" "$dir")" "create_directory"
            debug "$(printf "$create_directory_debug_0003" "$dir")" "CLI" "create_directory"
            return 1
        }
        log "$(printf "$create_directory_log_0003" "$dir")"
    fi

    # Berechtigungen setzen
    chown "$user:$group" "$dir" 2>/dev/null || {
        log "$(printf "$create_directory_log_0004" "$dir")" "create_directory"
        debug "$(printf "$create_directory_debug_0004" "$dir")" "CLI" "create_directory"
        # Fehler beim chown ist kein kritischer Fehler
    }

    chmod "$mode" "$dir" 2>/dev/null || {
        log "$(printf "$create_directory_log_0004" "$dir")" "create_directory"
        debug "$(printf "$create_directory_debug_0005" "$dir")" "CLI" "create_directory"
        # Fehler beim chmod ist kein kritischer Fehler
    }

    # Überprüfen, ob das Verzeichnis existiert und lesbar ist
    if [ -d "$dir" ] && [ -r "$dir" ]; then
        log "$(printf "$create_directory_log_0005" "$dir")" "create_directory"
        debug "$(printf "$create_directory_debug_0006" "$dir")" "CLI" "create_directory"
        return 0
    else
        log "$(printf "$create_directory_log_0006" "$dir")" "create_directory"
        return 1
    fi
}

# get_folder_path
get_folder_path_debug_0001="Prüfe Pfad: Standardpfad=%s, Fallback=%s"
get_folder_path_debug_0002="Verwende Standardpfad: %s"
get_folder_path_debug_0003="Standard-Pfad %s nicht verfügbar, versuche Fallback"
get_folder_path_debug_0004="Verwende Fallback-Pfad: %s"
get_folder_path_debug_0005="Versuche Symlink von %s zu %s zu erstellen"
get_folder_path_debug_0006="Symlink-Erstellung fehlgeschlagen, fahre trotzdem fort"
get_folder_path_debug_0007="Fallback-Pfad %s nicht verfügbar"
get_folder_path_debug_0008="Verwende Root-Verzeichnis als letzten Fallback: %s"
get_folder_path_log_0001="ERROR: Kein gültiger Pfad für die Ordnererstellung verfügbar"

get_folder_path() {
    # -----------------------------------------------------------------------
    # get_folder_path
    # -----------------------------------------------------------------------
    # Funktion: Hilfsfunktion zum Ermitteln und Erstellen eines Ordners mit 
    # .........  Fallback-Logik. Erstellt zusätzlich einen Symlink vom
    # .........  Standard-Pfad zum tatsächlich verwendeten Pfad, wenn möglich.
    # Parameter: $1 - Standard-Pfad
    # .........  $2 - Fallback-Pfad (falls Standard-Pfad nicht verfügbar)
    # .........  $3 - (Optional) Fallback zum Projekthauptverzeichnis (1=ja, 0=nein, Default: 1)
    # .........  $4 - (Optional) Symlink erstellen (1=ja, 0=nein, Default: 1)
    # Rückgabe.: Den Pfad zum verfügbaren Ordner oder leeren String bei Fehler
    # Extras...: Implementiert eine mehrschichtige Fallback-Strategie
    # -----------------------------------------------------------------------
    local standard_path="$1"
    local fallback_path="$2"
    local use_root_fallback="${3:-1}" # Standard: Ja, Root-Fallback verwenden
    local create_symlink="${4:-1}"    # Standard: Ja, Symlink erstellen
    local actual_path=""

    # Versuchen, den Standardpfad zu verwenden
    debug "$(printf "$get_folder_path_debug_0001" "$standard_path" "$fallback_path")" "CLI" "get_folder_path"
    if create_directory "$standard_path"; then
        debug "$(printf "$get_folder_path_debug_0002" "$standard_path")" "CLI" "get_folder_path"
        actual_path="$standard_path"
    else
        # Versuchen, den Fallback-Pfad zu verwenden
        debug "$(printf "$get_folder_path_debug_0003" "$standard_path")" "CLI" "get_folder_path"
        if create_directory "$fallback_path"; then
            debug "$(printf "$get_folder_path_debug_0004" "$fallback_path")" "CLI" "get_folder_path"
            actual_path="$fallback_path"
            
            # Wenn gewünscht und möglich, einen Symlink vom Standard-Pfad zum Fallback erstellen
            if [ "$create_symlink" -eq 1 ]; then
                debug "$(printf "$get_folder_path_debug_0005" "$standard_path" "$fallback_path")" "CLI" "get_folder_path"
                create_symlink_to_standard_path "$standard_path" "$fallback_path" || {
                    debug "$get_folder_path_debug_0006" "CLI" "get_folder_path"
                    # Fehler beim Symlink ist kein kritischer Fehler
                }
            fi
        else
            # Als letzte Option das Root-Verzeichnis verwenden
            debug "$(printf "$get_folder_path_debug_0007" "$fallback_path")" "CLI" "get_folder_path"
            if [ "$use_root_fallback" -eq 1 ]; then
                local root_path
                root_path=$(get_install_dir)
                if [ -n "$root_path" ] && create_directory "$root_path"; then
                    debug "$(printf "$get_folder_path_debug_0008" "$root_path")" "CLI" "get_folder_path"
                    actual_path="$root_path"
                    # Bei Verwendung des Root-Fallbacks ist kein Symlink nötig, da alle Standardpfade
                    # bereits im Installationsverzeichnis liegen sollten
                fi
            fi
        fi
    fi
    
    if [ -n "$actual_path" ]; then
        echo "$actual_path"
        return 0
    fi

    # Wenn alle Versuche fehlschlagen, eine Fehlermeldung im Log ausgeben    
    log "$get_folder_path_log_0001" "get_folder_path"
    return 1
}

# ===========================================================================
# Get- und Set-Funktionen für die Ordnerstruktur 
# ===========================================================================

# get_install_dir
get_install_dir_debug_0001="Ermittle Installations-Verzeichnis"
get_install_dir_debug_0002="Verwende bereits definiertes INSTALL_DIR: %s"
get_install_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für Installations-Verzeichnis"
get_install_dir_debug_0004="Verwende Pfad für Installations-Verzeichnis: %s"
get_install_dir_debug_0005="Alle Pfade für Installations-Verzeichnis fehlgeschlagen, verwende aktuelles Verzeichnis"

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
    debug "$get_install_dir_debug_0001" "CLI" "get_install_dir"
    if [ -n "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR" ]; then
        debug "$(printf "$get_install_dir_debug_0002" "$INSTALL_DIR")" "CLI" "get_install_dir"
        create_directory "$INSTALL_DIR" || true
        echo "$INSTALL_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "$get_install_dir_debug_0003" "CLI" "get_install_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_INSTALL" "$FALLBACK_DIR_INSTALL" 0)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_install_dir_debug_0004" "$dir")" "CLI" "get_install_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall das aktuelle Verzeichnis verwenden
    debug "$get_install_dir_debug_0005" "CLI" "get_install_dir"
    echo "$(pwd)/fotobox"
    return 0
}

# ---------------------------------------------------------------------------
# Backend-Verzeichnis
# ---------------------------------------------------------------------------

# get_backend_dir
get_backend_dir_debug_0001="Ermittle Backend-Verzeichnis"
get_backend_dir_debug_0002="Verwende bereits definiertes BACKEND_DIR: %s"
get_backend_dir_debug_0003="Prüfe Standard-Backend-Verzeichnis: %s"
get_backend_dir_debug_0004="Verwende Standard-Backend-Verzeichnis: %s"
get_backend_dir_debug_0005="Standard-Backend-Verzeichnis nicht verfügbar, verwende Fallback: %s"
get_backend_dir_debug_0006="Fallback-Backend-Verzeichnis nicht verfügbar, verwende: %s"

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
    debug "$get_backend_dir_debug_0001" "CLI" "get_backend_dir"
    if [ -n "$BACKEND_DIR" ] && [ -d "$BACKEND_DIR" ]; then
        debug "$(printf "$get_backend_dir_debug_0002" "$BACKEND_DIR")" "CLI" "get_backend_dir"
        create_directory "$BACKEND_DIR" || true
        echo "$BACKEND_DIR"
        return 0
    fi
    
    # Standardpfad verwenden
    dir="$DEFAULT_DIR_BACKEND"
    debug "$(printf "$get_backend_dir_debug_0003" "$dir")" "CLI" "get_backend_dir"
    if [ -d "$dir" ]; then
        create_directory "$dir" || true
        debug "$(printf "$get_backend_dir_debug_0004" "$dir")" "CLI" "get_backend_dir"
        echo "$dir"
        return 0
    fi
    
    # Fallback auf alternatives Verzeichnis
    dir="$FALLBACK_DIR_BACKEND"
    debug "$(printf "$get_backend_dir_debug_0005" "$dir")" "CLI" "get_backend_dir"
    create_directory "$dir" || true
    
    # Als letzten Ausweg, ein Unterverzeichnis des Install-Verzeichnisses verwenden
    if [ ! -d "$dir" ]; then
        local install_dir
        install_dir=$(get_install_dir)
        dir="$install_dir/backend"
        debug "$(printf "$get_backend_dir_debug_0006" "$dir")" "CLI" "get_backend_dir"
        create_directory "$dir" || true
    fi
    
    echo "$dir"
    return 0
}

# get_script_dir
get_script_dir_debug_0001="Ermittle Backend-Skript-Verzeichnis"
get_script_dir_debug_0002="Verwende bereits definiertes BASH_DIR: %s"
get_script_dir_debug_0003="Prüfe Standard-Pfad für Backend-Skript-Verzeichnis"
get_script_dir_debug_0004="Verwende Standard-Pfad für Backend-Skript-Verzeichnis: %s"
get_script_dir_debug_0005="Versuche Backend-Skript-Verzeichnis über Installationsverzeichnis zu ermitteln: %s"

get_script_dir() {
    # -----------------------------------------------------------------------
    # get_script_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Backend-Skript-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    local standard_path="$DEFAULT_DIR_BACKEND_SCRIPTS"
        
    # Prüfen, ob BASH_DIR bereits gesetzt ist
    debug "$get_script_dir_debug_0001" "CLI" "get_script_dir"
    if [ -n "$BASH_DIR" ] && [ -d "$BASH_DIR" ]; then
        debug "$(printf "$get_script_dir_debug_0002" "$BASH_DIR")" "CLI" "get_script_dir"
        create_directory "$BASH_DIR" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        
        # Wenn das definierte Verzeichnis nicht dem Standard entspricht, erstelle einen Symlink
        if [ "$BASH_DIR" != "$standard_path" ]; then
            create_symlink_to_standard_path "$standard_path" "$BASH_DIR" || true
        fi
        
        echo "$BASH_DIR"
        return 0
    fi
    
    # Verwende die in lib_core definierten Pfade
    debug "$get_script_dir_debug_0003" "CLI" "get_script_dir"
    dir="$DEFAULT_DIR_BACKEND_SCRIPTS"
    if [ -d "$dir" ]; then
        debug "$(printf "$get_script_dir_debug_0004" "$dir")" "CLI" "get_script_dir"
        create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        echo "$dir"
        return 0
    fi
    
    # Wenn das Verzeichnis nicht existiert, versuchen wir es über das Installationsverzeichnis zu ermitteln
    local install_dir
    install_dir=$(get_install_dir)
    dir="$install_dir/backend/scripts"
    debug "$(printf "$get_script_dir_debug_0005" "$dir")" "CLI" "get_script_dir"
    create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
    
    # Versuche einen Symlink vom Standard-Pfad zu erstellen, wenn der Fallback verwendet wird
    create_symlink_to_standard_path "$standard_path" "$dir" || true
    
    echo "$dir"
    return 0
}

# set_script_permissions
set_script_permissions_debug_0001="Skript-Verzeichnis %s existiert nicht"
set_script_permissions_debug_0002="Setze Ausführbarkeitsrechte für %s/*.sh"
set_script_permissions_debug_0003="Ausführbarkeitsrechte erfolgreich gesetzt"

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
get_venv_dir_debug_0001="Ermittle Python Virtual Environment-Verzeichnis"
get_venv_dir_debug_0002="Verwende bereits definiertes BACKEND_VENV_DIR: %s"
get_venv_dir_debug_0003="Prüfe Standard-VENV-Verzeichnis: %s"
get_venv_dir_debug_0004="Verwende Standard-VENV-Verzeichnis: %s"
get_venv_dir_debug_0005="Standard-VENV-Verzeichnis nicht verfügbar, verwende Fallback: %s"
get_venv_dir_debug_0006="Fallback-VENV-Verzeichnis nicht verfügbar, verwende: %s"

get_venv_dir() {
    # -----------------------------------------------------------------------
    # get_venv_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Python Virtual Environment zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    
    debug "$get_venv_dir_debug_0001" "CLI" "get_venv_dir"
    
    # Prüfen, ob BACKEND_VENV_DIR bereits gesetzt ist (z.B. vom install.sh)
    if [ -n "$BACKEND_VENV_DIR" ] && [ -d "$BACKEND_VENV_DIR" ]; then
        debug "$(printf "$get_venv_dir_debug_0002" "$BACKEND_VENV_DIR")" "CLI" "get_venv_dir"
        create_directory "$BACKEND_VENV_DIR" || true
        echo "$BACKEND_VENV_DIR"
        return 0
    fi
    
    # Standardpfad verwenden
    dir="$DEFAULT_DIR_BACKEND_VENV"
    debug "$(printf "$get_venv_dir_debug_0003" "$dir")" "CLI" "get_venv_dir"
    
    if [ -d "$dir" ]; then
        create_directory "$dir" || true
        debug "$(printf "$get_venv_dir_debug_0004" "$dir")" "CLI" "get_venv_dir"
        echo "$dir"
        return 0
    fi
    
    # Fallback auf alternatives Verzeichnis
    dir="$FALLBACK_BACKEND_VENV_DIR"
    debug "$(printf "$get_venv_dir_debug_0005" "$dir")" "CLI" "get_venv_dir"
    create_directory "$dir" || true
    
    # Als letzten Ausweg, ein Unterverzeichnis im Backend-Verzeichnis verwenden
    if [ ! -d "$dir" ]; then
        local backend_dir
        backend_dir=$(get_backend_dir)
        dir="$backend_dir/venv"
        debug "$(printf "$get_venv_dir_debug_0006" "$dir")" "CLI" "get_venv_dir"
        create_directory "$dir" || true
    fi
    
    echo "$dir"
    return 0
}

# get_pip_path
get_pip_path_debug_0001="Ermittle Pfad zur pip-Binary"
get_pip_path_debug_0002="Verwende Unix/Linux pip-Pfad: %s"
get_pip_path_debug_0003="Verwende Windows pip-Pfad: %s"
get_pip_path_debug_0004="Verwende Python-Modul für pip: %s -m pip"
get_pip_path_debug_0005="Kein pip im venv gefunden, fallback auf System-pip"

get_pip_path() {
    # -----------------------------------------------------------------------
    # get_pip_path
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zur pip-Binary im Virtual Environment zurück
    # Parameter: keine
    # Rückgabe: Pfad zur Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local venv_dir
    debug "$get_pip_path_debug_0001" "CLI" "get_pip_path"
    
    # Hole das Virtual Environment-Verzeichnis
    venv_dir=$(get_venv_dir)
    
    # Standard-Unix/Linux-Pfad
    local pip_path="$venv_dir/bin/pip"
    
    # Prüfe, ob wir auf Unix/Linux oder Windows sind
    if [ -f "$pip_path" ]; then
        debug "$(printf "$get_pip_path_debug_0002" "$pip_path")" "CLI" "get_pip_path"
        echo "$pip_path"
        return 0
    fi
    
    # Windows-Pfad prüfen
    pip_path="$venv_dir/Scripts/pip.exe"
    if [ -f "$pip_path" ]; then
        debug "$(printf "$get_pip_path_debug_0003" "$pip_path")" "CLI" "get_pip_path"
        echo "$pip_path"
        return 0
    fi
    
    # Python-Pfade ermitteln für python -m pip Fallback
    local python_path="$venv_dir/bin/python3"
    if [ ! -f "$python_path" ]; then
        python_path="$venv_dir/bin/python"
    fi
    if [ ! -f "$python_path" ]; then
        python_path="$venv_dir/Scripts/python.exe"
    fi
    
    # Wenn Python existiert, können wir python -m pip verwenden
    if [ -f "$python_path" ]; then
        debug "$(printf "$get_pip_path_debug_0004" "$python_path")" "CLI" "get_pip_path"
        echo "$python_path -m pip"
        return 0
    fi
    
    # Als Fallback geben wir einfach "pip" zurück und hoffen, dass es im PATH ist
    debug "$get_pip_path_debug_0005" "CLI" "get_pip_path"
    echo "pip"
    return 0
}

# ---------------------------------------------------------------------------
# Backup-Verzeichnisse
# ---------------------------------------------------------------------------

# get_backup_dir
get_backup_dir_debug_0001="Ermittle Backup-Verzeichnis"
get_backup_dir_debug_0002="Verwende bereits definiertes BACKUP_DIR: %s"
get_backup_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für Backup-Verzeichnis"
get_backup_dir_debug_0004="Verwende Pfad für Backup-Verzeichnis: %s"
get_backup_dir_debug_0005="Alle Pfade für Backup-Verzeichnis fehlgeschlagen, verwende %s/backup"

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
    debug "$get_backup_dir_debug_0001" "CLI" "get_backup_dir"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        debug "$(printf "$get_backup_dir_debug_0002" "$BACKUP_DIR")" "CLI" "get_backup_dir"
        create_directory "$BACKUP_DIR" || true
        echo "$BACKUP_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "$get_backup_dir_debug_0003" "CLI" "get_backup_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_BACKUP" "$FALLBACK_DIR_BACKUP" 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_backup_dir_debug_0004" "$dir")" "CLI" "get_backup_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall ein Unterverzeichnis des Installationsverzeichnisses verwenden
    local install_dir
    install_dir=$(get_install_dir)
    debug "$(printf "$get_backup_dir_debug_0005" "$install_dir")" "CLI" "get_backup_dir"
    echo "$install_dir/backup"
    return 0
}

# get_nginx_backup_dir
get_nginx_backup_dir_debug_0001="Ermittle NGINX-Backup-Verzeichnis"
get_nginx_backup_dir_debug_0002="Verwende bereits definiertes BACKUP_DIR_NGINX: %s"
get_nginx_backup_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für NGINX-Backup-Verzeichnis"
get_nginx_backup_dir_debug_0004="Verwende Pfad für NGINX-Backup-Verzeichnis: %s"
get_nginx_backup_dir_debug_0005="Fallback für NGINX-Backup-Verzeichnis: %s"

get_nginx_backup_dir() {
    # -----------------------------------------------------------------------
    # get_nginx_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum NGINX-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    local backup_dir
    
    # Zuerst das generelle Backup-Verzeichnis ermitteln
    backup_dir=$(get_backup_dir)
    
    # Prüfen, ob BACKUP_DIR_NGINX bereits gesetzt ist
    debug "$get_nginx_backup_dir_debug_0001" "CLI" "get_nginx_backup_dir"
    if [ -n "$BACKUP_DIR_NGINX" ] && [ -d "$BACKUP_DIR_NGINX" ]; then
        debug "$(printf "$get_nginx_backup_dir_debug_0002" "$BACKUP_DIR_NGINX")" "CLI" "get_nginx_backup_dir"
        create_directory "$BACKUP_DIR_NGINX" "$DEFAULT_USER" "$DEFAULT_GROUP" "750" || true
        echo "$BACKUP_DIR_NGINX"
        return 0
    fi
    
    # Verwende die in lib_core definierten Pfade
    debug "$get_nginx_backup_dir_debug_0003" "CLI" "get_nginx_backup_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_BACKUP_NGINX" "$FALLBACK_DIR_BACKUP_NGINX" 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_backup_dir_debug_0004" "$dir")" "CLI" "get_nginx_backup_dir"
        # Setze restriktivere Berechtigungen für das Backup-Verzeichnis (nur Besitzer und Gruppe haben Zugriff)
        create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "750" || true
        echo "$dir"
        return 0
    fi
    
    # Als Fallback ein Unterverzeichnis im allgemeinen Backup-Verzeichnis verwenden
    dir="$backup_dir/nginx"
    debug "$(printf "$get_nginx_backup_dir_debug_0005" "$dir")" "CLI" "get_nginx_backup_dir"
    # Setze restriktivere Berechtigungen für das Backup-Verzeichnis (nur Besitzer und Gruppe haben Zugriff)
    create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "750" || true
    echo "$dir"
    return 0
}

# get_https_backup_dir
get_https_backup_dir_debug_0001="Ermittle HTTPS-Backup-Verzeichnis"
get_https_backup_dir_debug_0002="Verwende bereits definiertes BACKUP_DIR_HTTPS: %s"
get_https_backup_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für HTTPS-Backup-Verzeichnis"
get_https_backup_dir_debug_0004="Verwende Pfad für HTTPS-Backup-Verzeichnis: %s"
get_https_backup_dir_debug_0005="Fallback für HTTPS-Backup-Verzeichnis: %s"

get_https_backup_dir() {
    # -----------------------------------------------------------------------
    # get_https_backup_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum HTTPS-Backup-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    local backup_dir
    
    # Zuerst das generelle Backup-Verzeichnis ermitteln
    backup_dir=$(get_backup_dir)

    # Prüfen, ob BACKUP_DIR_HTTPS bereits gesetzt ist
    debug "$get_https_backup_dir_debug_0001" "CLI" "get_https_backup_dir"
    if [ -n "$BACKUP_DIR_HTTPS" ] && [ -d "$BACKUP_DIR_HTTPS" ]; then
        debug "$(printf "$get_https_backup_dir_debug_0002" "$BACKUP_DIR_HTTPS")" "CLI" "get_https_backup_dir"
        create_directory "$BACKUP_DIR_HTTPS" "$DEFAULT_USER" "$DEFAULT_GROUP" "750" || true
        echo "$BACKUP_DIR_HTTPS"
        return 0
    fi
    
    # Verwende die in lib_core definierten Pfade
    debug "$get_https_backup_dir_debug_0003" "CLI" "get_https_backup_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_BACKUP_HTTPS" "$FALLBACK_DIR_BACKUP_HTTPS" 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_https_backup_dir_debug_0004" "$dir")" "CLI" "get_https_backup_dir"
        # Setze restriktivere Berechtigungen für das Backup-Verzeichnis (nur Besitzer und Gruppe haben Zugriff)
        create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "750" || true
        echo "$dir"
        return 0
    fi
    
    # Als Fallback ein Unterverzeichnis im allgemeinen Backup-Verzeichnis verwenden
    dir="$backup_dir/https"
    debug "$(printf "$get_https_backup_dir_debug_0005" "$dir")" "CLI" "get_https_backup_dir"
    # Setze restriktivere Berechtigungen für das Backup-Verzeichnis (nur Besitzer und Gruppe haben Zugriff)
    create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "750" || true
    echo "$dir"
    return 0
}

# ---------------------------------------------------------------------------
# Konfigurations-Verzeichnis
# ---------------------------------------------------------------------------

# get_config_dir
get_config_dir_debug_0001="Ermittle Konfigurations-Verzeichnis"
get_config_dir_debug_0002="Verwende bereits definiertes CONF_DIR: %s"
get_config_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für Konfigurations-Verzeichnis" 
get_config_dir_debug_0004="Verwende Pfad für Konfigurations-Verzeichnis: %s"
get_config_dir_debug_0005="Alle Pfade für Konfigurations-Verzeichnis fehlgeschlagen, verwende %s/conf"

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
    debug "$get_config_dir_debug_0001" "CLI" "get_config_dir"
    if [ -n "$CONF_DIR" ] && [ -d "$CONF_DIR" ]; then
        debug "$(printf "$get_config_dir_debug_0002" "$CONF_DIR")" "CLI" "get_config_dir"
        create_directory "$CONF_DIR" || true
        echo "$CONF_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "$get_config_dir_debug_0003" "CLI" "get_config_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_CONF" "$FALLBACK_DIR_CONF" 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_config_dir_debug_0004" "$dir")" "CLI" "get_config_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall ein Unterverzeichnis des Installationsverzeichnisses verwenden
    local install_dir
    install_dir=$(get_install_dir)
    debug "$(printf "$get_config_dir_debug_0005" "$install_dir")" "CLI" "get_config_dir"
    echo "$install_dir/conf"
    return 0
}

# get_nginx_conf_dir
get_nginx_conf_dir_debug_0001="Ermittle NGINX-Konfigurations-Verzeichnis"
get_nginx_conf_dir_debug_0002="Verwende bereits definiertes CONF_DIR_NGINX: %s" 
get_nginx_conf_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für NGINX-Konfigurations-Verzeichnis"
get_nginx_conf_dir_debug_0004="Verwende Pfad für NGINX-Konfigurations-Verzeichnis: %s"
get_nginx_conf_dir_debug_0005="Fallback für NGINX-Konfigurations-Verzeichnis: %s"

get_nginx_conf_dir() {
    # -----------------------------------------------------------------------
    # get_nginx_conf_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum NGINX-Konfigurationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    local config_dir
        
    # Zuerst den übergeordneten Konfigurationsordner ermitteln
    config_dir=$(get_config_dir)
    
    # Prüfen, ob CONF_DIR_NGINX bereits gesetzt ist
    debug "$get_nginx_conf_dir_debug_0001" "CLI" "get_nginx_conf_dir"
    if [ -n "$CONF_DIR_NGINX" ] && [ -d "$CONF_DIR_NGINX" ]; then
        debug "$(printf "$get_nginx_conf_dir_debug_0002" "$CONF_DIR_NGINX")" "CLI" "get_nginx_conf_dir"
        # Setze explizit die Standard-Berechtigungen (755)
        create_directory "$CONF_DIR_NGINX" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        echo "$CONF_DIR_NGINX"
        return 0
    fi
    
    # Verwende die in lib_core definierten Pfade
    debug "$get_nginx_conf_dir_debug_0003" "CLI" "get_nginx_conf_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_CONF_NGINX" "$FALLBACK_DIR_CONF_NGINX" 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_nginx_conf_dir_debug_0004" "$dir")" "CLI" "get_nginx_conf_dir"
        # Setze explizit die Standard-Berechtigungen (755)
        create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        echo "$dir"
        return 0
    fi
    
    # Als Fallback ein Unterverzeichnis im Konfigurations-Verzeichnis verwenden
    dir="$config_dir/nginx"
    debug "$(printf "$get_nginx_conf_dir_debug_0005" "$dir")" "CLI" "get_nginx_conf_dir"
    # Setze explizit die Standard-Berechtigungen (755)
    create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
    echo "$dir"
    return 0
}

# get_https_conf_dir
get_https_conf_dir_debug_0001="Ermittle HTTPS-Konfigurations-Verzeichnis"
get_https_conf_dir_debug_0002="Verwende bereits definiertes CONF_DIR_HTTPS: %s" 
get_https_conf_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für HTTPS-Konfigurations-Verzeichnis"
get_https_conf_dir_debug_0004="Verwende Pfad für HTTPS-Konfigurations-Verzeichnis: %s"
get_https_conf_dir_debug_0005="Fallback für HTTPS-Konfigurations-Verzeichnis: %s"

get_https_conf_dir() {
    # -----------------------------------------------------------------------
    # get_https_conf_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum HTTPS-Konfigurationsverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
    local config_dir
        
    # Zuerst den übergeordneten Konfigurationsordner ermitteln
    config_dir=$(get_config_dir)

    # Prüfen, ob CONF_DIR_HTTPS bereits gesetzt ist
    debug "$get_https_conf_dir_debug_0001" "CLI" "get_https_conf_dir"
    if [ -n "$CONF_DIR_HTTPS" ] && [ -d "$CONF_DIR_HTTPS" ]; then
        debug "$(printf "$get_https_conf_dir_debug_0002" "$CONF_DIR_HTTPS")" "CLI" "get_https_conf_dir"
        # Setze explizit die Standard-Berechtigungen (755)
        create_directory "$CONF_DIR_HTTPS" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        echo "$CONF_DIR_HTTPS"
        return 0
    fi
    
    # Verwende die in lib_core definierten Pfade
    debug "$get_https_conf_dir_debug_0003" "CLI" "get_https_conf_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_CONF_HTTPS" "$FALLBACK_DIR_CONF_HTTPS" 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_https_conf_dir_debug_0004" "$dir")" "CLI" "get_https_conf_dir"
        # Setze explizit die Standard-Berechtigungen (755)
        create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        echo "$dir"
        return 0
    fi
    
    # Als Fallback ein Unterverzeichnis im Konfigurations-Verzeichnis verwenden
    dir="$config_dir/https"
    debug "$(printf "$get_https_conf_dir_debug_0005" "$dir")" "CLI" "get_https_conf_dir"
    # Setze explizit die Standard-Berechtigungen (755)
    create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
    echo "$dir"
    return 0
}

# get_camera_conf_dir
get_camera_conf_dir_debug_0001="Ermittle Kamera-Konfigurations-Verzeichnis"
get_camera_conf_dir_debug_0002="Verwende bereits definiertes CONF_DIR_CAMERA: %s"
get_camera_conf_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für Kamera-Konfigurations-Verzeichnis"
get_camera_conf_dir_debug_0004="Verwende Pfad für Kamera-Konfigurations-Verzeichnis: %s"
get_camera_conf_dir_debug_0005="Fallback für Kamera-Konfigurations-Verzeichnis: %s"

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
    local config_dir
    local standard_path="$DEFAULT_DIR_CONF_CAMERA"
        
    # Zuerst den übergeordneten Konfigurationsordner ermitteln
    config_dir=$(get_config_dir)

    # Prüfen, ob CONF_DIR_CAMERA bereits gesetzt ist
    debug "$get_camera_conf_dir_debug_0001" "CLI" "get_camera_conf_dir"
    if [ -n "$CONF_DIR_CAMERA" ] && [ -d "$CONF_DIR_CAMERA" ]; then
        debug "$(printf "$get_camera_conf_dir_debug_0002" "$CONF_DIR_CAMERA")" "CLI" "get_camera_conf_dir"
        # Setze explizit die Standard-Berechtigungen (755)
        create_directory "$CONF_DIR_CAMERA" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        
        # Wenn das definierte Verzeichnis nicht dem Standard entspricht, erstelle einen Symlink
        if [ "$CONF_DIR_CAMERA" != "$standard_path" ]; then
            create_symlink_to_standard_path "$standard_path" "$CONF_DIR_CAMERA" || true
        fi
        
        echo "$CONF_DIR_CAMERA"
        return 0
    fi
    
    # Verwende die in lib_core definierten Pfade
    debug "$get_camera_conf_dir_debug_0003" "CLI" "get_camera_conf_dir"
    # Symlink-Erstellung ist jetzt in get_folder_path integriert
    dir=$(get_folder_path "$DEFAULT_DIR_CONF_CAMERA" "$FALLBACK_DIR_CONF_CAMERA" 1 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_camera_conf_dir_debug_0004" "$dir")" "CLI" "get_camera_conf_dir"
        # Setze explizit die Standard-Berechtigungen (755)
        create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
        echo "$dir"
        return 0
    fi
    
    # Als Fallback ein Unterverzeichnis im Konfigurations-Verzeichnis verwenden
    dir="$config_dir/cameras"
    debug "$(printf "$get_camera_conf_dir_debug_0005" "$dir")" "CLI" "get_camera_conf_dir"
    # Setze explizit die Standard-Berechtigungen (755)
    create_directory "$dir" "$DEFAULT_USER" "$DEFAULT_GROUP" "$DEFAULT_MODE" || true
    
    # Versuche einen Symlink vom Standard-Pfad zu erstellen, wenn der Fallback verwendet wird
    create_symlink_to_standard_path "$standard_path" "$dir" || true
    
    echo "$dir"
    return 0
}

# ---------------------------------------------------------------------------
# Daten-Verzeichnis
# ---------------------------------------------------------------------------

# get_data_dir
get_data_dir_debug_0001="Ermittle Daten-Verzeichnis"
get_data_dir_debug_0002="Verwende bereits definiertes DATA_DIR: %s"
get_data_dir_debug_0003="Prüfe Standard- und Fallback-Pfade für Daten-Verzeichnis"
get_data_dir_debug_0004="Verwende Pfad für Daten-Verzeichnis: %s"
get_data_dir_debug_0005="Alle Pfade für Daten-Verzeichnis fehlgeschlagen, verwende %s/data"

get_data_dir() {
    # -----------------------------------------------------------------------
    # get_data_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Datenverzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Datenverzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
        
    # Prüfen, ob DATA_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_data_dir_debug_0001" "CLI" "get_data_dir"
    if [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR" ]; then
        debug "$(printf "$get_data_dir_debug_0002" "$DATA_DIR")" "CLI" "get_data_dir"
        create_directory "$DATA_DIR" || true
        echo "$DATA_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "$get_data_dir_debug_0003" "CLI" "get_data_dir"
    dir=$(get_folder_path "$DEFAULT_DIR_DATA" "$FALLBACK_DIR_DATA" 1)
    if [ -n "$dir" ]; then
        debug "$(printf "$get_data_dir_debug_0004" "$dir")" "CLI" "get_data_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall ein Unterverzeichnis des Installationsverzeichnisses verwenden
    local install_dir
    install_dir=$(get_install_dir)
    debug "$(printf "$get_data_dir_debug_0005" "$install_dir")" "CLI" "get_data_dir"
    echo "$install_dir/data"
    return 0
}

# ---------------------------------------------------------------------------
# Frontend-Verzeichnis
# ---------------------------------------------------------------------------

# get_frontend_dir
get_frontend_dir_debug_0001="Ermittle Frontend-Verzeichnis"
get_frontend_dir_debug_0002="Verwende bereits definiertes FRONTEND_DIR: %s"
get_frontend_dir_debug_0003="Prüfe Standard-Frontend-Verzeichnis: %s"
get_frontend_dir_debug_0004="Standard-Frontend-Verzeichnis nicht verfügbar, verwende Fallback: %s"

get_frontend_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Frontend-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local dir
        
    # Prüfen, ob FRONTEND_DIR bereits gesetzt ist
    debug "$get_frontend_dir_debug_0001" "CLI" "get_frontend_dir"
    if [ -n "$FRONTEND_DIR" ] && [ -d "$FRONTEND_DIR" ]; then
        debug "$(printf "$get_frontend_dir_debug_0002" "$FRONTEND_DIR")" "CLI" "get_frontend_dir"
        create_directory "$FRONTEND_DIR" || true
        echo "$FRONTEND_DIR"
        return 0
    fi
    
    # Standardpfad verwenden
    dir="$DEFAULT_DIR_FRONTEND"
    debug "$(printf "$get_frontend_dir_debug_0003" "$dir")" "CLI" "get_frontend_dir"
    if [ -d "$dir" ]; then
        create_directory "$dir" || true
        echo "$dir"
        return 0
    fi
    
    # Fallback auf Systemweb-Verzeichnis
    dir="$FALLBACK_DIR_FRONTEND"
    debug "$(printf "$get_frontend_dir_debug_0004" "$dir")" "CLI" "get_frontend_dir"
    create_directory "$dir" || true
    
    echo "$dir"
    return 0
}

# get_frontend_css_dir
get_frontend_css_dir_debug_0001="Ermittle Frontend-CSS-Verzeichnis"
get_frontend_css_dir_debug_0002="Prüfe CSS-Verzeichnis: %s"
get_frontend_css_dir_debug_0003="Verwende CSS-Verzeichnis: %s"
get_frontend_css_dir_debug_0004="CSS-Verzeichnis nicht verfügbar, verwende Fallback: %s"

get_frontend_css_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_css_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum CSS-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local frontend_dir
    debug "$get_frontend_css_dir_debug_0001" "CLI" "get_frontend_css_dir"
    
    # Hole das Frontend-Hauptverzeichnis
    frontend_dir=$(get_frontend_dir)
    local css_dir="$frontend_dir/css"
    
    debug "$(printf "$get_frontend_css_dir_debug_0002" "$css_dir")" "CLI" "get_frontend_css_dir"
    if create_directory "$css_dir"; then
        debug "$(printf "$get_frontend_css_dir_debug_0003" "$css_dir")" "CLI" "get_frontend_css_dir"
        echo "$css_dir"
        return 0
    fi
    
    # Fallback direkt zum Frontend-Verzeichnis
    debug "$(printf "$get_frontend_css_dir_debug_0004" "$frontend_dir")" "CLI" "get_frontend_css_dir"
    echo "$frontend_dir"
    return 1
}

# get_frontend_fonts_dir
get_frontend_fonts_dir_debug_0001="Ermittle Frontend-Fonts-Verzeichnis"
get_frontend_fonts_dir_debug_0002="Prüfe Fonts-Verzeichnis: %s"
get_frontend_fonts_dir_debug_0003="Verwende Fonts-Verzeichnis: %s"
get_frontend_fonts_dir_debug_0004="Fonts-Verzeichnis nicht verfügbar, verwende Fallback: %s"

get_frontend_fonts_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_fonts_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Fonts-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local frontend_dir
    debug "$get_frontend_fonts_dir_debug_0001" "CLI" "get_frontend_fonts_dir"
    
    # Hole das Frontend-Hauptverzeichnis
    frontend_dir=$(get_frontend_dir)
    local fonts_dir="$frontend_dir/fonts"
    
    debug "$(printf "$get_frontend_fonts_dir_debug_0002" "$fonts_dir")" "CLI" "get_frontend_fonts_dir"
    if create_directory "$fonts_dir"; then
        debug "$(printf "$get_frontend_fonts_dir_debug_0003" "$fonts_dir")" "CLI" "get_frontend_fonts_dir"
        echo "$fonts_dir"
        return 0
    fi
    
    # Fallback direkt zum Frontend-Verzeichnis
    debug "$(printf "$get_frontend_fonts_dir_debug_0004" "$frontend_dir")" "CLI" "get_frontend_fonts_dir"
    echo "$frontend_dir"
    return 1
}

# get_frontend_js_dir
get_frontend_js_dir_debug_0001="Ermittle Frontend-JavaScript-Verzeichnis"
get_frontend_js_dir_debug_0002="Prüfe JavaScript-Verzeichnis: %s"
get_frontend_js_dir_debug_0003="Verwende JavaScript-Verzeichnis: %s"
get_frontend_js_dir_debug_0004="JavaScript-Verzeichnis nicht verfügbar, verwende Fallback: %s"

get_frontend_js_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_js_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum JavaScript-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local frontend_dir
    debug "$get_frontend_js_dir_debug_0001" "CLI" "get_frontend_js_dir"
    
    # Hole das Frontend-Hauptverzeichnis
    frontend_dir=$(get_frontend_dir)
    local js_dir="$frontend_dir/js"
    
    debug "$(printf "$get_frontend_js_dir_debug_0002" "$js_dir")" "CLI" "get_frontend_js_dir"
    if create_directory "$js_dir"; then
        debug "$(printf "$get_frontend_js_dir_debug_0003" "$js_dir")" "CLI" "get_frontend_js_dir"
        echo "$js_dir"
        return 0
    fi
    
    # Fallback direkt zum Frontend-Verzeichnis
    debug "$(printf "$get_frontend_js_dir_debug_0004" "$frontend_dir")" "CLI" "get_frontend_js_dir"
    echo "$frontend_dir"
    return 1
}

# get_photos_dir
get_photos_dir_debug_0001="Ermittle Fotos-Verzeichnis"
get_photos_dir_debug_0002="Prüfe Standard-Fotos-Verzeichnis: %s"
get_photos_dir_debug_0003="Verwende Standard-Fotos-Verzeichnis: %s"
get_photos_dir_debug_0004="Standard-Fotos-Verzeichnis nicht verfügbar, verwende Fallback: %s/photos"

get_photos_dir() {
    # -----------------------------------------------------------------------
    # get_photos_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Fotos-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    debug "$get_photos_dir_debug_0001" "CLI" "get_photos_dir"
    
    local frontend_dir
    frontend_dir=$(get_frontend_dir)
    
    local photos_dir="$frontend_dir/photos"
    debug "$(printf "$get_photos_dir_debug_0002" "$photos_dir")" "CLI" "get_photos_dir"
    if create_directory "$photos_dir"; then
        debug "$(printf "$get_photos_dir_debug_0003" "$photos_dir")" "CLI" "get_photos_dir"
        echo "$photos_dir"
        return 0
    fi
    
    # Fallback zum Datenverzeichnis
    local data_dir
    data_dir=$(get_data_dir)
    debug "$(printf "$get_photos_dir_debug_0004" "$data_dir")" "CLI" "get_photos_dir"
    echo "$data_dir/photos"
    return 0
}

# get_photos_originals_dir
get_photos_originals_dir_debug_0001="Ermittle Original-Fotos-Verzeichnis"
get_photos_originals_dir_debug_0002="Prüfe Originals-Verzeichnis: %s"
get_photos_originals_dir_debug_0003="Event-Name angegeben, prüfe Verzeichnis: %s"
get_photos_originals_dir_debug_0004="Verwende Event-spezifisches Original-Fotos-Verzeichnis: %s"
get_photos_originals_dir_debug_0005="Verwende Standard Original-Fotos-Verzeichnis: %s"
get_photos_originals_dir_debug_0006="Originals-Verzeichnis nicht verfügbar, verwende Fallback: %s"

get_photos_originals_dir() {
    # -----------------------------------------------------------------------
    # get_photos_originals_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Originalfotos-Verzeichnis zurück
    # Parameter: $1 - (Optional) Name des Events
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local event_name="$1"
    debug "$get_photos_originals_dir_debug_0001" "CLI" "get_photos_originals_dir"
    
    local photos_dir
    photos_dir=$(get_photos_dir)
    local originals_dir="$photos_dir/originals"
    
    debug "$(printf "$get_photos_originals_dir_debug_0002" "$originals_dir")" "CLI" "get_photos_originals_dir"
    if create_directory "$originals_dir"; then
        if [ -n "$event_name" ]; then
            local event_dir="$originals_dir/$event_name"
            debug "$(printf "$get_photos_originals_dir_debug_0003" "$event_dir")" "CLI" "get_photos_originals_dir"
            if create_directory "$event_dir"; then
                debug "$(printf "$get_photos_originals_dir_debug_0004" "$event_dir")" "CLI" "get_photos_originals_dir"
                echo "$event_dir"
                return 0
            fi
        else
            debug "$(printf "$get_photos_originals_dir_debug_0005" "$originals_dir")" "CLI" "get_photos_originals_dir"
            echo "$originals_dir"
            return 0
        fi
    fi
    
    # Fallback, wenn Event-Verzeichnis nicht erstellt werden konnte
    debug "$(printf "$get_photos_originals_dir_debug_0006" "$photos_dir")" "CLI" "get_photos_originals_dir"
    echo "$photos_dir"
    return 0
}

# get_photos_gallery_dir
get_photos_gallery_dir_debug_0001="Ermittle Galerie-Verzeichnis"
get_photos_gallery_dir_debug_0002="Prüfe Galerie-Verzeichnis: %s"
get_photos_gallery_dir_debug_0003="Event-Name angegeben, prüfe Verzeichnis: %s"
get_photos_gallery_dir_debug_0004="Verwende Event-spezifisches Galerie-Verzeichnis: %s"
get_photos_gallery_dir_debug_0005="Verwende Standard Galerie-Verzeichnis: %s"
get_photos_gallery_dir_debug_0006="Galerie-Verzeichnis nicht verfügbar, verwende Fallback: %s"

get_photos_gallery_dir() {
    # -----------------------------------------------------------------------
    # get_photos_gallery_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Galerie-Verzeichnis zurück
    # Parameter: $1 - (Optional) Name des Events
    # Rückgabe: Pfad zum Galerie-Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local event_name="$1"
    debug "$get_photos_gallery_dir_debug_0001" "CLI" "get_photos_gallery_dir"
    
    local photos_dir
    photos_dir=$(get_photos_dir)
    local gallery_dir="$photos_dir/gallery"
    
    debug "$(printf "$get_photos_gallery_dir_debug_0002" "$gallery_dir")" "CLI" "get_photos_gallery_dir"
    if create_directory "$gallery_dir"; then
        if [ -n "$event_name" ]; then
            local event_dir="$gallery_dir/$event_name"
            debug "$(printf "$get_photos_gallery_dir_debug_0003" "$event_dir")" "CLI" "get_photos_gallery_dir"
            if create_directory "$event_dir"; then
                debug "$(printf "$get_photos_gallery_dir_debug_0004" "$event_dir")" "CLI" "get_photos_gallery_dir"
                echo "$event_dir"
                return 0
            fi
        else
            debug "$(printf "$get_photos_gallery_dir_debug_0005" "$gallery_dir")" "CLI" "get_photos_gallery_dir"
            echo "$gallery_dir"
            return 0
        fi
    fi
    
    # Fallback, wenn Event-Verzeichnis nicht erstellt werden konnte
    debug "$(printf "$get_photos_gallery_dir_debug_0006" "$photos_dir")" "CLI" "get_photos_gallery_dir"
    echo "$photos_dir"
    return 0
}

# get_frontend_picture_dir
get_frontend_picture_dir_debug_0001="Ermittle Frontend-Picture-Verzeichnis"
get_frontend_picture_dir_debug_0002="Prüfe Picture-Verzeichnis: %s"
get_frontend_picture_dir_debug_0003="Verwende Picture-Verzeichnis: %s"
get_frontend_picture_dir_debug_0004="Picture-Verzeichnis nicht verfügbar, verwende Fallback: %s"

get_frontend_picture_dir() {
    # -----------------------------------------------------------------------
    # get_frontend_picture_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Picture-Verzeichnis im Frontend zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local frontend_dir
    debug "$get_frontend_picture_dir_debug_0001" "CLI" "get_frontend_picture_dir"
    
    # Hole das Frontend-Hauptverzeichnis
    frontend_dir=$(get_frontend_dir)
    local picture_dir="$frontend_dir/picture"
    
    debug "$(printf "$get_frontend_picture_dir_debug_0002" "$picture_dir")" "CLI" "get_frontend_picture_dir"
    if create_directory "$picture_dir"; then
        debug "$(printf "$get_frontend_picture_dir_debug_0003" "$picture_dir")" "CLI" "get_frontend_picture_dir"
        echo "$picture_dir"
        return 0
    fi
    
    # Fallback direkt zum Frontend-Verzeichnis
    debug "$(printf "$get_frontend_picture_dir_debug_0004" "$frontend_dir")" "CLI" "get_frontend_picture_dir"
    echo "$frontend_dir"
    return 1
}

# ---------------------------------------------------------------------------
# Log-Verzeichnis
# ---------------------------------------------------------------------------

# get_log_dir
get_log_dir_debug_0001="Ermittle Log-Verzeichnis"
get_log_dir_debug_0002="Verwende bereits definiertes LOG_DIR: %s"
get_log_dir_debug_0003="Prüfe Standard-Logverzeichnis: %s"
get_log_dir_debug_0004="Verwende Standard-Logverzeichnis: %s"
get_log_dir_debug_0005="Standard-Logverzeichnis nicht verfügbar, prüfe Fallback-Optionen"
get_log_dir_debug_0006="Verwende Fallback 1: %s"
get_log_dir_debug_0007="Verwende Fallback 2: %s"
get_log_dir_debug_0008="Verwende Fallback 3: %s"
get_log_dir_debug_0009="Fehler: Keine Schreibrechte im Logverzeichnis %s"
get_log_dir_debug_0010="Fehler: Auch Fallback-Logverzeichnis %s nicht schreibbar"
get_log_dir_debug_0011="Fehler: Kein schreibbares Logverzeichnis gefunden"
get_log_dir_debug_0012="Warnung: Logverzeichnis konnte nicht erstellt werden, verwende aktuelles Verzeichnis"
get_log_dir_debug_0013="Entferne vorhandenes Verzeichnis /var/log/fotobox"
get_log_dir_debug_0014="Symlink /var/log/fotobox zeigt auf %s, wird auf %s geändert"
get_log_dir_debug_0015="Symlink /var/log/fotobox zeigt bereits korrekt auf %s"
get_log_dir_debug_0016="Erstelle Symlink in /var/log/fotobox zu %s"

get_log_dir() {
    # ------------------------------------------------------------------------------
    # get_log_dir
    # ------------------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Log-Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # ------------------------------------------------------------------------------
    local logdir
    local found_dir=0
        
    # Prüfen, ob LOG_DIR bereits gesetzt ist (z.B. vom install.sh)
    debug "$get_log_dir_debug_0001" "CLI" "get_log_dir"
    if [ -n "$LOG_DIR" ] && [ -d "$LOG_DIR" ]; then
        debug "$(printf "$get_log_dir_debug_0002" "$LOG_DIR")" "CLI" "get_log_dir" >/dev/null 2>&1
        create_directory "$LOG_DIR" || true
        logdir="$LOG_DIR"
        found_dir=1
    fi

    # Wenn kein Verzeichnis gefunden wurde, exakt die gleiche Logik wie in get_log_path
    if [ $found_dir -eq 0 ]; then
        logdir="$DEFAULT_DIR_LOG"
        debug "$(printf "$get_log_dir_debug_0003" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
        if [ -d "$logdir" ] || mkdir -p "$logdir" 2>/dev/null; then
            create_directory "$logdir" || true
            debug "$(printf "$get_log_dir_debug_0004" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
            found_dir=1
        fi
    fi

    # Fallback-Kette wie in get_log_path, wenn kein Verzeichnis gefunden wurde
    if [ $found_dir -eq 0 ]; then
        debug "$get_log_dir_debug_0005" "CLI" "get_log_dir" >/dev/null 2>&1
        if [ -w "/var/log" ]; then
            logdir="$FALLBACK_DIR_LOG"
            debug "$(printf "$get_log_dir_debug_0006" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
            create_directory "$logdir" || true
            found_dir=1
        elif [ -w "/tmp" ]; then
            logdir="$FALLBACK_DIR_LOG_2"
            debug "$(printf "$get_log_dir_debug_0007" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
            create_directory "$logdir" || true
            found_dir=1
        else
            logdir="$FALLBACK_DIR_LOG_3"
            debug "$(printf "$get_log_dir_debug_0008" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
            create_directory "$logdir" || true
            found_dir=1
        fi
    fi
    
    # Teste Schreibrecht für das Logverzeichnis - stellen wir sicher, dass es existiert
    if [ ! -d "$logdir" ]; then
        mkdir -p "$logdir" 2>/dev/null || true
    fi
    
    # Prüfe explizit, ob das Verzeichnis existiert, bevor wir die Datei erstellen
    if [ -d "$logdir" ]; then
        if ! touch "$logdir/test_log.tmp" 2>/dev/null; then
            echo "$(printf "$get_log_dir_debug_0009" "$logdir")" >&2
            # Versuche Fallback zu /tmp
            if [ -w "/tmp" ] && [ "$logdir" != "$FALLBACK_DIR_LOG_2" ]; then
                logdir="$FALLBACK_DIR_LOG_2"
                mkdir -p "$logdir" 2>/dev/null || true
                if [ -d "$logdir" ] && ! touch "$logdir/test_log.tmp" 2>/dev/null; then
                    echo "$(printf "$get_log_dir_debug_0010" "$logdir")" >&2
                    return 1
                fi
                rm -f "$logdir/test_log.tmp" 2>/dev/null || true
            else
                # Als letztes Mittel das aktuelle Verzeichnis verwenden
                logdir="."
                if ! touch "./test_log.tmp" 2>/dev/null; then
                    echo "$get_log_dir_debug_0011" >&2
                    return 1
                fi
                rm -f "./test_log.tmp" 2>/dev/null || true
            fi
        else
            rm -f "$logdir/test_log.tmp" 2>/dev/null || true
        fi
    else
        # Verzeichnis konnte nicht erstellt werden, verwende aktuelles Verzeichnis
        echo "$get_log_dir_debug_0012" >&2
        logdir="."
    fi
    
    # Als letzter Schritt: Symlink setzen, unabhängig davon, wie das Verzeichnis ermittelt wurde
    # Dies ist wichtig, um sicherzustellen, dass der Symlink immer auf das tatsächlich verwendete Verzeichnis zeigt
    if [ "$(id -u)" = "0" ] && [ -w "/var/log" ]; then
        # Prüfen, ob das Ziel ein Verzeichnis ist (kein Symlink)
        if [ -d "/var/log/fotobox" ] && [ ! -L "/var/log/fotobox" ]; then
            debug "$get_log_dir_debug_0013" "CLI" "get_log_dir" >/dev/null 2>&1
            rm -rf /var/log/fotobox 2>/dev/null || true
        fi
        
        # Wenn /var/log/fotobox ein Symlink ist, der auf einen anderen Pfad als $logdir zeigt, korrigiere ihn
        if [ -L "/var/log/fotobox" ]; then
            local current_target
            current_target=$(readlink -f "/var/log/fotobox")
            if [ "$current_target" != "$logdir" ]; then
                debug "$(printf "$get_log_dir_debug_0014" "$current_target" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
                rm -f /var/log/fotobox 2>/dev/null || true
            else
                debug "$(printf "$get_log_dir_debug_0015" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
                echo "$logdir"
                return 0
            fi
        fi
        
        debug "$(printf "$get_log_dir_debug_0016" "$logdir")" "CLI" "get_log_dir" >/dev/null 2>&1
        ln -sf "$logdir" /var/log/fotobox
    fi
    
    echo "$logdir"
    return 0
}

# ---------------------------------------------------------------------------
# Temp-Verzeichnis
# ---------------------------------------------------------------------------

# get_tmp_dir
get_tmp_dir_debug_0001="Ermittle temporäres Verzeichnis"
get_tmp_dir_debug_0002="Verwende bereits definiertes TMP_DIR: %s"
get_tmp_dir_debug_0003="Prüfe Standard-Temp-Verzeichnis: %s"
get_tmp_dir_debug_0004="Verwende Standard-Temp-Verzeichnis: %s"
get_tmp_dir_debug_0005="Standard-Temp-Verzeichnis nicht verfügbar, prüfe Fallback-Optionen"
get_tmp_dir_debug_0006="Verwende Fallback im Log-Verzeichnis: %s"
get_tmp_dir_debug_0007="Verwende Fallback-System-Temp: %s"
get_tmp_dir_debug_0008="Verwende Systemverzeichnis /tmp als letzte Option"
get_tmp_dir_debug_0009="Entferne vorhandenes Verzeichnis /tmp/fotobox"
get_tmp_dir_debug_0010="Symlink /tmp/fotobox zeigt auf %s, wird auf %s geändert"
get_tmp_dir_debug_0011="Symlink /tmp/fotobox zeigt bereits korrekt auf %s"
get_tmp_dir_debug_0012="Erstelle Symlink in /tmp/fotobox zu %s"

get_tmp_dir() {
    # -----------------------------------------------------------------------
    # get_tmp_dir
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum temporären Verzeichnis zurück
    # Parameter: keine
    # Rückgabe: Pfad zum Verzeichnis oder leerer String bei Fehler
    # -----------------------------------------------------------------------
    local tmpdir
    local found_dir=0
    
    debug "$get_tmp_dir_debug_0001" "CLI" "get_tmp_dir" >/dev/null 2>&1
    
    # Prüfen, ob TMP_DIR bereits gesetzt ist (z.B. vom install.sh)
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        debug "$(printf "$get_tmp_dir_debug_0002" "$TMP_DIR")" "CLI" "get_tmp_dir" >/dev/null 2>&1
        create_directory "$TMP_DIR" || true
        tmpdir="$TMP_DIR"
        found_dir=1
    fi
    
    # Wenn kein Verzeichnis gefunden wurde, den Standardpfad verwenden
    if [ $found_dir -eq 0 ]; then
        tmpdir="$DEFAULT_DIR_TMP"
        debug "$(printf "$get_tmp_dir_debug_0003" "$tmpdir")" "CLI" "get_tmp_dir" >/dev/null 2>&1
        
        if [ -d "$tmpdir" ] || mkdir -p "$tmpdir" 2>/dev/null; then
            create_directory "$tmpdir" || true
            debug "$(printf "$get_tmp_dir_debug_0004" "$tmpdir")" "CLI" "get_tmp_dir" >/dev/null 2>&1
            found_dir=1
        fi
    fi
    
    # Fallback-Optionen, wenn das Standardverzeichnis nicht verfügbar ist
    if [ $found_dir -eq 0 ]; then
        debug "$get_tmp_dir_debug_0005" "CLI" "get_tmp_dir" >/dev/null 2>&1
        
        # Fallback auf das Projekt-Log-Verzeichnis
        tmpdir="$(get_log_dir)/tmp"
        if mkdir -p "$tmpdir" 2>/dev/null; then
            debug "$(printf "$get_tmp_dir_debug_0006" "$tmpdir")" "CLI" "get_tmp_dir" >/dev/null 2>&1
            create_directory "$tmpdir" || true
            found_dir=1
        fi
    fi
    
    if [ $found_dir -eq 0 ]; then
        # Fallback auf System-temp
        tmpdir="$FALLBACK_DIR_TMP" # /tmp/fotobox_tmp
        if mkdir -p "$tmpdir" 2>/dev/null; then
            debug "$(printf "$get_tmp_dir_debug_0007" "$tmpdir")" "CLI" "get_tmp_dir" >/dev/null 2>&1
            create_directory "$tmpdir" || true
            found_dir=1
        fi
    fi
    
    if [ $found_dir -eq 0 ]; then
        # Als absolute Notlösung: Verwende /tmp direkt
        tmpdir="/tmp"
        debug "$get_tmp_dir_debug_0008" "CLI" "get_tmp_dir" >/dev/null 2>&1
        found_dir=1
    fi
    
    # Als letzter Schritt: Symlink setzen, unabhängig davon, wie das Verzeichnis ermittelt wurde
    # Dies ist wichtig, um sicherzustellen, dass der Symlink immer auf das tatsächlich verwendete Verzeichnis zeigt
    if [ "$(id -u)" = "0" ] && [ -w "/tmp" ]; then
        # Prüfen, ob das Ziel ein Verzeichnis ist (kein Symlink)
        if [ -d "/tmp/fotobox" ] && [ ! -L "/tmp/fotobox" ]; then
            debug "$get_tmp_dir_debug_0009" "CLI" "get_tmp_dir" >/dev/null 2>&1
            rm -rf /tmp/fotobox 2>/dev/null || true
        fi
        
        # Wenn /tmp/fotobox ein Symlink ist, der auf einen anderen Pfad als $tmpdir zeigt, korrigiere ihn
        if [ -L "/tmp/fotobox" ]; then
            local current_target
            current_target=$(readlink -f "/tmp/fotobox")
            if [ "$current_target" != "$tmpdir" ]; then
                debug "$(printf "$get_tmp_dir_debug_0010" "$current_target" "$tmpdir")" "CLI" "get_tmp_dir" >/dev/null 2>&1
                rm -f /tmp/fotobox 2>/dev/null || true
            else
                debug "$(printf "$get_tmp_dir_debug_0011" "$tmpdir")" "CLI" "get_tmp_dir" >/dev/null 2>&1
                echo "$tmpdir"
                return 0
            fi
        fi
        
        debug "$(printf "$get_tmp_dir_debug_0012" "$tmpdir")" "CLI" "get_tmp_dir" >/dev/null 2>&1
        ln -sf "$tmpdir" /tmp/fotobox
    fi
    
    echo "$tmpdir"
    return 0
}

# ---------------------------------------------------------------------------
# Verzeichnis Struktur sicherstellen
# ---------------------------------------------------------------------------

# ensure_folder_structure
ensure_folder_structure_debug_0001="Stelle sicher, dass alle notwendigen Verzeichnisse existieren"
ensure_folder_structure_debug_0002="Ordnerstruktur erfolgreich erstellt"

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
    debug "$ensure_folder_structure_debug_0001" "CLI" "ensure_folder_structure"
    
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
    
    debug "$ensure_folder_structure_debug_0002" "CLI" "ensure_folder_structure"
    return 0
}

# ---------------------------------------------------------------------------
# Abschluss: Markiere dieses Modul als geladen
# ---------------------------------------------------------------------------
MANAGE_FOLDERS_LOADED=1

