#!/bin/bash
# ------------------------------------------------------------------------------
# manage_backend_service.sh
# ------------------------------------------------------------------------------
# Funktion: Installation, Konfiguration und Verwaltung des Backend-Services
# .........  für die Fotobox-Anwendung. Dies umfasst das Erstellen, Aktivieren,
# .........  Starten, Stoppen und Überprüfen des Status des systemd-Services.
# .........  Das Skript ermöglicht die einfache Verwaltung des Backend-Services
# .........  und stellt sicher, dass der Service korrekt konfiguriert ist.
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
MANAGE_BACKEND_SERVICE_LOADED=0
# ===========================================================================

# ===========================================================================
# Globale Konstanten die für die Nutzung des Moduls erforderlich sind
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
# ---------------------------------------------------------------------------

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

# ===========================================================================
# Funktionen zur Verwaltung des Backend-Services
# ===========================================================================

# install_backend_service
install_backend_service_debug_0001="INFO: Installiere Backend-Service ..."
install_backend_service_debug_0002="ERROR: Systemd-Service-Datei konnte nicht ermittelt werden."
install_backend_service_debug_0003="INFO: Verwende systemd-Service-Datei: '%s'"
install_backend_service_debug_0004="INFO: Verwende systemd-Service-Backup-Datei: '%s'"
install_backend_service_debug_0005="ERROR: Erstellen des Backups fehlgeschlagen."
install_backend_service_debug_0006="SUCCESS: Backup der bestehenden systemd-Service-Datei erstellt."
install_backend_service_debug_0007="ERROR: Systemd-Service-Template nicht gefunden."
install_backend_service_debug_0008="INFO: Verwende systemd-Service-Template: '%s'"
install_backend_service_debug_0009="INFO: Kopiere systemd-Service-Template nach: '%s'"
install_backend_service_debug_0010="ERROR: Kopieren der systemd-Service-Template-Datei fehlgeschlagen."
install_backend_service_debug_0011="SUCCESS: Systemd-Service-Template erfolgreich kopiert."
install_backend_service_debug_0012="ERROR: Ersetzen des Backend-Verzeichnisses in der Service-Datei fehlgeschlagen."
install_backend_service_debug_0013="ERROR: Ersetzen des Python-Kommandos in der Service-Datei fehlgeschlagen."
install_backend_service_debug_0014="SUCCESS: Platzhalter in der systemd-Service-Datei ersetzt."
install_backend_service_debug_0015="ERROR: Systemd-Systemverzeichnis konnte nicht ermittelt werden."
install_backend_service_debug_0016="INFO: Verwende systemd-Systemverzeichnis: '%s'"
install_backend_service_debug_0017="INFO: Kopiere systemd-Service-Datei in den systemd-Systemordner: '%s'"
install_backend_service_debug_0018="ERROR: Kopieren der systemd-Service-Datei in den systemd-Systemordner fehlgeschlagen."
install_backend_service_debug_0019="SUCCESS: Systemd-Service-Datei erfolgreich in den systemd-Systemordner kopiert."
install_backend_service_debug_0020="INFO: Aktualisiere systemd-Service"
install_backend_service_debug_0021="ERROR: Aktualisieren des systemd-Service fehlgeschlagen."
install_backend_service_debug_0022="SUCCESS: Systemd-Daemon neu geladen."

install_backend_service() {
    # -----------------------------------------------------------------------
    # install_backend_service
    # -----------------------------------------------------------------------
    # Funktion.: Erstellt im systemd Konfigurationsordner des Projekt eine 
    # .........  Kopie der im Templateordner vorliegenden Service Datei,  
    # .........  ergänzt die Vorgaben. Im zweiten Schritt wird eine Kopie der 
    # .........  systemd-Service-Datei in den System-Ordner kopiert, der 
    # .........  Service aktualisiert und wieder aktiviert
    # Parameter: keine
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local systemd_file
    local systemd_file_system
    local systemd_file_backup
    local systemd_file_template

    # Eröffnungsmeldung im Debug Modus
    debug "$install_backend_service_debug_0001"

    # Ermitteln des Pfades zur systemd-Service-Datei
    systemd_file="$(get_system_file systemd fotobox-backend 0)"
    if [ $? -ne 0 ] || [ -z "$systemd_file" ]; then
        debug "$install_backend_service_debug_0002"
        return 1
    fi
    debug "$(printf "$install_backend_service_debug_0003" "$systemd_file")"

    # --- 1. Erstelle Backup falls Service bereits existiert
    if [ -f "$systemd_file" ]; then
        # Ermitteln des Pfades zur systemd-Service-Backup-Datei
        systemd_file_backup="$(get_systemd_backup_dir)/$(basename $systemd_file).bak.$(date +%Y%m%d%H%M%S)"
        debug "$(printf "$install_backend_service_debug_0004" "$systemd_file_backup")"
        if ! cp "$systemd_file" "$systemd_file_backup"; then
            debug "$install_backend_service_debug_0005"
            return 1
        fi
        debug "$install_backend_service_debug_0006"
    fi

    # --- 2. Kopiere systemd-Service-Template als neue Datei in den Config Ordner
    # Ermitteln des systemd-Service-Templates
    systemd_file_template="$(get_template_file systemd fotobox-backend)"
    if [ $? -ne 0 ] || [ -z "$systemd_file_template" ]; then
        debug "$install_backend_service_debug_0007"
        return 1
    fi
    debug "$(printf "$install_backend_service_debug_0008" "$systemd_file_template")"
    # Kopiere das Template in den Config-Ordner
    debug "$(printf "$install_backend_service_debug_0009" "$systemd_file")"
    if ! cp "$systemd_file_template" "$systemd_file"; then
        debug "$install_backend_service_debug_0010"
        return 1
    fi
    debug "$install_backend_service_debug_0011"

    # --- 3. Einsetzen der Werte in die systemd-Service-Datei
    # Hier können weitere Anpassungen an der Service-Datei vorgenommen werden
    # wie z.B. das Einfügen von Umgebungsvariablen oder Pfaden
    if ! sed -i "s|{{BACKEND_DIR}}|$(get_backend_dir)|g" "$systemd_file"; then
        debug "$install_backend_service_debug_0012"
        return 1
    fi
    if ! sed -i "s|{{PYTHON_CMD}}|$(get_python_cmd)|g" "$systemd_file"; then
        debug "$install_backend_service_debug_0013"
        return 1
    fi
    debug "$install_backend_service_debug_0014"

    # --- 4. Kopiere die systemd-Service-Datei in den systemd-Systemordner
    # Ermitteln des vollen Pfades zur systemd-Service-Datei im Systemordner
    systemd_file_system="$(get_system_file systemd fotobox-backend 1)"
    if [ $? -ne 0 ] || [ -z "$systemd_file_system" ]; then
        debug "$install_backend_service_debug_0015"
        return 1
    fi
    debug "$(printf "$install_backend_service_debug_0016" "$systemd_file_system")"
    # Kopiere die systemd-Service-Datei in den systemd-Service-Systemordner
    debug "$(printf "$install_backend_service_debug_0017" "$systemd_file_system")"
    if ! cp "$systemd_file" "$systemd_file_system"; then
        debug "$install_backend_service_debug_0018"
        return 1
    fi
    debug "$install_backend_service_debug_0019"

    # --- 5. Aktualisiere systemd
    # Aktualisiere den systemd-Daemon, damit die Änderungen wirksam werden
    debug "$install_backend_service_debug_0020"
    if ! systemctl daemon-reload; then
        debug "$install_backend_service_debug_0021"
        return 1
    else
        debug "$install_backend_service_debug_0022"
    fi

    return 0
}

# enable_backend_service
enable_backend_service_debug_0001="INFO: Aktiviere Backend-Service..."
enable_backend_service_debug_0002="ERROR: Aktivieren des Backend-Services fehlgeschlagen."
enable_backend_service_debug_0003="SUCCESS: Backend-Service aktiviert."

enable_backend_service() {
    # -----------------------------------------------------------------------
    # enable_backend_service
    # -----------------------------------------------------------------------
    # Funktion.: Aktiviert den Backend-Service, damit er beim Systemstart 
    # .........  automatisch startet
    # Parameter: keine
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    debug "$enable_backend_service_debug_0001"
    
    if ! systemctl enable fotobox-backend; then
        debug "$enable_backend_service_debug_0002"
        return 1
    fi
    
    debug "$enable_backend_service_debug_0003"
    return 0
}

# disable_backend_service
disable_backend_service_debug_0001="INFO: Deaktiviere Backend-Service..."
disable_backend_service_debug_0002="ERROR: Deaktivieren des Backend-Services fehlgeschlagen."
disable_backend_service_debug_0003="SUCCESS: Backend-Service deaktiviert."

disable_backend_service() {
    # -----------------------------------------------------------------------
    # disable_backend_service
    # -----------------------------------------------------------------------
    # Funktion.: Deaktiviert den Backend-Service, sodass er nicht mehr beim 
    # .........  Systemstart startet
    # Parameter: keine
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    debug "$disable_backend_service_debug_0001"
    
    if ! systemctl disable fotobox-backend; then
        debug "$disable_backend_service_debug_0002"
        return 1
    fi
    
    debug "$disable_backend_service_debug_0003"
    return 0
}

# start_backend_service
start_backend_service_debug_0001="INFO: Starte Backend-Service..."
start_backend_service_debug_0002="ERROR: Starten des Backend-Services fehlgeschlagen."
start_backend_service_debug_0003="SUCCESS: Backend-Service erfolgreich gestartet."
start_backend_service_debug_0004="WARNING: Backend-Service konnte nicht gestartet werden oder läuft nicht."
start_backend_service_debug_0005="INFO: Der Status kann mit 'systemctl status fotobox-backend' überprüft werden."

start_backend_service() {
    # -----------------------------------------------------------------------
    # start_backend_service
    # -----------------------------------------------------------------------
    # Funktion.: Startet den Backend-Service
    # Parameter: keine
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    debug "$start_backend_service_debug_0001"
    
    if ! systemctl start fotobox-backend; then
        debug "$start_backend_service_debug_0002"
        return 1
    fi
    
    # Überprüfe, ob der Service läuft
    if systemctl is-active --quiet fotobox-backend; then
        debug "$start_backend_service_debug_0003"
        return 0
    else
        debug "$start_backend_service_debug_0004"
        debug "$start_backend_service_debug_0005"
        return 1
    fi
}

# stop_backend_service
stop_backend_service_debug_0001="INFO: Stoppe Backend-Service..."
stop_backend_service_debug_0002="ERROR: Stoppen des Backend-Services fehlgeschlagen."
stop_backend_service_debug_0003="SUCCESS: Backend-Service gestoppt."

stop_backend_service() {
    # -----------------------------------------------------------------------
    # stop_backend_service
    # -----------------------------------------------------------------------
    # Funktion.: Stoppt den Backend-Service
    # Parameter: keine
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    debug "$stop_backend_service_debug_0001"

    if ! systemctl stop fotobox-backend; then
        debug "$stop_backend_service_debug_0002"
        return 1
    fi
    
    # Überprüfe, ob der Service gestoppt wurde
    if systemctl is-active --quiet fotobox-backend; then
        debug "$stop_backend_service_debug_0002"
        return 1
    fi

    debug "$stop_backend_service_debug_0003"
    return 0
}

# restart_backend_service
restart_backend_service_debug_0001="INFO: Starte Backend-Service neu..."
restart_backend_service_debug_0002="ERROR: Neustart des Backend-Services fehlgeschlagen."
restart_backend_service_debug_0003="SUCCESS: Backend-Service erfolgreich neugestartet."
restart_backend_service_debug_0004="WARNING: Backend-Service konnte nicht neugestartet werden oder läuft nicht."
restart_backend_service_debug_0005="INFO: Der Status kann mit 'systemctl status fotobox-backend' überprüft werden."

restart_backend_service() {
    # -----------------------------------------------------------------------
    # restart_backend_service
    # -----------------------------------------------------------------------
    # Funktion.: Startet den Backend-Service neu
    # Parameter: keine
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    debug "$restart_backend_service_debug_0001"

    if ! systemctl restart fotobox-backend; then
        debug "$restart_backend_service_debug_0002"
        return 1
    fi
    
    # Überprüfe, ob der Service läuft
    if systemctl is-active --quiet fotobox-backend; then
        debug "$restart_backend_service_debug_0003"
        return 0
    else
        debug "$restart_backend_service_debug_0004"
        debug "$restart_backend_service_debug_0005"
        return 1
    fi
}

# get_backend_service_status
get_backend_service_status_debug_0001="INFO: Überprüfe Backend-Service-Status..."
get_backend_service_status_debug_0002="SUCCESS: Backend-Service ist aktiv und läuft."
get_backend_service_status_debug_0003="WARN: Backend-Service ist inaktiv (gestoppt)."
get_backend_service_status_debug_0004="ERROR: Backend-Service-Status: %s"

get_backend_service_status() {
    # -----------------------------------------------------------------------
    # get_backend_service_status
    # -----------------------------------------------------------------------
    # Funktion.: Gibt den Status des Backend-Services zurück
    # Parameter: keine
    # Rückgabe.: 0 wenn aktiv und läuft
    # .........  1 wenn inaktiv
    # .........  2 bei Fehler oder Failed
    # -----------------------------------------------------------------------
    debug "$get_backend_service_status_debug_0001"

    # Prüfe erst den Status
    status=$(systemctl is-active fotobox-backend)
    
    # Prüfe dann die Unit für Fehler
    failed=$(systemctl show -p ActiveState fotobox-backend | cut -d= -f2)

    if [ "$status" = "active" ] && [ "$failed" = "active" ]; then
        # Service läuft wirklich
        debug "$get_backend_service_status_debug_0002"
        return 0
    elif [ "$status" = "inactive" ]; then
        # Service ist gestoppt
        debug "$get_backend_service_status_debug_0003" 
        return 1
    else
        # Service hat Fehler oder unbekannter Status
        debug "$(printf "$get_backend_service_status_debug_0004" "$status ($failed)")"
        return 2
    fi
}

# -----------------------------------------------------------------------
# uninstall_backend_service
# -----------------------------------------------------------------------
# Funktion: Deinstalliert den Backend-Service (stoppt, deaktiviert und entfernt)
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
uninstall_backend_service() {
    # Stoppe den Service zuerst
    print_info "Stoppe Backend-Service vor der Deinstallation..."
    systemctl stop fotobox-backend &>/dev/null
    
    # Deaktiviere den Service
    print_info "Deaktiviere Backend-Service..."
    systemctl disable fotobox-backend &>/dev/null
    
    # Erstelle Backup vor dem Löschen
    local backup="$BACKUP_DIR/fotobox-backend.service.bak.$(date +%Y%m%d%H%M%S)"
    if [ -f "$SYSTEMD_DST" ]; then
        if ! cp "$SYSTEMD_DST" "$backup"; then
            print_warning "Erstellen des Backups fehlgeschlagen. Fahre trotzdem fort."
        else
            print_success "Backup der systemd-Unit nach $backup erstellt."
        fi
        
        # Entferne Service-Datei
        if ! rm -f "$SYSTEMD_DST"; then
            print_error "Entfernen der Service-Datei fehlgeschlagen."
            return 1
        fi
        print_success "Service-Datei erfolgreich entfernt."
    else
        print_info "Keine Service-Datei zum Entfernen gefunden."
    fi
    
    # Lade systemd neu
    print_info "Aktualisiere systemd..."
    if ! systemctl daemon-reload; then
        print_warning "Aktualisieren des systemd-Daemons fehlgeschlagen."
    else
        print_success "Systemd-Daemon neu geladen."
    fi
    
    print_success "Backend-Service erfolgreich deinstalliert."
    return 0
}

setup_backend_service() {
    # -----------------------------------------------------------------------
    # setup_backend_service
    # -----------------------------------------------------------------------
    # Funktion: Führt die komplette Installation des Backend-Services durch
    # Parameter: $1 - Optional: CLI oder JSON-Ausgabe. Wenn nicht angegeben, 
    # .........       wird die Standardausgabe verwendet (CLI-Ausgabe)
    # Rückgabe: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local output_mode="${1:-cli}"  # Standardmäßig CLI-Ausgabe
    local service_pid

    if [ "$output_mode" = "json" ]; then
        # Installiere den Service
        install_backend_service || return 1
    else
        # Ausgabe im CLI-Modus, Spinner anzeigen
        echo -n "[/] Installiere systemd-Backend-Service ..."
        # Installiere den Service
        install_backend_service
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob die Installation erfolgreich war
        if [ $? -ne 0 ]; then
            print_error "Installation des Backend-Services fehlgeschlagen."
            return 1
        fi
        print_success "systemd-Backend-Service wurde erfolgreich installiert."
    fi

    if [ "$output_mode" = "json" ]; then
        # Aktiviere den Service
        enable_backend_service || return 1
    else
        # Ausgabe im CLI-Modus, Spinner anzeigen
        echo -n "[/] Aktiviere systemd-Backend-Service ..."
        # Aktiviere den Service
        enable_backend_service
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob die Aktivierung erfolgreich war
        if [ $? -ne 0 ]; then
            print_error "Aktivierung des systemd-Backend-Services fehlgeschlagen."
            return 1
        fi
        print_success "systemd-Backend-Service Autostart wurde erfolgreich aktiviert."
    fi
    
    if [ "$output_mode" = "json" ]; then
        # Starte den Service
        start_backend_service || return 1
    else
        # Ausgabe im CLI-Modus, Spinner anzeigen
        echo -n "[/] Starte systemd-Backend-Service ..."
        # Starte den Service
        start_backend_service
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob der Service erfolgreich gestartet wurde
        if [ $? -ne 0 ]; then
            print_error "systemd-Backend-Service konnte nicht gestartet werden. Bitte überprüfen Sie die Logs für weitere Details."
            return 1
        fi
        print_success "systemd-Backend-Service wurde erfolgreich gestartet."
    fi

    if [ "$output_mode" = "json" ]; then
        # Überprüfe den Status des Services
        get_backend_service_status || return 1
    else
        # Ausgabe im CLI-Modus, Spinner anzeigen
        echo -n "[/] Prüfe systemd-Backend-Service-Status ..."
        # Überprüfe den Status des Services
        if ! get_backend_service_status; then
            print_error "systemd-Backend-Service läuft nicht. Bitte überprüfen Sie die Logs für weitere Details."
            return 1
        fi
        print_success "systemd-Backend-Service läuft und ist aktiv."
    fi

    return 0
}
