#!/bin/bash
# ------------------------------------------------------------------------------
# manage_backend_service.sh
# ------------------------------------------------------------------------------
# Funktion: Installation, Konfiguration und Verwaltung des Fotobox-Backend-Services
# ------------------------------------------------------------------------------
# HINWEIS: Dieses Skript ist Bestandteil der Backend-Logik und darf nur im
# Unterordner 'backend/scripts/' abgelegt werden 
# ---------------------------------------------------------------------------
# POLICY-HINWEIS: Dieses Skript ist ein reines Funktions-/Modulskript und 
# enthält keine main()-Funktion mehr. Die Nutzung als eigenständiges 
# CLI-Programm ist nicht vorgesehen. Die Policy zur main()-Funktion gilt nur 
# für Hauptskripte.
#
# HINWEIS: Dieses Skript erfordert lib_core.sh und sollte nie direkt aufgerufen werden.
# ---------------------------------------------------------------------------

# ===============================================================================
# TODO-Liste für manage_backend_service.sh wurde gemäß Policy ausgelagert.
# Siehe: .manage_backend_service.todo
# ===============================================================================

# ... Skript-Logik folgt ...

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_BACKEND_SERVICE_LOADED=0

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
# Globale Konstanten die für die Nutzung des Moduls erforderlich sind
# ===========================================================================
# ---------------------------------------------------------------------------
# Einstellungen: Backend Service 
# ---------------------------------------------------------------------------
SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"
SYSTEMD_DST="/etc/systemd/system/fotobox-backend.service"

# Konfigurationsvariablen aus lib_core.sh werden verwendet
# Debug-Modus für dieses Skript (lokales Flag)
DEBUG_MOD_LOCAL=0  # Nur für dieses Skript

# Markiere dieses Modul als geladen
MANAGE_BACKEND_SERVICE_LOADED=1

