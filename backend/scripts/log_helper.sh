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

log() {
    # -----------------------------------------------------------------------
    # log
    # -----------------------------------------------------------------------
    # Hilfsfunktion zur Erzeugung eines einfachen Log mit Rotation und Komprimierung
    # Logdatei: /opt/fotobox/log/YYYY-MM-DD_fotobox.log
    # Fallback: /var/log/fotobox/ oder /tmp/fotobox/
    local LOG_FILE
    LOG_FILE="$(get_log_file)"
    local LOG_PATH
    LOG_PATH="$(dirname "$LOG_FILE")"
    local MAX_ROTATE=5
    if [ -z "$1" ]; then
        # Logrotation und Komprimierung
        if [ -f "${LOG_FILE}.${MAX_ROTATE}.gz" ]; then
            rm -f "${LOG_FILE}.${MAX_ROTATE}.gz"
        fi
        for ((i=MAX_ROTATE-1; i>=2; i--)); do
            if [ -f "${LOG_FILE}.${i}.gz" ]; then
                mv "${LOG_FILE}.${i}.gz" "${LOG_FILE}.$((i+1)).gz"
            fi
        done
        if [ -f "${LOG_FILE}.1" ]; then
            gzip -c "${LOG_FILE}.1" > "${LOG_FILE}.2.gz"
            rm -f "${LOG_FILE}.1"
        fi
        if [ -f "${LOG_FILE}" ]; then
            mv "${LOG_FILE}" "${LOG_FILE}.1"
        fi
        if [ ! -f "${LOG_FILE}" ]; then
            touch "${LOG_FILE}" || return 1
        fi
        echo "" >> "${LOG_FILE}"
    else
        if [ ! -f "${LOG_FILE}" ]; then
            touch "${LOG_FILE}" || return 1
        fi
        echo "$(date "+%Y-%m-%d %H:%M:%S") $1" >> "${LOG_FILE}"
    fi
}

