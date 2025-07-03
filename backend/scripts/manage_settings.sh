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
_ensure_database_file_debug_0007="SUCCESS: SQLite-Datenbank existiert und ist gültig: '%s'"

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
            return 1
        fi
        
        # Erneut prüfen, ob die Initialisierung erfolgreich war
        if ! sqlite3 "$db_file" "PRAGMA integrity_check;" &>/dev/null; then
            debug "$(printf "$_ensure_database_file_debug_0006" "$db_file")"
            return 1
        fi

        debug "$(printf "$_ensure_database_file_debug_0004" "$db_file")"
        return 0
    fi
    
    debug "$(printf "$_ensure_database_file_debug_0007" "$db_file")"
    return 0
}

# _ensure_table_schema_versions
_ensure_table_schema_versions_debug_0001="INFO: Sicherstellen, dass die Tabelle '%s' existiert."
_ensure_table_schema_versions_debug_0002="SUCCESS: Tabelle '%s' existiert."
_ensure_table_schema_versions_debug_0003="INFO: Erstelle Tabelle '%s', falls sie nicht existiert."
_ensure_table_schema_versions_debug_0004="ERROR: Fehler beim Erstellen der Tabelle '%s'."
_ensure_table_schema_versions_debug_0005="SUCCESS: Tabelle '%s' erfolgreich erstellt."
_ensure_table_schema_versions_debug_0006="DEBUG: SQL-Statement für Tabellenerstellung: \n%s"
_ensure_table_schema_versions_debug_0007="DEBUG: Tatsächliche Tabellenstruktur in der Datenbank: \n%s"

_ensure_table_schema_versions () {
    # -----------------------------------------------------------------------
    # _ensure_table_schema_versions
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die Tabelle 'schema_versions' existiert.
    # .........  Diese Tabelle wird für die Verwaltung der Datenbank-Schema-
    # .........  Versionen verwendet.
    # Parameter: Keine
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local db_file=$(get_data_file)
    local table_name="schema_versions"

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_ensure_table_schema_versions_debug_0001" "$table_name")"

    # SQL-Statement für die Tabellenerstellung definieren
    local create_table_sql="
        CREATE TABLE IF NOT EXISTS schema_versions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,        -- Name der Tabelle
            version INTEGER NOT NULL,        -- Aktuelle Schemaversion
            migration_timestamp DATETIME DEFAULT (datetime('now','localtime')), -- Zeitpunkt der letzten Migration
            description TEXT                 -- Beschreibung der letzten Änderung
        );"

    # Prüfen, ob die Tabelle bereits existiert
    if sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table_name';" | grep -q "$table_name"; then
        # Tabelle existiert bereits
        debug "$(printf "$_ensure_table_schema_versions_debug_0002" "$table_name")"

        # Tabellenstruktur aus der Datenbank auslesen und ausgeben
        local table_structure=$(sqlite3 "$db_file" ".schema $table_name")
        debug "$(printf "$_ensure_table_schema_versions_debug_0007" "$table_structure")"

        return 0
    fi
    # Tabelle existiert nicht, also erstellen
    debug "$(printf "$_ensure_table_schema_versions_debug_0003" "$table_name")"
    if ! sqlite3 "$db_file" "$create_table_sql"; then
        debug "$(printf "$_ensure_table_schema_versions_debug_0004" "$table_name")"
        return 1
    fi

    # Erfolgreiche Erstellung, Struktur der neu erstellten Tabelle auslesen
    local table_structure=$(sqlite3 "$db_file" ".schema $table_name")
    debug "$(printf "$_ensure_table_schema_versions_debug_0007" "$table_structure")"

    debug "$(printf "$_ensure_table_schema_versions_debug_0005" "$table_name")"
    return 0
}

# ===========================================================================
# Funktionen zur Datenbank-Verwaltung
# ===========================================================================

# ensure_database
ensure_database_debug_0001="INFO: Sicherstellen, dass die Datenbank initialisiert ist."
ensure_database_debug_0002="SUCCESS: Datenbank ist initialisiert und bereit zur Nutzung."
ensure_database_debug_0003="ERROR: Datenbank-Initialisierung fehlgeschlagen."
ensure_database_debug_0004="ERROR: Tabelle 'schema_versions' konnte nicht erstellt werden."

ensure_database() {
    # -----------------------------------------------------------------------
    # ensure_database
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass die SQLite-Datenbank initialisiert ist.
    # .........  Diese Funktion prüft, ob die Datenbankdatei existiert und 
    # .........  gültig ist. Falls nicht, wird sie neu initialisiert.
    # Parameter: Keine
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    
    debug "$ensure_database_debug_0001"
    
    if ! _ensure_database_file; then
        debug "$ensure_database_debug_0003"
        return 1
    fi
    
    if ! _ensure_table_schema_versions; then
        debug "$ensure_database_debug_0004"
        return 1
    fi
    
    debug "$ensure_database_debug_0002"
    return 0
}   

# ===========================================================================
# Prüfungen bei der Datenbank-Initialisierung
# ===========================================================================
# Prüfung, ob die SQLite-Datenbankdatei existiert und ob die gefundene Datei
# eine gültige SQLite-Datenbank ist. Falls nicht, wird sie neu initialisiert.
# ---------------------------------------------------------------------------
DEBUG_MOD_GLOBAL=1  # Setze globale Debug-Variable, damit Debug-Ausgaben aktiviert sind

# Prüfe zuerst, ob SQLite installiert ist
if ! _is_sqlite_installed; then
    debug "WARN: SQLite ist nicht installiert. Datenbank-Initialisierung wird übersprungen."
else
    # SQLite ist verfügbar, initialisiere die Datenbank
    if ! ensure_database; then
        debug "ERROR: Datenbank-Initialisierung fehlgeschlagen."
        return 1
    fi
fi

DEBUG_MOD_GLOBAL=0  # Löschen globale Debug-Variable, damit Debug-Ausgaben deaktiviert sind
