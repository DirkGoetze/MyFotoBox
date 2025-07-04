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
    
    debug "$(printf "$_ensure_database_file_debug_0007" "$db_file")"
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

# _is_column_exists
_is_column_exists_debug_0001="INFO: Prüfe, ob Spalte '%s' in Tabelle '%s' existiert."
_is_column_exists_debug_0002="INFO: Spalte '%s' in Tabelle '%s' gefunden."
_is_column_exists_debug_0003="ERROR: Spalte '%s' in Tabelle '%s' nicht gefunden."

_is_column_exists() {
    # -----------------------------------------------------------------------
    # _chk_invalid_types
    # -----------------------------------------------------------------------
    # Funktion.: Prüft ob eine Spalte in einer Tabelle vorkommt
    # Parameter: $1 - Name der zu prüfenden Spalte
    # .........  $2 - Name der Tabelle
    # .........  $3 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Spalte existiert
    # .........  1 - Spalte existiert nicht
    # -----------------------------------------------------------------------
    local column_name="$1"
    local table_name="$2"
    local db_file="$3"

    # Überprüfen, ob der Spaltenname, Tabellenname und der Datenbankpfad angegeben sind
    if ! check_param "$column_name" "column_name"; then return 1; fi
    if ! check_param "$table_name" "table_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_is_column_exists_debug_0001" "$column_name" "$table_name")"

    # Überprüfen, ob die Spalte in der Tabelle existiert
    if sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$column_name"; then
        debug "$(printf "$_is_column_exists_debug_0002" "$column_name" "$table_name")"
        return 0
    else
        debug "$(printf "$_is_column_exists_debug_0003" "$column_name" "$table_name")"
        return 1
    fi
}

# _chk_invalid_types
_chk_invalid_types_debug_0001="INFO: Prüfe auf ungültige Datentypen in Tabelle '%s'."
_chk_invalid_types_debug_0002="INFO: Tabelle '%s' hat keine '%s'-Spalte, Typvalidierung wird übersprungen."
_chk_invalid_types_debug_0003="ERROR: Ungültige Datentypen in Tabelle '%s' gefunden: %s"
_chk_invalid_types_debug_0004="INFO: Keine ungültigen Datentypen in Tabelle '%s' gefunden."

_chk_invalid_types() {
    # -----------------------------------------------------------------------
    # _chk_invalid_types
    # -----------------------------------------------------------------------
    # Funktion.: Prüft eine Tabelle auf ungültige Datentypen
    # Parameter: $1 - Name der zu prüfenden Tabelle
    # .........  $2 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Keine ungültigen Datentypen gefunden
    # .........  1 - Ungültige Datentypen gefunden
    # -----------------------------------------------------------------------
    local table_name="$1"                # Name der zu prüfenden Tabelle
    local db_file="$2"                   # Pfad zur Datenbankdatei
    local column="key"                   # Standard-Spalte für Einstellungen
    local field="value_type"             # Spalte mit dem Datentyp
    local valid_types="'string','int','bool','float','json'"  

    # Überprüfen, ob der Tabellenname und der Datenbankpfad angegeben sind
    if ! check_param "$table_name" "table_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_chk_invalid_types_debug_0001" "$table_name")"

    # Tabellen-spezifische Anpassungen
    case "$table_name" in
        settings)
            column="key"
            field="value_type"
            valid_types="'string','int','bool','float','json'"
            ;;
        # Weitere Tabellen können hier hinzugefügt werden
        *)
            # Prüfen, ob die Tabelle die benötigten Spalten hat
            if ! _is_column_exists "$field" "$table_name" "$db_file"; then
            # if ! sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$field"; then
                debug "$(printf "$_chk_invalid_types_debug_0002" "$table_name" "$field")"
                return 0
            fi
            ;;
    esac
    
    # SQL-Abfrage für ungültige Typen vorbereiten
    local invalid_values=$(sqlite3 "$db_file" "SELECT $column FROM $table_name WHERE $field NOT IN ($valid_types);")
    
    # Auswertung des Ergebnisses
    if [ -n "$invalid_values" ]; then
        debug "$(printf "$_chk_invalid_types_debug_0003" "$table_name" "$invalid_values")"
        return 1
    else
        debug "$(printf "$_chk_invalid_types_debug_0004" "$table_name")"
        return 0
    fi
}

# _chk_empty_values
_chk_empty_values_debug_0001="INFO: Prüfe auf leere Werte in Tabelle '%s'."
_chk_empty_values_debug_0002="INFO: Tabelle '%s' hat keine '%s'-Spalte, Leerwerteprüfung wird übersprungen."
_chk_empty_values_debug_0003="ERROR: Leere Werte in Tabelle '%s' gefunden: %s"
_chk_empty_values_debug_0004="INFO: Keine leeren Werte in Tabelle '%s' gefunden."

_chk_empty_values() {
    # -----------------------------------------------------------------------
    # _chk_empty_values
    # -----------------------------------------------------------------------
    # Funktion.: Prüft eine Tabelle auf leere Werte
    # Parameter: $1 - Name der zu prüfenden Tabelle
    # .........  $2 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Keine leeren Werte gefunden
    # .........  1 - Leere Werte gefunden
    # -----------------------------------------------------------------------
    local table_name="$1"                # Name der zu prüfenden Tabelle
    local db_file="$2"                   # Pfad zur Datenbankdatei
    local key_column="key"               # Standard-Spalte für Schlüssel
    local value_column="value"           # Spalte mit dem Wert
    
    # Überprüfen, ob der Tabellenname und der Datenbankpfad angegeben sind
    if ! check_param "$table_name" "table_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_chk_empty_values_debug_0001" "$table_name")"

    # Tabellen-spezifische Anpassungen
    case "$table_name" in
        settings|config_hierarchies)
            # Spezifische Spalten für diese Tabellen
            ;;
        # Weitere Tabellen können hier hinzugefügt werden
        *)
            # Prüfen, ob die Tabelle die benötigten Spalten hat
            if ! _is_column_exists "$value_column" "$table_name" "$db_file"; then
            # if ! sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$value_column"; then
                debug "$(printf "$_chk_empty_values_debug_0002" "$table_name" "$value_column")"
                return 0
            fi
            ;;
    esac
    
    # SQL-Abfrage für leere Werte vorbereiten
    local empty_values=$(sqlite3 "$db_file" "SELECT $key_column FROM $table_name WHERE $value_column IS NULL OR $value_column = '';")

    # Auswertung des Ergebnisses
    if [ -n "$empty_values" ]; then
        debug "$(printf "$_chk_empty_values_debug_0003" "$table_name" "$empty_values")"
        return 1
    else
        debug "$(printf "$_chk_empty_values_debug_0004" "$table_name")"
        return 0
    fi
}

# _chk_inactive_settings
_chk_inactive_settings_debug_0001="INFO: Prüfe auf inaktive Einstellungen in Tabelle '%s'."
_chk_inactive_settings_debug_0002="INFO: Tabelle '%s' hat keine '%s'-Spalte, Aktivitätsprüfung wird übersprungen."
_chk_inactive_settings_debug_0003="WARN: Inaktive Einstellungen in Tabelle '%s' gefunden: %s"
_chk_inactive_settings_debug_0004="INFO: Keine inaktiven Einstellungen in Tabelle '%s' gefunden."

_chk_inactive_settings() {
    # -----------------------------------------------------------------------
    # _chk_inactive_settings
    # -----------------------------------------------------------------------
    # Funktion.: Prüft eine Tabelle auf inaktive Einstellungen
    # Parameter: $1 - Name der zu prüfenden Tabelle
    # .........  $2 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Keine inaktiven Einstellungen gefunden
    # .........  1 - Inaktive Einstellungen gefunden
    # -----------------------------------------------------------------------
    local table_name="$1"           # Name der zu prüfenden Tabelle
    local db_file="$2"              # Pfad zur Datenbankdatei
    local key_column="key"          # Standard-Spalte für Schlüssel
    local active_column="is_active" # Spalte, die den Aktivitätsstatus angibt
    
    # Überprüfen, ob der Tabellenname und der Datenbankpfad angegeben sind
    if ! check_param "$table_name" "table_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_chk_inactive_settings_debug_0001" "$table_name")"

    # Nur für Tabellen mit is_active-Spalte
    if ! _is_column_exists "$active_column" "$table_name" "$db_file"; then
    # if ! sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$active_column"; then
        debug "$(printf "$_chk_inactive_settings_debug_0002" "$table_name" "$active_column")"
        return 0
    fi

    # SQL-Abfrage für inaktive Einstellungen vorbereiten    
    local inactive_settings=$(sqlite3 "$db_file" "SELECT $key_column FROM $table_name WHERE $active_column = 0;")
    
    # Bei inaktiven Einstellungen nur warnen, nicht als Fehler werten
    if [ -n "$inactive_settings" ]; then
        debug "$(printf "$_chk_inactive_settings_debug_0003" "$table_name" "$inactive_settings")"
    else
        debug "$(printf "$_chk_inactive_settings_debug_0004" "$table_name")"
    fi
    
    # Immer erfolgreich, da inaktive Einstellungen kein Fehler sind
    return 0
}

# _chk_foreign_key_integrity
_chk_foreign_key_integrity_debug_0001="INFO: Prüfe Fremdschlüsselintegrität in Tabelle '%s'."
_chk_foreign_key_integrity_debug_0002="INFO: Tabelle '%s' hat keine '%s'-Spalte, FK-Prüfung wird übersprungen."
_chk_foreign_key_integrity_debug_0003="ERROR: Ungültige Fremdschlüsselreferenzen in Tabelle '%s' gefunden: %s"
_chk_foreign_key_integrity_debug_0004="INFO: Keine ungültigen Fremdschlüsselreferenzen in Tabelle '%s' gefunden."

_chk_foreign_key_integrity() {
    # -----------------------------------------------------------------------
    # _chk_foreign_key_integrity
    # -----------------------------------------------------------------------
    # Funktion.: Prüft eine Tabelle auf ungültige Fremdschlüsselreferenzen
    # Parameter: $1 - Name der zu prüfenden Tabelle
    # .........  $2 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Keine ungültigen Fremdschlüsselreferenzen gefunden
    # .........  1 - Ungültige Fremdschlüsselreferenzen gefunden
    # -----------------------------------------------------------------------
    local table_name="$1"            # Name der zu prüfenden Tabelle
    local db_file="$2"               # Pfad zur Datenbankdatei
    local fk_column=""               # Standard-Spalte für Fremdschlüssel
    local ref_table=""               # Referenztabelle für den Fremdschlüssel
    local ref_column=""              # Referenzspalte in der Referenztabelle
    
    # Überprüfen, ob der Tabellenname und der Datenbankpfad angegeben sind
    if ! check_param "$table_name" "table_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_chk_foreign_key_integrity_debug_0001" "$table_name")"

    # Tabellen-spezifische Fremdschlüsselbeziehungen definieren
    case "$table_name" in
        settings)
            fk_column="hierarchy_id"
            ref_table="config_hierarchies"
            ref_column="id"
            ;;
        settings_history)
            fk_column="setting_id"
            ref_table="settings"
            ref_column="id"
            ;;
        # Weitere Tabellen können hier hinzugefügt werden
        *)
            # Wenn keine spezifischen FK-Beziehungen definiert sind, überspringen
            debug "$(printf "$_chk_foreign_key_integrity_debug_0002" "$table_name" "$fk_column")"
            return 0
            ;;
    esac
    
    # Prüfen, ob die Tabelle die benötigte FK-Spalte hat
    if ! _is_column_exists "$fk_column" "$table_name" "$db_file"; then
    # if ! sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$fk_column"; then
        debug "$(printf "$_chk_foreign_key_integrity_debug_0002" "$table_name" "$fk_column")"
        return 0
    fi
    
    # SQL-Abfrage für ungültige Fremdschlüsselreferenzen vorbereiten
    local invalid_refs=$(sqlite3 "$db_file" "
        SELECT s.$fk_column FROM $table_name s 
        LEFT JOIN $ref_table r ON s.$fk_column = r.$ref_column 
        WHERE s.$fk_column IS NOT NULL AND r.$ref_column IS NULL;")

    # Auswertung des Ergebnisses
    if [ -n "$invalid_refs" ]; then
        debug "$(printf "$_chk_foreign_key_integrity_debug_0003" "$table_name" "$invalid_refs")"
        return 1
    else
        debug "$(printf "$_chk_foreign_key_integrity_debug_0004" "$table_name")"
        return 0
    fi
}

# _chk_duplicate_keys
_chk_duplicate_keys_debug_0001="INFO: Prüfe auf Duplikate in Tabelle '%s'."
_chk_duplicate_keys_debug_0002="INFO: Tabelle '%s' hat keine '%s'-Spalte, Duplikatprüfung wird übersprungen."
_chk_duplicate_keys_debug_0003="ERROR: Duplikate in Tabelle '%s' gefunden: %s"
_chk_duplicate_keys_debug_0004="INFO: Keine Duplikate in Tabelle '%s' gefunden."

_chk_duplicate_keys() {
    # -----------------------------------------------------------------------
    # _chk_duplicate_keys
    # -----------------------------------------------------------------------
    # Funktion.: Prüft eine Tabelle auf Duplikate in Schlüsseln
    # Parameter: $1 - Name der zu prüfenden Tabelle
    # .........  $2 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Keine Duplikate gefunden
    # .........  1 - Ungültige Datentypen gefunden
    # -----------------------------------------------------------------------
    local table_name="$1"      # Name der zu prüfenden Tabelle
    local db_file="$2"         # Pfad zur Datenbankdatei
    local key_column="key"     # Standard-Spalte für Schlüssel
    local extra_column=""      # Zusätzliche Spalte für spezifische Tabellen
    
    # Überprüfen, ob der Tabellenname und der Datenbankpfad angegeben sind
    if ! check_param "$table_name" "table_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_chk_invalid_types_debug_0001" "$table_name")"

    # Tabellen-spezifische Anpassungen
    case "$table_name" in
        settings)
            extra_column="hierarchy_id"
            ;;
        # Weitere Tabellen können hier hinzugefügt werden
        *)
            # Wenn keine spezifischen Schlüsselspalten definiert sind, überspringen
            if ! _is_column_exists "$key_column" "$table_name" "$db_file"; then
            # if ! sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$key_column"; then
                debug "$(printf "$_chk_duplicate_keys_debug_0002" "$table_name" "$key_column")"
                return 0
            fi
            ;;
    esac

    # SQL-Abfrage für Duplikate vorbereiten    
    local sql_query
    if [ -n "$extra_column" ] && _is_column_exists "$extra_column" "$table_name" "$db_file"; then
    # if [ -n "$extra_column" ] && sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$extra_column"; then
        sql_query="SELECT $key_column, $extra_column, COUNT(*) as count FROM $table_name 
                  GROUP BY $key_column, $extra_column HAVING count > 1;"
    else
        sql_query="SELECT $key_column, COUNT(*) as count FROM $table_name 
                  GROUP BY $key_column HAVING count > 1;"
    fi

    # Führe die SQL-Abfrage aus und prüfe auf Duplikate    
    local duplicates=$(sqlite3 "$db_file" "$sql_query")
    
    # Auswertung des Ergebnisses
    if [ -n "$duplicates" ]; then
        debug "$(printf "$_chk_duplicate_keys_debug_0003" "$table_name" "$duplicates")"
        return 1
    else
        debug "$(printf "$_chk_duplicate_keys_debug_0004" "$table_name")"
        return 0
    fi
}

# _chk_invalid_key_chars
_chk_invalid_key_chars_debug_0001="INFO: Prüfe auf ungültige Zeichen in Schlüsselnamen in Tabelle '%s'."
_chk_invalid_key_chars_debug_0002="INFO: Tabelle '%s' hat keine '%s'-Spalte, Zeichenprüfung wird übersprungen."
_chk_invalid_key_chars_debug_0003="ERROR: Ungültige Zeichen in Schlüsselnamen in Tabelle '%s' gefunden: %s"
_chk_invalid_key_chars_debug_0004="INFO: Keine ungültigen Zeichen in Schlüsselnamen in Tabelle '%s' gefunden."

_chk_invalid_key_chars() {
    # -----------------------------------------------------------------------
    # _chk_invalid_key_chars
    # -----------------------------------------------------------------------
    # Funktion.: Prüft eine Tabelle auf ungültige Zeichen in Schlüsselnamen
    # Parameter: $1 - Name der zu prüfenden Tabelle
    # .........  $2 - Pfad zur Datenbankdatei
    # Rückgabe.: 0 - Keine ungültigen Zeichen gefunden
    # .........  1 - Ungültige Zeichen gefunden
    # -----------------------------------------------------------------------
    local table_name="$1"                     # Name der zu prüfenden Tabelle
    local db_file="$2"                        # Pfad zur Datenbankdatei
    local key_column="key"                    # Standard-Spalte für Schlüssel
    local allowed_pattern="[a-zA-Z0-9._-]"    # Erlaubte Zeichen im Schlüssel
    
    # Überprüfen, ob der Tabellenname und der Datenbankpfad angegeben sind
    if ! check_param "$table_name" "table_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_chk_invalid_key_chars_debug_0001" "$table_name")"

    # Prüfen, ob die Tabelle die benötigte Schlüsselspalte hat
    if ! _is_column_exists "$key_column" "$table_name" "$db_file"; then
    # if ! sqlite3 "$db_file" "PRAGMA table_info($table_name);" | grep -q "$key_column"; then
        debug "$(printf "$_chk_invalid_key_chars_debug_0002" "$table_name" "$key_column")"
        return 0
    fi

    # SQL-Abfrage für ungültige Schlüsselzeichen vorbereiten
    local invalid_keys=$(sqlite3 "$db_file" "SELECT $key_column FROM $table_name 
                                           WHERE $key_column GLOB '*[^$allowed_pattern]*';")
    
    # Auswertung des Ergebnisses
    if [ -n "$invalid_keys" ]; then
        debug "$(printf "$_chk_invalid_key_chars_debug_0003" "$table_name" "$invalid_keys")"
        return 1
    else
        debug "$(printf "$_chk_invalid_key_chars_debug_0004" "$table_name")"
        return 0
    fi
}

# _validate_table
_validate_table_debug_0001="INFO: Validiere Tabelle '%s' mit %d Prüfungen."
_validate_table_debug_0002="ERROR: Tabelle '%s' existiert nicht in der Datenbank."
_validate_table_debug_0003="SUCCESS: Tabelle '%s' hat alle Validierungsprüfungen bestanden."
_validate_table_debug_0004="ERROR: Tabelle '%s' hat %d Validierungsprüfungen nicht bestanden."

_validate_table() {
    # -----------------------------------------------------------------------
    # _validate_table
    # -----------------------------------------------------------------------
    # Funktion.: Führt verschiedene Validierungsprüfungen für eine Tabelle
    # .........  durch, sie ist die Zentrale Validierungsfunktion für eine
    # .........  beliebige Tabellen
    # Parameter: $1 - Name der zu validierenden Tabelle
    # .........  $2 - Liste von Validierungsprüfungen, 
    # .........       die durchgeführt werden sollen
    # Rückgabe.: 0 - Validierung erfolgreich
    # .........  1 - Validierung fehlgeschlagen
    # -----------------------------------------------------------------------
    local table_name="$1"
    shift  # Entferne den ersten Parameter, übrig bleiben die Validierungsprüfungen
    
    # Prüfen, ob Tabellenname angegeben wurde
    if ! check_param "$table_name" "table_name"; then return 1; fi
    
    # Debug-Ausgabe eröffnen
    debug "$(printf "$_validate_table_debug_0001" "$table_name" "$#")"

    local db_file=$(get_data_file)
    local validation_errors=0
    
    # Prüfen, ob die Tabelle überhaupt existiert
    if ! sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table_name';" | grep -q "$table_name"; then
        debug "$_validate_table_debug_0002" "$table_name"
        return 1
    fi
    
    # Durchführen aller übergebenen Validierungsprüfungen
    for validation in "$@"; do
        # Prüfung durchführen und Fehler zählen
        if ! "$validation" "$table_name" "$db_file"; then
            validation_errors=$((validation_errors + 1))
        fi
    done
    
    # Rückgabe je nach Validierungsergebnis
    if [ $validation_errors -eq 0 ]; then
        debug "$(printf "$_validate_table_debug_0003" "$table_name")"
        return 0
    else
        debug "$(printf "$_validate_table_debug_0004" "$table_name" "$validation_errors")"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Hilfsfunktionen zu Datenbank-Tabellen-Struktur
# ---------------------------------------------------------------------------

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

# _validate_table_config_hierarchies
_validate_table_config_hierarchies_debug_0001="INFO: Validiere die Integrität der 'config_hierarchies'-Tabelle."

_validate_table_config_hierarchies() {
    debug "$_validate_table_config_hierarchies_debug_0001"

    _validate_table "config_hierarchies" \
        _chk_empty_values \
        _chk_duplicate_keys
        
    return $?
}

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

# _validate_table_settings
_validate_table_settings_debug_0001="INFO: Validiere die Integrität der 'settings'-Tabelle."

_validate_table_settings() {
    # -----------------------------------------------------------------------
    # _validate_table_settings
    # -----------------------------------------------------------------------
    # Funktion.: Überprüft die Integrität und Konsistenz der 'settings'-Tabelle
    # Parameter: keine
    # Rückgabe.: 0 - Validierung erfolgreich (Tabelle ist konsistent)
    # .........  1 - Validierung fehlgeschlagen (Probleme gefunden)
    # -----------------------------------------------------------------------
    debug "$_validate_table_settings_debug_0001"

    # Aufruf der generischen Validierungsfunktion mit den spezifischen Prüfungen für settings
    _validate_table "settings" \
        _chk_invalid_types \
        _chk_empty_values \
        _chk_inactive_settings \
        _chk_foreign_key_integrity \
        _chk_duplicate_keys \
        _chk_invalid_key_chars
        
    return $?
}

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

# _validate_table_settings_history
_validate_table_settings_history_debug_0001="INFO: Validiere die Integrität der 'settings_history'-Tabelle."

_validate_table_settings_history() {
    # -----------------------------------------------------------------------
    # _validate_table_settings_history
    # -----------------------------------------------------------------------
    # Funktion.: Überprüft die Integrität und Konsistenz der 'settings_history'-Tabelle
    # Parameter: keine
    # Rückgabe.: 0 - Validierung erfolgreich (Tabelle ist konsistent)
    # .........  1 - Validierung fehlgeschlagen (Probleme gefunden)
    # -----------------------------------------------------------------------
    debug "$_validate_table_settings_history_debug_0001"

    # Aufruf der generischen Validierungsfunktion mit den spezifischen Prüfungen für settings_history
    _validate_table "settings_history" \
        _chk_invalid_types \
        _chk_empty_values \
        _chk_foreign_key_integrity \
        _chk_duplicate_keys
        
    return $?
}

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

# ensure_database
ensure_database_debug_0001="INFO: Sicherstellen, dass die Datenbank initialisiert ist."
ensure_database_debug_0002="SUCCESS: Datenbank ist initialisiert und bereit zur Nutzung."
ensure_database_debug_0003="WARN: SQLite ist nicht installiert. Datenbank-Initialisierung wurde übersprungen."
ensure_database_debug_0004="ERROR: Datenbank-Initialisierung fehlgeschlagen."
ensure_database_debug_0005="ERROR: Tabelle 'schema_versions' konnte nicht erstellt werden."
ensure_database_debug_0006="ERROR: Tabelle 'settings_change_groups' konnte nicht erstellt werden."
ensure_database_debug_0007="ERROR: Tabelle 'config_hierarchies' konnte nicht erstellt werden."
ensure_database_debug_0008="ERROR: Tabelle 'settings' konnte nicht erstellt werden."
ensure_database_debug_0009="ERROR: Tabelle 'settings_history' konnte nicht erstellt werden."
ensure_database_debug_0010="ERROR: Tabelle 'setting_dependencies' konnte nicht erstellt werden."
ensure_database_debug_0011="ERROR: Tabelle 'change_groups' konnte nicht erstellt werden."
ensure_database_debug_0012="ERROR: Tabelle 'settings_change_groups' konnte nicht erstellt werden."

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

        # Alle Tabellen erfolgreich erstellt, Datenbank ist bereit
        debug "$ensure_database_debug_0002"
        return 0
    else
        # SQLite ist nicht installiert, Datenbank-Initialisierung wurde übersprungen
        debug "$ensure_database_debug_0003"
        return 1
    fi    
}   

# validate_database
validate_database_debug_0001="INFO: Starte Datenbankvalidierung..."
validate_database_debug_0002="SUCCESS: Datenbankvalidierung abgeschlossen, keine Fehler gefunden."
validate_database_debug_0003="ERROR: Datenbankvalidierung abgeschlossen, %d Fehler gefunden."

validate_database() {
    # -----------------------------------------------------------------------
    # validate_database
    # -----------------------------------------------------------------------
    # Funktion.: Stellt sicher, dass alle Tabellen in der SQLite-Datenbank 
    # .........  konsistent sind und die Datenbank keine Fehler aufweist.
    # Parameter: keine
    # Rückgabe.: 0 - Erfolg
    # .........  1 - Fehler
    # -----------------------------------------------------------------------
    local validation_errors=0

    # Debug-Ausgabe eröffnen
    debug "$validate_database_debug_0001"

    # Alle Tabellen validieren
    _validate_table_settings || validation_errors=$((validation_errors + 1))
    _validate_table_config_hierarchies || validation_errors=$((validation_errors + 1))
    _validate_table_settings_history || validation_errors=$((validation_errors + 1))

    if [ $validation_errors -eq 0 ]; then
        debug "$validate_database_debug_0002"
        return 0
    else
        debug "$validate_database_debug_0003" "$validation_errors"
        return 1
    fi
}

# setup_database
setup_database_debug_0001="INFO: Starte Datenbank-Setup..."
setup_database_debug_0002="INFO: Starte Installation Datenbank ..."
setup_database_debug_0003="ERROR: Datenbank-Installation fehlgeschlagen."
setup_database_debug_0004="SUCCESS: Datenbank-Installation erfolgreich abgeschlossen."

setup_database_txt_0001="[/] Installiere Datenbank ..."
setup_database_txt_0002="Datenbank-Installation fehlgeschlagen."
setup_database_txt_0003="Datenbank-Installation erfolgreich abgeschlossen."

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
