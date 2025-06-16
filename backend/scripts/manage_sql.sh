#!/bin/bash
# ------------------------------------------------------------------------------
# manage_sql.sh
# ------------------------------------------------------------------------------
# Funktion: Verwaltung und Initialisierung der SQLite-Datenbank für die Fotobox
# ------------------------------------------------------------------------------

# ===============================================================================
# TODO-Liste für manage_sql.sh wurde gemäß Policy ausgelagert.
# Siehe: .manage_sql.todo
# ===============================================================================

# ... Skript-Logik folgt ...

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_SQL_LOADED=0

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ -f "$BASH_DIR/lib_core.sh" ]; then
    source "$BASH_DIR/lib_core.sh"
    load_core_resources || {
        echo "Fehler beim Laden der Kernressourcen."
        exit 1
    }
else
    echo "Fehler: Zentrale Bibliothek lib_core.sh nicht gefunden!"
    exit 1
fi
# ===========================================================================

# Konfigurationsvariablen aus lib_core.sh werden verwendet
# Debug-Modus für dieses Skript (lokales Flag)
DEBUG_MOD_LOCAL=0  # Nur für dieses Skript
