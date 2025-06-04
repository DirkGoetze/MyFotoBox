#!/bin/bash
# ------------------------------------------------------------------------------
# log_helper.sh
# ------------------------------------------------------------------------------
# Funktion: Stellt Logging-Funktionalität für alle Fotobox-Skripte bereit.
# Logdateien werden im Projektordner /opt/fotobox/log/ abgelegt (empfohlen).
# Optional kann ein Symlink /var/log/fotobox → /opt/fotobox/log/ angelegt werden,
# damit Logs auch systemweit sichtbar sind.
# ------------------------------------------------------------------------------
# HINWEIS: Für Shellskripte gilt zusätzlich:
# - Fehlerausgaben immer in Rot
# - Ausgaben zu auszuführenden Schritten in Gelb
# - Erfolgsmeldungen in Dunkelgrün
# - Aufforderungen zur Nutzeraktion in Blau
# - Alle anderen Ausgaben nach Systemstandard
# Siehe Funktionsbeispiele und DOKUMENTATIONSSTANDARD.md
# ------------------------------------------------------------------------------

# Farbkonstanten für Ausgaben (Shell-ANSI)
COLOR_RESET="\033[0m"
COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_CYAN="\033[1;36m"

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
    # Aufruf:  log "Nachricht" [Funktionsname] [Dateiname]
    #          log               → prüft/rotiert/komprimiert das Logfile
    # Besonderheiten:
    # - Logdatei: /opt/fotobox/log/YYYY-MM-DD_fotobox.log 
    #  (Fallback: /var/log/fotobox/ oder /tmp/fotobox/)
    # - Rotation und Komprimierung werden von chk_log_file übernommen
    # - Legt Logdatei neu an, falls sie fehlt oder verschoben wurde
    # - Im Fehlerfall MUSS die aufrufende Funktion (Funktionsname) als verpflichtender Parameter an log() übergeben werden.
    # - Wenn DEBUG aktiv ist, MUSS im Fehlerfall die Datei (Skript/Programm), in der der Fehler aufgetreten ist, als verpflichtender Parameter an log() übergeben werden.
    local LOG_FILE
    LOG_FILE="$(get_log_file)"
    local msg="$1"
    local func="$2"
    local file="$3"
    if [ -z "$msg" ]; then
        chk_log_file
    else
        if [ ! -f "$LOG_FILE" ]; then
            touch "$LOG_FILE" || return 1
        fi
        # Fehlerfall: Funktionsname und ggf. Dateiname erzwingen
        if [[ "$msg" == ERROR:* ]]; then
            if [ -z "$func" ]; then
                func="${FUNCNAME[1]}"
            fi
            if { [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; } && [ -z "$file" ]; then
                file="${BASH_SOURCE[1]}"
            fi
            if [ -n "$file" ]; then
                echo "$(date "+%Y-%m-%d %H:%M:%S") [$func][$file] $msg" >> "$LOG_FILE"
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S") [$func] $msg" >> "$LOG_FILE"
            fi
        else
            echo "$(date "+%Y-%m-%d %H:%M:%S") $msg" >> "$LOG_FILE"
        fi
    fi
}

print_step() {
    # -----------------------------------------------------------------------
    # print_step
    # -----------------------------------------------------------------------
    # Funktion: Gibt einen Hinweis auf einen auszuführenden Schritt in Gelb aus
    # Parameter: $* = Meldungstext
    echo -e "${COLOR_YELLOW}$*${COLOR_RESET}"
    log "STEP: $*"
}

print_info() {
    # -----------------------------------------------------------------------
    # print_info
    # -----------------------------------------------------------------------
    # Funktion: Gibt allgemeine Informationen nach Systemstandard aus
    # Parameter: $* = Meldungstext
    echo -e "${COLOR_RESET}$*${COLOR_RESET}"
    log "INFO: $*"
}

print_success() {
    # -----------------------------------------------------------------------
    # print_success
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Erfolgsmeldung in Dunkelgrün aus
    # Parameter: $* = Meldungstext
    echo -e "${COLOR_GREEN}  → [OK]${COLOR_RESET} $*"
    log "SUCCESS: $*"
}

print_warning() {
    # -----------------------------------------------------------------------
    # print_warning
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Warnung in gelber Farbe aus 
    # Parameter: $* = Warnungstext
    echo -e "${COLOR_YELLOW}  → [WARN]${COLOR_RESET} $*"
    log "WARNING: $*"
}

print_error() {
    # -----------------------------------------------------------------------
    # print_error
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Fehlermeldung farbig aus
    # Parameter: $* = Fehlertext
    echo -e "${COLOR_RED}  → [ERROR]${COLOR_RESET} $*"
    log "ERROR: $*"
}

print_prompt() {
    # -----------------------------------------------------------------------
    # print_prompt
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Nutzeraufforderung in Blau aus (nur, wenn nicht unattended)
    # Parameter: $* = Eingabeaufforderungstext
    if [ "$UNATTENDED" -eq 0 ]; then
        echo -e "${COLOR_BLUE}$*${COLOR_RESET}"
    fi
    log "PROMPT: $*"
}

print_debug() {
    # -----------------------------------------------------------------------
    # print_debug
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Debug-Ausgabe in Cyan aus (nur, wenn DEBUG aktiv)
    # Parameter: $* = Debugtext
    echo -e "${COLOR_CYAN}  → ${COLOR_RESET}$*"
}

# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Nur Debug für dieses Skript (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL="${DEBUG_MOD_LOCAL:-0}"
DEBUG_MOD_GLOBAL="${DEBUG_MOD_GLOBAL:-0}"

debug() {
    # -----------------------------------------------------------------------
    # debug
    # -----------------------------------------------------------------------
    # Funktion: Gibt Debug-Ausgaben je nach Modus aus (LOG, CLI, JSON)
    # Debug ist aktiv, wenn DEBUG_MOD_GLOBAL=1 oder DEBUG_MOD_LOCAL=1
    # Parameter: $1 = Nachricht, $2 = optional: Modus (CLI|JSON|LOG), $3 = optional: Funktionsname
    if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
        local msg="$1"
        local mode="${2:-LOG}"
        local func="${3:-${FUNCNAME[1]}}"
        case "$mode" in
            CLI)
                print_debug "[$func] $msg"
                ;;
            JSON)
                echo "{\"debug\":true, \"function\":\"$func\", \"message\":\"$msg\"}"
                ;;
            LOG|*)
                log "DEBUG[$func]: $msg"
                ;;
        esac
    fi
}