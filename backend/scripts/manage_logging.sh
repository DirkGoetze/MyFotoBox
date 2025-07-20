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
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
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
    # Parameter: $1 - zu prüfendes Logfile (optional)
    # Rückgabe:  Keine
    # Seiteneffekte: Logdatei wird rotiert und komprimiert,
    #                Logdatei wird neu angelegt, falls sie fehlt
    #                oder verschoben wurde.
    # Besonderheiten:
    # - Logdatei: /opt/fotobox/log/YYYY-MM-DD_fotobox
    #  (Fallback: /var/log/fotobox/ oder /tmp/fotobox/)
    # - Rotation und Komprimierung: max. 5 Rotationen, danach wird die
    #  älteste Rotation gelöscht.
    # -----------------------------------------------------------------------
    local log_file_to_check="$1"
    local MAX_ROTATE=5

    debug "Prüfe Logdatei: ${log_file_to_check}"

    # Alte, maximal rotierte Datei löschen
    if [ -f "${log_file_to_check}.${MAX_ROTATE}.gz" ]; then
        rm -f "${log_file_to_check}.${MAX_ROTATE}.gz"
    fi
    
    # Bestehende rotierte Dateien weiterschieben
    for ((i=MAX_ROTATE-1; i>=2; i--)); do
        if [ -f "${log_file_to_check}.${i}.gz" ]; then
            mv "${log_file_to_check}.${i}.gz" "${log_file_to_check}.$((i+1)).gz"
        fi
    done
    
    # 1. Rotation komprimieren
    if [ -f "${log_file_to_check}.1" ]; then
        gzip -c "${log_file_to_check}.1" > "${log_file_to_check}.2.gz"
        rm -f "${log_file_to_check}.1"
    fi
    
    # Aktuelles Logfile rotieren
    if [ -f "${log_file_to_check}" ]; then
        mv "${log_file_to_check}" "${log_file_to_check}.1"
    fi
        
    # Sicherstellen, dass das Logfile existiert
    if [ ! -f "${log_file_to_check}" ]; then
        touch "${log_file_to_check}" 2>/dev/null || echo "Warnung: Log-Datei ${log_file_to_check} konnte nicht erstellt werden" >&2
    fi
    # Nur wenn die Datei existiert und schreibbar ist, schreiben wir etwas hinein
    if [ -f "${log_file_to_check}" ] && [ -w "${log_file_to_check}" ]; then
        echo "---" >> "${log_file_to_check}" 2>/dev/null || true
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

# log
log_debug_0001="Funktionsaufruf ohne Parameter, führe Log-Rotation aus"
log_debug_0002="%s ([Datei: '%s'][Funktion: '%s'])"
log_debug_0003="FEHLER: Konnte nicht in Logdatei %s schreiben!"

log() {
    # -----------------------------------------------------------------------
    # log
    # -----------------------------------------------------------------------
    # Funktion: Schreibt eine Logzeile in die zentrale Logdatei oder führt
    #           Logrotation und Komprimierung durch (über chk_log_file).
    # Aufruf:  log "Nachricht" [Funktionsname] [Dateiname]
    #          log ohne Parameter → prüft/rotiert/komprimiert das Logfile
    # -----------------------------------------------------------------------
    local msg="${1:-}"
    local log_file=$(get_log_file) #"$LOG_FILENAME"

    # Wenn Debug-Modus aktiv ist, kein Log, sondern nur Debug
    if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
        return 0
    fi
    
    if [ -z "$msg" ]; then
        # Debug Meldung: log() ohne Parameter aufgerufen
        debug "$(printf "$log_debug_0001")"
        # Prüfe und rotiere Logdatei
        chk_log_file "$log_file"
    else
        # Fehlerfall: Funktionsname und ggf. Dateiname erzwingen
        local called_func="${FUNCNAME[1]}"
        local called_file="${BASH_SOURCE[1]}"
        debug "$(printf "$log_debug_0002" "$msg" "$called_file" "$called_func")"
        # Wenn Fehlermeldung, Meldung um aufrufende Datei und Funktion ergänzen
        if [[ "$msg" == ERROR:* ]]; then
            if [ -n "$called_file" ]; then
                echo "$(date "+%Y-%m-%d %H:%M:%S") [$called_file][$called_func] $msg" >> "$log_file" 2>/dev/null || {
                    debug "$(printf "$log_debug_0003" "$log_file")"
                    echo "$(printf "$log_debug_0003" "$log_file")" >&2
                    return 1
                }
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S") [$called_func] $msg" >> "$log_file" 2>/dev/null || {
                    debug "$(printf "$log_debug_0003" "$log_file")"
                    echo "$(printf "$log_debug_0003" "$log_file")" >&2
                    return 1
                }
            fi
        else
            echo "$(date "+%Y-%m-%d %H:%M:%S") $msg" >> "$log_file" 2>/dev/null || {
                debug "$(printf "$log_debug_0003" "$log_file")"
                echo "$(printf "$log_debug_0003" "$log_file")" >&2
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
    local message="$*"
    local message_length=${#message}
    local underline_chars=$(printf "%0.s-" $(seq 1 $message_length))

    echo -e "\r${COLOR_YELLOW}$message${COLOR_RESET}"
    echo -e "\r${COLOR_YELLOW}$underline_chars${COLOR_RESET}"
    log "STEP: $message"
}

print_info() {
    # -----------------------------------------------------------------------
    # print_info
    # -----------------------------------------------------------------------
    # Funktion: Gibt allgemeine Informationen nach Systemstandard aus
    # Parameter: $* = Meldungstext
    echo -e "\r${COLOR_RESET}$*${COLOR_RESET}"
    log "INFO: $*"
}

print_success() {
    # -----------------------------------------------------------------------
    # print_success
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Erfolgsmeldung in Dunkelgrün aus
    # Parameter: $* = Meldungstext
    echo -e "\r${COLOR_GREEN}✅ ${COLOR_RESET} $*"
    log "SUCCESS: $*"
}

print_warning() {
    # -----------------------------------------------------------------------
    # print_warning
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Warnung in gelber Farbe aus 
    # Parameter: $* = Warnungstext
    echo -e "\r${COLOR_YELLOW}⚠️ ${COLOR_RESET} $*"
    log "WARNING: $*"
}

print_error() {
    # -----------------------------------------------------------------------
    # print_error
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Fehlermeldung farbig aus
    # Parameter: $* = Fehlertext
    echo -e "\r${COLOR_RED}❌ ${COLOR_RESET} $*"
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
    if [ "${DEBUG_MOD_GLOBAL:-0}" = "1" ] || [ "${DEBUG_MOD_LOCAL:-0}" = "1" ]; then
        local content="$*"
    
        # Einfacher Fall: Keine verschachtelten Debug-Ausgaben
        if [[ "$content" != *"[DEBUG]"* ]]; then
            # Farbliche Hervorhebung basierend auf Schlüsselwörtern
            if [[ "$content" == *"INFO:"* ]]; then
                # Info-Stil (Standard/Reset-Farbe)
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_GRAY}$content${COLOR_RESET}" >&2
            elif [[ "$content" == *"WARN:"* ]]; then
                # Warnungs-Stil (gelb)
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_YELLOW}$content${COLOR_RESET}" >&2
            elif [[ "$content" == *"SUCCESS:"* ]]; then
                # Erfolgs-Stil (grün)
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_GREEN}$content${COLOR_RESET}" >&2
            elif [[ "$content" == *"ERROR:"* ]]; then
                # Fehler-Stil (rot)
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_RED}$content${COLOR_RESET}" >&2
            else
                # Standard Debug-Ausgabe ohne Farbakzente
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} $content" >&2
            fi
            return 0
        fi
        
        # Komplexer Fall: Debug-Ausgabe enthält bereits Debug-Marker
        
        # 1. Teile den Content in Zeilen auf und speichere in Array
        local IFS=$'\n'
        local lines=($content)
        
        # 2. Extrahiere Präfix aus dem ersten Array-Eintrag
        local prefix=""
        local rest_output=""
        local first_line="${lines[0]}"
        
        # Extraktion des Präfix durch Suche nach "[DEBUG]" (ohne Farb-Escape-Sequenzen)
        # Das funktioniert auch mit Farb-Escape-Sequenzen im String
        if [[ "$first_line" =~ (.*)\[DEBUG\] ]]; then
            # Finde die Position von "[DEBUG]"
            local debug_pos=$(echo "$first_line" | grep -b -o "\[DEBUG\]" | head -1 | cut -d':' -f1)
            
            # Finde den Pfeiloperator vor "[DEBUG]"
            local arrow_pos=$(echo "${first_line:0:$debug_pos}" | grep -b -o "→" | tail -1 | cut -d':' -f1)
            
            if [ -n "$arrow_pos" ]; then
                # Extrahiere den Präfix (alles vor dem Pfeil)
                prefix="${first_line:0:$arrow_pos}"
                
                # Entferne führende und nachfolgende Whitespaces vom Präfix
                prefix=$(echo "$prefix" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                prefix=$(echo "$prefix" | sed $'s/\033\\[[0-9;]*[a-zA-Z]//g')

                # Ersetze die erste Zeile im Array mit nur dem Teil nach dem Präfix
                # Damit wird verhindert, dass der Präfix doppelt erscheint
                local rest_of_line="${first_line:$arrow_pos}"
                rest_of_line="  $(echo "$rest_of_line" | sed $'s/\033\\[[0-9;]*[a-zA-Z]//g')"
                lines[0]="$rest_of_line"
            fi
        fi
        
        # 3. Sammle alle Debug-Zeilen und das verbleibende Ergebnis
        local debug_lines=()
        local result_text=""
        
        # Finde die letzte Zeile ohne Debug-Marker als Ergebnis
        for ((i=${#lines[@]}-1; i>=0; i--)); do
            if [[ "${lines[$i]}" != *"[DEBUG]"* ]]; then
                result_text="${lines[$i]}"
                break
            fi
        done
        
        # Sammle alle Zeilen mit Debug-Marker für separate Ausgabe
        for line in "${lines[@]}"; do
            if [[ "$line" == *"[DEBUG]"* ]]; then
                debug_lines+=("$line")
            fi
        done
        
        # 4. Gib alle Debug-Zeilen direkt aus
        for line in "${debug_lines[@]}"; do
            echo -e "${COLOR_CYAN}  →${COLOR_RESET} $line" >&2
        done
        
        # 5. Gib das Ergebnis mit dem extrahierten Präfix aus, wenn nicht leer
        if [ -n "$result_text" ]; then
            #echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${prefix}${result_text}"
            if [[ "$result_text" == *"INFO:"* ]]; then
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_RESET}${prefix}${result_text}${COLOR_RESET}" >&2
            elif [[ "$result_text" == *"WARN:"* ]]; then
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_YELLOW}${prefix}${result_text}${COLOR_RESET}" >&2
            elif [[ "$result_text" == *"SUCCESS:"* ]]; then
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_GREEN}${prefix}${result_text}${COLOR_RESET}" >&2
            elif [[ "$result_text" == *"ERROR:"* ]]; then
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${COLOR_RED}${prefix}${result_text}${COLOR_RESET}" >&2
            else
                echo -e "${COLOR_CYAN}  → [DEBUG]${COLOR_RESET} ${prefix}${result_text}" >&2
            fi
        fi
    fi
}

# Logdatei global ermitteln und speichern
if [ -z "${LOG_FILENAME+x}" ] || [ -z "$LOG_FILENAME" ]; then
    debug "INFO: Logdatei wird ermittelt um Umstellung auf zentralisierte Logdatei zu ermöglichen"
    LOG_FILENAME="$(get_log_file)"
    export LOG_FILENAME
    debug "INFO: Modul 'manage_logging' geladen, Logdatei ermittelt: $LOG_FILENAME"
    # Log-Rotation anstoßen
    log
    log "Modul 'manage_logging' geladen: $(date '+%Y-%m-%d %H:%M:%S')"
    log "Logdatei: $LOG_FILENAME"
    debug "INFO: Log-Rotation initialisiert für: $LOG_FILENAME"
    #log "Logverzeichnis: $LOG_DIR"
fi
