#!/bin/bash
# ---------------------------------------------------------------------------
# manage_nginx.sh
# ---------------------------------------------------------------------------
# Funktion: Installiert, konfiguriert oder aktualisiert den Webserver (NGINX)
# ......... Unterstützt: Installation, Anpassung, Update, Backup, Rollback.
# ......... 
# ......... 
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
MANAGE_NGINX_LOADED=0
# ===========================================================================

# ===========================================================================
# Globale Konstanten (Vorgaben und Defaults für die Installation)
# ===========================================================================
# Die meisten globalen Konstanten werden bereits durch lib_core.sh gesetzt.
# bereitgestellt. Hier definieren wir nur Konstanten, die noch nicht durch 
# lib_core.sh gesetzt wurden oder die speziell für die Installation 
# überschrieben werden müssen.

# ===========================================================================

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
# DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
# : "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt
# Debug-Modus für dieses Skript (lokales Flag)

# Port-Einstellungen für WEB-Server
# ---------------------------------------------------------------------------
DEFAULT_HTTP_PORT=80                     # Standard-Ports für HTTP
DEFAULT_HTTPS_PORT=443                   # Standard-Ports für HTTPS
DEFAULT_HTTP_PORT_FALLBACK=8080          # falls 80/443 nicht verfügbar sind

# Server-Name für NGINX
# ---------------------------------------------------------------------------
DEFAULT_SERVER_NAME="_"                    # Standard-Server-Name für Projekt
DEFAULT_SERVER_NAME_FALLBACK="localhost"   # Standard-Server-Name für NGINX

# Frontend-Verzeichnis für NGINX
# ---------------------------------------------------------------------------
DEFAULT_FRONTEND_DIR="$(get_frontend_dir)"    # Standard-Frontend-Verzeichnis
DEFAULT_FRONTEND_DIR_FALLBACK="/var/www/html" # Fallback-Verzeichnis

# Index-Dateien für NGINX
# ---------------------------------------------------------------------------
DEFAULT_INDEX_FILES=("index.html" "start.html")
DEFAULT_INDEX_FILES_FALLBACK=("index.html" "index.htm" "index.php")

# Standard-API-URL für NGINX
# ---------------------------------------------------------------------------
DEFAULT_API_URL="http://127.0.0.1:5000"          # Standard-API-URL für NGINX
DEFAULT_API_URL_FALLBACK="http://localhost:5000/api"       # Fallback-API-URL

# ===========================================================================

# ===========================================================================
# Interne Hilfsfunktionen
# ===========================================================================

# _is_installed_nginx
_is_installed_nginx_debug_0001="INFO: NGINX-Installation wird geprüft ..."
_is_installed_nginx_debug_0002="ERROR: NGINX ist nicht installiert!"
_is_installed_nginx_debug_0003="WARN: NGINX ist nicht installiert, Installation wird gestartet."
_is_installed_nginx_debug_0004="ERROR: NGINX-Installation fehlgeschlagen!"
_is_installed_nginx_debug_0005="INFO: NGINX-Installation erfolgreich abgeschlossen."
_is_installed_nginx_debug_0006="SUCCESS: NGINX ist installiert."
_is_installed_nginx_log_0001="NGINX nicht installiert!"
_is_installed_nginx_log_0002="NGINX konnte nicht installiert werden!"
_is_installed_nginx_log_0003="NGINX wurde erfolgreich nach installiert."
_is_installed_nginx_log_0004="NGINX ist installiert."

_is_installed_nginx() {
    # -----------------------------------------------------------------------
    # _is_installed_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Prüft, ob NGINX installiert ist und installiert ggf. nach 
    # Parameter: $1 = Installationsentscheidung (j/N), optional (Default: N)
    # Rückgabe.:  0 = OK (Installiert)
    # .........   1 = Fehler (Nicht installiert)
    # .........   2 = Installationsfehler
    # Seiteneffekte: Installiert ggf. nginx über apt-get
    # -----------------------------------------------------------------------
    local install_decision="${1:-N}"
    
    # Prüfung 'Unattended'-Modus' bei Install-Skripten
    if [ "${UNATTENDED:-0}" -eq 1 ]; then install_decision="J"; fi

    # Debug-Meldung eröffnen
    debug "$_is_installed_nginx_debug_0001"

    # Prüfen, ob nginx installiert ist
    if ! command -v nginx >/dev/null 2>&1; then  
        # nicht installiert - Prüfe Freigabe für Installation
        if [[ "$install_decision" =~ ^([nN])$ ]]; then
            debug "$_is_installed_nginx_debug_0002"
            log "$_is_installed_nginx_log_0001" 1
            return 1
        fi

        # Freigabe für Installation - Installation von nginx durchführen 
        # Verwende 'manage_update.py', da das die Abhängigkeiten aus 
        # 'conf/requirements_system.inf' verwendet
        debug "$_is_installed_nginx_debug_0003"
        local backend_dir
        backend_dir="$(get_backend_dir)"
        python3 "$backend_dir/manage_update.py" --install-system-deps

        # Nach der Installation erneut prüfen, ob nginx jetzt verfügbar ist
        if ! command -v nginx >/dev/null 2>&1; then
            debug "$_is_installed_nginx_debug_0004"
            log "$_is_installed_nginx_log_0002"
            return 2
        fi
        debug "$_is_installed_nginx_debug_0005"
        log "$_is_installed_nginx_log_0003"
    fi

    # NGINX ist jetzt installiert
    debug "$_is_installed_nginx_debug_0006"
    log "$_is_installed_nginx_log_0004"
    return 0
}

# _is_running_nginx
_is_running_nginx_debug_0001="INFO: NGINX-Dienst wird geprüft ..."
_is_running_nginx_debug_0002="WARN: NGINX ist nicht installiert!"
_is_running_nginx_debug_0003="ERROR: NGINX-Dienst ist gestoppt! Status: %s"
_is_running_nginx_debug_0004="SUCCESS: NGINX-Dienst ist aktiv."
_is_running_nginx_log_0001="NGINX ist nicht installiert!"
_is_running_nginx_log_0002="NGINX-Dienst ist gestoppt! Status: %s"
_is_running_nginx_log_0003="NGINX-Dienst läuft."

_is_running_nginx() {
    # -----------------------------------------------------------------------
    # _is_running_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Prüft, ob der NGINX-Dienst aktiv läuft
    # Parameter: keine
    # Rückgabe.:  0 = NGINX läuft
    # .........   1 = NGINX gestoppt/Fehler
    # .........   2 = NGINX nicht installiert
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------
    # Debug-Meldung eröffnen
    debug "$_is_running_nginx_debug_0001"

    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    _is_installed_nginx
    if [ $? -ne 0 ]; then
        # NGINX ist nicht installiert
        debug "$_is_running_nginx_debug_0002"
        log "$_is_running_nginx_log_0001"
        return 2
    fi

    # NGINX ist installiert, jetzt Status prüfen
    if ! systemctl is-active --quiet nginx; then
        # NGINX-Dienst ist gestoppt oder hat Fehler
        local status_details
        status_details=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 5)

        # Debug-Ausgabe mit Statusdetails
        debug "$(printf "$_is_running_nginx_debug_0003" "$status_details")"
        log "$(printf "$_is_running_nginx_log_0002" "$status_details")"
        return 1
    fi

    debug "$_is_running_nginx_debug_0004"
    log "$_is_running_nginx_log_0003"
    return 0
}

# _is_default_nginx
_is_default_nginx_debug_0001="INFO: NGINX-Dienst Konfigurationsmodus prüfen ..."
_is_default_nginx_debug_0002="SUCCESS: NGINX-Dienst verwendet Default-Konfiguration."
_is_default_nginx_debug_0003="WARN: NGINX-Dienst verwendet eine angepasste Konfiguration."
_is_default_nginx_debug_0004="ERROR: NGINX-Dienst Konfigurationsstatus unklar."
_is_default_nginx_log_0001="NGINX verwendet Default-Konfiguration."
_is_default_nginx_log_0002="NGINX verwendet angepasste Konfiguration."
_is_default_nginx_log_0003="NGINX-Konfigurationsstatus unklar."

_is_default_nginx() {
    # -----------------------------------------------------------------------
    # _is_default_nginx
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX in der Default-Konfiguration vorliegt oder
    # .........  bereits eine angepasste Konfiguration verwendet wird.
    # Parameter: keine
    # Rückgabe.:  0 = Default-Konfiguration, 
    # .........   1 = angepasste Konfiguration, 
    # .........   2 = Status unklar
    # -----------------------------------------------------------------------
    local enabled_sites
    enabled_sites=$(ls /etc/nginx/sites-enabled 2>/dev/null | wc -l)

    # Debug-Meldung eröffnen
    debug "$_is_default_nginx_debug_0001"

    # Prüfen, ob nur die Default-Site aktiv ist
    if [ "$enabled_sites" -eq 1 ] && [ -f /etc/nginx/sites-enabled/default ]; then
        # Nur Default-Site aktiv
        debug "$_is_default_nginx_debug_0002"
        log "$_is_default_nginx_log_0001"
        return 0
    elif [ "$enabled_sites" -ge 1 ]; then
        # Eine oder mehrere Sites aktiv, die nicht der Default entsprechen
        debug "$_is_default_nginx_debug_0003"
        log "$_is_default_nginx_log_0002"
        return 1
    else
        # Status unklar
        debug "$_is_default_nginx_debug_0004"
        log "$_is_default_nginx_log_0003"
        return 2
    fi
}

# _is_multisite_nginx
_is_multisite_nginx_debug_0001="INFO: NGINX-Dienst auf Multisite-Konfiguration prüfen ..."
_is_multisite_nginx_debug_0002="SUCCESS: NGINX-Dienst verwendet Multisite-Konfiguration."
_is_multisite_nginx_debug_0003="WARN: NGINX-Dienst verwendet eine Single-Konfiguration."

_is_multisite_nginx() {
    # -----------------------------------------------------------------------
    # _is_multisite_nginx
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX im Multisite-Modus läuft
    # Parameter: keine
    # Rückgabe.: 0 = Multisite, 1 = Singlesite
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    log_debug "$_is_multisite_nginx_debug_0001"
    
    # NGINX-Dienst läuft - Betriebsmodus prüfen
    local nginx_mode=$(nginx -V 2>&1 | grep -o "multisite")

    if [ -n "$nginx_mode" ]; then
        debug "$_is_multisite_nginx_debug_0002"
        echo "multisite"
        return 0
    else
        debug "$_is_multisite_nginx_debug_0003"
        echo "default"
        return 1
    fi
}   

# get_nginx_template_path
get_nginx_template_path_txt_0001="Template-Datei nicht gefunden: %s"
get_nginx_template_path_txt_0002="manage_folders.sh nicht verfügbar"
get_nginx_template_path_txt_0003="Template-Datei im Fallback-Pfad nicht gefunden: %s"

_template_filename_nginx() {
    # -----------------------------------------------------------------------
    # _template_filename_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Hilfsfunktion zum Ermitteln des vollständigen Pfads zur
    # .........  NGINX-Template-Datei basierend auf dem Typ (local, internal,
    # .........  external).
    # Parameter: $1 = Template-Typ (local, internal, external)
    # Rückgabe:  Pfad zur NGINX-Template-Datei
    # -----------------------------------------------------------------------
    local template_type="${1:-internal}"
    local template_file
    
    case "$template_type" in
        local)
            template_file="$(get_template_file "nginx" "template_local")"
            ;;
        internal)
            template_file="$(get_template_file "nginx" "template_internal")"
            ;;
        external)
            template_file="$(get_template_file "nginx" "template_external")"
            ;;
        *)
            log "Ungültiger Template-Typ: $template_type"
            return 1
            ;;
    esac
    
    echo "$template_file"
    return 0
}

# ===========================================================================
# Externe Funktionen zur Prüfung der NGINX-Server Installation
# ===========================================================================

# chk_installation_nginx
chk_installation_nginx_debug_0001="INFO: Überprüfung der NGINX-Installation ..."
chk_installation_nginx_debug_0002="WARN: NGINX ist nicht installiert. Installation wird gestartet..."
chk_installation_nginx_debug_0003="ERROR: NGINX-Installation fehlgeschlagen!"
chk_installation_nginx_debug_0004="SUCCESS: NGINX ist installiert und aktiv."
chk_installation_nginx_debug_0005="WARN: NGINX ist installiert, aber nicht aktiv. Starte NGINX..."
chk_installation_nginx_debug_0006="ERROR: NGINX konnte nicht gestartet werden!"
chk_installation_nginx_log_0001="NGINX ist nicht installiert. Installation wird gestartet..."
chk_installation_nginx_log_0002="NGINX-Installation fehlgeschlagen!"
chk_installation_nginx_log_0003="NGINX ist installiert und aktiv."
chk_installation_nginx_log_0004="NGINX ist installiert, aber nicht aktiv. Starte NGINX..."
chk_installation_nginx_log_0005="NGINX konnte nicht gestartet werden!"

chk_installation_nginx() {
    # -----------------------------------------------------------------------
    # chk_installation_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Prüft, ob NGINX installiert und aktiv ist, ggf. wird wenn 
    # .........  nicht anders ausgewählt NGINX nachinstalliert.
    # Parameter: $1 = Installationsentscheidung (J/n), optional (Default: J)
    # Rückgabe:  0 = OK, 1 = Installationsfehler
    # Seiteneffekte: Installiert ggf. nginx 
    # -----------------------------------------------------------------------
    local install_decision="${1:-J}"

    # Debug-Meldung eröffnen
    debug "$chk_installation_nginx_debug_0001"

    # 1. Prüfen, ob NGINX installiert ist
    _is_installed_nginx "$install_decision"
    local install_status=$?
    
    if [ $install_status -ne 0 ]; then
        # NGINX ist nicht installiert oder Installation fehlgeschlagen
        if [ $install_status -eq 1 ]; then
            # NGINX ist nicht installiert und Installation wurde abgebrochen
            debug "$chk_installation_nginx_debug_0002"
            log "$chk_installation_nginx_log_0001"
            return 1
        else
            # Installation fehlgeschlagen
            debug "$chk_installation_nginx_debug_0003"
            log "$chk_installation_nginx_log_0002"
            return 1
        fi
    fi

    # 2. Prüfen, ob NGINX läuft
    _is_running_nginx
    local running_status=$?
    
    if [ $running_status -ne 0 ]; then
        # NGINX ist installiert, aber nicht aktiv
        if [ $running_status -eq 1 ]; then
            # NGINX ist gestoppt/hat Fehler, versuchen zu starten
            debug "$chk_installation_nginx_debug_0005"
            log "$chk_installation_nginx_log_0004"
            
            # NGINX starten
            start_nginx
            if [ $? -ne 0 ]; then
                # Start fehlgeschlagen
                debug "$chk_installation_nginx_debug_0006"
                log "$chk_installation_nginx_log_0005"
                return 1
            fi
        else
            # Unerwarteter Fehler (sollte nicht auftreten, da wir bereits geprüft haben, dass NGINX installiert ist)
            return 1
        fi
    fi

    # NGINX ist installiert und aktiv
    debug "$chk_installation_nginx_debug_0004"
    log "$chk_installation_nginx_log_0003"
    return 0
}

# chk_config_nginx
chk_config_nginx_debug_0001="INFO: Prüfe NGINX-Konfiguration..."
chk_config_nginx_debug_0002="ERROR: NGINX ist nicht installiert."
chk_config_nginx_debug_0003="SUCCESS: NGINX-Konfiguration ist fehlerfrei."
chk_config_nginx_debug_0004="ERROR: Fehler in der NGINX-Konfiguration gefunden! \n%s"

chk_config_nginx() {
    # -----------------------------------------------------------------------
    # chk_config_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Prüft die NGINX-Konfiguration auf Syntaxfehler
    # Parameter: keine
    # Rückgabe.:  0 = Konfiguration gültig
    # .........   1 = Fehler in der NGINX-Konfiguration
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$chk_config_nginx_debug_0001"

    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if ! _is_installed_nginx; then
        debug "$chk_config_nginx_debug_0002"
        return 1
    fi

    # NGINX-Konfiguration testen
    if nginx -t 2>&1 | grep -q "syntax is ok"; then
        # Konfiguration ist fehlerfrei
        debug "$chk_config_nginx_debug_0003"
        return 0
    else
        # Konfiguration fehlerhaft, Fehlerdetails ausgeben
        local error_out
        error_out=$(nginx -t 2>&1)
        debug "$(printf "$chk_config_nginx_debug_0004" "$error_out")"
        return 1
    fi
}

# chk_port_nginx
chk_port_nginx_debug_0001="INFO: Port-Prüfung starten ..."
chk_port_nginx_debug_0002="WARN: Port '%s' ist belegt."
chk_port_nginx_debug_0003="SUCCESS: Port '%s' ist frei."
chk_port_nginx_debug_0004="ERROR: Fehler bei der Portprüfung! (Tools 'lsof'/'ss'/'netstat' fehlen!)"
chk_port_nginx_log_0001="Port '%s' ist belegt."
chk_port_nginx_log_0002="Port '%s' ist frei."
chk_port_nginx_log_0003="Fehler bei der Portprüfung! (Tools 'lsof'/'ss'/'netstat' fehlen!)"

chk_port_nginx() {
    # -----------------------------------------------------------------------
    # chk_port_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Prüft, ob der übergebene Port belegt ist oder frei.
    # Parameter: $1 = Port (Default: 80/443)
    # Rückgabe.:  0 = frei
    # .........   1 = belegt
    # .........   2 = Fehler
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------
    local port=${1:-$DEFAULT_HTTP_PORT}

    # Debug-Meldung eröffnen
    debug "$chk_port_nginx_debug_0001"

    # Prüfen, ob lsof, ss oder netstat verfügbar ist
    if command -v lsof >/dev/null 2>&1; then
        # Prüfen, ob der Port belegt ist (lsof)
        if lsof -i :$port | grep LISTEN > /dev/null; then
            debug "$(printf "$chk_port_nginx_debug_0002" "$port")"
            log "$(printf "$chk_port_nginx_log_0001" "$port")"
            return 1
        else
            debug "$(printf "$chk_port_nginx_debug_0003" "$port")"
            log "$(printf "$chk_port_nginx_log_0002" "$port")"
            return 0
        fi
    elif command -v ss >/dev/null 2>&1; then
        # Prüfen, ob der Port belegt ist (ss)
        if ss -tuln | grep -E ":$port[[:space:]]" > /dev/null; then
            debug "$(printf "$chk_port_nginx_debug_0002" "$port")"
            log "$(printf "$chk_port_nginx_log_0003" "$port")"
            return 1
        else
            debug "$(printf "$chk_port_nginx_debug_0003" "$port")"
            log "$(printf "$chk_port_nginx_log_0004" "$port")"
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # Prüfen, ob der Port belegt ist (netstat)
        if netstat -tuln | grep -E ":$port[[:space:]]" > /dev/null; then
            debug "$(printf "$chk_port_nginx_debug_0002" "$port")"
            log "$(printf "$chk_port_nginx_log_0003" "$port")"
            return 1
        else
            debug "$(printf "$chk_port_nginx_debug_0003" "$port")"
            log "$(printf "$chk_port_nginx_log_0004" "$port")"
            return 0
        fi
    else
        # Keines der Tools verfügbar
        debug "$chk_port_nginx_debug_0004"
        log "${chk_port_nginx_log_0003}"
        return 2
    fi
}

# ===========================================================================
# Funktionen zur Konfiguration der NGINX-Server in der Datenbank
# ===========================================================================

# get_port_nginx
get_port_nginx_debug_0001="INFO: Port für NGINX aus DB abgefragen..."
get_port_nginx_debug_0002="WARN: Port für NGINX nicht gesetzt, Standardwert '%s' wird verwendet."
get_port_nginx_debug_0003="SUCCESS: Port für NGINX: %s."
get_port_nginx_log_0001="Port für NGINX nicht gesetzt, Standardwert '%s' wird verwendet."
get_port_nginx_log_0002="Port für NGINX: %s."

get_port_nginx() {
    # -----------------------------------------------------------------------
    # get_port_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Gibt den aktuell konfigurierten Port für NGINX aus der 
    # .........  Datenbank zurück. Falls kein Port gesetzt ist, wird der
    # .........  Standardport '80' zurückgegeben.
    # Parameter: keine
    # Rückgabe.: Portnummer (Standard: 80)
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$get_port_nginx_debug_0001"

    # Port aus der Konfiguration abrufen
    local port=$(get_config_value "nginx.port")
    if [ $? -ne 0 ] || [ -z "$port" ]; then
        # Port nicht gesetzt, Standardwert verwenden
        debug "$(printf "$get_port_nginx_debug_0002" "$DEFAULT_HTTP_PORT")"
        log "$(printf "$get_port_nginx_log_0001" "$DEFAULT_HTTP_PORT")"
        port=$DEFAULT_HTTP_PORT
    fi

    # Port zurückgeben
    debug "$(printf "$get_port_nginx_debug_0003" "$port")"
    log "$(printf "$get_port_nginx_log_0002" "$port")"
    echo "$port"  
    return 0
}

# set_port_nginx
set_port_nginx_debug_0001="INFO: Setze NGINX-Port auf: '%s'"
set_port_nginx_debug_0002="ERROR: Fehler beim Schreiben des Port: '%s'"
set_port_nginx_debug_0003="SUCCESS: NGINX-Port erfolgreich geschrieben: '%s'"
set_port_nginx_log_0001="Fehler beim Schreiben des Port: '%s'"

set_port_nginx() {
    # -----------------------------------------------------------------------
    # set_port_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Setzt den Port für NGINX in der Datenbank
    # Parameter: $1 = Portnummer (z.B. 80, 443)
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler (ungültiger Port)
    # Seiteneffekte: Aktualisiert die NGINX-Konfiguration in der Datenbank
    # -----------------------------------------------------------------------
    local port="$1"

    # Debug-Meldung eröffnen
    debug "$(printf "$set_port_nginx_debug_0001" "$port")"

    # Parameterprüfung
    if ! check_param "$port" "port"; then return 1; fi

    # Port in der Konfiguration setzen
    set_config_value "nginx.port" "$port" "int" "Port für NGINX-Server"    
    if [ $? -ne 0 ]; then
        # Fehler beim Setzen des Ports
        debug "$(printf "$set_port_nginx_debug_0002" "$port")"
        log "$(printf "$set_port_nginx_log_0001" "$port")"
        return 1
    fi

    debug "$(printf "$set_port_nginx_debug_0003" "$port")"
    return 0
}

# get_server_name_nginx
get_server_name_nginx_debug_0001="INFO: Server-Name für NGINX aus DB abfragen..."
get_server_name_nginx_debug_0002="ERROR: Server-Name für NGINX nicht gesetzt, Standardwert 'localhost' wird verwendet."
get_server_name_nginx_debug_0003="SUCCESS: NGINX-Server-Name: '%s'."
get_server_name_nginx_log_0001="Server-Name für NGINX nicht gesetzt, Standardwert wird verwendet."
get_server_name_nginx_log_0002="NGINX-Server-Name: '%s'."

get_server_name_nginx() {
    # -----------------------------------------------------------------------
    # get_server_name_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Gibt den aktuell konfigurierten Server-Name für NGINX aus
    # .........  der Datenbank zurück. Falls kein Server-Name gesetzt ist, 
    # .........  wird der Standardwert 'localhost' zurückgegeben.
    # Parameter: keine
    # Rückgabe.: Server-Name (Standard: 'localhost')
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$get_server_name_nginx_debug_0001"

    # Server-Name aus der Konfiguration abrufen
    local server_name=$(get_config_value "nginx.server_name")
    if [ $? -ne 0 ] || [ -z "$server_name" ]; then
        # Server-Name nicht gesetzt, Standardwert verwenden
        debug "$get_server_name_nginx_debug_0002"
        log "$get_server_name_nginx_log_0001"
        server_name=$DEFAULT_SERVER_NAME
    fi

    # Server-Name zurückgeben
    debug "$(printf "$get_server_name_nginx_debug_0003" "$server_name")"
    log "$(printf "$get_server_name_nginx_log_0002" "$server_name")"
    echo "$server_name"  # Standardwert 'localhost', falls nicht gesetzt
    return 0
}

# set_server_name_nginx
set_server_name_nginx_debug_0001="INFO: Server-Name für NGINX aus DB abfragen..."
set_server_name_nginx_debug_0002="ERROR: Fehler beim Schreiben des Server-Name: '%s'"
set_server_name_nginx_debug_0003="SUCCESS: NGINX-Server-Name erfolgreich geschrieben: '%s'"
set_server_name_nginx_log_0001="Fehler beim Schreiben des Server-Name: '%s'"

set_server_name_nginx() {
    # -----------------------------------------------------------------------
    # set_server_name_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Setzt den Server-Name für NGINX in der Datenbank
    # Parameter: $1 = Server-Name (z.B. 'localhost', 'example.com')
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler (ungültiger Server-Name)
    # Seiteneffekte: Aktualisiert die NGINX-Konfiguration in der Datenbank
    # -----------------------------------------------------------------------
    local server_name="$1"

    # Debug-Meldung eröffnen
    debug "$(printf "$set_server_name_nginx_debug_0001" "$server_name")"

    # Parameterprüfung
    if ! check_param "$server_name" "server_name"; then return 1; fi

    # Server-Name in der Konfiguration setzen
    set_config_value "nginx.server_name" "$server_name" "string" "Server-Name für NGINX-Server"
    if [ $? -ne 0 ]; then
        # Fehler beim Setzen des Server-Namens
        debug "$(printf "$set_server_name_nginx_debug_0002" "$server_name")"
        log "$(printf "$set_server_name_nginx_log_0001" "$server_name")"
        return 1
    fi

    debug "$(printf "$set_server_name_nginx_debug_0003" "$server_name")"
    return 0
}

# get_frontend_dir_nginx
get_frontend_dir_nginx_debug_0001="INFO: Frontend-Verzeichnis für NGINX aus DB abfragen..."
get_frontend_dir_nginx_debug_0002="ERROR: Frontend-Verzeichnis für NGINX nicht gesetzt, Standardwert '%s' wird verwendet."
get_frontend_dir_nginx_debug_0003="SUCCESS: NGINX-Frontend-Verzeichnis: '%s'."
get_frontend_dir_nginx_log_0001="Frontend-Verzeichnis für NGINX nicht gesetzt, Standardwert wird verwendet."
get_frontend_dir_nginx_log_0002="NGINX-Frontend-Verzeichnis: '%s'."

get_frontend_dir_nginx() {
    # -----------------------------------------------------------------------
    # get_frontend_dir_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Gibt das aktuell konfigurierte Frontend-Verzeichnis für  
    # .........  NGINX aus der Datenbank zurück. Falls kein Verzeichnis
    # .........  gesetzt ist, wird der Standardwert '/var/www/html'
    # .........  zurückgegeben.
    # Parameter: keine
    # Rückgabe.: Frontend-Verzeichnis (Standard: '/var/www/html')
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$get_frontend_dir_nginx_debug_0001"

    # Frontend-Verzeichnis aus der Konfiguration abrufen
    local frontend_dir=$(get_config_value "nginx.document_root")
    if [ $? -ne 0 ] || [ -z "$frontend_dir" ]; then
        # Frontend-Verzeichnis nicht gesetzt, Standardwert verwenden
        debug "$(printf "$get_frontend_dir_nginx_debug_0002" "$DEFAULT_FRONTEND_DIR_FALLBACK")"
        log "$(printf "$get_frontend_dir_nginx_log_0001" "$DEFAULT_FRONTEND_DIR_FALLBACK")"
        frontend_dir=$DEFAULT_FRONTEND_DIR
    fi

    # Frontend-Verzeichnis zurückgeben
    debug "$(printf "$get_frontend_dir_nginx_debug_0003" "$frontend_dir")"
    log "$(printf "$get_frontend_dir_nginx_log_0002" "$frontend_dir")"
    echo "$frontend_dir"  # Standardwert '/var/www/html', falls nicht gesetzt
    return 0
}

# set_frontend_dir_nginx
set_frontend_dir_nginx_debug_0001="INFO: Setze Frontend-Verzeichnis für NGINX auf: '%s'"
set_frontend_dir_nginx_debug_0002="ERROR: Fehler beim Schreiben des Frontend-Verzeichnis: '%s'"
set_frontend_dir_nginx_debug_0003="SUCCESS: NGINX-Frontend-Verzeichnis erfolgreich geschrieben: '%s'"
set_frontend_dir_nginx_log_0001="Fehler beim Schreiben des Frontend-Verzeichnis: '%s'"

set_frontend_dir_nginx() {
    # -----------------------------------------------------------------------
    # set_frontend_dir_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Setzt das Frontend-Verzeichnis für NGINX in der Datenbank
    # Parameter: $1 = Frontend-Verzeichnis (z.B. '/var/www/html')
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler (ungültiges Verzeichnis)
    # Seiteneffekte: Aktualisiert die NGINX-Konfiguration in der Datenbank
    # -----------------------------------------------------------------------
    local frontend_dir="$1"

    # Debug-Meldung eröffnen
    debug "$(printf "$set_frontend_dir_nginx_debug_0001" "$frontend_dir")"

    # Parameterprüfung
    if ! check_param "$frontend_dir" "frontend_dir"; then return 1; fi

    # Frontend-Verzeichnis in der Konfiguration setzen
    set_config_value "nginx.document_root" "$frontend_dir" "string" "Web-Root Verzeichnis der Application"
    if [ $? -ne 0 ]; then
        # Fehler beim Setzen des Frontend-Verzeichnisses
        debug "$(printf "$set_frontend_dir_nginx_debug_0002" "$frontend_dir")"
        log "$(printf "$set_frontend_dir_nginx_log_0001" "$frontend_dir")"
        return 1
    fi

    debug "$(printf "$set_frontend_dir_nginx_debug_0003" "$frontend_dir")"
    return 0
}

# get_index_file_nginx
get_index_file_nginx_debug_0001="INFO: Index-Datei für NGINX aus DB abfragen..."
get_index_file_nginx_debug_0002="ERROR: Index-Datei für NGINX nicht gesetzt, Standardwert '%s' wird verwendet."
get_index_file_nginx_debug_0003="SUCCESS: NGINX-Index-Datei: '%s'."
get_index_file_nginx_log_0001="Index-Datei für NGINX nicht gesetzt, Standardwert wird verwendet."
get_index_file_nginx_log_0002="NGINX-Index-Datei: '%s'."

get_index_file_nginx() {
    # -----------------------------------------------------------------------
    # get_index_file_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Gibt die aktuell konfigurierte Index-Datei für NGINX aus 
    # .........  der Datenbank zurück. Falls keine Index-Datei gesetzt ist, 
    # .........  wird der Standardwert 'index.html' zurückgegeben.
    # Parameter: keine
    # Rückgabe.: Index-Datei (Standard: 'index.html')
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$get_index_file_nginx_debug_0001"

    # Index-Datei aus der Konfiguration abrufen
    local index_file=$(get_config_value "nginx.index_files")
    if [ $? -ne 0 ] || [ -z "$index_file" ]; then
        # Index-Datei nicht gesetzt, Standardwert verwenden
        debug "$(printf "$get_index_file_nginx_debug_0002" "$DEFAULT_INDEX_FILE_FALLBACK")"
        log "$(printf "$get_index_file_nginx_log_0001" "$DEFAULT_INDEX_FILE_FALLBACK")"
        index_file=$DEFAULT_INDEX_FILE
    fi

    # Index-Datei zurückgeben
    debug "$(printf "$get_index_file_nginx_debug_0003" "$index_file")"
    log "$(printf "$get_index_file_nginx_log_0002" "$index_file")"
    echo "$index_file"  # Standardwert 'index.html', falls nicht gesetzt
    return 0
}

# set_index_file_nginx
set_index_file_nginx_debug_0001="INFO: Setze Index-Datei für NGINX auf: '%s'"
set_index_file_nginx_debug_0002="ERROR: Fehler beim Schreiben der Index-Datei: '%s'"
set_index_file_nginx_debug_0003="SUCCESS: NGINX-Index-Datei erfolgreich geschrieben: '%s'"
set_index_file_nginx_log_0001="Fehler beim Schreiben der Index-Datei: '%s'"

set_index_file_nginx() {
    # -----------------------------------------------------------------------
    # set_index_file_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Setzt die Index-Datei für NGINX in der Datenbank
    # Parameter: $1 = Index-Datei (z.B. 'index.html')
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler (ungültige Index-Datei)
    # Seiteneffekte: Aktualisiert die NGINX-Konfiguration in der Datenbank
    # -----------------------------------------------------------------------
    local index_file="$1"

    # Debug-Meldung eröffnen
    debug "$(printf "$set_index_file_nginx_debug_0001" "$index_file")"

    # Parameterprüfung
    if ! check_param "$index_file" "index_file"; then return 1; fi

    # Index-Datei in der Konfiguration setzen
    set_config_value "nginx.index_files" "$index_file" "string" "Index-Dateien für NGINX-Server"
    if [ $? -ne 0 ]; then
        # Fehler beim Setzen der Index-Datei
        debug "$(printf "$set_index_file_nginx_debug_0002" "$index_file")"
        log "$(printf "$set_index_file_nginx_log_0001" "$index_file")"
        return 1
    fi

    debug "$(printf "$set_index_file_nginx_debug_0003" "$index_file")"
    return 0
}

# get_api_url_nginx
get_api_url_nginx_debug_0001="INFO: API-URL für NGINX aus DB abfragen..."
get_api_url_nginx_debug_0002="ERROR: API-URL für NGINX nicht gesetzt, Standardwert '%s' wird verwendet."
get_api_url_nginx_debug_0003="SUCCESS: NGINX-API-URL: '%s'."
get_api_url_nginx_log_0001="API-URL für NGINX nicht gesetzt, Standardwert wird verwendet."
get_api_url_nginx_log_0002="NGINX-API-URL: '%s'."

get_api_url_nginx() {
    # -----------------------------------------------------------------------
    # get_api_url_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Gibt die aktuell konfigurierte API-URL für NGINX aus der 
    # .........  Datenbank zurück. Falls keine API-URL gesetzt ist, wird 
    # .........  der Standardwert 'http://localhost:8080/api' zurückgegeben.
    # Parameter: keine
    # Rückgabe.: API-URL (Standard: 'http://localhost:8080/api')
    # Seiteneffekte: keine
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$get_api_url_nginx_debug_0001"

    # API-URL aus der Konfiguration abrufen
    local api_url=$(get_config_value "nginx.api_url")
    if [ $? -ne 0 ] || [ -z "$api_url" ]; then
        # API-URL nicht gesetzt, Standardwert verwenden
        debug "$(printf "$get_api_url_nginx_debug_0002" "$DEFAULT_API_URL_FALLBACK")"
        log "$(printf "$get_api_url_nginx_log_0001" "$DEFAULT_API_URL_FALLBACK")"
        api_url=$DEFAULT_API_URL
    fi

    # API-URL zurückgeben
    debug "$(printf "$get_api_url_nginx_debug_0003" "$api_url")"
    log "$(printf "$get_api_url_nginx_log_0002" "$api_url")"
    echo "$api_url"  # Standardwert 'http://localhost:8080/api', falls nicht gesetzt
    return 0
}

# set_api_url_nginx
set_api_url_nginx_debug_0001="INFO: Setze API-URL für NGINX auf: '%s'"
set_api_url_nginx_debug_0002="ERROR: Fehler beim Schreiben der API-URL: '%s'"
set_api_url_nginx_debug_0003="SUCCESS: NGINX-API-URL erfolgreich geschrieben: '%s'"
set_api_url_nginx_log_0001="Fehler beim Schreiben der API-URL: '%s'"

set_api_url_nginx() {
    # -----------------------------------------------------------------------
    # set_api_url_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Setzt die API-URL für NGINX in der Datenbank
    # Parameter: $1 = API-URL (z.B. 'http://localhost:8080/api')
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler (ungültige API-URL)
    # Seiteneffekte: Aktualisiert die NGINX-Konfiguration in der Datenbank
    # -----------------------------------------------------------------------
    local api_url="$1"

    # Debug-Meldung eröffnen
    debug "$(printf "$set_api_url_nginx_debug_0001" "$api_url")"

    # Parameterprüfung
    if ! check_param "$api_url" "api_url"; then return 1; fi

    # API-URL in der Konfiguration setzen
    set_config_value "nginx.api_url" "$api_url" "string" "API-URL für NGINX-Server"
    if [ $? -ne 0 ]; then
        # Fehler beim Setzen der API-URL
        debug "$(printf "$set_api_url_nginx_debug_0002" "$api_url")"
        log "$(printf "$set_api_url_nginx_log_0001" "$api_url")"
        return 1
    fi

    debug "$(printf "$set_api_url_nginx_debug_0003" "$api_url")"
    return 0
}

# ===========================================================================
# Externe Funktionen zur Steuerung des NGINX-Server
# ===========================================================================

# stop_nginx
stop_nginx_debug_0001="INFO: Stoppe NGINX-Dienst..."
stop_nginx_debug_0002="ERROR: NGINX ist nicht installiert."
stop_nginx_debug_0003="ERROR: NGINX-Dienst konnte nicht gestoppt werden! Meldung: \n%s"
stop_nginx_debug_0004="SUCCESS: NGINX-Dienst erfolgreich gestoppt."
stop_nginx_log_0001="Stop NGINX-Server fehlgeschlagen: NGINX ist nicht installiert!"
stop_nginx_log_0002="Stop NGINX-Server fehlgeschlagen: \n%s"
stop_nginx_log_0003="NGINX-Server erfolgreich gestoppt."

stop_nginx() {
    # -----------------------------------------------------------------------
    # stop_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Stoppt den NGINX-Dienst
    # Parameter: keine
    # Rückgabe.:  0 = erfolgreich gestoppt
    # .........   1 = Fehler
    # Seiteneffekte: Stoppt den NGINX-Dienst (systemctl stop nginx)
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$stop_nginx_debug_0001"
    
    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if ! is_nginx_available; then
        # NGINX ist nicht installiert
        debug "$stop_nginx_debug_0002"
        log "$stop_nginx_log_0001"
        return 1
    fi
    
    # NGINX ist installiert, jetzt NGINX-Dienst stoppen
    if ! systemctl stop nginx; then
        # Stop fehlgeschlagen, Fehlerdetails ausgeben
        local status_out
        status_out=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 10)
        debug "$(printf "$stop_nginx_debug_0003" "$status_out")"
        log "$(printf "$stop_nginx_log_0002" "$status_out")"
        return 1
    fi

    # Stop erfolgreich
    debug "$stop_nginx_debug_0004"
    log "$stop_nginx_log_0003"
    return 0
}

# start_nginx
start_nginx_debug_0001="INFO: Starte NGINX-Dienst..."
start_nginx_debug_0002="ERROR: NGINX ist nicht installiert."
start_nginx_debug_0003="ERROR: NGINX-Dienst konnte nicht gestartet werden! Meldung: \n%s"
start_nginx_debug_0004="SUCCESS: NGINX-Dienst erfolgreich gestartet."
start_nginx_log_0001="Start NGINX-Server fehlgeschlagen: NGINX ist nicht installiert!"
start_nginx_log_0002="Start NGINX-Server fehlgeschlagen: \n%s"
start_nginx_log_0003="NGINX-Server erfolgreich gestartet."

start_nginx() {
    # -----------------------------------------------------------------------
    # start_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Startet den NGINX-Dienst
    # Parameter: keine
    # Rückgabe.:  0 = erfolgreich gestartet, 
    # .........   1 = Fehler
    # Seiteneffekte: Startet den NGINX-Dienst (systemctl start nginx)
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$start_nginx_debug_0001"

    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if ! _is_installed_nginx; then
        # NGINX ist nicht installiert
        debug "$start_nginx_debug_0002"
        log "$start_nginx_log_0001"
        return 1
    fi

    # NGINX ist installiert, jetzt NGINX-Service starten
    if ! systemctl start nginx; then
        # Start fehlgeschlagen, Fehlerdetails ausgeben
        local status_out
        status_out=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 10)
        debug "$(printf "$start_nginx_debug_0003" "$status_out")"
        log "$(printf "$start_nginx_log_0002" "$status_out")"
        return 1
    fi

    # Start erfolgreich
    debug "$start_nginx_debug_0004"
    log "$start_nginx_log_0003"
    return 0
}

# reload_nginx
reload_nginx_debug_0001="INFO: NGINX-Konfiguration wird getestet und ein Reload versucht ..."
reload_nginx_debug_0002="ERROR: Fehler in der NGINX-Konfiguration! Bitte prüfen."
reload_nginx_debug_0003="ERROR: NGINX konnte nicht neu geladen werden! Statusauszug: \n%s"
reload_nginx_debug_0004="SUCCESS: NGINX-Konfiguration erfolgreich neu geladen."
reload_nginx_log_0001="Fehler in der NGINX-Konfiguration! Bitte prüfen."
reload_nginx_log_0002="NGINX konnte nicht neu geladen werden! Statusauszug: \n%s"

reload_nginx() {
    # -----------------------------------------------------------------------
    # reload_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Testet die NGINX-Konfiguration und lädt sie falls fehlerfrei
    # .........  neu
    # Parameter: keine
    # Rückgabe.:  0 = OK, 
    # .........   1 = Reload-Fehler,
    # .........   2 = Konfigurationsfehler
    # Seiteneffekte: Reload von nginx (systemctl reload nginx)
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$reload_nginx_debug_0001"

    # Prüfen, ob die NGINX-Konfiguration fehlerfrei ist
    chk_config_nginx
    if [ $? -ne 0 ]; then
        # Konfiguration fehlerhaft, Fehlerdetails ausgeben
        debug "$reload_nginx_debug_0002"
        log "$reload_nginx_log_0001"
        return 2
    fi

    # Konfiguration ist fehlerfrei
    if ! systemctl reload nginx; then
        # Reload fehlgeschlagen, Fehlerdetails ausgeben
        local status_out
        status_out=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 10)
        debug "$(printf "$reload_nginx_debug_0003" "$status_out")"
        log "$(printf "$reload_nginx_log_0002" "$status_out")"
        return 1
    fi

    # Reload erfolgreich
    debug "$reload_nginx_debug_0004"
    return 0
}

# ===========================================================================
# Externe Funktionen zur Verarbeitung der NGINX-Server Konigurationsdateien
# ===========================================================================

# backup_config_nginx
backup_config_nginx_debug_0001="INFO: Backup der NGINX-Konfiguration wird erstellt..."
backup_config_nginx_debug_0002="ERROR: Orginal NGINX-Konfigurationsdatei nicht gefunden: %s"
backup_config_nginx_debug_0003="ERROR: Schreiben der Metadaten-Datei fehlgeschlagen: %s"
backup_config_nginx_debug_0004="SUCCESS: Backup der NGINX-Konfiguration erfolgreich erstellt: %s"
backup_config_nginx_debug_0005="ERROR: Backup der NGINX-Konfiguration fehlgeschlagen: %s"
backup_config_nginx_log_0001="Orginal NGINX-Konfigurationsdatei nicht gefunden: %s"
backup_config_nginx_log_0002="Schreiben der Metadaten-Datei fehlgeschlagen: %s"
backup_config_nginx_log_0003="Backup der NGINX-Konfiguration fehlgeschlagen: %s"

backup_config_nginx() {
    # -----------------------------------------------------------------------
    # backup_config_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Legt ein Backup der übergebenen NGINX-Konfigurationsdatei 
    # .........  im zentralen Backup-Ordner an und erzeugt eine 
    # .........  maschinenlesbare Metadaten-Datei (.meta.json)
    # Parameter: $1 = Quellpfad der Konfigurationsdatei
    # .........  $2 = Typ der Konfiguration (z.B. internal, external)
    # .........  $3 = Aktion (z.B. set_port, set_default_config)
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler bei Erstellung der Backup-Datei, 
    # .........   2 = Fehler bei Erstellung der Metadaten-Datei
    # Seiteneffekte: Schreibt Backup- und Metadaten-Dateien ins Dateisystem
    # -----------------------------------------------------------------------
    local src="$1"
    local config_type="$2"
    local action="$3"

    # Debug-Meldung eröffnen
    debug "$backup_config_nginx_debug_0001"

    # Parameterprüfung
    if ! check_param "$src" "src"; then return 1; fi
    if ! check_param "$config_type" "config_type"; then return 1; fi
    if ! check_param "$action" "action"; then return 1; fi

    # Prüfen, ob die Quell-Konfigurationsdatei existiert
    if [ ! -f "$src" ]; then
        # Quell-Datei nicht gefunden, Fehler melden
        debug "$(printf "$backup_config_nginx_debug_0002" "$src")"
        log "$(printf "$backup_config_nginx_log_0001" "$src")"
        return 1
    fi

    # Ermitteln des Backup-und Backup-Meta-Dateipfades
    local backup_file="$(get_backup_file "nginx" "$src")"
    local backup_meta_file="$(get_backup_meta_file "$backup_file")"
    
    # Quell-Datei sichern 
    if cp "$src" "$backup_file"; then
        # Metadaten über Template-Datei erstellen
        local template_file
        template_file="$(get_template_file "backup_meta" "backup-nginx")"

        # Template Daten vorbereiten
        local timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"  # Aktueller Zeitstempel

        # Wende Template an
        debug "$(printf "Zu sichernde Datei.: '%s'" "$src")"
        debug "$(printf "Backup-Datei.......: '%s'" "$backup_file")"
        debug "$(printf "Metadaten-Datei....: '%s'" "$backup_meta_file")"
        debug "$(printf "Ersetze Platzhalter:\
                         \n\t\ttimestamp  : '%s' \
                         \n\t\tsource     : '%s' \
                         \n\t\tbackup     : '%s' \
                         \n\t\tconfig_type: '%s' \
                         \n\t\taction     : '%s'" \
                         "$timestamp" "$src" "$backup_file" "$config_type" "$action")"

        apply_template "$template_file" "$backup_meta_file" \
            "timestamp=$timestamp" \
            "source=$src" \
            "backup=$backup_file" \
            "config_type=$config_type" \
            "action=$action"

        if [ $? -ne 0 ]; then
            debug "$(printf "$backup_config_nginx_debug_0003" "$backup_meta_file")"
            log "$(printf "$backup_config_nginx_log_0002" "$backup_meta_file")"
            return 2
        fi

        debug "$(printf "$backup_config_nginx_debug_0004" "$backup_file")"
        return 0
    else
        # Fehler beim Kopieren der Konfigurationsdatei
        debug "$(printf "$backup_config_nginx_debug_0005" "$src")"
        log "$(printf "$backup_config_nginx_log_0003" "$src")"
        return 1
    fi
}

# write_config_file_nginx
write_config_file_nginx_debug_0001="INFO: Integration der Applikation in die NGINX-Konfiguration gestartet."
write_config_file_nginx_debug_0002="ERROR: Default-Konfiguration nicht gefunden: %s"
write_config_file_nginx_debug_0003="ERROR: Backup der NGINX-Konfiguration fehlgeschlagen!"
write_config_file_nginx_debug_0004="ERROR: Beim Verwenden des Template '%s' ist ein Fehler aufgetreten!"
write_config_file_nginx_debug_0005="ERROR: NGINX-Symlink konnte nicht erstellt oder aktualisiert werden!"
write_config_file_nginx_debug_0006="ERROR: NGINX-Konfiguration konnte nach Integration nicht neu geladen werden!"
write_config_file_nginx_debug_0007="SUCCESS: NGINX-Konfiguration erfolgreich integriert und neu geladen."
write_config_file_nginx_log_0001="NGINX-Konfiguration nicht gefunden: %s"
write_config_file_nginx_log_0002="Backup der NGINX-Konfiguration fehlgeschlagen!"
write_config_file_nginx_log_0003="NGINX-Symlink konnte nicht erstellt oder aktualisiert werden!"
write_config_file_nginx_log_0004="NGINX-Konfiguration konnte nach Integration nicht neu geladen werden!"
write_config_file_nginx_log_0005="NGINX-Konfiguration erfolgreich integriert und neu geladen."

write_config_file_nginx() {
    # -----------------------------------------------------------------------
    # write_config_file_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Integriert die Anwendung in die Konfiguration von 
    # .........  NGINX, indem die Konfiguration wie ein Template 
    # .........  geladen und angepasst wird.
    # Parameter: $1 = Modus (z.B. local, internal, external)
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler, 
    # .........   2 = Backup-Fehler, 
    # .........   3 = Template-Fehler, 
    # .........   4 = Reload-Fehler
    # -----------------------------------------------------------------------
    local modus_nginx="$1"

    # Debug-Meldung eröffnen
    debug "$write_config_file_nginx_debug_0001"

    # Parameterprüfung
    if ! check_param "$modus_nginx" "modus_nginx"; then return 1; fi

    # Ermitteln der Default-Konfigurationsdatei inkl. Prüfung
    local src_cnf_file_nginx
    src_cnf_file_nginx=$(get_config_file_nginx "$modus_nginx")
    if [ $? -ne 0 ] || [ -z "$src_cnf_file_nginx" ]; then
        # Fehler beim Abrufen der Konfigurationsdatei
        debug "$(printf "$write_config_file_nginx_debug_0002" "$src_cnf_file_nginx")"
        log "$(printf "$write_config_file_nginx_log_0001" "$src_cnf_file_nginx")"
        return 1
    fi

    # Backup der Default-Konfiguration anlegen
    backup_config_nginx "$src_cnf_file_nginx" "$modus_nginx" "write_config_file_nginx"
    if [ $? -ne 0 ]; then
        # Fehler beim Backup der Default-Konfiguration
        debug "$write_config_file_nginx_debug_0003"
        log "$write_config_file_nginx_log_0002"
        return 2
    fi

    # Template-Ersetzung vorbereiten, Einstellungen aus der Datenbank abrufen
    local port="$(get_port_nginx)"               # Port für NGINX
    local server_name="$(get_server_name_nginx)" # Standard Server-Name
    local frontend_dir="$(get_frontend_dir)"     # WEB-Root Verzeichnis
    local index_files="$(get_index_file_nginx)"  # Standard Index-Dateien
    local api_url="$(get_api_url_nginx)"         # API-URL

    # Template-Datei suchen, wenn gefunden wurde, Platzhalter ersetzen
    local template_file  
    template_file="$(_template_filename_nginx $modus_nginx)"
    apply_template "$template_file" "$src_cnf_file_nginx" \
                "PORT=$port" \
                "SERVER_NAME=$server_name" \
                "DOCUMENT_ROOT=$frontend_dir" \
                "INDEX_FILE=$index_files" \
                "API_URL=$api_url"

    if [ $? -ne 0 ]; then
        # Fehler beim Anwenden des Templates
        debug "$(printf "$write_config_file_nginx_debug_0004" "$template_file")"
        return 3
    fi

    # --- TODO: Prüfe KI Source ---------------------------------------------
    # Trenne den Dateinamen vom Pfad und erstelle den Symlink-Namen
    local sites_enabled="/etc/nginx/sites-enabled"
    local enabled_link="$sites_enabled/$(basename "$src_cnf_file_nginx")"
    # Prüfen, ob der Symlink bereits existiert
    if [ ! -L "$enabled_link" ]; then
        # Symlink erstellen, wenn nicht vorhanden
        if ! ln -s "$src_cnf_file_nginx" "$enabled_link"; then
            # Fehler beim Erstellen des Symlinks
            debug "$(printf "$write_config_file_nginx_debug_0005" "$src_cnf_file_nginx")"
            log "$(printf "$write_config_file_nginx_log_0003" "$src_cnf_file_nginx")"
            return 4
        fi
    else
        # Symlink existiert bereits, prüfen ob er auf die richtige Datei zeigt
        local current_link_target=$(readlink "$enabled_link")
        if [ "$current_link_target" != "$src_cnf_file_nginx" ]; then
            # Symlink zeigt auf eine andere Datei, aktualisieren
            if ! ln -sf "$src_cnf_file_nginx" "$enabled_link"; then
                # Fehler beim Aktualisieren des Symlinks
                debug "$(printf "$write_config_file_nginx_debug_0005" "$src_cnf_file_nginx")"
                log "$(printf "$write_config_file_nginx_log_0003" "$src_cnf_file_nginx")"
                return 4
            fi
        fi
    fi
    # --- Ende TODO: Prüfe KI Source ---------------------------------------------

    # NGINX-Konfiguration neu laden
    reload_nginx    
    if [ $? -ne 0 ]; then 
        # Fehler beim Neuladen der NGINX-Konfiguration
        debug "$write_config_file_nginx_debug_0006"
        log "$(printf "$write_config_file_nginx_log_0004" "$src_cnf_file_nginx")"
        return 4
    fi
    
    # Firewall-Regeln aktualisieren
    # TODO: Firewall Modul einbinden
    # update_firewall_rules "$mode"

    # Erfolgreiche Integration der NGINX-Konfiguration
    debug "$write_config_file_nginx_debug_0007"
    log "$(printf "$write_config_file_nginx_log_0005")"
    return 0
}







# read_url_nginx
read_url_nginx_debug_0001="INFO: NGINX-URL wird ermittelt..."
read_url_nginx_debug_0002="ERROR: NGINX-URL konnte nicht ermittelt werden!"
read_url_nginx_debug_0003="SUCCESS: NGINX-URL: '%s'"
read_url_nginx_log_0001="NGINX-URL konnte nicht ermittelt werden!"
read_url_nginx_log_0002="NGINX-URL: '%s'"

read_url_nginx() {
    # -----------------------------------------------------------------------
    # read_url_nginx
    # -----------------------------------------------------------------------
    # Funktion.: Ermittelt die aktuelle NGINX-URL basierend auf der 
    # .........  Konfiguration und gibt sie zurück.
    # Parameter: keine
    # Rückgabe.:  0 = OK, 
    # .........   1 = Fehler bei der URL-Ermittlung
    # Seiteneffekte: Keine
    # -----------------------------------------------------------------------

    # Debug-Meldung eröffnen
    debug "$read_url_nginx_debug_0001"

    # Protokoll basierend auf Port ermitteln
    local server_port=$(get_nginx_port "text")
 
    # NGINX-URL ermitteln
    local nginx_url=$(get_nginx_url "text")
    
    if [ $? -ne 0 ] || [ -z "$nginx_url" ]; then
        # Fehler bei der URL-Ermittlung
        debug "$read_url_nginx_debug_0002"
        log "$read_url_nginx_log_0001"
        return 1
    fi

    debug "$(printf "$read_url_nginx_debug_0003" "$nginx_url")"
    log "$(printf "$read_url_nginx_log_0002" "$nginx_url")"
    
    echo "$nginx_url"
    return 0
}


# ===========================================================================
# Hilfsfunktionen zum lesen und setzen von einzelnen NGINX-Konfigurationen
# ===========================================================================

# get_nginx_url
get_nginx_url_txt_0001="Konnte IP-Adresse nicht ermitteln."
get_nginx_url_txt_0002="Ermittelte Fotobox-URL: %s"
get_nginx_url_txt_0003="URL-Ermittlung abgeschlossen."
get_nginx_url_txt_0004="Fehler bei der URL-Ermittlung."
get_nginx_url_txt_0005="Verwende IP-Adresse: %s"
get_nginx_url_txt_0006="Verwende Hostname: %s"

get_nginx_url() {
    # -----------------------------------------------------------------------
    # get_nginx_url
    # -----------------------------------------------------------------------
    # Funktion: Gibt die aktuelle NGINX-URL zurück
    # Parameter: $1 = Modus (text|json), optional (Default: text)
    # Rückgabe:  URL als String oder JSON
    # -----------------------------------------------------------------------
    local mode="${1:-text}"
    local server_port server_name server_proto url

    # Port ermitteln
    server_port=$(get_nginx_port text)
    
    # Protokoll basierend auf Port ermitteln
    if [ "$server_port" = "443" ]; then
        server_proto="https"
    else
        server_proto="http"
    fi
    
    # Servername/IP-Adresse ermitteln
    # Versuche zuerst Hostname aufzulösen
    server_name=$(hostname -I | awk '{print $1}')
    
    if [ -z "$server_name" ]; then
        # Fallback: Versuche lokale IP-Adresse zu bestimmen
        server_name=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
    fi
    
    if [ -z "$server_name" ]; then
        # Fallback: localhost verwenden
        server_name="localhost"
        log_or_json "$mode" "warning" "$get_nginx_url_txt_0001" 1
    else
        log_or_json "$mode" "info" "$(printf "$get_nginx_url_txt_0005" "$server_name")" 0
    fi
    
    # URL zusammenbauen
    if [ "$server_port" = "80" ]; then
        # Standard-HTTP-Port weglassen
        url="${server_proto}://${server_name}"
    elif [ "$server_port" = "443" ]; then
        # Standard-HTTPS-Port weglassen
        url="${server_proto}://${server_name}"
    else
        # Bei anderen Ports den Port mit angeben
        url="${server_proto}://${server_name}:${server_port}"
    fi
    
    # Ausgabe je nach Modus
    if [ "$mode" = "json" ]; then
        cat << EOF
{
  "status": "success",
  "message": "$(printf "$get_nginx_url_txt_0002" "$url")",
  "code": 0,
  "data": {
    "url": "$url",
    "protocol": "$server_proto",
    "hostname": "$server_name",
    "port": "$server_port"
  }
}
EOF
    else
        echo "$url"
    fi
    
    log_debug "$get_nginx_url_txt_0003"
    return 0
}

get_nginx_port() {
    # -----------------------------------------------------------------------
    # get_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Ermittelt den aktuell verwendeten Port der Fotobox-Weboberfläche.
    # Prüft eigene Fotobox-Konfiguration, Default-Konfiguration und liefert Fallback.
    # Parameter: $1 = Modus (text|json), optional (Standard: text)
    # Rückgabe: Portnummer (echo/JSON), 0 = OK, 1 = Fehler
    local mode="${1:-text}"
    local port=""
    local conf_file=""
    # 1. Eigene Fotobox-Konfiguration prüfen
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-enabled/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-enabled/default"
    fi
    if [ -n "$conf_file" ]; then
        port=$(grep -Eo 'listen[[:space:]]+[0-9.]*(:[0-9]+)?' "$conf_file" | head -n1 | grep -Eo '[0-9]+$')
        if [ -z "$port" ]; then
            port=80
        fi
        if [ "$mode" = "json" ]; then
            json_out "success" "$port" 0
        else
            echo "$port"
        fi
        return 0
    else
        # Keine passende Konfiguration gefunden, Fallback
        if [ "$mode" = "json" ]; then
            json_out "info" "80" 1
        else
            echo "80"
        fi
        return 1
    fi
}

# set_nginx_port
set_nginx_port_txt_0001="Portauswahl für Fotobox-Weboberfläche gestartet."
set_nginx_port_txt_0002="Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:"
set_nginx_port_txt_0003="Ungültige Eingabe: '%s'. Bitte eine gültige Portnummer angeben."
set_nginx_port_txt_0004="Fehler beim Schreiben des Ports in die Konfiguration."
set_nginx_port_txt_0005="Port %s wird verwendet."
set_nginx_port_txt_0006="Keine passende NGINX-Konfiguration gefunden. Port kann nicht gesetzt werden."
set_nginx_port_txt_0007="Abbrechen? [j/N]"
set_nginx_port_txt_0008="Portauswahl abgebrochen."

set_nginx_port() {
    # -----------------------------------------------------------------------
    # set_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Setzt den Port in der aktiven Konfiguration (passt Konfigurationsdatei an, reload)
    # Parameter: $1 = Port, $2 = Modus (text|json)
    # Rückgabe: 0 = OK, >0 = Fehler
    local port="$1"
    local mode="${2:-text}"
    local conf_file=""
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-available/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-available/default"
    else
        log_or_json "$mode" "error" "$set_nginx_port_txt_0006" 1
        return 1
    fi
    if [ -z "$port" ] || ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_or_json "$mode" "error" "$(printf "$set_nginx_port_txt_0003" "$port")" 2
        return 2
    fi
    backup_nginx_config "$conf_file" "$(get_nginx_config_type text)" "set_nginx_port" "$mode" || return 3
    sed -i -E "s/(listen[[:space:]]+)[0-9.]*(:[0-9]+)?/\1$port/" "$conf_file" || { log_or_json "$mode" "error" "$set_nginx_port_txt_0004" 4; return 4; }
    log_or_json "$mode" "success" "$(printf "$set_nginx_port_txt_0005" "$port")" 0
    
    # NGINX neu laden
    local reload_result
    reload_result=$(chk_nginx_reload "$mode")
    local reload_status=$?
    
    # Firewall-Regeln aktualisieren
    update_firewall_rules "$mode"
    
    return $reload_status
}

get_nginx_bind_address() {
    # -----------------------------------------------------------------------
    # get_nginx_bind_address
    # -----------------------------------------------------------------------
    # Funktion: Gibt die aktuelle Bind-Adresse (listen ...) zurück
    # Optional: $1 = Modus (text|json)
    local mode="${1:-text}"
    local conf_file=""
    local bind_addr=""
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-available/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-available/default"
    fi
    if [ -n "$conf_file" ]; then
        bind_addr=$(grep -Eo 'listen[[:space:]]+[0-9.]*' "$conf_file" | head -n1 | awk '{print $2}')
        [ -z "$bind_addr" ] && bind_addr="0.0.0.0"
    else
        bind_addr="0.0.0.0"
    fi
    if [ "$mode" = "json" ]; then
        json_out "success" "$bind_addr" 0
    else
        echo "$bind_addr"
    fi
}

# set_nginx_bind_address
set_nginx_bind_address_txt_0001="Bind-Adresse erfolgreich gesetzt"
set_nginx_bind_address_txt_0002="Fehler beim Setzen der Bind-Adresse"
set_nginx_bind_address_txt_0003="Keine passende NGINX-Konfiguration gefunden"
set_nginx_bind_address_txt_0004="Keine IP-Adresse angegeben"

set_nginx_bind_address() {
    # -----------------------------------------------------------------------
    # set_nginx_bind_address
    # -----------------------------------------------------------------------
    # Funktion: Setzt die Bind-Adresse in der aktiven Konfiguration
    # Parameter: $1 = IP, $2 = Modus (text|json)
    # Rückgabe: 0 = OK, >0 = Fehler
    local ip="$1"
    local mode="${2:-text}"
    local conf_file=""
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-available/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-available/default"
    fi
    if [ -z "$ip" ]; then log_or_json "$mode" "error" "$set_nginx_bind_address_txt_0004" 2; return 2; fi
    backup_nginx_config "$conf_file" "$(get_nginx_config_type text)" "set_nginx_bind_address" "$mode" || return 3
    sed -i -E "s/(listen[[:space:]]+)[0-9.]+/\1$ip/" "$conf_file" || { log_or_json "$mode" "error" "$set_nginx_bind_address_txt_0002" 4; return 4; }
    log_or_json "$mode" "success" "$set_nginx_bind_address_txt_0001" 0
    chk_nginx_reload "$mode"
    return $?
}

get_nginx_server_name() {
    # -----------------------------------------------------------------------
    # get_nginx_server_name
    # -----------------------------------------------------------------------
    # Funktion: Gibt den aktuellen server_name zurück
    # Optional: $1 = Modus (text|json)
    local mode="${1:-text}"
    local conf_file=""
    local server_name=""
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-available/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-available/default"
    fi
    if [ -n "$conf_file" ]; then
        server_name=$(grep -Eo 'server_name[[:space:]]+[^;]+' "$conf_file" | head -n1 | awk '{print $2}')
        [ -z "$server_name" ] && server_name="_"
    else
        server_name="_"
    fi
    if [ "$mode" = "json" ]; then
        json_out "success" "$server_name" 0
    else
        echo "$server_name"
    fi
}

# set_nginx_server_name
set_nginx_server_name_txt_0001="Server-Name erfolgreich gesetzt"
set_nginx_server_name_txt_0002="Fehler beim Setzen des Server-Namens"
set_nginx_server_name_txt_0003="Kein Server-Name angegeben"

set_nginx_server_name() {
    # -----------------------------------------------------------------------
    # set_nginx_server_name
    # -----------------------------------------------------------------------
    # Funktion: Setzt den server_name in der aktiven Konfiguration
    # Parameter: $1 = Name, $2 = Modus (text|json)
    # Rückgabe: 0 = OK, >0 = Fehler
    local name="$1"
    local mode="${2:-text}"
    local conf_file=""
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-available/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-available/default"
    fi
    if [ -z "$name" ]; then log_or_json "$mode" "error" "$set_nginx_server_name_txt_0003" 2; return 2; fi
    backup_nginx_config "$conf_file" "$(get_nginx_config_type text)" "set_nginx_server_name" "$mode" || return 3
    sed -i -E "s/(server_name[[:space:]]+)[^;]+/\1$name/" "$conf_file" || { log_or_json "$mode" "error" "$set_nginx_server_name_txt_0002" 4; return 4; }
    log_or_json "$mode" "success" "$set_nginx_server_name_txt_0001" 0
    chk_nginx_reload "$mode"
    return $?
}

get_nginx_webroot_path() {
    # -----------------------------------------------------------------------
    # get_nginx_webroot_path
    # -----------------------------------------------------------------------
    # Funktion: Gibt den aktuellen URL-Pfad (location ...) zurück
    # Optional: $1 = Modus (text|json)
    local mode="${1:-text}"
    local conf_file=""
    local path=""
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-available/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-available/default"
    elif [ -f /etc/nginx/conf.d/nginx-fotobox.conf ]; then
        conf_file="/etc/nginx/conf.d/nginx-fotobox.conf"
    fi
    if [ -n "$conf_file" ]; then
        # Bestimme den Frontend-Pfad über manage_folders
        local frontend_path
        if [ -f "$(dirname "$0")/manage_folders.sh" ] && [ -x "$(dirname "$0")/manage_folders.sh" ]; then
            frontend_path="$($(dirname "$0")/manage_folders.sh get_frontend_dir)"
        else
            frontend_path="${DEFAULT_DIR_FRONTEND:-/opt/fotobox/frontend}"
        fi
        
        # Prüfe zuerst, ob wir eine direkte root-Direktive ohne spezifischen Location-Block haben
        local has_root_directive
        has_root_directive=$(grep -E "^[[:space:]]*root[[:space:]]+${frontend_path};" "$conf_file")
        local has_location_block
        has_location_block=$(grep -E 'location[[:space:]]+/[^[:space:]/]+' "$conf_file" | grep -v '/api' | grep -v '/photos')
        
        if [ -n "$has_root_directive" ] && [ -z "$has_location_block" ]; then
            # Wenn wir eine direkte root-Direktive haben und keinen spezifischen Location-Block,
            # dann ist der Zugriff direkt auf / möglich
            path=""
        else
            # Sonst extrahiere den Pfad aus dem Location-Block
            path=$(grep -Eo 'location[[:space:]]+/[^[:space:]/]+' "$conf_file" | grep -v '/api' | head -n1 | awk '{print $2}')
            [ -z "$path" ] && path="/fotobox/"
        fi
    else
        path="/fotobox/"
    fi
    if [ "$mode" = "json" ]; then
        json_out "success" "$path" 0
    else
        echo "$path"
    fi
}

# set_nginx_webroot_path
set_nginx_webroot_path_txt_0001="Web-Root-Pfad erfolgreich gesetzt"
set_nginx_webroot_path_txt_0002="Fehler beim Setzen des Web-Root-Pfads"
set_nginx_webroot_path_txt_0003="Kein Web-Root-Pfad angegeben"

set_nginx_webroot_path() {
    # -----------------------------------------------------------------------
    # set_nginx_webroot_path
    # -----------------------------------------------------------------------
    # Funktion: Setzt den URL-Pfad in der aktiven Konfiguration
    # Parameter: $1 = Pfad, $2 = Modus (text|json)
    # Rückgabe: 0 = OK, >0 = Fehler
    local path="$1"
    local mode="${2:-text}"
    local conf_file=""
    if [ -L /etc/nginx/sites-enabled/fotobox ] && [ -f /etc/nginx/sites-enabled/fotobox ]; then
        conf_file="/etc/nginx/sites-available/fotobox"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        conf_file="/etc/nginx/sites-available/default"
    fi
    if [ -z "$path" ]; then log_or_json "$mode" "error" "$set_nginx_webroot_path_txt_0003" 2; return 2; fi
    backup_nginx_config "$conf_file" "$(get_nginx_config_type text)" "set_nginx_webroot_path" "$mode" || return 3
    sed -i -E "0,/location[[:space:]]+\/[a-zA-Z0-9_-]+\//s//location $path/" "$conf_file" || { log_or_json "$mode" "error" "$set_nginx_webroot_path_txt_0002" 4; return 4; }
    log_or_json "$mode" "success" "$set_nginx_webroot_path_txt_0001" 0
    chk_nginx_reload "$mode"
    return $?
}

get_nginx_config_type() {
    # -----------------------------------------------------------------------
    # get_nginx_config_type
    # -----------------------------------------------------------------------
    # Funktion: Gibt zurück, ob die Fotobox als eigene Site (external) oder in der Default-Site (internal) eingebunden ist.
    # Rückgabe: "internal" oder "external"
    # Optional: $1 = Modus (text|json)
    local mode="${1:-text}"
    local type="internal"
    if [ -L /etc/nginx/sites-enabled/fotobox ]; then
        type="external"
    fi
    if [ "$mode" = "json" ]; then
        json_out "success" "$type" 0
    else
        echo "$type"
    fi
}

set_nginx_config_type() {
    # -----------------------------------------------------------------------
    # set_nginx_config_type
    # -----------------------------------------------------------------------
    # Funktion: Setzt den Konfigurationstyp (internal/external) und passt die aktive Konfiguration/Symlinks an.
    # Parameter: $1 = Typ ("internal"|"external"), $2 = Modus (text|json)
    # Rückgabe: 0 = OK, >0 = Fehler
    local type="$1"
    local mode="${2:-text}"
    if [ "$type" = "external" ]; then
        # Externe Konfiguration aktivieren
        if [ ! -L /etc/nginx/sites-enabled/fotobox ]; then
            ln -s /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox || { log "Symlink für externe Konfiguration konnte nicht erstellt werden!"; return 1; }
        fi
        # Default deaktivieren (optional)
        # rm -f /etc/nginx/sites-enabled/default
    elif [ "$type" = "internal" ]; then
        # Externe Konfiguration deaktivieren
        rm -f /etc/nginx/sites-enabled/fotobox
        # Default aktivieren (optional)
        # ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    else
        log "Ungültiger Konfigurationstyp: $type"
        return 2
    fi
    chk_nginx_reload "$mode"
    return $?
}

# ===========================================================================
# Hilfsfunktionen zum lesen und setzen der gesamten NGINX-Konfigurationen am Stück
# ===========================================================================

get_nginx_status() {
    # -----------------------------------------------------------------------
    # get_nginx_status
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine strukturierte Übersicht der aktuellen Konfiguration zurück (JSON)
    # Optional: $1 = Modus (text|json)
    local mode="${1:-json}"
    local config_type port bind_addr server_name webroot_path url reachable
    config_type=$(get_nginx_config_type text)
    port=$(get_nginx_port text)
    bind_addr=$(get_nginx_bind_address text)
    server_name=$(get_nginx_server_name text)
    webroot_path=$(get_nginx_webroot_path text)
    url="http://$server_name:$port$webroot_path"
    reachable=true
    if [ "$mode" = "json" ]; then
        echo "{\"config_type\":\"$config_type\",\"bind_address\":\"$bind_addr\",\"port\":$port,\"server_name\":\"$server_name\",\"webroot_path\":\"$webroot_path\",\"reachable\":$reachable,\"url\":\"$url\"}"
    else
        echo "Typ: $config_type, Bind: $bind_addr, Port: $port, Name: $server_name, Pfad: $webroot_path, URL: $url"
    fi
}

conf_nginx_port() {
    # -----------------------------------------------------------------------
    # conf_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Fragt gewünschten Port und Abbruchentscheidung als Parameter ab, prüft Port und gibt Ergebnis zurück.
    # HINWEIS: Interaktive Schleifenlogik (z.B. wiederholte Portabfrage) wurde entfernt. Wiederholungen/Benutzereingaben müssen im aufrufenden Programm erfolgen!
    # Parameter: $1 = Modus (text|json), $2 = Port (Default: 80), $3 = Abbruchentscheidung (Default: N)
    # Rückgabe: 0 = Port frei, 1 = Fehler/Abbruch
    local mode="$1"
    local port="${2:-80}"
    local abort_decision="${3:-N}"
    log "$set_nginx_port_txt_0001"
    # Port prüfen (keine Schleife/Interaktivität mehr)
    if [[ -z "$port" ]]; then
        port=80
    elif ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_or_json "$mode" "error" "$(printf "$set_nginx_port_txt_0003" "$port")" 12
        return 1
    fi
    chk_nginx_port "$port" "$mode"
    if [ $? -eq 0 ]; then
        log_or_json "$mode" "success" "$(printf "$set_nginx_port_txt_0005" "$port")" 0
        
        # Port in der Konfiguration setzen
        local set_result
        set_result=$(set_nginx_port "$port" "$mode")
        local set_status=$?
        
        if [ $set_status -eq 0 ]; then
            # Firewall-Regeln wurden bereits in set_nginx_port aktualisiert
            return 0
        else
            return $set_status
        fi
    else
        log_or_json "$mode" "error" "$(printf "$set_nginx_port_txt_0006" "$port")" 13
        log_or_json "$mode" "prompt" "$set_nginx_port_txt_0007" 14
        if [[ "$abort_decision" =~ ^([jJ]|[yY])$ ]]; then
            log_or_json "$mode" "info" "$set_nginx_port_txt_0008" 1
            return 1
        fi
    fi
    return 1
}

get_nginx_template_file() {
    # -----------------------------------------------------------------------
    # get_nginx_template_file
    # -----------------------------------------------------------------------
    # Funktion: Gibt den Pfad zur NGINX-Template-Konfigurationsdatei zurück
    # Parameter: $1 - Template-Typ (default: fotobox)
    # Rückgabe: Pfad zur NGINX-Konfigurationsdatei
    # -----------------------------------------------------------------------
    local template_type="${1:-fotobox}"
    local conf_file=""
    local manage_folders_sh
    
    # Verwende manage_folders.sh, falls verfügbar
    manage_folders_sh="$(dirname "$0")/manage_folders.sh"
    
    if [ -f "$manage_folders_sh" ] && [ -x "$manage_folders_sh" ]; then
        # Hole NGINX-Konfigurationsverzeichnis
        local nginx_conf_dir
        nginx_conf_dir="$("$manage_folders_sh" get_nginx_conf_dir)"
        conf_file="$nginx_conf_dir/template_$template_type.conf"
        
        # Prüfe, ob die Datei existiert, sonst Fallback auf Standardvorlage
        if [ -f "$conf_file" ]; then
            echo "$conf_file"
            return 0
        else
            # Fallback: Datei aus conf-Verzeichnis kopieren, falls verfügbar
            local conf_dir
            conf_dir="$("$manage_folders_sh" config_dir)"
            if [ -f "$conf_dir/nginx-$template_type.conf" ]; then
                mkdir -p "$nginx_conf_dir"
                cp "$conf_dir/nginx-$template_type.conf" "$conf_file"
                log "NGINX-Template wurde in das neue Verzeichnis kopiert: $conf_file"
                echo "$conf_file"
                return 0
            fi
        fi
    fi
    
    # Fallback zur alten Methode
    echo "/opt/fotobox/conf/nginx-$template_type.conf"
    return 0
}

# ===========================================================================
# Verbesserter NGINX-Installationsfluss
# ===========================================================================

# Konstanten für improved_nginx_install
improved_nginx_install_txt_0001="Starte verbesserten NGINX-Installationsfluss..."
improved_nginx_install_txt_0002="NGINX ist nicht installiert. Installation wird gestartet."
improved_nginx_install_txt_0003="NGINX-Installation fehlgeschlagen!"
improved_nginx_install_txt_0004="NGINX erfolgreich installiert."
improved_nginx_install_txt_0005="NGINX verwendet Default-Konfiguration. Integriere Fotobox..."
improved_nginx_install_txt_0006="NGINX verwendet angepasste Konfiguration. Erstelle separate Konfiguration..."
improved_nginx_install_txt_0007="Erfolgreich: NGINX ist jetzt für die Fotobox konfiguriert."
improved_nginx_install_txt_0008="Fehler bei der NGINX-Konfiguration für die Fotobox."
improved_nginx_install_txt_0009="Unklarer Konfigurationsstatus bei NGINX."
improved_nginx_install_txt_0010="NGINX wurde erfolgreich für die Fotobox konfiguriert."
improved_nginx_install_txt_0011="Fotobox-URL: %s"
improved_nginx_install_txt_0012="NGINX ist installiert, wird aber nicht verwendet. Aktiviere NGINX..."
improved_nginx_install_txt_0013="Fehler beim Aktivieren von NGINX!"

improved_nginx_install() {
    # -----------------------------------------------------------------------
    # improved_nginx_install
    # -----------------------------------------------------------------------
    # Funktion: Führt die verbesserte NGINX-Installation durch
    # Parameter: $1 = Modus (text|json|auto), optional (Default: text)
    #            $2 = Port (optional, Default: 80)
    # Rückgabe: 0 = OK, >0 = Fehler
    # -----------------------------------------------------------------------
    local mode="${1:-text}"
    local port="${2:-80}"
    
    local is_interactive=1  # 0 = interaktiv, 1 = nicht-interaktiv
    if [ "$mode" = "auto" ]; then
        mode="text"
        is_interactive=0
    fi
    
    log_or_json "$mode" "info" "$improved_nginx_install_txt_0001" 0
    
    # Schritt 1: Prüfen, ob NGINX überhaupt installiert ist
    if ! is_nginx_available >/dev/null; then
        log_or_json "$mode" "warning" "$improved_nginx_install_txt_0002" 0
        # NGINX installieren
        if ! chk_installation_nginx "$mode" $is_interactive; then
            log_or_json "$mode" "error" "$improved_nginx_install_txt_0003" 1
            return 1
        fi
        log_or_json "$mode" "success" "$improved_nginx_install_txt_0004" 0
    fi
    
    # Schritt 2: Prüfen, ob NGINX aktiv ist
    if ! is_nginx_running >/dev/null; then
        log_or_json "$mode" "warning" "$improved_nginx_install_txt_0012" 0
        # NGINX aktivieren und starten
        if ! nginx_start "$mode"; then
            log_or_json "$mode" "error" "$improved_nginx_install_txt_0013" 2
            return 2
        fi
    fi
    
    # Schritt 3: Je nach aktuellem Zustand der NGINX-Konfiguration vorgehen
    local nginx_status
    nginx_status=$(is_nginx_default)
    
    if [ $? -eq 0 ]; then  # Default-Konfiguration
        log_or_json "$mode" "info" "$improved_nginx_install_txt_0005" 0
        
        # Option 1: NGINX hat nur Default-Konfiguration
        # In diesem Fall können wir entweder die Default-Konfiguration ergänzen
        # oder eine komplett neue Konfiguration anlegen

        # Variante: Neue Konfiguration erstellen und aktivieren
        local nginx_content
        local config_name="fotobox"
        local priority=50
        local template_path
        
        # Template-Datei suchen
        template_path=$(get_nginx_template_path "internal")
        
        if [ -n "$template_path" ] && [ -f "$template_path" ]; then
            # Template-Datei gefunden, Platzhalter ersetzen
            local temp_file="/tmp/nginx-fotobox-$$.conf"
            
            # Template anwenden mit Platzhalterersetzung
            apply_template "$template_path" "$temp_file" \
                "PORT=$port" \
                "SERVER_NAME=_" \
                "DOCUMENT_ROOT=/opt/fotobox/frontend" \
                "INDEX_FILE=start.html index.html" \
                "API_URL=http://127.0.0.1:5000"
                
            nginx_content=$(cat "$temp_file")
            rm -f "$temp_file"
        else
            log "Keine Template-Datei gefunden, verwende eingebautes Template"
            # Fallback auf einfaches Template
            nginx_content="server {
    listen $port;
    server_name _;

    root /opt/fotobox/frontend;
    index start.html index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000;
    }
}"
        fi
        
        # Anpassen des Ports im Template, falls nötig
        if [ "$port" != "80" ]; then
            nginx_template=$(echo "$nginx_template" | sed -E "s/listen [0-9]+;/listen $port;/")
        fi
        
        # Neue Konfiguration hinzufügen
        if ! nginx_add_config "$nginx_template" "$config_name" "$priority" "$mode"; then
            log_or_json "$mode" "error" "$improved_nginx_install_txt_0008" 3
            return 3
        fi
        
    elif [ $? -eq 1 ]; then  # Angepasste Konfiguration
        log_or_json "$mode" "info" "$improved_nginx_install_txt_0006" 0
        
        # Option 2: NGINX hat bereits angepasste Konfiguration
        # In diesem Fall erstellen wir eine separate Konfiguration mit einem alternativen Port
        
        # Alternativen Port wählen
        local alt_port=8080
        
        # Prüfen, ob der Standard-Port bereits belegt ist
        if [ "$port" = "80" ]; then
            # Wenn der Standard-Port verwendet werden soll, aber andere Konfigurationen bestehen,
            # verwenden wir einen alternativen Port
            port=$alt_port
        fi
        
        local template_path
        local nginx_template
        local temp_file="/tmp/nginx-fotobox-$$.conf"
        
        # Template-Datei für externe Konfiguration suchen
        template_path=$(get_nginx_template_path "external")
        
        if [ -n "$template_path" ] && [ -f "$template_path" ]; then
            # Template-Datei gefunden, Platzhalter ersetzen
            
            # Template anwenden mit Platzhalterersetzung
            apply_template "$template_path" "$temp_file" \
                "PORT=$port" \
                "SERVER_NAME=_" \
                "DOCUMENT_ROOT=/opt/fotobox/frontend" \
                "INDEX_FILE=start.html index.html" \
                "API_URL=http://127.0.0.1:5000"
                
            nginx_template=$(cat "$temp_file")
            rm -f "$temp_file"
        else
            log "Keine externe Template-Datei gefunden, verwende eingebautes Template"
            # Fallback auf Default-Template-Datei oder eingebautes Template
            local conf_src="$(get_nginx_template_file fotobox)"
            if [ -f "$conf_src" ]; then
                nginx_template=$(cat "$conf_src")
                # Port im Template anpassen
                nginx_template=$(echo "$nginx_template" | sed -E "s/listen [0-9]+;/listen $port;/")
            else
                # Eingebautes Fallback-Template
                nginx_template="server {
    listen $port;
    server_name _;

    root /opt/fotobox/frontend;
    index start.html index.html;
    
    # Cache-Kontrolle für Testphase
    add_header Cache-Control \"no-cache, no-store, must-revalidate\";
    add_header Pragma \"no-cache\";
    add_header Expires \"0\";
    add_header X-Fotobox-Test-Mode \"active\";

    # Saubere URLs für statische Seiten
    location = /capture {
        try_files /capture.html =404;
    }
    location = /gallery {
        try_files /gallery.html =404;
    }
    location = /settings {
        try_files /settings.html =404;
    }
    location = /installation {
        try_files /install.html =404;
    }
    location = /contact {
        try_files /contact.html =404;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }

    # API-Requests an das Backend weiterleiten
    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Fotos aus Backend-Verzeichnis bereitstellen
    location /photos/ {
        proxy_pass http://127.0.0.1:5000/photos/;
    }
}"
            fi
        fi
        
        # Konfiguration mit höherer Priorität hinzufügen (niedrigere Zahl)
        local config_name="fotobox"
        local priority=20  # Höhere Priorität für unsere Konfiguration
        
        if ! nginx_add_config "$nginx_template" "$config_name" "$priority" "$mode"; then
            log_or_json "$mode" "error" "$improved_nginx_install_txt_0008" 4
            return 4
        fi
        
    else  # Unklarer Status
        log_or_json "$mode" "warning" "$improved_nginx_install_txt_0009" 0
        
        # Option 3: Status unklar, wir versuchen externe Konfiguration
        if ! set_nginx_cnf_external "$mode"; then
            log_or_json "$mode" "error" "$improved_nginx_install_txt_0008" 5
            return 5
        fi
    fi
    
    # Schritt 4: Firewall-Regeln aktualisieren
    update_firewall_rules "$mode"
    
    # Schritt 5: NGINX-URL ermitteln und ausgeben
    local nginx_url
    nginx_url=$(get_nginx_url "text")
    log_or_json "$mode" "success" "$(printf "$improved_nginx_install_txt_0011" "$nginx_url")" 0
    
    log_or_json "$mode" "success" "$improved_nginx_install_txt_0010" 0
    return 0
}

# setup_nginx_service
setup_nginx_service_debug_0001="INFO: Starte NGINX-Server-Setup..."
setup_nginx_service_debug_0002="INFO: Prüfe NGINX-Installation..."
setup_nginx_service_debug_0003="ERROR: NGINX-Installation fehlgeschlagen!"
setup_nginx_service_debug_0004="INFO: NGINX-Server erfolgreich installiert."
setup_nginx_service_debug_0005="INFO: Versuche Start NGINX-Server ..."
setup_nginx_service_debug_0006="ERROR: NGINX-Server Start fehlgeschlagen!"
setup_nginx_service_debug_0007="INFO: NGINX-Server erfolgreich gestartet."
setup_nginx_service_debug_0008="INFO: NGINX-Server läuft bereits."
setup_nginx_service_debug_0009="INFO: Konfiguriere NGINX-Server neu..."
setup_nginx_service_debug_0010="ERROR: NGINX-Server Konfiguration fehlgeschlagen!"
setup_nginx_service_debug_0011="SUCCESS: NGINX-Server Konfiguration erfolgreich. Server neu gestartet."
setup_nginx_service_txt_0001="[/] Starte NGINX-Server-Setup..."
setup_nginx_service_txt_0002="NGINX-Server Installation fehlgeschlagen!"
setup_nginx_service_txt_0003="NGINX-Server erfolgreich installiert."
setup_nginx_service_txt_0004="[/] Starte NGINX-Server..."
setup_nginx_service_txt_0005="NGINX-Server Start fehlgeschlagen!"
setup_nginx_service_txt_0006="NGINX-Server erfolgreich gestartet."
setup_nginx_service_txt_0007="NGINX-Server läuft bereits."
setup_nginx_service_txt_0008="[/] Konfiguriere NGINX-Server..."
setup_nginx_service_txt_0009="NGINX-Server Einrichtung fehlgeschlagen!"
setup_nginx_service_txt_0010="NGINX-Server Einrichtung erfolgreich. Server neu gestartet."

setup_nginx_service() {
    # -----------------------------------------------------------------------
    # setup_nginx_service
    # -----------------------------------------------------------------------
    # Funktion: Führt die komplette Installation des NGINX-Servers durch
    # Parameter: $1 - Optional: CLI oder JSON-Ausgabe. Wenn nicht angegeben, 
    # .........       wird die Standardausgabe verwendet (CLI-Ausgabe)
    # Rückgabe: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local output_mode="${1:-cli}"  # Standardmäßig CLI-Ausgabe
    local service_pid

    # Eröffnungsmeldung im Debug Modus
    debug "$setup_nginx_service_debug_0001"

    # Schritt 1: NGINX-Installation prüfen
    if [ "$output_mode" = "json" ]; then
        _is_installed_nginx "J" || return 1
    else
        # Ausgabe im CLI-Modus, Spinner anzeigen
        echo -n "$setup_nginx_service_txt_0001"
        # Installation des Backend-Services im Hintergrund ausführen
        # und Spinner anzeigen
        debug "$setup_nginx_service_debug_0002"
        (_is_installed_nginx "J") &> /dev/null 2>&1 &
        service_pid=$!
        show_spinner "$service_pid" "dots"
        # Überprüfe, ob die Installation erfolgreich war
        if [ $? -ne 0 ]; then
            debug "$setup_nginx_service_debug_0003"
            print_error "$setup_nginx_service_txt_0002"
            return 1
        fi
        debug "$setup_nginx_service_debug_0004"
        print_success "$setup_nginx_service_txt_0003"
    fi

    # Schritt 2: Prüfen, ob NGINX aktiv ist
    if ! _is_running_nginx; then
        if [ "$output_mode" = "json" ]; then
            start_nginx || return 1
        else
            # Ausgabe im CLI-Modus, Spinner anzeigen
            echo -n "$setup_nginx_service_txt_0004"
            # Installation des Backend-Services im Hintergrund ausführen
            # und Spinner anzeigen
            debug "$setup_nginx_service_debug_0005"
            (start_nginx) &> /dev/null 2>&1 &
            service_pid=$!
            show_spinner "$service_pid" "dots"
            # Überprüfe, ob die Installation erfolgreich war
            if [ $? -ne 0 ]; then
                debug "$setup_nginx_service_debug_0006"
                print_error "$setup_nginx_service_txt_0005"
                return 1
            fi
            debug "$setup_nginx_service_debug_0007"
            print_success "$setup_nginx_service_txt_0006"
        fi
    else
        if [ "$output_mode" = "json" ]; then
            log "$setup_nginx_service_txt_0007"
        else
            debug "$setup_nginx_service_debug_0008"
            log "$setup_nginx_service_txt_0007"
            print_success "$setup_nginx_service_txt_0007"
        fi
    fi

    # Standard-Konfiguration in die Datenbank schreiben
    register_config_hierarchy "nginx" "NGINX-Konfigurationsmodul" "manage_nginx"
    set_port_nginx "$DEFAULT_HTTP_PORT"
    set_server_name_nginx "$DEFAULT_SERVER_NAME"
    set_frontend_dir_nginx "$DEFAULT_FRONTEND_DIR"  
    set_index_file_nginx "$DEFAULT_INDEX_FILE"
    set_api_url_nginx "$DEFAULT_API_URL"

    # Schritt 3: Je nach aktuellen Zustand der NGINX-Konfiguration vorgehen
    local nginx_status
    nginx_status=$(_is_default_nginx)
    if [ $? -eq 0 ]; then  # Default-Konfiguration
        if [ "$output_mode" = "json" ]; then
            write_config_file_nginx "local" || return 1
        else
            # Ausgabe im CLI-Modus, Spinner anzeigen
            echo -n "$setup_nginx_service_txt_0008"
            # Einrichtung NGINX-Server im Hintergrund ausführen
            # und Spinner anzeigen
            debug "$setup_nginx_service_debug_0009"
            # TODO: write_default_config_nginx im Hintergrund ausführen für DEBUG abgeschaltet
            #(write_config_file_nginx "local") &> /dev/null 2>&1 & 
            write_config_file_nginx "local"
            service_pid=$!
            show_spinner "$service_pid" "dots"
            # Überprüfe, ob die neue Konfiguration erfolgreich war
            if [ $? -ne 0 ]; then
                debug "$setup_nginx_service_debug_0010"
                print_error "$setup_nginx_service_txt_0009"
                return 1
            fi
            print_success "$setup_nginx_service_txt_0010"
        fi
    elif [ $? -eq 1 ]; then  # Angepasste Konfiguration
        if [ "$output_mode" = "json" ]; then
            write_external_config_nginx "json" || return 1
        else
            # Ausgabe im CLI-Modus, Spinner anzeigen
            echo -n "$setup_nginx_service_txt_0008"
            # Einrichtung NGINX-Server im Hintergrund ausführen
            # und Spinner anzeigen
            debug "$setup_nginx_service_debug_0009"
            # TODO: write_external_config_nginx im Hintergrund ausführen für DEBUG abgeschaltet
            #(write_config_file_nginx "external") &> /dev/null 2>&1 & 
            write_config_file_nginx "external"
            service_pid=$!
            show_spinner "$service_pid" "dots"
            # Überprüfe, ob die neue Konfiguration erfolgreich war
            if [ $? -ne 0 ]; then
                debug "$setup_nginx_service_debug_0010"
                print_error "$setup_nginx_service_txt_0009"
                return 1
            fi
            print_success "$setup_nginx_service_txt_0010"
        fi
    else  # Unklarer Status
        debug "$setup_nginx_service_debug_0010"
        log "$setup_nginx_service_txt_0009"
        return 9
    fi
}

# ============================================================================
# Test-Funktionen
# ============================================================================

# test_manage_nginx

test_manage_nginx() {
    # -----------------------------------------------------------------------
    # test_manage_nginx
    # -----------------------------------------------------------------------
    # Funktion: Führt einen Test des Moduls durch
    # Parameter: keine
    # Rückgabe: 0 = Erfolg, 1 = Fehler
    # -----------------------------------------------------------------------
    # Eröffnungsmeldung im Debug Modus
    debug "$(printf "$global_test_debug_0001" "manage_nginx.sh")"

    # Aktivieren des globalen Debug-Modus für die Tests
    # DEBUG_MOD_GLOBAL=1 

    # Allgemeiner Test des Moduls
    test_modul "manage_nginx.sh"
    if [ $? -ne 0 ]; then
        debug "$(printf "$global_test_debug_0002" "manage_nginx.sh")"
        return 1
    fi

    # Aktivieren des globalen Debug-Modus für die Tests
    local old_debug_mode
    old_debug_mode=$DEBUG_MOD_GLOBAL
    DEBUG_MOD_GLOBAL=1 

    # Hier können spezifische Tests für die Funktion implementiert werden
    # -----------------------------------------------------------------------
    # Test: chk_installation_nginx
    # test_function "manage_nginx_sh" "chk_installation_nginx" "J"
    # Test: chk_config_nginx
    test_function "manage_nginx_sh" "chk_config_nginx"
    # Test: chk_port_nginx
    test_function "manage_nginx_sh" "chk_port_nginx" 
    # Test: chk_port_nginx
    test_function "manage_nginx_sh" "chk_port_nginx" "$DEFAULT_HTTP_PORT"
    # Test: chk_port_nginx
    test_function "manage_nginx_sh" "chk_port_nginx" "$DEFAULT_HTTPS_PORT"
    # Test: chk_port_nginx
    test_function "manage_nginx_sh" "chk_port_nginx" "$DEFAULT_HTTP_PORT_FALLBACK"
    # Test: get_port_nginx
    test_function "manage_nginx_sh" "get_port_nginx" 
    # Test: set_port_nginx
    test_function "manage_nginx_sh" "set_port_nginx" "$DEFAULT_HTTP_PORT"
    # Test: get_server_name_nginx
    test_function "manage_nginx_sh" "get_server_name_nginx" 
    # Test: set_server_name_nginx
    test_function "manage_nginx_sh" "set_server_name_nginx" "$DEFAULT_SERVER_NAME"
    # Test: get_frontend_dir_nginx
    test_function "manage_nginx_sh" "get_frontend_dir_nginx" 
    # Test: set_frontend_dir_nginx
    test_function "manage_nginx_sh" "set_frontend_dir_nginx" "$DEFAULT_FRONTEND_DIR"
    # Test: get_index_file_nginx
    test_function "manage_nginx_sh" "get_index_file_nginx"
    # Test: set_index_file_nginx
    test_function "manage_nginx_sh" "set_index_file_nginx" "$DEFAULT_INDEX_FILES"
    # Test: get_api_url_nginx
    test_function "manage_nginx_sh" "get_api_url_nginx"
    # Test: set_api_url_nginx
    test_function "manage_nginx_sh" "set_api_url_nginx" "$DEFAULT_API_URL"
    # Test: stop_nginx
    test_function "manage_nginx_sh" "stop_nginx"
    # Test: start_nginx
    test_function "manage_nginx_sh" "start_nginx"
    # Test: reload_nginx
    test_function "manage_nginx_sh" "reload_nginx"
    # Test: backup_config_nginx
    test_function "manage_nginx_sh" "backup_config_nginx" "$(get_config_file_nginx "local")" "Testaufruf-Backup NGINX"
    # Test: write_config_file_nginx
    test_function "manage_nginx_sh" "write_config_file_nginx" "local"
    # Test: write_config_file_nginx
    test_function "manage_nginx_sh" "write_config_file_nginx" "internal"
    # Test: write_config_file_nginx
    test_function "manage_nginx_sh" "write_config_file_nginx" "external"
    # Test: setup_nginx_service
    test_function "manage_nginx_sh" "setup_nginx_service"

    # Meldung ausgeben, Test abgeschlossen ----------------------------------
    debug "$(printf "$global_test_debug_0003" "manage_nginx.sh")"

    # Tests abgeschlossen, wiederherstellen des globalen Debug-Modus  -------
    DEBUG_MOD_GLOBAL=$old_debug_mode
    return 0
}

# Prüfe, ob SQLite installiert ist 
if [ "$MANAGE_DATABASE_LOADED" -eq 1 ] && [ "$MANAGE_SETTINGS_LOADED" -eq 1 ]; then
    debug "INFO: Modul manage_nginx.sh wurde geladen. Prüfe Datenbank-Installation..."
    if _is_sqlite_installed; then
        # Einstellungshierarchie für Manage Modul erstellen
        debug "INFO: Starte Erstellung der Konfigurationshierarchie für NGINX-Modul..."
        register_config_hierarchy "nginx" "NGINX-Konfigurationsmodul" "manage_nginx"
    fi
fi
