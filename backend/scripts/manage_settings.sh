#!/bin/bash
# ------------------------------------------------------------------------------
# manage_settings.sh
# ------------------------------------------------------------------------------
# Funktion: Verwaltung, Initialisierung und Update der SQLite Datenbank und  
# ......... Bereitstellung einer einheitlichen Schnittstelle für die Lese- und
# ......... Schreiboperationen auf die Datenbank.
# ......... 
# ......... 
# ------------------------------------------------------------------------------
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
MANAGE_SETTINGS_LOADED=0
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

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

_ensure_database_file() {
    # -----------------------------------------------------------------------
    # _ensure_database_file
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die SQLite-Datenbankdatei existiert.
    # .........  Erstellt die Datei, falls sie nicht vorhanden ist, und setzt
    # .........  die richtigen Berechtigungen. Prüft zusätzlich, ob eine 
    # .........  gefundene/vorhandene Datei eine gültige SQLite-DB ist.
    # Parameter: Keine
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file=$(get_data_file)
    local is_valid_sqlite=0
    
    # Prüfen, ob die Datei existiert und eine gültige SQLite-DB ist
    if [ -s "$db_file" ]; then
        # Datei existiert und hat Inhalt, prüfen ob es eine gültige SQLite-DB ist
        if sqlite3 "$db_file" "PRAGMA integrity_check;" &>/dev/null; then
            # Gültige SQLite-Datenbank
            is_valid_sqlite=1
            debug "Bestehende SQLite-Datenbank ist gültig: $db_file"
        else
            # Datei existiert, ist aber keine gültige SQLite-DB
            debug "Datei '$db_file' existiert, ist aber keine gültige SQLite-Datenbank. Wird neu initialisiert."
            # Sicherheitshalber Backup erstellen, falls es wichtige Daten sind
            # Extrahiere Dateinamen ohne Endung und Extension
            local db_basename=$(basename "$db_file")
            local db_name="${db_basename%.*}"
            local db_ext="${db_basename##*.}"
            local db_file_backup=$(get_backup_data_file "$db_name" "$db_ext")
            cp "$db_file" "$db_file_backup" 2>/dev/null
            # Datei leeren, um sie neu zu initialisieren
            true > "$db_file"
        fi
    fi
    
    # SQLite-Datenbank initialisieren, wenn nötig
    if [ "$is_valid_sqlite" -eq 0 ]; then
        # SQLite-DB initialisieren
        debug "Initialisiere SQLite-Datenbank: $db_file"
        if ! sqlite3 "$db_file" "PRAGMA foreign_keys = ON; VACUUM;"; then
            error "Fehler beim Initialisieren der SQLite-Datenbank: $db_file"
            return 1
        fi
        
        # Erneut prüfen, ob die Initialisierung erfolgreich war
        if ! sqlite3 "$db_file" "PRAGMA integrity_check;" &>/dev/null; then
            error "SQLite-Datenbank konnte nicht korrekt initialisiert werden: $db_file"
            return 1
        fi
        
        debug "SQLite-Datenbank erfolgreich initialisiert: $db_file"
    else
        debug "Bestehende SQLite-Datenbank ist gültig: $db_file"
    fi
    
    return 0
}

_ensure_settings_table() {
    local db_file="$1"
    
    sqlite3 "$db_file" "
    CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT,
        previous_value TEXT,
        group_id TEXT,
        weight INTEGER DEFAULT 1,
        changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        changed_by TEXT,
        description TEXT,
        version TEXT DEFAULT 'current',
        is_sensitive BOOLEAN DEFAULT 0,
        UNIQUE(key, version)
    );
    
    CREATE INDEX IF NOT EXISTS idx_settings_key ON settings(key);
    CREATE INDEX IF NOT EXISTS idx_settings_group ON settings(group_id);
    CREATE INDEX IF NOT EXISTS idx_settings_version ON settings(version);
    "
}

# ===========================================================================
# Funktionen zur Datenbank-Verwaltung
# ===========================================================================

# ===========================================================================
# Prüfungen bei der Datenbank-Initialisierung
# ===========================================================================
# Prüfung, ob die SQLite-Datenbankdatei existiert und ob die gefundene Datei
# eine gültige SQLite-Datenbank ist. Falls nicht, wird sie neu initialisiert.
# ---------------------------------------------------------------------------
if ! _ensure_database_file; then
    debug "ERROR: Datenbank-Initialisierung fehlgeschlagen."
    return 1
fi
