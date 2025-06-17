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

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ ! -f "$BASH_DIR/lib_core.sh" ]; then
    echo "KRITISCHER FEHLER: Zentrale Bibliothek lib_core.sh nicht gefunden!" >&2
    echo "Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch." >&2
    exit 1
fi

source "$BASH_DIR/lib_core.sh"
load_core_resources || {
    echo "KRITISCHER FEHLER: Die Kernressourcen konnten nicht geladen werden." >&2
    echo "Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch." >&2
    exit 1
}
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

# ------------------------------------------------------------------------------
# create_directory
# ------------------------------------------------------------------------------
# Funktion: Erstellt ein Verzeichnis mit den korrekten Berechtigungen, wenn es noch nicht existiert
# Parameter:
#   $1 - Pfad des zu erstellenden Verzeichnisses
#   $2 - (Optional) Benutzername, Standard: "fotobox"
#   $3 - (Optional) Gruppe, Standard: "fotobox"
#   $4 - (Optional) Berechtigungen, Standard: "755"
# Rückgabe:
#   0 - Erfolg (Verzeichnis existiert und hat korrekte Berechtigungen)
#   1 - Fehler (Verzeichnis konnte nicht erstellt werden)
# ------------------------------------------------------------------------------
create_directory() {
    local dir="$1"
    local user="${2:-$DEFAULT_USER}"
    local group="${3:-$DEFAULT_GROUP}"
    local mode="${4:-$DEFAULT_MODE}"

    if [ -z "$dir" ]; then
        log "ERROR: create_directory: Kein Verzeichnis angegeben" "create_directory"
        debug "Kein Verzeichnis angegeben" "CLI" "create_directory"
        return 1
    fi

    # Verzeichnis erstellen, falls es nicht existiert
    if [ ! -d "$dir" ]; then
        debug "Verzeichnis $dir existiert nicht, wird erstellt" "CLI" "create_directory"
        mkdir -p "$dir" || {
            log "ERROR: Fehler beim Erstellen des Verzeichnisses $dir" "create_directory"
            debug "Fehler beim Erstellen von $dir" "CLI" "create_directory"
            return 1
        }
        log "INFO: Verzeichnis $dir wurde erstellt"
    fi

    # Berechtigungen setzen
    chown "$user:$group" "$dir" 2>/dev/null || {
        debug "Warnung: chown für $dir fehlgeschlagen, fahre fort" "CLI" "create_directory"
        # Fehler beim chown ist kein kritischer Fehler
    }

    chmod "$mode" "$dir" 2>/dev/null || {
        debug "Warnung: chmod für $dir fehlgeschlagen, fahre fort" "CLI" "create_directory"
        # Fehler beim chmod ist kein kritischer Fehler
    }

    # Überprüfen, ob das Verzeichnis existiert und lesbar ist
    if [ -d "$dir" ] && [ -r "$dir" ]; then
        debug "Verzeichnis $dir erfolgreich vorbereitet" "CLI" "create_directory"
        return 0
    else
        log "ERROR: Verzeichnis $dir konnte nicht korrekt vorbereitet werden" "create_directory"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# get_folder_path
# ------------------------------------------------------------------------------
# Funktion: Hilfsfunktion zum Ermitteln und Erstellen eines Ordners mit Fallback-Logik
# Parameter:
#   $1 - Standard-Pfad
#   $2 - Fallback-Pfad (falls Standard-Pfad nicht verfügbar)
#   $3 - (Optional) Fallback zum Projekthauptverzeichnis, falls beide vorherigen Pfade fehlschlagen
# Rückgabe:
#   - Den Pfad zum verfügbaren Ordner oder leeren String bei Fehler
# ------------------------------------------------------------------------------
get_folder_path() {
    local standard_path="$1"
    local fallback_path="$2"
    local use_root_fallback="${3:-1}" # Standard: Ja, Root-Fallback verwenden
    
    debug "Prüfe Pfad: Standardpfad=$standard_path, Fallback=$fallback_path" "CLI" "get_folder_path"

    # Versuchen, den Standardpfad zu verwenden
    if create_directory "$standard_path"; then
        debug "Verwende Standardpfad: $standard_path" "CLI" "get_folder_path"
        echo "$standard_path"
        return 0
    fi
    
    debug "Standard-Pfad $standard_path nicht verfügbar, versuche Fallback" "CLI" "get_folder_path"
    
    # Versuchen, den Fallback-Pfad zu verwenden
    if create_directory "$fallback_path"; then
        debug "Verwende Fallback-Pfad: $fallback_path" "CLI" "get_folder_path"
        echo "$fallback_path"
        return 0
    fi
    
    debug "Fallback-Pfad $fallback_path nicht verfügbar" "CLI" "get_folder_path"
    
    # Als letzte Option das Root-Verzeichnis verwenden
    if [ "$use_root_fallback" -eq 1 ]; then
        local root_path
        root_path=$(get_install_dir)
        if [ -n "$root_path" ] && create_directory "$root_path"; then
            debug "Verwende Root-Verzeichnis als letzten Fallback: $root_path" "CLI" "get_folder_path"
            echo "$root_path"
            return 0
        fi
    fi
    
    log "ERROR: Kein gültiger Pfad für die Ordnererstellung verfügbar" "get_folder_path"
    return 1
}

# ------------------------------------------------------------------------------
# get_install_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Installationsverzeichnis zurück
# Parameter: keine
# Rückgabe: Pfad zum Installationsverzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_install_dir() {
    local dir
    
    debug "Ermittle Installations-Verzeichnis" "CLI" "get_install_dir"
    
    # Prüfen, ob INSTALL_DIR bereits gesetzt ist (z.B. vom install.sh)
    if [ -n "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR" ]; then
        debug "Verwende bereits definiertes INSTALL_DIR: $INSTALL_DIR" "CLI" "get_install_dir"
        create_directory "$INSTALL_DIR" || true
        echo "$INSTALL_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "Prüfe Standard- und Fallback-Pfade für Installations-Verzeichnis" "CLI" "get_install_dir"
    dir=$(get_folder_path "$DEFAULT_INSTALL_DIR" "$FALLBACK_INSTALL_DIR" 0)
    if [ -n "$dir" ]; then
        debug "Verwende Pfad für Installations-Verzeichnis: $dir" "CLI" "get_install_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall das aktuelle Verzeichnis verwenden
    debug "Alle Pfade für Installations-Verzeichnis fehlgeschlagen, verwende aktuelles Verzeichnis" "CLI" "get_install_dir"
    echo "$(pwd)/fotobox"
    return 0
}

# ------------------------------------------------------------------------------
# get_data_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Datenverzeichnis zurück
# Parameter: keine
# Rückgabe: Pfad zum Datenverzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_data_dir() {
    local dir
    
    debug "Ermittle Daten-Verzeichnis" "CLI" "get_data_dir"
    
    # Prüfen, ob DATA_DIR bereits gesetzt ist (z.B. vom install.sh)
    if [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR" ]; then
        debug "Verwende bereits definiertes DATA_DIR: $DATA_DIR" "CLI" "get_data_dir"
        create_directory "$DATA_DIR" || true
        echo "$DATA_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "Prüfe Standard- und Fallback-Pfade für Daten-Verzeichnis" "CLI" "get_data_dir"
    dir=$(get_folder_path "$DEFAULT_DATA_DIR" "$FALLBACK_DATA_DIR" 1)
    if [ -n "$dir" ]; then
        debug "Verwende Pfad für Daten-Verzeichnis: $dir" "CLI" "get_data_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall ein Unterverzeichnis des Installationsverzeichnisses verwenden
    local install_dir
    install_dir=$(get_install_dir)
    debug "Alle Pfade für Daten-Verzeichnis fehlgeschlagen, verwende $install_dir/data" "CLI" "get_data_dir"
    echo "$install_dir/data"
    return 0
}

# ------------------------------------------------------------------------------
# get_backup_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Backup-Verzeichnis zurück
# Parameter: keine
# Rückgabe: Pfad zum Backup-Verzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_backup_dir() {
    local dir
    
    debug "Ermittle Backup-Verzeichnis" "CLI" "get_backup_dir"
    
    # Prüfen, ob BACKUP_DIR bereits gesetzt ist (z.B. vom install.sh)
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        debug "Verwende bereits definiertes BACKUP_DIR: $BACKUP_DIR" "CLI" "get_backup_dir"
        create_directory "$BACKUP_DIR" || true
        echo "$BACKUP_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "Prüfe Standard- und Fallback-Pfade für Backup-Verzeichnis" "CLI" "get_backup_dir"
    dir=$(get_folder_path "$DEFAULT_BACKUP_DIR" "$FALLBACK_BACKUP_DIR" 1)
    if [ -n "$dir" ]; then
        debug "Verwende Pfad für Backup-Verzeichnis: $dir" "CLI" "get_backup_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall ein Unterverzeichnis des Installationsverzeichnisses verwenden
    local install_dir
    install_dir=$(get_install_dir)
    debug "Alle Pfade für Backup-Verzeichnis fehlgeschlagen, verwende $install_dir/backup" "CLI" "get_backup_dir"
    echo "$install_dir/backup"
    return 0
}

# ------------------------------------------------------------------------------
# get_log_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Log-Verzeichnis zurück
# Parameter: keine
# Rückgabe: Pfad zum Log-Verzeichnis oder leerer String bei Fehler
# 
# Diese Funktion implementiert dieselbe Logik wie get_log_path aus manage_logging.sh,
# um Kompatibilität und Konsistenz zu gewährleisten.
# ------------------------------------------------------------------------------
get_log_dir() {
    local logdir
    
    debug "Ermittle Log-Verzeichnis" "CLI" "get_log_dir"
    
    # Prüfen, ob LOG_DIR bereits gesetzt ist (z.B. vom install.sh)
    if [ -n "$LOG_DIR" ] && [ -d "$LOG_DIR" ]; then
        debug "Verwende bereits definiertes LOG_DIR: $LOG_DIR" "CLI" "get_log_dir"
        create_directory "$LOG_DIR" || true
        echo "$LOG_DIR"
        return 0
    fi
    
    # Exakt die gleiche Logik wie in get_log_path aus manage_logging.sh
    logdir="$DEFAULT_LOG_DIR"
    debug "Prüfe Standard-Logverzeichnis: $logdir" "CLI" "get_log_dir"
    if [ -d "$logdir" ]; then
        # Symlink nach /var/log/fotobox anlegen, falls root und möglich
        if [ "$(id -u)" = "0" ] && [ -w "/var/log" ]; then
            debug "Erstelle Symlink in /var/log/fotobox" "CLI" "get_log_dir"
            ln -sf "$logdir" /var/log/fotobox
        fi
        create_directory "$logdir" || true
        debug "Verwende Standard-Logverzeichnis: $logdir" "CLI" "get_log_dir"
        echo "$logdir"
        return 0
    fi
    
    # Fallback-Kette wie in get_log_path
    debug "Standard-Logverzeichnis nicht verfügbar, prüfe Fallback-Optionen" "CLI" "get_log_dir"
    if [ -w "/var/log" ]; then
        logdir="$FALLBACK_LOG_DIR"
        debug "Verwende Fallback 1: $logdir" "CLI" "get_log_dir"
    elif [ -w "/tmp" ]; then
        logdir="$FALLBACK_LOG_DIR_2"
        debug "Verwende Fallback 2: $logdir" "CLI" "get_log_dir"
    else
        logdir="$FALLBACK_LOG_DIR_3"
        debug "Verwende Fallback 3: $logdir" "CLI" "get_log_dir"
    fi
    
    create_directory "$logdir" || true
    
    # Teste Schreibrecht für das Logverzeichnis
    if ! touch "$logdir/test_log.tmp" 2>/dev/null; then
        echo "Fehler: Keine Schreibrechte im Logverzeichnis $logdir" >&2
        # Versuche Fallback zu /tmp
        if [ -w "/tmp" ] && [ "$logdir" != "$FALLBACK_LOG_DIR_2" ]; then
            logdir="$FALLBACK_LOG_DIR_2"
            create_directory "$logdir" || true
            if ! touch "$logdir/test_log.tmp" 2>/dev/null; then
                echo "Fehler: Auch Fallback-Logverzeichnis $logdir nicht schreibbar" >&2
                return 1
            fi
        else
            return 1
        fi
    fi
    rm -f "$logdir/test_log.tmp" 2>/dev/null
    
    echo "$logdir"
    return 0
}

# ------------------------------------------------------------------------------
# get_frontend_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Frontend-Verzeichnis zurück
# Parameter: keine
# Rückgabe: Pfad zum Frontend-Verzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_frontend_dir() {
    local dir
    
    debug "Ermittle Frontend-Verzeichnis" "CLI" "get_frontend_dir"
    
    # Prüfen, ob FRONTEND_DIR bereits gesetzt ist
    if [ -n "$FRONTEND_DIR" ] && [ -d "$FRONTEND_DIR" ]; then
        debug "Verwende bereits definiertes FRONTEND_DIR: $FRONTEND_DIR" "CLI" "get_frontend_dir"
        create_directory "$FRONTEND_DIR" || true
        echo "$FRONTEND_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "Prüfe Standard- und Fallback-Pfade für Frontend-Verzeichnis" "CLI" "get_frontend_dir"
    dir=$(get_folder_path "$DEFAULT_FRONTEND_DIR" "$FALLBACK_FRONTEND_DIR" 1)
    if [ -n "$dir" ]; then
        debug "Verwende Pfad für Frontend-Verzeichnis: $dir" "CLI" "get_frontend_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall ein Unterverzeichnis des Installationsverzeichnisses verwenden
    local install_dir
    install_dir=$(get_install_dir)
    debug "Alle Pfade für Frontend-Verzeichnis fehlgeschlagen, verwende $install_dir/frontend" "CLI" "get_frontend_dir"
    echo "$install_dir/frontend"
    return 0
}

# ------------------------------------------------------------------------------
# get_config_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Konfigurationsverzeichnis zurück
# Parameter: keine
# Rückgabe: Pfad zum Konfigurationsverzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_config_dir() {
    local dir
    
    debug "Ermittle Konfigurations-Verzeichnis" "CLI" "get_config_dir"
    
    # Prüfen, ob CONFIG_DIR bereits gesetzt ist
    if [ -n "$CONFIG_DIR" ] && [ -d "$CONFIG_DIR" ]; then
        debug "Verwende bereits definiertes CONFIG_DIR: $CONFIG_DIR" "CLI" "get_config_dir"
        create_directory "$CONFIG_DIR" || true
        echo "$CONFIG_DIR"
        return 0
    fi
    
    # Verwende die in dieser Datei definierten Pfade
    debug "Prüfe Standard- und Fallback-Pfade für Konfigurations-Verzeichnis" "CLI" "get_config_dir"
    dir=$(get_folder_path "$DEFAULT_CONFIG_DIR" "$FALLBACK_CONFIG_DIR" 1)
    if [ -n "$dir" ]; then
        debug "Verwende Pfad für Konfigurations-Verzeichnis: $dir" "CLI" "get_config_dir"
        echo "$dir"
        return 0
    fi
    
    # Als absoluten Notfall ein Unterverzeichnis des Installationsverzeichnisses verwenden
    local install_dir
    install_dir=$(get_install_dir)
    debug "Alle Pfade für Konfigurations-Verzeichnis fehlgeschlagen, verwende $install_dir/conf" "CLI" "get_config_dir"
    echo "$install_dir/conf"
    return 0
}

# ------------------------------------------------------------------------------
# get_photos_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Fotos-Verzeichnis zurück
# Parameter: keine
# Rückgabe: Pfad zum Fotos-Verzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_photos_dir() {
    debug "Ermittle Fotos-Verzeichnis" "CLI" "get_photos_dir"
    
    local frontend_dir
    frontend_dir=$(get_frontend_dir)
    
    local photos_dir="$frontend_dir/photos"
    debug "Prüfe Standard-Fotos-Verzeichnis: $photos_dir" "CLI" "get_photos_dir"
    if create_directory "$photos_dir"; then
        debug "Verwende Standard-Fotos-Verzeichnis: $photos_dir" "CLI" "get_photos_dir"
        echo "$photos_dir"
        return 0
    fi
    
    # Fallback zum Datenverzeichnis
    local data_dir
    data_dir=$(get_data_dir)
    debug "Standard-Fotos-Verzeichnis nicht verfügbar, verwende Fallback: $data_dir/photos" "CLI" "get_photos_dir"
    echo "$data_dir/photos"
    return 0
}

# ------------------------------------------------------------------------------
# get_photos_originals_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Originalfotos-Verzeichnis zurück
# Parameter: $1 - (Optional) Name des Events
# Rückgabe: Pfad zum Originalfotos-Verzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_photos_originals_dir() {
    local event_name="$1"
    debug "Ermittle Original-Fotos-Verzeichnis" "CLI" "get_photos_originals_dir"
    
    local photos_dir
    photos_dir=$(get_photos_dir)
    local originals_dir="$photos_dir/originals"
    
    debug "Prüfe Originals-Verzeichnis: $originals_dir" "CLI" "get_photos_originals_dir"
    if create_directory "$originals_dir"; then
        if [ -n "$event_name" ]; then
            local event_dir="$originals_dir/$event_name"
            debug "Event-Name angegeben, prüfe Verzeichnis: $event_dir" "CLI" "get_photos_originals_dir"
            if create_directory "$event_dir"; then
                debug "Verwende Event-spezifisches Original-Fotos-Verzeichnis: $event_dir" "CLI" "get_photos_originals_dir"
                echo "$event_dir"
                return 0
            fi
        else
            debug "Verwende Standard Original-Fotos-Verzeichnis: $originals_dir" "CLI" "get_photos_originals_dir"
            echo "$originals_dir"
            return 0
        fi
    fi
    
    # Fallback, wenn Event-Verzeichnis nicht erstellt werden konnte
    debug "Originals-Verzeichnis nicht verfügbar, verwende Fallback: $photos_dir" "CLI" "get_photos_originals_dir"
    echo "$photos_dir"
    return 0
}

# ------------------------------------------------------------------------------
# get_photos_gallery_dir
# ------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zum Galerie-Verzeichnis zurück
# Parameter: $1 - (Optional) Name des Events
# Rückgabe: Pfad zum Galerie-Verzeichnis oder leerer String bei Fehler
# ------------------------------------------------------------------------------
get_photos_gallery_dir() {
    local event_name="$1"
    debug "Ermittle Galerie-Verzeichnis" "CLI" "get_photos_gallery_dir"
    
    local photos_dir
    photos_dir=$(get_photos_dir)
    local gallery_dir="$photos_dir/gallery"
    
    debug "Prüfe Galerie-Verzeichnis: $gallery_dir" "CLI" "get_photos_gallery_dir"
    if create_directory "$gallery_dir"; then
        if [ -n "$event_name" ]; then
            local event_dir="$gallery_dir/$event_name"
            debug "Event-Name angegeben, prüfe Verzeichnis: $event_dir" "CLI" "get_photos_gallery_dir"
            if create_directory "$event_dir"; then
                debug "Verwende Event-spezifisches Galerie-Verzeichnis: $event_dir" "CLI" "get_photos_gallery_dir"
                echo "$event_dir"
                return 0
            fi
        else
            debug "Verwende Standard Galerie-Verzeichnis: $gallery_dir" "CLI" "get_photos_gallery_dir"
            echo "$gallery_dir"
            return 0
        fi
    fi
    
    # Fallback, wenn Event-Verzeichnis nicht erstellt werden konnte
    debug "Galerie-Verzeichnis nicht verfügbar, verwende Fallback: $photos_dir" "CLI" "get_photos_gallery_dir"
    echo "$photos_dir"
    return 0
}

set_script_permissions() {
    # -----------------------------------------------------------------------
    # set_script_permissions
    # -----------------------------------------------------------------------
    # Funktion: Setzt Ausführbarkeitsrechte für alle Skripte im BASH_DIR
    # Parameter: keine
    # Rückgabe: 0 = OK, 1 = Verzeichnis existiert nicht
    # -----------------------------------------------------------------------
    local bash_dir="$DEFAULT_BASH_DIR"
    
    if [ -n "$BASH_DIR" ]; then
        bash_dir="$BASH_DIR"
    fi
    
    if [ ! -d "$bash_dir" ]; then
        debug "BASH_DIR $bash_dir existiert nicht" "CLI" "set_script_permissions"
        return 1
    fi
    
    debug "Setze Ausführbarkeitsrechte für $bash_dir/*.sh" "CLI" "set_script_permissions"
    chmod +x "$bash_dir"/*.sh 2>/dev/null || true
    
    debug "Ausführbarkeitsrechte erfolgreich gesetzt" "CLI" "set_script_permissions"
    return 0
}

ensure_folder_structure() {
    # -----------------------------------------------------------------------
    # ensure_folder_structure
    # -----------------------------------------------------------------------
    # Funktion: Stellt sicher, dass die gesamte Ordnerstruktur existiert
    # Parameter: keine
    # Rückgabe: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    debug "Stelle sicher, dass alle notwendigen Verzeichnisse existieren" "CLI" "ensure_folder_structure"
    
    # Hauptverzeichnisse erstellen
    get_install_dir >/dev/null || return 1
    get_data_dir >/dev/null || return 1
    get_backup_dir >/dev/null || return 1
    get_log_dir >/dev/null || return 1
    get_frontend_dir >/dev/null || return 1
    get_config_dir >/dev/null || return 1
    
    # Frontend-Unterverzeichnisse erstellen
    local frontend_dir
    frontend_dir=$(get_frontend_dir)
    create_directory "$frontend_dir/css" || true
    create_directory "$frontend_dir/js" || true
    create_directory "$frontend_dir/fonts" || true
    create_directory "$frontend_dir/picture" || true
    
    # Fotos-Verzeichnisstruktur
    get_photos_dir >/dev/null || return 1
    get_photos_originals_dir >/dev/null || return 1
    get_photos_gallery_dir >/dev/null || return 1
    
    # Setze Ausführbarkeitsrechte für Skripte
    set_script_permissions || true
    
    debug "Ordnerstruktur erfolgreich erstellt" "CLI" "ensure_folder_structure"
    return 0
}

# ------------------------------------------------------------------------------
# Hauptlogik für direkten Aufruf des Skripts
# ------------------------------------------------------------------------------

# Wenn das Skript direkt aufgerufen wird, überprüfen wir die Parameter
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Setze eine sinnvolle Umgebung für direkte Aufrufe
    if [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    fi

    # Verarbeite Kommandozeilen-Parameter
    case "$1" in
        install_dir|get_install_dir)
            get_install_dir
            ;;
        data_dir|get_data_dir)
            get_data_dir
            ;;
        backup_dir|get_backup_dir)
            get_backup_dir
            ;;
        log_dir|get_log_dir)
            get_log_dir
            ;;
        frontend_dir|get_frontend_dir)
            get_frontend_dir
            ;;
        config_dir|get_config_dir)
            get_config_dir
            ;;
        photos_dir|get_photos_dir)
            get_photos_dir
            ;;
        photos_originals_dir|get_photos_originals_dir)
            get_photos_originals_dir "$2"
            ;;
        photos_gallery_dir|get_photos_gallery_dir)
            get_photos_gallery_dir "$2"
            ;;
        create_directory)
            if [ -z "$2" ]; then
                echo "Fehler: Kein Verzeichnis angegeben"
                exit 1
            fi
            if create_directory "$2" "$3" "$4" "$5"; then
                echo "Verzeichnis $2 erfolgreich erstellt oder bereits vorhanden."
                exit 0
            else
                echo "Fehler beim Erstellen des Verzeichnisses $2"
                exit 1
            fi
            ;;
        ensure_structure|ensure_folder_structure)
            if ensure_folder_structure; then
                echo "Ordnerstruktur erfolgreich erstellt."
                exit 0
            else
                echo "Fehler beim Erstellen der Ordnerstruktur."
                exit 1
            fi
            ;;
        *)
            echo "Verwendung: $0 [OPTION] [PARAMETER]"
            echo ""
            echo "Optionen:"
            echo "  install_dir               Gibt den Pfad zum Installationsverzeichnis zurück"
            echo "  data_dir                  Gibt den Pfad zum Datenverzeichnis zurück"
            echo "  backup_dir                Gibt den Pfad zum Backup-Verzeichnis zurück"
            echo "  log_dir                   Gibt den Pfad zum Log-Verzeichnis zurück"
            echo "  frontend_dir              Gibt den Pfad zum Frontend-Verzeichnis zurück"
            echo "  config_dir                Gibt den Pfad zum Konfigurationsverzeichnis zurück"
            echo "  photos_dir                Gibt den Pfad zum Fotos-Verzeichnis zurück"
            echo "  photos_originals_dir      Gibt den Pfad zum Originalfotos-Verzeichnis zurück"
            echo "                            Optional: Name des Events als Parameter"
            echo "  photos_gallery_dir        Gibt den Pfad zum Galerie-Verzeichnis zurück"
            echo "                            Optional: Name des Events als Parameter"
            echo "  create_directory DIR      Erstellt das angegebene Verzeichnis"
            echo "                            Optional: Benutzer Gruppe Mode"
            echo "  ensure_structure          Stellt sicher, dass die gesamte Ordnerstruktur existiert"
            echo ""
            echo "Beispiele:"
            echo "  $0 install_dir"
            echo "  $0 photos_gallery_dir event_2025_06_15"
            echo "  $0 create_directory /path/to/dir fotobox www-data 775"
            echo "  $0 ensure_structure"
            exit 1
            ;;
    esac
    
    exit 0
fi

# Markiere dieses Modul als geladen
MANAGE_FOLDERS_LOADED=1
