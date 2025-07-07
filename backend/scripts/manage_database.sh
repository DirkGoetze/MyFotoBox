#!/bin/bash
# ------------------------------------------------------------------------------
# manage_database.sh
# ------------------------------------------------------------------------------
# Funktion: Verwaltung, Initialisierung und Update der SQLite Datenbank und  
# ......... Bereitstellung einer einheitlichen Schnittstelle für den Zugriff
# ......... auf die Datenbank.
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
MANAGE_DATABASE_LOADED=0
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
# ---------------------------------------------------------------------------
# Hilfsfunktionen zur Datenbank-Verwaltung
# ---------------------------------------------------------------------------

# _is_sqlite_installed
_is_sqlite_installed_debug_0001="INFO: Prüfe, ob SQLite installiert ist"
_is_sqlite_installed_debug_0002="SUCCESS: SQLite ist installiert (Version: %s)"
_is_sqlite_installed_debug_0003="ERROR: SQLite ist nicht installiert oder nicht im PATH"
_is_sqlite_installed_debug_0004="INFO: SQLite CLI wurde gefunden unter: %s"

_is_sqlite_installed() {
    # -----------------------------------------------------------------------
    # _is_sqlite_installed
    # -----------------------------------------------------------------------
    # Funktion.: Prüft, ob SQLite auf dem System installiert ist und 
    # .........  die sqlite3-Kommandozeile im PATH verfügbar ist
    # Parameter: Keine
    # Rückgabe.: 0 - SQLite ist installiert
    # .........  1 - SQLite ist nicht installiert
    # -----------------------------------------------------------------------
    debug "$_is_sqlite_installed_debug_0001"
    
    # Prüfe, ob der sqlite3-Befehl existiert und ausführbar ist
    if command -v sqlite3 >/dev/null 2>&1; then
        # SQLite gefunden, hole den Pfad
        local sqlite_path=$(command -v sqlite3)
        debug "$(printf "$_is_sqlite_installed_debug_0004" "$sqlite_path")"
        
        # Prüfe die Version und ob der Befehl tatsächlich ausführbar ist
        local sqlite_version=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
        if [ -n "$sqlite_version" ]; then
            debug "$(printf "$_is_sqlite_installed_debug_0002" "$sqlite_version")"
            return 0
        fi
    fi
    
    # SQLite nicht gefunden oder nicht ausführbar
    debug "$_is_sqlite_installed_debug_0003"
    return 1
}

# _ensure_database_file
_ensure_database_file_debug_0001="INFO: Bestehende SQLite-Datenbank ist gültig: '%s'"
_ensure_database_file_debug_0002="WARN: Datei '%s' existiert, ist aber keine gültige SQLite-Datenbank. Wird neu initialisiert."
_ensure_database_file_debug_0003="INFO: Initialisiere SQLite-Datenbank: '%s'"
_ensure_database_file_debug_0004="SUCCESS: SQLite-Datenbank erfolgreich initialisiert: '%s'"
_ensure_database_file_debug_0005="ERROR: Fehler beim Initialisieren der SQLite-Datenbank: '%s'"
_ensure_database_file_debug_0006="ERROR: SQLite-Datenbank konnte nicht korrekt initialisiert werden: '%s'"
_ensure_database_file_debug_0008="SUCCESS: SQLite-Datenbank existiert und ist gültig: '%s'"

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
    # .........  Vollständiger Pfad zur Datenbankdatei für weitere Operationen
    # -----------------------------------------------------------------------
    local db_file=$(get_data_file)
    local is_valid_sqlite=0
    
    # Prüfen, ob die Datei existiert und eine gültige SQLite-DB ist
    if [ -s "$db_file" ]; then
        # Datei existiert und hat Inhalt, prüfen ob es eine gültige SQLite-DB ist
        if sqlite3 "$db_file" "PRAGMA quick_check;" &>/dev/null; then
            # Gültige SQLite-Datenbank
            is_valid_sqlite=1
            debug "$(printf "$_ensure_database_file_debug_0001" "$db_file")"
        else
            # Datei existiert, ist aber keine gültige SQLite-DB
            debug "$(printf "$_ensure_database_file_debug_0002" "$db_file")"
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
        debug "$(printf "$_ensure_database_file_debug_0003" "$db_file")"
        if ! sqlite3 "$db_file" "PRAGMA foreign_keys = ON; VACUUM;"; then
            debug "$(printf "$_ensure_database_file_debug_0005" "$db_file")"
            echo ""
            return 1
        fi
        
        # Erneut prüfen, ob die Initialisierung erfolgreich war
        if ! sqlite3 "$db_file" "PRAGMA integrity_check;" &>/dev/null; then
            debug "$(printf "$_ensure_database_file_debug_0006" "$db_file")"
            echo ""
            return 1
        fi

        debug "$(printf "$_ensure_database_file_debug_0004" "$db_file")"
        echo "$db_file"
        return 0
    fi
    
    debug "$(printf "$_ensure_database_file_debug_0008" "$db_file")"
    echo "$db_file"
    return 0
}

# ---------------------------------------------------------------------------
# Hilfsfunktionen zur Tabellen-Verwaltung
# ---------------------------------------------------------------------------

# _create_table
_create_table_debug_0001="INFO: Erstelle Tabelle aus SQL-Statement..."
_create_table_debug_0002="ERROR: Kein Tabellenname im SQL-Statement gefunden."
_create_table_debug_0003="INFO: SQL-Statement für Tabellenerstellung: \n%s"
_create_table_debug_0004="SUCCESS: Tabelle '%s' existiert."
_create_table_debug_0005="INFO: Tabellenstruktur in der Datenbank: \n%s"
_create_table_debug_0006="INFO: Erstelle Tabelle '%s', da sie nicht existiert."
_create_table_debug_0007="ERROR: Fehler beim Erstellen der Tabelle '%s'."
_create_table_debug_0008="SUCCESS: Tabelle '%s' erfolgreich erstellt."

_create_table() {
    # -----------------------------------------------------------------------
    # _create_table
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die als SQL-Statement übergebene Tabelle 
    # .........  existiert. Falls nicht, wird sie erstellt.
    # Parameter: $1 - SQL-Statement zum Erstellen der Tabelle
    # .........  $2 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local sql_statement="$1"
    local db_file="$2"

    # Überprüfen, ob das SQL-Statement und der Datenbankpfad angegeben sind
    if ! check_param "$sql_statement" "sql_statement"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Tabellenname aus dem SQL-Statement extrahieren
    # Nach dem ersten "CREATE TABLE" suchen und den nächsten "Wort"-Token nehmen
    local table_name
    table_name=$(echo "$sql_statement" | grep -i -o "CREATE\s\+TABLE\s\+\(IF\s\+NOT\s\+EXISTS\s\+\)\?\w\+" | \
                awk '{print $NF}')

    # Wenn kein Tabellenname gefunden wurde, Fehler ausgeben
    if [ -z "$table_name" ]; then
        debug "$_create_table_debug_0002"
        return 1
    fi        

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_create_table_debug_0003" "$sql_statement")"

    # Prüfen, ob die Tabelle bereits existiert
    if sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table_name';" | grep -q "$table_name"; then
        # Tabelle existiert bereits
        debug "$(printf "$_create_table_debug_0004" "$table_name")"

        # Tabellenstruktur aus der Datenbank auslesen und ausgeben
        local table_structure=$(sqlite3 "$db_file" ".schema $table_name")
        debug "$(printf "$_create_table_debug_0005" "$table_structure")"
        return 0
    fi

    # Tabelle existiert nicht, also erstellen
    debug "$(printf "$_create_table_debug_0006" "$table_name")"
    if ! sqlite3 "$db_file" "$sql_statement"; then
        debug "$(printf "$_create_table_debug_0007" "$table_name")"
        return 1
    fi

    # Erfolgreiche Erstellung, Struktur der neu erstellten Tabelle auslesen
    local table_structure=$(sqlite3 "$db_file" ".schema $table_name")
    debug "$(printf "$_create_table_debug_0005" "$table_structure")"

    # Erfolgreich erstellt
    debug "$(printf "$_create_table_debug_0008" "$table_name")"
    return 0
}

# ---------------------------------------------------------------------------
# Hilfsfunktionen zu Datenbank-Tabellen-Struktur
# ---------------------------------------------------------------------------
## --- 1. Tabelle: schema_versions ------------------------------------------
# _ensure_table_schema_versions
_ensure_table_schema_versions_debug_0001="INFO: Sicherstellen, dass die Tabelle 'schema_versions' existiert."

_ensure_table_schema_versions () {
    # -----------------------------------------------------------------------
    # _ensure_table_schema_versions
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'schema_versions' existiert.
    # .........  Diese Tabelle wird für die Verwaltung der Datenbank-Schema-
    # .........  Versionen verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_schema_versions_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS schema_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,        -- Name der Tabelle
        version INTEGER NOT NULL,        -- Aktuelle Schemaversion
        migration_timestamp DATETIME DEFAULT (datetime('now','localtime')), -- Zeitpunkt der letzten Migration
        description TEXT                 -- Beschreibung der letzten Änderung
    );"

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"

    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}

## --- 2. Tabelle: db_backups -----------------------------------------------
# _ensure_table_db_backups
_ensure_table_db_backups_debug_0001="INFO: Sicherstellen, dass die Tabelle 'db_backups' existiert."

_ensure_table_db_backups () {
    # -----------------------------------------------------------------------
    # _ensure_table_db_backups
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'db_backups' existiert.
    # .........  Diese Tabelle wird für die Verwaltung von Datenbank-Backups 
    # .........  verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_db_backups_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS db_backups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backup_name TEXT NOT NULL UNIQUE, -- Name des Backups
        backup_file TEXT NOT NULL,       -- Dateipfad zum Backup
        created_at DATETIME DEFAULT (datetime('now','localtime')), -- Erstellungszeitpunkt
        backup_type TEXT NOT NULL,       -- Typ des Backups (manuell, automatisch, vor Migration)
        backup_reason TEXT,              -- Grund für das Backup
        checksum TEXT                    -- SHA256-Prüfsumme zur Integritätsvalidierung
    );"

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"


    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}   

## --- 3. Tabelle: config_hierarchies ---------------------------------------
# _ensure_table_config_hierarchies
_ensure_table_config_hierarchies_debug_0001="INFO: Sicherstellen, dass die Tabelle 'config_hierarchies' existiert."

_ensure_table_config_hierarchies () {
    # -----------------------------------------------------------------------
    # _ensure_table_config_hierarchies
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'config_hierarchies' existiert.
    # .........  Diese Tabelle wird für die Verwaltung der Hierarchien in der 
    # .........  Konfiguration verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_config_hierarchies_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS config_hierarchies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hierarchy_name TEXT NOT NULL UNIQUE, -- Name der Hierarchie (z.B. "nginx", "camera")
        hierarchy_data TEXT NOT NULL,         -- JSON-Daten der Hierarchie
        description TEXT,                    -- Beschreibung der Hierarchie
        responsible TEXT,                    -- Verantwortliches Modul/Person
        created_at DATETIME DEFAULT (datetime('now','localtime')), -- Erstellungszeitpunkt
        updated_at DATETIME DEFAULT (datetime('now','localtime')), -- Aktualisierungszeitpunkt
        enabled BOOLEAN DEFAULT 1            -- Hierarchie aktiv/inaktiv
    );

    CREATE INDEX idx_config_hierarchies_name ON config_hierarchies(hierarchy_name);
    "

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"

    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}

## --- 4. Tabelle: settings -------------------------------------------------
# _ensure_table_settings
_ensure_table_settings_debug_0001="INFO: Sicherstellen, dass die Tabelle 'settings' existiert."

_ensure_table_settings () {
    # -----------------------------------------------------------------------
    # _ensure_table_settings
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'settings' existiert.
    # .........  Diese Tabelle wird für die Speicherung von Konfigurationseinstellungen 
    # .........  verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_settings_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hierarchy_id INTEGER,                -- Verweis auf die Hierarchie
        key TEXT NOT NULL,                   -- Konfigurationsschlüssel (z.B. "port", "ssl.enabled")
        value TEXT,                          -- Konfigurationswert
        value_type TEXT NOT NULL,            -- Datentyp (string, int, bool, float, json)
        description TEXT,                    -- Beschreibung des Konfigurationsschlüssels
        created_at DATETIME DEFAULT (datetime('now','localtime')), -- Erstellungszeitpunkt
        updated_at DATETIME DEFAULT (datetime('now','localtime')), -- Aktualisierungszeitpunkt
        is_active BOOLEAN DEFAULT 1,         -- Aktive/Inaktive Einstellung
        weight INTEGER DEFAULT 0,            -- Gewichtung für Anwendungsreihenfolge
        change_group TEXT,                   -- Gruppierung für zusammengehörige Änderungen
        FOREIGN KEY (hierarchy_id) REFERENCES config_hierarchies(id) ON DELETE SET NULL,
        UNIQUE(hierarchy_id, key)            -- Verhindert doppelte Schlüssel in einer Hierarchie
    );
    
    CREATE INDEX idx_settings_key ON settings(key);
    CREATE INDEX idx_settings_active ON settings(is_active);
    CREATE INDEX idx_settings_hierarchy ON settings(hierarchy_id);
    "

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"

    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}

## --- 5. Tabelle: settings_history -----------------------------------------
# _ensure_table_settings_history
_ensure_table_settings_history_debug_0001="INFO: Sicherstellen, dass die Tabelle 'settings_history' existiert."

_ensure_table_settings_history () {
    # -----------------------------------------------------------------------
    # _ensure_table_settings_history
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'settings_history' existiert.
    # .........  Diese Tabelle wird für die Speicherung von Änderungen an
    # .........  Konfigurationseinstellungen verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_settings_history_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS settings_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_id INTEGER NOT NULL,         -- Verweis auf die Einstellung
        old_value TEXT,                      -- Vorheriger Wert
        new_value TEXT,                      -- Neuer Wert
        changed_at DATETIME DEFAULT (datetime('now','localtime')), -- Änderungszeitpunkt
        changed_by TEXT,                     -- Benutzer oder Prozess, der die Änderung vornahm
        change_reason TEXT,                  -- Grund für die Änderung
        FOREIGN KEY (setting_id) REFERENCES settings(id) ON DELETE CASCADE
    );

    CREATE INDEX idx_settings_history_setting ON settings_history(setting_id);
    "

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"

    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}

## --- 6. Tabelle: setting_dependencies -------------------------------------
# _ensure_table_setting_dependencies
_ensure_table_setting_dependencies_debug_0001="INFO: Sicherstellen, dass die Tabelle 'setting_dependencies' existiert."

_ensure_table_setting_dependencies () {
    # -----------------------------------------------------------------------
    # _ensure_table_setting_dependencies
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'setting_dependencies' existiert.
    # .........  Diese Tabelle wird für die Verwaltung von Abhängigkeiten 
    # .........  zwischen Konfigurationseinstellungen verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_setting_dependencies_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS setting_dependencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_id INTEGER NOT NULL,         -- Verweis auf die Einstellung
        dependent_setting_id INTEGER NOT NULL, -- Abhängige Einstellung
        dependency_type TEXT NOT NULL,       -- Typ der Abhängigkeit (z.B. 'requires', 'conflicts')
        condition TEXT,                      -- Bedingung für die Abhängigkeit
        FOREIGN KEY (setting_id) REFERENCES settings(id) ON DELETE CASCADE,
        FOREIGN KEY (dependent_setting_id) REFERENCES settings(id) ON DELETE CASCADE,
        UNIQUE(setting_id, dependent_setting_id, dependency_type) -- Verhindert doppelte Abhängigkeiten
    );"

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"

    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}

## --- 7. Tabelle: change_groups --------------------------------------------
# _ensure_table_change_groups
_ensure_table_change_groups_debug_0001="INFO: Sicherstellen, dass die Tabelle 'change_groups' existiert."

_ensure_table_change_groups () {
    # -----------------------------------------------------------------------
    # _ensure_table_change_groups
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'change_groups' existiert.
    # .........  Diese Tabelle wird für die Gruppierung von Änderungen an 
    # .........  Konfigurationseinstellungen verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_change_groups_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS change_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_name TEXT NOT NULL UNIQUE,     -- Name der Änderungsgruppe
        description TEXT,                    -- Beschreibung der Gruppe
        status TEXT DEFAULT 'pending',       -- Status (pending, complete, error)
        created_at DATETIME DEFAULT (datetime('now','localtime')), -- Erstellungszeitpunkt
        updated_at DATETIME DEFAULT (datetime('now','localtime')), -- Aktualisierungszeitpunkt
        priority INTEGER DEFAULT 0           -- Priorität für die Anwendungsreihenfolge
    );

    CREATE INDEX idx_change_groups_name ON change_groups(group_name);
    "

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"

    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}

## --- 8. Tabelle: settings_change_groups -----------------------------------
# _ensure_table_settings_change_groups
_ensure_table_settings_change_groups_debug_0001="INFO: Sicherstellen, dass die Tabelle 'settings_change_groups' existiert."

_ensure_table_settings_change_groups () {
    # -----------------------------------------------------------------------
    # _ensure_table_settings_change_groups
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'settings_change_groups' existiert.
    # .........  Diese Tabelle wird für die Zuordnung von Einstellungen zu 
    # .........  Änderungsgruppen verwendet.
    # Parameter: $1 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="$1"

    # Debug-Ausgabe eröffnen
    debug "$_ensure_table_settings_change_groups_debug_0001"

    # Überprüfen, ob der Datenbankpfad angegeben ist
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="CREATE TABLE IF NOT EXISTS settings_change_groups (
        setting_id INTEGER NOT NULL,         -- Verweis auf die Einstellung
        change_group_id INTEGER NOT NULL,    -- Verweis auf die Änderungsgruppe
        FOREIGN KEY (setting_id) REFERENCES settings(id) ON DELETE CASCADE,
        FOREIGN KEY (change_group_id) REFERENCES change_groups(id) ON DELETE CASCADE,
        PRIMARY KEY (setting_id, change_group_id),  -- Primärschlüssel für eindeutige Zuordnung
        UNIQUE(setting_id, change_group_id)  -- Verhindert doppelte Zuordnungen
    );"

    # Tabelle erstellen
    _create_table "$create_table_sql" "$db_file"

    # Prüfen, ob die Tabelle erfolgreich erstellt wurde
    if [ $? -ne 0 ]; then return 1; else return 0; fi
}

# ===========================================================================
# Funktionen zur Datenbank-Verwaltung
# ===========================================================================

# validate_database
validate_database_debug_0001="INFO: Starte Datenbankvalidierung..."
validate_database_debug_0002="SUCCESS: Datenbankvalidierung abgeschlossen, keine Fehler gefunden."
validate_database_debug_0003="ERROR: Datenbankvalidierung abgeschlossen, %d Fehler gefunden."
validate_database_debug_0004="INFO: Führe vollständige PRAGMA integrity_check für die gesamte Datenbank aus..."
validate_database_debug_0005="ERROR: Allgemeine Datenbankintegritätsprüfung fehlgeschlagen: %s"

validate_database() {
    # -----------------------------------------------------------------------
    # validate_database
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass alle Tabellen in der SQLite-Datenbank 
    # .........  konsistent sind und die Datenbank keine Fehler aufweist.
    # Parameter: $1 - (Optional) Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file="${1:-$(get_data_file)}"
    local validation_errors=0

    # Debug-Ausgabe eröffnen
    debug "$validate_database_debug_0001"

    # 1. Vollständige Datenbank-Integritätsprüfung (schneller als tabellenweise)
    debug "$validate_database_debug_0004"
    local integrity_check=$(sqlite3 "$db_file" "PRAGMA integrity_check;")
    
    if [ "$integrity_check" != "ok" ]; then
        debug "$(printf "$validate_database_debug_0005" "$integrity_check")"
        return 1
    fi

    # 2. Validiere einzelne Tabellen (Struktur und Fremdschlüsselbeziehungen)
    local tables=$(sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    
    for table in $tables; do
        _validate_table "$table" || validation_errors=$((validation_errors + 1))
    done

    # Zusammenfassung ausgeben
    if [ $validation_errors -eq 0 ]; then
        debug "$validate_database_debug_0002"
        return 0
    else
        debug "$(printf "$validate_database_debug_0003" "$validation_errors")"
        return 1
    fi
}

# ensure_database
ensure_database_debug_0001="INFO: Sicherstellen, dass die Datenbank initialisiert ist."
ensure_database_debug_0002="SUCCESS: Datenbank ist initialisiert und bereit zur Nutzung."
ensure_database_debug_0003="WARN: SQLite ist nicht installiert. Datenbank-Initialisierung wurde übersprungen."
ensure_database_debug_0004="ERROR: Datenbank-Initialisierung fehlgeschlagen."
ensure_database_debug_0005="ERROR: Tabelle 'db_backups' konnte nicht erstellt werden."
ensure_database_debug_0006="ERROR: Tabelle 'schema_versions' konnte nicht erstellt werden."
ensure_database_debug_0007="ERROR: Tabelle 'config_hierarchies' konnte nicht erstellt werden."
ensure_database_debug_0008="ERROR: Tabelle 'settings' konnte nicht erstellt werden."
ensure_database_debug_0009="ERROR: Tabelle 'settings_history' konnte nicht erstellt werden."
ensure_database_debug_0010="ERROR: Tabelle 'setting_dependencies' konnte nicht erstellt werden."
ensure_database_debug_0011="ERROR: Tabelle 'change_groups' konnte nicht erstellt werden."
ensure_database_debug_0012="ERROR: Tabelle 'settings_change_groups' konnte nicht erstellt werden."
ensure_database_debug_0013="INFO: Prüfe Tabellenstruktur in der Datenbank: '%s'"

ensure_database() {
    # -----------------------------------------------------------------------
    # ensure_database
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die SQLite-Datenbank initialisiert ist.
    # .........  Diese Funktion prüft, ob die Datenbankdatei existiert und 
    # .........  gültig ist. Falls nicht, wird sie neu initialisiert.
    # Parameter: keine
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file
    
    # Prüfe zuerst, ob SQLite installiert ist
    if _is_sqlite_installed; then

        # SQLite ist verfügbar, initialisiere die Datenbank
        debug "$ensure_database_debug_0001"

        # Prüfe, ob die Datenbankdatei existiert und gültig ist
        db_file=$(_ensure_database_file)
        if [ -z "$db_file" ]; then debug "$ensure_database_debug_0004"; return 1; fi

        # Tabellen erstellen, falls sie nicht existieren
        if ! _ensure_table_db_backups "$db_file"; then debug "$ensure_database_debug_0005"; return 1; fi
        if ! _ensure_table_schema_versions "$db_file"; then debug "$ensure_database_debug_0006"; return 1; fi
        if ! _ensure_table_config_hierarchies "$db_file"; then debug "$ensure_database_debug_0007"; return 1; fi
        if ! _ensure_table_settings "$db_file"; then debug "$ensure_database_debug_0008"; return 1; fi
        if ! _ensure_table_settings_history "$db_file"; then debug "$ensure_database_debug_0009"; return 1; fi
        if ! _ensure_table_setting_dependencies "$db_file"; then debug "$ensure_database_debug_0010"; return 1; fi
        if ! _ensure_table_change_groups "$db_file"; then debug "$ensure_database_debug_0011"; return 1; fi
        if ! _ensure_table_settings_change_groups "$db_file"; then debug "$ensure_database_debug_0012"; return 1; fi

        # Wenn die Datei bereits existiert und gültig ist, Tabellenstruktur prüfen
        validate_database "$db_file"
        if [ $? -ne 0 ]; then
            debug "$(printf "$ensure_database_debug_0013" "$db_file")"
            echo ""
            return 1
        fi

        # Alle Tabellen erfolgreich erstellt, Datenbank ist bereit
        debug "$ensure_database_debug_0002"
        return 0
    else
        # SQLite ist nicht installiert, Datenbank-Initialisierung wurde übersprungen
        debug "$ensure_database_debug_0003"
        return 1
    fi    
}   

# setup_database
setup_database_debug_0001="INFO: Starte Datenbank-Setup..."
setup_database_debug_0002="INFO: Starte Installation Datenbank ..."
setup_database_debug_0003="ERROR: Datenbank-Installation fehlgeschlagen."
setup_database_debug_0004="SUCCESS: Datenbank-Installation erfolgreich abgeschlossen."

setup_database_txt_0001="[/] Initialisiere Datenbank ..."
setup_database_txt_0002="Datenbank-Initialisierung fehlgeschlagen."
setup_database_txt_0003="Datenbank-Initialisierung erfolgreich abgeschlossen."

setup_database() {
    # -----------------------------------------------------------------------
    # setup_database
    # -----------------------------------------------------------------------
    # Funktion: Führt die komplette Installation der Datenbank durch
    # Parameter: $1 - Optional: CLI oder JSON-Ausgabe. Wenn nicht angegeben,
    # .........       wird die Standardausgabe verwendet (CLI-Ausgabe)
    # Rückgabe: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local output_mode="${1:-cli}"  # Standardmäßig CLI-Ausgabe
    local service_pid

    # Eröffnungsmeldung im Debug Modus
    debug "$setup_database_debug_0001"

    # Installiere die Datenbank
    if [ "$output_mode" = "json" ]; then
        ensure_database || return 1
    else
        # Ausgabe im CLI-Modus, Spinner anzeigen
        echo -n "$setup_database_txt_0001"
        # Installation der Datenbank im Hintergrund ausführen
        # und Spinner anzeigen
        debug "$setup_database_debug_0002"
        (ensure_database) &> /dev/null 2>&1 &
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob die Installation erfolgreich war
        if [ $? -ne 0 ]; then
            debug "$setup_database_debug_0003"
            print_error "$setup_database_txt_0002"
            return 1
        fi
        debug "$setup_database_debug_0004"
        print_success "$setup_database_txt_0003"
    fi

    return 0
}
