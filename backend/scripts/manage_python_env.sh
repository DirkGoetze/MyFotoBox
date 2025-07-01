#!/bin/bash
# ------------------------------------------------------------------------------
# manage_python_env.sh
# ------------------------------------------------------------------------------
# Funktion: Verwaltung, Initialisierung und Update der Python-Umgebung (venv, 
# ......... pip, requirements). 
# ......... 
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
MANAGE_PYTHON_ENV_LOADED=0
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

# ===========================================================================
# Funktionen zur Verwaltung des Python-Environments
# ===========================================================================

# create_python_env
create_python_env_debug_0001="INFO: Erstelle temporäre Datei für Kommandoausgabe im Projektverzeichnis..."
create_python_env_debug_0002="ERROR: Fehler beim Erstellen der temporären Datei für die Kommandoausgabe."
create_python_env_debug_0003="SUCCESS: Temporäre Datei für Kommandoausgabe im Projektverzeichnis: '%s'"
create_python_env_debug_0004="INFO: Ermitteln des Python-Virtual-Environment-Verzeichnisses..."
create_python_env_debug_0005="ERROR: Fehler beim Ermitteln des Python-Virtual-Environment-Verzeichnisses."
create_python_env_debug_0006="SUCCESS: Python-Virtual-Environment-Verzeichnis: '%s'"
create_python_env_debug_0007="INFO: Ermitteln des Python-Virtual-Environment-Verzeichnisses..."
create_python_env_debug_0008="ERROR: Fehler beim Ermitteln des Python-Virtual-Environment-Verzeichnisses."
create_python_env_debug_0009="SUCCESS: Python-Virtual-Environment-Verzeichnis: '%s'"
create_python_env_debug_0010="INFO: Starte die Einrichtung des Python-Virtual-Environment"
create_python_env_debug_0011="ERROR: Virtual-Environment-Erstellung fehlgeschlagen. Konnte venv nicht anlegen! Log-Auszug: %s"
create_python_env_debug_0012="SUCCESS: Python-Virtual-Environment erfolgreich erstellt."

create_python_env_log_0001="ERROR: Fehler beim Erstellen der temporären Datei für die Kommandoausgabe."
create_python_env_log_0002="ERROR: Fehler beim Ermitteln des Python-Virtual-Environment-Verzeichnisses."
create_python_env_log_0003="ERROR: Kein Python-Interpreter gefunden. Bitte installieren Sie Python 3"
create_python_env_log_0004="INFO: Starte die Einrichtung des Python-Virtual-Environment"
create_python_env_log_0005="VENV CREATE AUSGABE: %s"
create_python_env_log_0006="ERROR: Konnte venv nicht anlegen! Log-Auszug: %s"
create_python_env_log_0007="SUCCESS: Python-Virtual-Environment erfolgreich erstellt."

create_python_env() {
    # -----------------------------------------------------------------------
    # set_python_venv
    # -----------------------------------------------------------------------
    # Funktion.: Erstellt ein Python Virtual Environment für das Backend
    # Parameter: Keine
    # Rückgabe.: 0 - bei Erfolg
    # .........  1 - bei Fehler
    # Seiteneffekte: Benötigt Python 3 und venv-Modul, erstellt Verzeichnis
    # -----------------------------------------------------------------------
    local venv_dir
    local venv_output
    local python_cmd
    
    # Temporäre Datei für Kommandoausgabe im Projektverzeichnis
    debug "$create_python_env_debug_0001"
    venv_output="$(get_tmp_file)"
    if [ $? -ne 0 ]; then
        debug "$create_python_env_debug_0002"
        log "$create_python_env_log_0001"
        return 1
    fi
    debug "$(printf "$create_python_env_debug_0003" "$venv_output")"

    # Pfade für Python-Virtual-Environment-Verzeichnis ermitteln
    debug "$create_python_env_debug_0004"
    venv_dir=$(get_venv_dir)
    if [ $? -ne 0 ]; then
        debug "$create_python_env_debug_0005"
        log "$create_python_env_log_0002"
        return 1
    fi
    debug "$(printf "$create_python_env_debug_0006" "$venv_dir")"

    # Ermitteln des Python-Interpreters (python3 oder python)
    debug "$create_python_env_debug_0007"
    python_cmd="$(get_python_cmd)"
    if [ $? -ne 0 ]; then
        debug "$create_python_env_debug_0008"
        log "$create_python_env_log_0003"
        return 1
    fi
    debug "$(printf "$create_python_env_debug_0009" "$python_cmd")"

    # Einrichten der Python-Environment-Umgebung
    debug "$create_python_env_debug_0010"
    log "$create_python_env_log_0004"

    # Führe den Befehl im Hintergrund aus und leite die Ausgabe in die 
    # temporäre Datei um. Verwende den Python-Interpreter, um das Virtual 
    # Environment zu erstellen
    "$python_cmd" -m venv "$venv_dir" &> "$venv_output" &
    local venv_pid=$!
    # Warte auf den Abschluss des Hintergrundprozesses
    wait "$venv_pid"

    # Ausgabe des Hintergrundprozesses in die Logdatei übernehmen
    log "$(printf "$create_python_env_log_0005" "$(cat "$venv_output")")"

    if [ $? -ne 0 ]; then
        debug "$(printf "$create_python_env_debug_0011" "$(tail -n 10 "$venv_output")")"
        log "$(printf "$create_python_env_log_0006" "$(tail -n 10 "$venv_output")")"
        # Lösche temporäre Datei
        rm -f "$venv_output"
        return 1
    fi

    # Erfolgreiche Erstellung des Python-Virtual-Environment
    debug "$create_python_env_debug_0012"
    log "$create_python_env_log_0007"
    # Lösche temporäre Datei
    rm -f "$venv_output"        
    return 0
}

# install_pip
install_pip_debug_0001="INFO: Installiert/aktualisiert den Python-Paketmanager PIP im Python-Virtual-Environment..."
install_pip_debug_0002="ERROR: Fehler beim Erstellen der temporären Datei für die Kommandoausgabe."
install_pip_debug_0003="SUCCESS: Temporäre Datei für Kommandoausgabe im Projektverzeichnis: '%s'"
install_pip_debug_0004="INFO: Ermitteln des Python-Virtual-Environment-Verzeichnisses..."
install_pip_debug_0005="ERROR: Fehler beim Ermitteln des Python-Virtual-Environment-Verzeichnisses."
install_pip_debug_0006="SUCCESS: Python-Virtual-Environment-Verzeichnis: '%s'"
install_pip_debug_0007="INFO: Ermitteln des Python-Paketmanager (PIP)..."
install_pip_debug_0008="ERROR: Kein Python-Paketmanager (PIP) gefunden. Bitte installieren Sie Python-Paketmanager (PIP) für Python 3."
install_pip_debug_0009="SUCCESS: Python-Paketmanager (PIP): '%s'"
install_pip_debug_0010="ERROR: Python-Paketmanager pip-Upgrade fehlgeschlagen! Fehler beim Upgrade von Python-Paketmanager pip. Log-Auszug: %s"
install_pip_debug_0011="SUCCESS: Python-Paketmanager pip erfolgreich aktualisiert."

install_pip_log_0001="ERROR: Fehler beim Erstellen der temporären Datei für die Kommandoausgabe."
install_pip_log_0002="ERROR: Fehler beim Ermitteln des Python-Virtual-Environment-Verzeichnisses."
install_pip_log_0003="ERROR: Python-Paketmanager (PIP) nicht gefunden. Bitte installieren Sie Python-Paketmanager (PIP) für Python 3."
install_pip_log_0004="PIP install AUSGABE: %s"
install_pip_log_0005="ERROR: Fehler beim Upgrade von Python-Paketmanager pip. Log-Auszug: %s"
install_pip_log_0006="SUCCESS: Python-Paketmanager pip erfolgreich aktualisiert."

install_pip() {
    # -----------------------------------------------------------------------
    # install_pip
    # -----------------------------------------------------------------------
    # Funktion.: Installiert/aktualisiert den Python-Paketmanager PIP im  
    # .........  Python Virtual Environment für das Backend
    # Parameter: Keine
    # Rückgabe.: 0 - bei Erfolg
    # .........  1 - bei Fehler
    # Seiteneffekte: Benötigt Python 3 und venv-Modul, erstellt Verzeichnis
    # -----------------------------------------------------------------------
    local pip_output
    local venv_dir
    local pip_cmd

    # Temporäre Datei für Kommandoausgabe im Projektverzeichnis
    debug "$install_pip_debug_0001"
    pip_output="$(get_tmp_file)"
    if [ $? -ne 0 ]; then
        debug "$install_pip_debug_0002"
        log "$install_pip_log_0001"
        return 1
    fi
    debug "$(printf "$install_pip_debug_0003" "$pip_output")"

    # Pfade für Python-Virtual-Environment-Verzeichnis ermitteln
    debug "$install_pip_debug_0004"
    venv_dir=$(get_venv_dir)
    if [ $? -ne 0 ]; then
        debug "$install_pip_debug_0005"
        log "$install_pip_log_0002"
        return 1
    fi
    debug "$(printf "$install_pip_debug_0006" "$venv_dir")"

    # Ermitteln des Python-Paketmanager (PIP)
    debug "$install_pip_debug_0007"
    pip_cmd="$(get_pip_cmd)"
    if [ $? -ne 0 ]; then
        debug "$install_pip_debug_0008"
        log "$install_pip_log_0003"
        return 1
    fi
    debug "$(printf "$install_pip_debug_0009" "$pip_cmd")"

    # Führe den Befehl im Hintergrund aus und leite die Ausgabe in
    # die temporäre Datei um.
    "$pip_cmd" install --upgrade pip &> "$pip_output" &
    local pip_pid=$!
    # Warte auf den Abschluss des Hintergrundprozesses
    wait $pip_pid

    # Ausgabe des Hintergrundprozesses in die Logdatei übernehmen
    log "$(printf "$install_pip_log_0004" "$(cat "$pip_output")")"

    if [ $? -ne 0 ]; then
        debug "$(printf "$install_pip_debug_0010" "$(tail -n 10 "$venv_output")")"
        log "$(printf "$install_pip_log_0005" "$(tail -n 10 "$venv_output")")"
        # Lösche temporäre Datei
        rm -f "$venv_output"
        return 1
    fi

    # Erfolgreiche Erstellung des Python-Virtual-Environment
    debug "$install_pip_debug_0011"
    log "$install_pip_log_0006"
    # Lösche temporäre Datei
    rm -f "$venv_output"        
    return 0
}

# install_python_requirements
install_python_requirements_debug_0001="INFO: Installieren der Python-Virtual-Environment Abhängigkeiten..."
install_python_requirements_debug_0002="ERROR: Fehler beim Erstellen der temporären Datei für die Kommandoausgabe."
install_python_requirements_debug_0003="SUCCESS: Temporäre Datei für Kommandoausgabe im Projektverzeichnis: '%s'"
install_python_requirements_debug_0004="INFO: Ermitteln des Pfads zur Python-Anforderungsdatei..."
install_python_requirements_debug_0005="ERROR: Python-Anforderungsdatei nicht gefunden."
install_python_requirements_debug_0006="SUCCESS: Python-Anforderungsdatei: '%s'"
install_python_requirements_debug_0007="INFO: Ermitteln des Python-Paketmanager (PIP)..."
install_python_requirements_debug_0008="ERROR: Kein Python-Paketmanager (PIP) gefunden. Bitte installieren Sie Python-Paketmanager (PIP) für Python 3."
install_python_requirements_debug_0009="SUCCESS: Python-Paketmanager (PIP): '%s'"
install_python_requirements_debug_0010="Installation der Python-Abhängigkeiten fehlgeschlagen. Konnte Abhängigkeiten nicht installieren! Log-Auszug: %s"
install_python_requirements_debug_0011="SUCCESS: Python-Abhängigkeiten erfolgreich installiert."

install_python_requirements_log_0001="ERROR: Fehler beim Erstellen der temporären Datei für die Kommandoausgabe."
install_python_requirements_log_0002="ERROR: Python-Anforderungsdatei nicht gefunden."
install_python_requirements_log_0003="ERROR: Python-Paketmanager (PIP) nicht gefunden. Bitte installieren Sie Python-Paketmanager (PIP) für Python 3."
install_python_requirements_log_0004="PIP install AUSGABE: %s"
install_python_requirements_log_0005="ERROR: Konnte Abhängigkeiten nicht installieren! Log-Auszug: %s. Log-Auszug: %s"
install_python_requirements_log_0006="SUCCESS: Python-Abhängigkeiten erfolgreich installiert."

install_python_requirements() {
    # -----------------------------------------------------------------------
    # set_python_requirements
    # -----------------------------------------------------------------------
    # Funktion.: Installiert die Python-Abhängigkeiten für das Backend
    # Parameter: Keine
    # Rückgabe.: 0 bei Erfolg
    # .........  1 bei Fehler
    # Seiteneffekte: Benötigt Python 3 und venv-Modul, erstellt Verzeichnis
    # -----------------------------------------------------------------------
    local pip_output
    local requirements_file
    local pip_cmd

    # Temporäre Datei für Kommandoausgabe im Projektverzeichnis
    debug "$install_python_requirements_debug_0001"
    pip_output="$(get_tmp_file)"
    if [ $? -ne 0 ]; then
        debug "$install_python_requirements_debug_0002"
        log "$install_python_requirements_log_0001"
        return 1
    fi
    debug "$(printf "$install_python_requirements_debug_0003" "$pip_output")"

    # Ermitteln des Pfads zur Python-Anforderungsdatei
    debug "$install_python_requirements_debug_0004"
    requirements_file="$(get_requirements_python_file)"
    if [ $? -ne 0 ] || [ -z "$requirements_file" ]; then
        debug "$install_python_requirements_debug_0005"
        log "$install_python_requirements_log_0002"
        return 1
    fi
    debug "$(printf "$install_python_requirements_debug_0006" "$requirements_file")"

    # Ermitteln des Python-Paketmanager (PIP)
    debug "$install_python_requirements_debug_0007"
    pip_cmd="$(get_pip_cmd)"
    if [ $? -ne 0 ]; then
        debug "$install_python_requirements_debug_0008"
        log "$install_python_requirements_log_0003"
        return 1
    fi
    debug "$(printf "$install_python_requirements_debug_0009" "$pip_cmd")"

     # Führe den Befehl im Hintergrund aus und leite die Ausgabe in
    # die temporäre Datei um.
    debug "INFO: Installiere mit '$pip_cmd install -r $requirements_file' die Python-Abhängigkeiten ..."
    "$pip_cmd" install -r "$requirements_file" &> "$pip_output" &
    local pip_pid=$!
    # Warte auf den Abschluss des Hintergrundprozesses
    wait $pip_pid

    # Ausgabe des Hintergrundprozesses in die Logdatei übernehmen
    log "$(printf "$install_python_requirements_log_0004" "$(cat "$pip_output")")"
    
    if [ $? -ne 0 ]; then
        debug "$(printf "$install_python_requirements_debug_0010" "$(tail -n 10 "$pip_output")")"
        log "$(printf "$install_python_requirements_log_0005" "$(tail -n 10 "$pip_output")")"
        # Lösche temporäre Datei
        rm -f "$pip_output"
        return 1
    fi

    debug "$install_python_requirements_debug_0011"
    log "$install_python_requirements_log_0006"
    # Lösche temporäre Datei
    rm -f "$pip_output"
    return 0
}


# setup_python_env

setup_python_env() {
    # -----------------------------------------------------------------------
    # setup_python_env
    # -----------------------------------------------------------------------
    # Funktion: Führt die komplette Installation der Python-Umgebung durch
    # Parameter: $1 - Optional: CLI oder JSON-Ausgabe. Wenn nicht angegeben,
    # .........       wird die Standardausgabe verwendet (CLI-Ausgabe)
    # Rückgabe: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local output_mode="${1:-cli}"  # Standardmäßig CLI-Ausgabe
    local service_pid

    if [ "$output_mode" = "json" ]; then
        # Erstellt ein Python Virtual Environment
        create_python_env || return 1
    else
        # Erstellt ein Python Virtual Environment, Spinner anzeigen
        echo -n "[/] Erstelle Python Virtual Environment ..."
        # Erstellt ein Python Virtual Environment
        create_python_env
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob die Installation erfolgreich war
        if [ $? -ne 0 ]; then
            print_error "Installation des Python Virtual Environment fehlgeschlagen."
            return 1
        fi
        print_success "Python Virtual Environment wurde erfolgreich erstellt."
    fi

    if [ "$output_mode" = "json" ]; then
        # Installiert/aktualisiert den Python-Paketmanager PIP
        install_pip || return 1
    else
        # Installiert/aktualisiert den Python-Paketmanager PIP, Spinner anzeigen
        echo -n "[/] Installiert/aktualisiert den Python-Paketmanager PIP ..."
        # Installiert/aktualisiert den Python-Paketmanager PIP
        install_pip
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob die Installation erfolgreich war
        if [ $? -ne 0 ]; then
            print_error "Installation/Aktualisierung des Python-Paketmanagers PIP fehlgeschlagen."
            return 1
        fi
        print_success "Python-Paketmanager PIP wurde erfolgreich installiert/aktualisiert."
    fi

    if [ "$output_mode" = "json" ]; then
        # Installieren der Python-Abhängigkeiten
        install_python_requirements || return 1
    else
        # Installieren der Python-Abhängigkeiten, Spinner anzeigen
        echo -n "[/] Installiert/aktualisiert die Python-Abhängigkeiten ..."
        # Installiert/aktualisiert die Python-Abhängigkeiten
        DEBUG_MOD_GLOBAL=1
        install_python_requirements
        DEBUG_MOD_GLOBAL=0
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob die Installation erfolgreich war
        if [ $? -ne 0 ]; then
            print_error "Installation/Aktualisierung der Python-Abhängigkeiten fehlgeschlagen."
            return 1
        fi
        print_success "Python-Abhängigkeiten wurden erfolgreich installiert/aktualisiert."
    fi

    # Erfolgreiche Installation der Python-Umgebung
    return 0
}