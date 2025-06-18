#!/bin/bash
# ------------------------------------------------------------------------------
# debug_install.sh
# ------------------------------------------------------------------------------
# Funktion: Debug-Version des Installationsskripts mit zusätzlicher Fehlerprotokollierung
# Für Ubuntu/Debian-basierte Systeme, muss als root ausgeführt werden.
# ------------------------------------------------------------------------------

# Pfade für Debug-Ausgaben
DEBUG_LOG_FILE="/tmp/fotobox_install_debug.log"
ERROR_LOG_FILE="/tmp/fotobox_install_errors.log"

# Debug-Funktionen
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DEBUG: $*" | tee -a "$DEBUG_LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $*" | tee -a "$ERROR_LOG_FILE" >&2
}

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $*" | tee -a "$DEBUG_LOG_FILE"
}

# Initialisieren der Debug-Dateien
echo "=== Fotobox Debug-Installation gestartet $(date) ===" > "$DEBUG_LOG_FILE"
echo "=== Fotobox Fehlerprotokoll gestartet $(date) ===" > "$ERROR_LOG_FILE"

# Aktiviere Debugging für das Bash-Skript
set -x

# Exportiere Variablen für das Hauptskript
export DEBUG_MOD_GLOBAL=1

# Pfad zum Original-Installationsskript
INSTALL_SCRIPT="$(dirname "$(readlink -f "$0")")/install.sh"

log_info "Debug-Installation wird mit folgenden Einstellungen gestartet:"
log_info "- DEBUG_MOD_GLOBAL=1"
log_info "- Original-Installationsskript: $INSTALL_SCRIPT"
log_info "- Debug-Protokoll: $DEBUG_LOG_FILE"
log_info "- Fehlerprotokoll: $ERROR_LOG_FILE"

# Führe das Originalskript mit überwachter Ausführung aus
log_info "Starte Installationsskript..."

# Führe das Skript aus und protokolliere Rückgabewert
"$INSTALL_SCRIPT" "$@" 2>&1 | tee -a "$DEBUG_LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}

# Protokolliere das Ergebnis
if [ $EXIT_CODE -eq 0 ]; then
    log_info "Installation erfolgreich abgeschlossen (Exit-Code: $EXIT_CODE)"
else
    log_error "Installation mit Fehler beendet (Exit-Code: $EXIT_CODE)"
    log_error "Bitte prüfen Sie das Debug-Protokoll für Details: $DEBUG_LOG_FILE"
fi

# Deaktiviere Debugging
set +x

echo "=== Fotobox Debug-Installation beendet $(date) ===" >> "$DEBUG_LOG_FILE"
echo "=== Fotobox Fehlerprotokoll beendet $(date) ===" >> "$ERROR_LOG_FILE"

log_info "Zusammenfassung der Protokolle:"
log_info "- Debug-Protokoll: $DEBUG_LOG_FILE"
log_info "- Fehlerprotokoll: $ERROR_LOG_FILE" 

echo "Die Installation wurde abgeschlossen. Protokolle sind verfügbar unter:"
echo "- Debug-Protokoll: $DEBUG_LOG_FILE"
echo "- Fehlerprotokoll: $ERROR_LOG_FILE"

exit $EXIT_CODE
