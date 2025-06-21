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

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_BACKEND_SERVICE_LOADED=0

# HINWEIS: SCRIPT_DIR wird zentral in lib_core.sh definiert
# und muss hier nicht mehr gesetzt werden

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ ! -f "$SCRIPT_DIR/lib_core.sh" ]; then
    echo "KRITISCHER FEHLER: Zentrale Bibliothek lib_core.sh nicht gefunden!" >&2
    echo "Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch." >&2
    exit 1
fi

source "$SCRIPT_DIR/lib_core.sh"
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

# ===========================================================================
# Funktionen zur Verwaltung des Backend-Services
# ===========================================================================

# -----------------------------------------------------------------------
# install_backend_service
# -----------------------------------------------------------------------
# Funktion: Kopiert systemd-Service-Datei und aktiviert den Service
# Parameter: keine
# Rückgabe: 0 bei Erfolg, 1 bei Fehler
install_backend_service() {
    local backup="$BACKUP_DIR/fotobox-backend.service.bak.$(date +%Y%m%d%H%M%S)"
    
    # Erstelle Backup falls Service bereits existiert
    if [ -f "$SYSTEMD_DST" ]; then
        if ! cp "$SYSTEMD_DST" "$backup"; then
            print_error "Erstellen des Backups fehlgeschlagen."
            return 1
        fi
        print_success "Backup der bestehenden systemd-Unit nach $backup erstellt."
    fi
    
    # Kopiere Service-Datei
    print_info "Installiere systemd-Service..."
    if ! cp "$SYSTEMD_SERVICE" "$SYSTEMD_DST"; then
        print_error "Kopieren der Service-Datei fehlgeschlagen."
        return 1
    fi
    print_success "Service-Datei erfolgreich kopiert."
    
    # Aktualisiere systemd
    print_info "Aktualisiere systemd..."
    if ! systemctl daemon-reload; then
        print_warning "Aktualisieren des systemd-Daemons fehlgeschlagen."
    else
        print_success "Systemd-Daemon neu geladen."
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
    
    return 0
}

# ===========================================================================
# Abschluss: Markiere dieses Modul als geladen
# ===========================================================================
MANAGE_BACKEND_SERVICE_LOADED=1

