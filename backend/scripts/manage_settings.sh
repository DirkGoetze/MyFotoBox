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

# ===========================================================================
# Funktionen zur Datenbank-Verwaltung
# ===========================================================================

# ===========================================================================
# Prüfungen bei der Datenbank-Initialisierung
# ===========================================================================
# Prüfung, ob die SQLite-Datenbankdatei existiert und ob die gefundene Datei
# eine gültige SQLite-Datenbank ist. Falls nicht, wird sie neu initialisiert.
# ---------------------------------------------------------------------------
DEBUG_MOD_GLOBAL=1  # Setze globale Debug-Variable, damit Debug-Ausgaben aktiviert sind

if ! _ensure_database_file; then
    debug "ERROR: Datenbank-Initialisierung fehlgeschlagen."
    return 1
fi

DEBUG_MOD_GLOBAL=0  # Löschen globale Debug-Variable, damit Debug-Ausgaben deaktiviert sind
