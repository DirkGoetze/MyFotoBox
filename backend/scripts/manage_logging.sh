#!/bin/bash
# ===========================================================================
# manage_logging.sh
# ===========================================================================
# Funktion: Stellt Logging-Funktionalität für alle Fotobox-Skripte bereit.
# ......... Logdateien werden im Projektordner /opt/fotobox/log/ abgelegt 
# ......... Optional kann ein Symlink /var/log/fotobox → /opt/fotobox/log/
# ......... angelegt werden, damit Logs auch systemweit sichtbar sind.
# ......... 
# ---------------------------------------------------------------------------
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

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_LOGGING_LOADED=0
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
DEBUG_MOD_LOCAL=1            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

chk_log_file() {
    # -----------------------------------------------------------------------
    # chk_log_file
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob Logdateien zur Rotation vorhanden sind und führt
    #           ggf. Rotation und Komprimierung durch. Legt Logfile neu an,
    #           falls es fehlt oder durch Rotation verschoben wurde.
    local LOG_FILE
    LOG_FILE="$("$manage_files_sh" get_log_file)"
    local MAX_ROTATE=5

    echo "Prüfe Logdatei: ${LOG_FILE}"

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
    
    # Durch den Aufruf von get_log_file/get_log_dir wurde bereits sichergestellt,
    # sichergestellt, dass das Log-Verzeichnis existiert oder ein Fallback verwendet 
    # wird. Wir aktualisieren LOG_FILE über get_log_file, um sicherzustellen, dass
    # wir den aktuellen Pfad verwenden, falls get_log_dir eine Änderung vorgenommen 
    # hat.
    LOG_FILE="$(get_log_file)"
    
    # Sicherstellen, dass das Logfile existiert
    if [ ! -f "${LOG_FILE}" ]; then
        touch "${LOG_FILE}" 2>/dev/null || echo "Warnung: Log-Datei ${LOG_FILE} konnte nicht erstellt werden" >&2
    fi
    # Nur wenn die Datei existiert und schreibbar ist, schreiben wir etwas hinein
    if [ -f "${LOG_FILE}" ] && [ -w "${LOG_FILE}" ]; then
        echo "" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

json_out() {
    # -----------------------------------------------------------------------
    # json_out
    # -----------------------------------------------------------------------
    # Funktion: Hilfsfunktion zur JSON-Ausgabe. Gibt eine JSON-formatierte 
    # ........  Antwort aus
    # Parameter: $1 = Status (success, error, info, prompt)
    #            $2 = Nachricht
    #            $3 = optionaler Fehlercode (optional)
    # Rückgabe:  Gibt JSON-String auf stdout aus
    # Seiteneffekte: keine
    local status="$1"
    local message="$2"
    local code="$3"

    # Prüfen, ob ein Fehlercode übergeben wurde
    if [ -z "$code" ]; then
        echo "{\"status\": \"$status\", \"message\": \"$message\"}"
    else
        echo "{\"status\": \"$status\", \"message\": \"$message\", \"code\": $code}"
    fi
}

# ===========================================================================
# Externe Funktionen zur Log-Verwaltung
# ===========================================================================

log_or_json() {
    # -----------------------------------------------------------------------
    # log_or_json
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Nachricht entweder als JSON (für Web/Python) oder als Log (Shell) aus
    # Parameter: $1 = Modus (text|json)
    #            $2 = Status (success, error, info, prompt)
    #            $3 = Nachricht
    #            $4 = optionaler Fehlercode (optional)
    # Rückgabe:  Gibt Nachricht auf stdout aus (Log oder JSON)
    # Seiteneffekte: ruft log() auf (Logfile-Ausgabe möglich)
    local mode="$1"
    local status="$2"
    local message="$3"
    local code="$4"
    if [ "$mode" = "json" ]; then
        json_out "$status" "$message" "$code"
    else
        log "$message"
    fi
}

log() {
    # -----------------------------------------------------------------------
    # log
    # -----------------------------------------------------------------------
    # Funktion: Schreibt eine Logzeile in die zentrale Logdatei oder führt
    #           Logrotation und Komprimierung durch (über chk_log_file).
    # Aufruf:  log "Nachricht" [Funktionsname] [Dateiname]
    #          log ohne Parameter → prüft/rotiert/komprimiert das Logfile
    # Besonderheiten:
    # - Logdatei: /opt/fotobox/log/YYYY-MM-DD_fotobox.log 
    #  (Fallback: /var/log/fotobox/ oder /tmp/fotobox/)
    # - Rotation und Komprimierung werden von chk_log_file übernommen
    # - Legt Logdatei neu an, falls sie fehlt oder verschoben wurde
    # - Im Fehlerfall MUSS die aufrufende Funktion (Funktionsname) als 
    #   verpflichtender Parameter an log() übergeben werden.
    # - Wenn DEBUG aktiv ist, MUSS im Fehlerfall die Datei (Skript/
    #   Programm), in der der Fehler aufgetreten ist, als verpflichtender 
    #   Parameter an log() übergeben werden.
    local LOG_FILE
    LOG_FILE="$("$MANAGE_FILES_SH" get_log_file)"
    local msg="$1"
    
    if [ -z "$msg" ]; then
        # Auch hier debug-Aufruf entfernen
        # debug "log() ohne Parameter aufgerufen, führe Logrotation durch"
        chk_log_file
    else
        # Prüfen, ob das Log-Verzeichnis existiert und schreibbar ist
        local log_dir
        log_dir="$(dirname "$LOG_FILE")"
        if [ ! -d "$log_dir" ]; then
            echo "Logverzeichnis $log_dir existiert nicht, versuche es zu erstellen" >&2
            mkdir -p "$log_dir" 2>/dev/null || {
                echo "FEHLER: Konnte Logverzeichnis $log_dir nicht erstellen. Verwende /tmp als Fallback." >&2
                LOG_FILE="/tmp/fotobox_$(date '+%Y-%m-%d').log"
            }
        fi

        # Stellen wir sicher, dass die Datei existiert
        if [ ! -f "$LOG_FILE" ]; then
            echo "Logdatei $LOG_FILE existiert nicht, versuche sie zu erstellen" >&2
            touch "$LOG_FILE" 2>/dev/null || {
                echo "FEHLER: Konnte Logdatei $LOG_FILE nicht erstellen. Verwende /tmp als Fallback." >&2
                LOG_FILE="/tmp/fotobox_$(date '+%Y-%m-%d').log"
                touch "$LOG_FILE" 2>/dev/null || {
                    echo "KRITISCHER FEHLER: Kann keine Logdatei erstellen!" >&2
                    return 1
                }
            }
        fi

        # Fehlerfall: Funktionsname und ggf. Dateiname erzwingen
        local func
        local file
        if [[ "$msg" == ERROR:* ]]; then
            if [ -z "$func" ]; then
                func="${FUNCNAME[1]}"
            fi
            if { [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; } && [ -z "$file" ]; then
                file="${BASH_SOURCE[1]}"
            fi
            if [ -n "$file" ]; then
                echo "$(date "+%Y-%m-%d %H:%M:%S") [$func][$file] $msg" >> "$LOG_FILE" 2>/dev/null || {
                    echo "FEHLER: Konnte nicht in Logdatei $LOG_FILE schreiben!" >&2
                    return 1
                }
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S") [$func] $msg" >> "$LOG_FILE" 2>/dev/null || {
                    echo "FEHLER: Konnte nicht in Logdatei $LOG_FILE schreiben!" >&2
                    return 1
                }
            fi
        else
            echo "$(date "+%Y-%m-%d %H:%M:%S") $msg" >> "$LOG_FILE" 2>/dev/null || {
                echo "FEHLER: Konnte nicht in Logdatei $LOG_FILE schreiben!" >&2
                return 1
            }
        fi
    fi
    return 0
}

debug() {
    # -----------------------------------------------------------------------
    # debug
    # -----------------------------------------------------------------------
    # Funktion: Gibt Debug-Ausgaben je nach Modus aus (LOG, CLI, JSON)
    # Debug ist aktiv, wenn DEBUG_MOD_GLOBAL=1 oder DEBUG_MOD_LOCAL=1
    # Parameter: $1 = Nachricht, 
    # .........  $2 = optional: Modus (CLI|JSON|LOG), 
    # .........  $3 = optional: Funktionsname
    if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
        local msg="$1"
        local mode="${2:-CLI}"
        local func="${3:-${FUNCNAME[1]}}"
        case "$mode" in
            CLI)
                print_debug "[$func] $msg"
                ;;
            JSON)
                echo "{\"debug\":true, \"function\":\"$func\", \"message\":\"$msg\"}"
                ;;
        esac
    fi
}

# ===========================================================================
# Externe Funktionen zur Ausgabe von Meldungen
# ===========================================================================

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
    # Funktion: Gibt eine Nutzeraufforderung in Blau aus und kann Benutzereingaben verarbeiten
    # Parameter: 
    # $1 = Text für die Benutzerabfrage
    # $2 = (optional) Prompt-Typ:
    #      "yn" = Ja/Nein-Abfrage, gibt 0 für Ja und 1 für Nein zurück
    #      "text" = Texteingabe, gibt eingegebenen Text zurück
    #      Standardwert: Nur Anzeige ohne Eingabe
    # $3 = (optional) Default-Wert für Ja/Nein-Abfragen:
    #      "y" = Default ist Ja
    #      "n" = Default ist Nein (Standard)
    
    local prompt_type="${2:-}"
    local default="${3:-n}"
    local prompt_text="$1"
    local prompt_suffix=""
    local answer=""
    
    # Wenn unattended-Modus aktiv ist, keine interaktive Abfrage
    if [ "$UNATTENDED" -eq 1 ]; then
        # Bei Ja/Nein-Abfragen im unattended-Modus immer Nein zurückgeben
        if [ "$prompt_type" = "yn" ]; then
            return 1
        fi
        return 0
    fi
    
    # Prompt-Suffix je nach Typ anpassen
    if [ "$prompt_type" = "yn" ]; then
        if [ "$default" = "y" ]; then
            prompt_suffix=" [J/n]"
        else
            prompt_suffix=" [j/N]"
        fi
    fi
    
    # Prompt ausgeben
    echo -e "${COLOR_BLUE}${prompt_text}${prompt_suffix}${COLOR_RESET}"
    
    # Bei Bedarf Benutzereingabe abfragen
    if [ -n "$prompt_type" ]; then
        read -r answer
        
        # Ja/Nein-Abfrage auswerten
        if [ "$prompt_type" = "yn" ]; then
            log "PROMPT-YN: $prompt_text => $answer"
            if [ -z "$answer" ]; then
                # Leere Eingabe: Default-Wert verwenden
                [ "$default" = "y" ] && return 0 || return 1
            else
                # Eingabe auf J/j/Y/y prüfen
                [[ "$answer" =~ ^([jJ]|[yY])$ ]]
                return $?
            fi
        elif [ "$prompt_type" = "text" ]; then
            log "PROMPT-TEXT: $prompt_text => $answer"
            # Text zurückgeben (wenn mit eval aufgerufen)
            echo "$answer"
        fi
    else
        log "PROMPT: $prompt_text"
    fi
}

print_debug() {
    # -----------------------------------------------------------------------
    # print_debug
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Debug-Ausgabe in Cyan aus (nur, wenn DEBUG aktiv)
    # Parameter: $* = Debugtext
    if [ "${DEBUG_MOD_GLOBAL:-0}" = "1" ] || [ "${DEBUG_MOD_LOCAL:-0}" = "1" ] || [ "${DEBUG_MOD:-0}" = "1" ]; then
        local content="$*"
        local debug_prefix="${COLOR_CYAN}  → [DEBUG]${COLOR_RESET}"
        
        # Prüfen, ob die Nachricht bereits Debug-Ausgaben enthält
        if [[ "$content" == *"→ [DEBUG]"* ]]; then
            # Die Nachricht enthält bereits Debug-Ausgaben
            # Wir teilen sie in Zeilen auf und verarbeiten jede separat
            
            # Erster Teil: Extrahiere die normale Nachricht (wenn vorhanden)
            local prefix_part=""
            local debug_part=""
            local result_part=""
            
            # Teile die Nachricht in Zeilen
            IFS=$'\n' read -d '' -ra lines <<< "$content"
            
            # Verarbeite jede Zeile
            for line in "${lines[@]}"; do
                if [[ "$line" == *"→ [DEBUG]"* ]]; then
                    # Dies ist eine eingebettete Debug-Zeile, direkt ausgeben
                    echo -e "$line"
                else
                    # Dies ist eine normale Ausgabezeile
                    if [ -n "$line" ]; then
                        # Normales Ergebnis am Ende der Debug-Ausgaben
                        result_part="$line"
                    fi
                fi
            done
            
            # Gib das finale Ergebnis aus, wenn es existiert
            if [ -n "$result_part" ]; then
                echo -e "$debug_prefix $result_part"
            fi
        else
            # Normale Debug-Ausgabe ohne verschachtelte Debug-Meldungen
            echo -e "$debug_prefix $content"
        fi
    fi
}
