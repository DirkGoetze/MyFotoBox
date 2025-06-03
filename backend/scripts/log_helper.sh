#!/bin/bash
# ------------------------------------------------------------------------------
# log_helper.sh
# ------------------------------------------------------------------------------
# Funktion: Stellt Logging-Funktionalität für alle Fotobox-Skripte bereit.
# Logdateien werden im Projektordner /opt/fotobox/log/ abgelegt (empfohlen).
# Optional kann ein Symlink /var/log/fotobox → /opt/fotobox/log/ angelegt werden,
# damit Logs auch systemweit sichtbar sind.
# ------------------------------------------------------------------------------

get_log_path() {
    # --------------------------------------------------------------------------
    # get_log_path
    # --------------------------------------------------------------------------
    # Funktion: Gibt den Pfad zum Log-Verzeichnis zurück (inkl. Fallback-Logik)
    #           Erstellt das Verzeichnis falls nötig und legt ggf. Symlink an.
    local logdir="/opt/fotobox/log"
    if [ -d "$logdir" ]; then
        # Symlink nach /var/log/fotobox anlegen, falls root und möglich
        if [ "$(id -u)" = "0" ] && [ -w "/var/log" ]; then
            ln -sf "$logdir" /var/log/fotobox
        fi
        echo "$logdir"
        return
    fi
    if [ -w "/var/log" ]; then
        logdir="/var/log/fotobox"
    elif [ -w "/tmp" ]; then
        logdir="/tmp/fotobox"
    else
        logdir="."
    fi
    mkdir -p "$logdir"
    echo "$logdir"
}

get_log_file() {
    # --------------------------------------------------------------------------
    # get_log_file
    # --------------------------------------------------------------------------
    # Funktion: Gibt den vollständigen Pfad zur aktuellen Logdatei zurück
    local logdir
    logdir="$(get_log_path)"
    echo "${logdir}/$(date '+%Y-%m-%d')_fotobox.log"
}

chk_log_file() {
    # -----------------------------------------------------------------------
    # chk_log_file
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob Logdateien zur Rotation vorhanden sind und führt
    #           ggf. Rotation und Komprimierung durch. Legt Logfile neu an,
    #           falls es fehlt oder durch Rotation verschoben wurde.
    local LOG_FILE
    LOG_FILE="$(get_log_file)"
    local MAX_ROTATE=5
    # Alte, maximal rotierte Datei löschen
    if [ -f "${LOG_FILE}.${MAX_ROTATE}.gz" ]; then
        rm -f "${LOG_FILE}.${MAX_ROTATE}.gz"
    fi
    # Bestehende rotierte Dateien weiterschieben
    for ((i=MAX_ROTATE-1; i>=2; i--)); do
        if [ -f "${LOG_FILE}.${i}.gz" ]; then
            mv "${LOG_FILE}.${i}.gz" "${LOG_FILE}.$((i+1)).gz"
        fi
    done
    # 1. Rotation komprimieren
    if [ -f "${LOG_FILE}.1" ]; then
        gzip -c "${LOG_FILE}.1" > "${LOG_FILE}.2.gz"
        rm -f "${LOG_FILE}.1"
    fi
    # Aktuelles Logfile rotieren
    if [ -f "${LOG_FILE}" ]; then
        mv "${LOG_FILE}" "${LOG_FILE}.1"
    fi
    # Sicherstellen, dass das Logfile existiert
    if [ ! -f "${LOG_FILE}" ]; then
        touch "${LOG_FILE}" || return 1
    fi
    echo "" >> "${LOG_FILE}"
}

log() {
    # -----------------------------------------------------------------------
    # log
    # -----------------------------------------------------------------------
    # Funktion: Schreibt eine Logzeile in die zentrale Logdatei oder führt
    #           Logrotation und Komprimierung durch (über chk_log_file).
    # Aufruf:  log "Nachricht"   → schreibt Zeitstempel und Nachricht ins Log
    #          log               → prüft/rotiert/komprimiert das Logfile
    # Besonderheiten:
    # - Logdatei: /opt/fotobox/log/YYYY-MM-DD_fotobox.log 
    #  (Fallback: /var/log/fotobox/ oder /tmp/fotobox/)
    # - Rotation und Komprimierung werden von chk_log_file übernommen
    # - Legt Logdatei neu an, falls sie fehlt oder verschoben wurde
    local LOG_FILE
    LOG_FILE="$(get_log_file)"
    if [ -z "$1" ]; then
        chk_log_file
    else
        if [ ! -f "$LOG_FILE" ]; then
            touch "$LOG_FILE" || return 1
        fi
        echo "$(date "+%Y-%m-%d %H:%M:%S") $1" >> "$LOG_FILE"
    fi
}

print_step() {
    # -----------------------------------------------------------------------
    # print_step
    # -----------------------------------------------------------------------
    # Funktion: Gibt einen Hinweis auf einen auszuführenden Schritt in Gelb aus
    echo -e "\033[1;33m$1\033[0m"
    log "STEP: $1"
}

print_error() {
    # -----------------------------------------------------------------------
    # print_error
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Fehlermeldung farbig aus
    echo -e "\033[1;31m  → Fehler: $1\033[0m"
    log "ERROR: $1"
}

print_success() {
    # -----------------------------------------------------------------------
    # print_success
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Erfolgsmeldung in Dunkelgrün aus
    echo -e "\033[1;32m  → $1\033[0m"
    log "SUCCESS: $1"
}

print_prompt() {
    # -----------------------------------------------------------------------
    # print_prompt
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Nutzeraufforderung in Blau aus (nur, wenn nicht unattended)
    if [ "$UNATTENDED" -eq 0 ]; then
        echo -e "\033[1;34m$1\033[0m"
    fi
    log "PROMPT: $1"
}

