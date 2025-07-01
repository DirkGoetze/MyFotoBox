#!/bin/bash
# ------------------------------------------------------------------------------
# manage_backend_service.sh
# ------------------------------------------------------------------------------
# Funktion: Installation, Konfiguration und Verwaltung des Fotobox-Backend-Services
# ------------------------------------------------------------------------------
# HINWEIS: Dieses Skript ist Bestandteil der Backend-Logik und darf nur im
# Unterordner 'backend/scripts/' abgelegt werden 
#
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
MANAGE_BACKEND_SERVICE_LOADED=0
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
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt

# ===========================================================================
# Funktionen zur Verwaltung des Backend-Services
# ===========================================================================

install_backend_service() {
    # -----------------------------------------------------------------------
    # install_backend_service
    # -----------------------------------------------------------------------
    # Funktion.: Erstellt im Systemd Konfigurationsordner eine Kopie der im
    # .........  Templateordner vorliegenden Service Datei, ergänzt die 
    # .........  Vorgaben. Im zweiten Schritt wird eine Kopie der systemd
    # .........  Service-Datei in den System-Ordner, aktualisiert den systemd
    # .........  Service und aktiviert den Service.
    # Parameter: keine
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local systemd_file
    local systemd_file_system
    local systemd_file_backup
    local systemd_file_template

    # Eröffnungsmeldung im Debug Modus
    debug "INFO: Installiere Backend-Service ..."

    # Ermitteln des Pfades zur systemd-Service-Datei
    systemd_file="$(get_system_file systemd fotobox-backend 0)"
    if [ $? -ne 0 ] || [ -z "$systemd_file" ]; then
        debug "ERROR: Systemd-Service-Datei konnte nicht ermittelt werden."
        return 1
    fi
    debug "INFO: Verwende systemd-Service-Datei: '$systemd_file'"

    # --- 1. Erstelle Backup falls Service bereits existiert
    if [ -f "$systemd_file" ]; then
        # Ermitteln des Pfades zur systemd-Service-Backup-Datei
        systemd_file_backup="$(get_systemd_backup_dir)/$(basename $systemd_file).bak.$(date +%Y%m%d%H%M%S)"
        debug "INFO: Verwende systemd-Service-Backup-Datei: '$systemd_file_backup'"
        if ! cp "$systemd_file" "$systemd_file_backup"; then
            debug "ERROR: Erstellen des Backups fehlgeschlagen."
            return 1
        fi
        debug "SUCCESS: Backup der bestehenden systemd-Service-Datei erstellt."
    fi

    # --- 2. Kopiere systemd-Service-Template als neue Datei in den Config Ordner
    # Ermitteln des systemd-Service-Templates
    systemd_file_template="$(get_template_file systemd fotobox-backend)"
    if [ $? -ne 0 ] || [ -z "$systemd_file_template" ]; then
        debug "ERROR: Systemd-Service-Template nicht gefunden."
        return 1
    fi
    debug "INFO: Verwende systemd-Service-Template: '$systemd_file_template'"
    # Kopiere das Template in den Config-Ordner
    if ! cp "$systemd_file_template" "$systemd_file"; then
        debug "ERROR: Kopieren des systemd-Service-Templates fehlgeschlagen."
        return 1
    fi
    debug "SUCCESS: Systemd-Service-Template erfolgreich kopiert."

    # --- 3. Einsetzen der Werte in die systemd-Service-Datei
    # Hier können weitere Anpassungen an der Service-Datei vorgenommen werden
    # wie z.B. das Einfügen von Umgebungsvariablen oder Pfaden
    if ! sed -i "s|{{BACKEND_DIR}}|$(get_backend_dir)|g" "$systemd_file"; then
        debug "ERROR: Ersetzen des Backend-Verzeichnisses in der Service-Datei fehlgeschlagen."
        return 1
    fi
    if ! sed -i "s|{{PYTHON_CMD}}|$(get_python_cmd)|g" "$systemd_file"; then
        debug "ERROR: Ersetzen des Python-Kommandos in der Service-Datei fehlgeschlagen."
        return 1
    fi
    debug "SUCCESS: Platzhalter in der systemd-Service-Datei ersetzt."

    # --- 4. Kopiere die systemd-Service-Datei in den systemd-Systemordner
    # Ermitteln des vollen Pfades zur systemd-Service-Datei im Systemordner
    systemd_file_system="$(get_system_file systemd fotobox-backend 1)"
    if [ $? -ne 0 ] || [ -z "$systemd_file_system" ]; then
        debug "ERROR: Systemd-Systemverzeichnis konnte nicht ermittelt werden."
        return 1
    fi
    debug "INFO: Verwende systemd-Systemverzeichnis: '$systemd_file_system'"
    # Kopiere die systemd-Service-Datei in den systemd-Service-Systemordner
    if ! cp "$systemd_file" "$systemd_file_system"; then
        debug "ERROR: Kopieren der Service-Datei in den systemd-Systemordner fehlgeschlagen."
        return 1
    fi
    debug "SUCCESS: Service-Datei erfolgreich in den systemd-Systemordner kopiert."

    # --- 5. Aktualisiere systemd
    # Aktualisiere den systemd-Daemon, damit die Änderungen wirksam werden
    debug "INFO: Aktualisiere systemd..."
    if ! systemctl daemon-reload; then
        debug "WARNING: Aktualisieren des systemd-Daemons fehlgeschlagen."
    else
        debug "SUCCESS: Systemd-Daemon neu geladen."
    fi

    return 0
}

# -----------------------------------------------------------------------
# enable_backend_service
# -----------------------------------------------------------------------
# Funktion: Aktiviert den Backend-Service, damit er beim Systemstart startet
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
enable_backend_service() {
    print_info "Aktiviere Backend-Service..."
    if ! systemctl enable fotobox-backend; then
        print_error "Aktivieren des Backend-Services fehlgeschlagen."
        return 1
    fi
    print_success "Backend-Service aktiviert."
    return 0
}

# -----------------------------------------------------------------------
# disable_backend_service
# -----------------------------------------------------------------------
# Funktion: Deaktiviert den Backend-Service, sodass er nicht mehr beim Systemstart startet
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
disable_backend_service() {
    print_info "Deaktiviere Backend-Service..."
    if ! systemctl disable fotobox-backend; then
        print_error "Deaktivieren des Backend-Services fehlgeschlagen."
        return 1
    fi
    print_success "Backend-Service deaktiviert."
    return 0
}

# -----------------------------------------------------------------------
# start_backend_service
# -----------------------------------------------------------------------
# Funktion: Startet den Backend-Service
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
start_backend_service() {
    print_info "Starte Backend-Service..."
    if ! systemctl start fotobox-backend; then
        print_error "Starten des Backend-Services fehlgeschlagen."
        return 1
    fi
    
    # Überprüfe, ob der Service läuft
    if systemctl is-active --quiet fotobox-backend; then
        print_success "Backend-Service erfolgreich gestartet."
        return 0
    else
        print_warning "Backend-Service konnte nicht gestartet werden oder läuft nicht."
        print_info "Der Status kann mit 'systemctl status fotobox-backend' überprüft werden."
        return 1
    fi
}

# -----------------------------------------------------------------------
# stop_backend_service
# -----------------------------------------------------------------------
# Funktion: Stoppt den Backend-Service
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
stop_backend_service() {
    print_info "Stoppe Backend-Service..."
    if ! systemctl stop fotobox-backend; then
        print_error "Stoppen des Backend-Services fehlgeschlagen."
        return 1
    fi
    print_success "Backend-Service gestoppt."
    return 0
}

# -----------------------------------------------------------------------
# restart_backend_service
# -----------------------------------------------------------------------
# Funktion: Startet den Backend-Service neu
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
restart_backend_service() {
    print_info "Starte Backend-Service neu..."
    if ! systemctl restart fotobox-backend; then
        print_error "Neustart des Backend-Services fehlgeschlagen."
        return 1
    fi
    
    # Überprüfe, ob der Service läuft
    if systemctl is-active --quiet fotobox-backend; then
        print_success "Backend-Service erfolgreich neugestartet."
        return 0
    else
        print_warning "Backend-Service konnte nicht neugestartet werden oder läuft nicht."
        print_info "Der Status kann mit 'systemctl status fotobox-backend' überprüft werden."
        return 1
    fi
}

# -----------------------------------------------------------------------
# get_backend_service_status
# -----------------------------------------------------------------------
# Funktion: Gibt den Status des Backend-Services zurück
# Parameter: keine
# Rückgabe: 0 wenn aktiv, 1 wenn inaktiv, 2 bei Fehler
get_backend_service_status() {
    if systemctl is-active --quiet fotobox-backend; then
        print_success "Backend-Service ist aktiv und läuft."
        return 0
    else
        status=$(systemctl is-active fotobox-backend)
        if [ "$status" = "inactive" ]; then
            print_warning "Backend-Service ist inaktiv (gestoppt)."
            return 1
        else
            print_error "Backend-Service-Status: $status"
            return 2
        fi
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

# -----------------------------------------------------------------------
# setup_backend_service
# -----------------------------------------------------------------------
# Funktion: Führt die komplette Installation des Backend-Services durch
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
setup_backend_service() {
    # Installiere den Service
    install_backend_service || return 1
    
    # Aktiviere den Service
    enable_backend_service || return 1
    
    # Starte den Service
    start_backend_service || return 1

    # Überprüfe den Status des Services
    get_backend_service_status || return 1
    
    return 0
}
