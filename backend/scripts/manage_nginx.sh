#!/bin/bash
# ------------------------------------------------------------------------------
# manage_nginx.sh
# ------------------------------------------------------------------------------
# Funktion: Installiert, konfiguriert oder aktualisiert den Webserver (NGINX)
# Unterstützt: Installation, Anpassung, Update, Backup, Rollback.
# ------------------------------------------------------------------------------
# HINWEIS: Dieses Skript ist Bestandteil der Backend-Logik und darf nur im
# Unterordner 'backend/scripts/' abgelegt werden 
# ------------------------------------------------------------------------------

# Policy-Hinweis: Dieses Skript ist ein reines Funktions-/Modulskript und enthält keine main()-Funktion mehr.
# Die Nutzung als eigenständiges CLI-Programm ist nicht vorgesehen. Die Policy zur main()-Funktion gilt nur für Hauptskripte.

# ==============================================================================
# TODO-/Checkliste für manage_nginx.sh (Stand: 2025-06-04)
# ==============================================================================
# [x] Rückgabewerte/Fehlercodes aller Funktionen klar und einheitlich definieren
# [x] Rückgabewerte: Jede Funktion MUSS einen Fehlercode (0=OK, >0=Fehler) oder eine strukturierte Rückgabe (JSON für Python, String/Array/Zahl für Shell) liefern
# [x] LOG-Logik aus log_helper.sh überall konsistent verwenden (Logik vereinheitlichen)
# [x] Debug-Modus: DEBUG_MOD-Variable, zentrale debug()-Funktion in log_helper.sh ausgelagert, gezielte Debug-Ausgaben in kritischen Abschnitten/Funktionen
# [x] Alle Ausgaben (echo, printf, etc.) auf konsistente Rückmeldungen umstellen
# [x] Alle Benutzereingaben (read, select, etc.) durch Parameter/Defaults ersetzen
# [ ] Interaktive Schleifenlogik (z.B. Portwahl) in aufrufende Programme auslagern
# [ ] Funktionen einzeln testbar gestalten (Parameter statt globaler State)
# [ ] Seiteneffekte (z.B. globale Variablen) minimieren und dokumentieren
# [ ] DOKUMENTATIONSSTANDARD.md für alle Funktionsblöcke einhalten
# [ ] Abwärtskompatibilität für interaktive Nutzung sicherstellen
# [ ] Automatisierte Tests für alle Betriebsmodi vorsehen
# [ ] Unterstützung für verschiedene NGINX-Konfigurationen (Default, externe Site)
# [ ] Port Prüfung überarbeiten, ggf Abhänigkeit von lsof umgehen
# [ ] Debug-Modus für eigene JavaScript-Komponenten: Lokaler und globaler Debug-Schalter (analog zu Bash: DEBUG_MOD_LOCAL, DEBUG_MOD_GLOBAL) und zentrale debug()-Funktion für konsistente Debug-Ausgaben in zukünftigen JS-Modulen implementieren. (Aktuell nicht relevant, aber für spätere Frontend-Entwicklung vormerken)
# ==============================================================================

# ===========================================================================
# Funktionstexte (für spätere Mehrsprachigkeit als Konstanten ausgelagert)
# ===========================================================================

# chk_nginx_installation
chk_nginx_installation_txt_0001="NGINX nicht installiert, Installation wird gestartet."
chk_nginx_installation_txt_0002="NGINX ist nicht installiert. Jetzt installieren? [J/n]"
chk_nginx_installation_txt_0003="NGINX-Installation abgebrochen."
chk_nginx_installation_txt_0004="NGINX konnte nicht installiert werden!"
chk_nginx_installation_txt_0005="NGINX wurde erfolgreich installiert."
chk_nginx_installation_txt_0006="NGINX ist bereits installiert."

# chk_nginx_reload
chk_nginx_reload_txt_0001="NGINX-Konfiguration wird getestet ..."
chk_nginx_reload_txt_0002="NGINX-Konfiguration erfolgreich neu geladen."
chk_nginx_reload_txt_0003="NGINX konnte nicht neu geladen werden!"
chk_nginx_reload_txt_0004="Fehler in der NGINX-Konfiguration!"
chk_nginx_reload_txt_0005="Fehler in der NGINX-Konfiguration! Bitte prüfen."

# chk_nginx_port
chk_nginx_port_txt_0001="Port-Prüfung starten ..."
chk_nginx_port_txt_0002="lsof ist nicht verfügbar. Portprüfung nicht möglich."
chk_nginx_port_txt_0003="Port %s ist belegt."
chk_nginx_port_txt_0004="Port %s ist frei."

# chk_nginx_activ
chk_nginx_activ_txt_0001="Nur Default-Site ist aktiv."
chk_nginx_activ_txt_0002="Weitere Sites sind aktiv."
chk_nginx_activ_txt_0003="Konnte aktive NGINX-Sites nicht eindeutig ermitteln."
chk_nginx_activ_txt_0004="NGINX-Status: Nur Default-Site aktiv."
chk_nginx_activ_txt_0005="NGINX-Status: Mehrere Sites aktiv."
chk_nginx_activ_txt_0006="Fehler: NGINX-Site-Status unklar."

# get_nginx_url
get_nginx_url_txt_0001="Konnte IP-Adresse nicht ermitteln."
get_nginx_url_txt_0002="Ermittelte Fotobox-URL: %s"

# set_nginx_port
set_nginx_port_txt_0001="Portauswahl für Fotobox-Weboberfläche gestartet."
set_nginx_port_txt_0002="Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:"
set_nginx_port_txt_0003="Ungültige Eingabe bei Portauswahl: %s"
set_nginx_port_txt_0004="Ungültige Eingabe. Bitte nur Zahlen verwenden."
set_nginx_port_txt_0005="Port %s wird verwendet."
set_nginx_port_txt_0006="Port %s ist bereits belegt. Bitte anderen Port wählen."
set_nginx_port_txt_0007="Abbrechen? [j/N]"
set_nginx_port_txt_0008="Portauswahl abgebrochen."

# set_nginx_cnf_internal
set_nginx_cnf_internal_txt_0001="Integration der Fotobox in Default-NGINX-Konfiguration gestartet."
set_nginx_cnf_internal_txt_0002="Default-Konfiguration nicht gefunden: %s"
set_nginx_cnf_internal_txt_0003="Backup der Default-Konfiguration fehlgeschlagen!"
set_nginx_cnf_internal_txt_0004="Backup der Default-Konfiguration nach %s"
set_nginx_cnf_internal_txt_0005="Fotobox-Block in Default-Konfiguration eingefügt."
set_nginx_cnf_internal_txt_0006="Fotobox-Block bereits in Default-Konfiguration vorhanden."
set_nginx_cnf_internal_txt_0007="NGINX-Konfiguration konnte nach Integration nicht neu geladen werden!"

# set_nginx_cnf_external
set_nginx_cnf_external_txt_0001="Externe Fotobox-NGINX-Konfiguration wird eingerichtet."
set_nginx_cnf_external_txt_0002="Backup der bestehenden Fotobox-Konfiguration fehlgeschlagen!"
set_nginx_cnf_external_txt_0003="Backup der bestehenden Fotobox-Konfiguration nach %s"
set_nginx_cnf_external_txt_0004="Kopieren der Fotobox-Konfiguration fehlgeschlagen!"
set_nginx_cnf_external_txt_0005="Fotobox-Konfiguration nach %s kopiert."
set_nginx_cnf_external_txt_0006="Symlink für Fotobox-Konfiguration konnte nicht erstellt werden!"
set_nginx_cnf_external_txt_0007="Symlink für Fotobox-Konfiguration erstellt."
set_nginx_cnf_external_txt_0008="NGINX-Konfiguration konnte nach externer Integration nicht neu geladen werden!"

# main
main_txt_0001="Starte NGINX-Installation (manage_nginx.sh)"
main_txt_0002="Fehler: NGINX-Installation fehlgeschlagen"
main_txt_0003="Fehler: Portwahl fehlgeschlagen"
main_txt_0004="Fehler: NGINX-Konfiguration fehlgeschlagen"
main_txt_0005="NGINX-Installation abgeschlossen."
main_txt_0006="Starte NGINX-Update (manage_nginx.sh)"
main_txt_0007="Fehler: NGINX-Update fehlgeschlagen"
main_txt_0008="NGINX-Update abgeschlossen."
main_txt_0009="Starte NGINX-Backup (manage_nginx.sh)"
main_txt_0010="Backup der Konfiguration nach %s"
main_txt_0011="Fehler: Backup fehlgeschlagen!"
main_txt_0012="Keine Konfiguration zum Sichern gefunden."
main_txt_0013="Starte NGINX-Rollback (manage_nginx.sh)"
main_txt_0014="Rollback durchgeführt: %s -> %s"
main_txt_0015="Fehler: Rollback fehlgeschlagen!"
main_txt_0016="Kein Backup für Rollback gefunden."
main_txt_0017="Verwendung: $0 [--json] {install|update|backup|rollback}"
main_txt_0018="Fehler: Falsche Skriptverwendung (manage_nginx.sh)"
# ===========================================================================

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

json_out() {
    # -----------------------------------------------------------------------
    # Hilfsfunktion JSON-Ausgabe
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine JSON-formatierte Antwort aus
    # Parameter: $1 = Status (success, error, info, prompt), 
    # .........  $2 = Nachricht, $3 = optionaler Code
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

chk_nginx_installation() {
    # -----------------------------------------------------------------------
    # chk_nginx_installation
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX installiert ist, installiert ggf. nach (mit Rückfrage)
    # Rückgabe: 0 = OK, 1 = Installation abgebrochen, 2 = Installationsfehler
    local mode="$1"
    local install_decision="${2:-J}"
    # Prüfen, ob nginx installiert ist
    if ! command -v nginx >/dev/null 2>&1; then  # Falls nicht installiert
        log "$chk_nginx_installation_txt_0001"
        if [ "$mode" = "json" ]; then
            json_out "prompt" "$chk_nginx_installation_txt_0002" 10
            # Kein read mehr, Entscheidung kommt als Parameter
        else
            log "$chk_nginx_installation_txt_0002"
            # Kein read mehr, Entscheidung kommt als Parameter
        fi
        # Prüfen, ob der Nutzer die Installation abgelehnt hat
        if [[ "$install_decision" =~ ^([nN])$ ]]; then
            log "$chk_nginx_installation_txt_0003"
            if [ "$mode" = "json" ]; then
                json_out "error" "$chk_nginx_installation_txt_0003" 1
            else
                log "$chk_nginx_installation_txt_0003"
            fi
            return 1
        fi
        # Installation von nginx durchführen
        apt-get update -qq && apt-get install -y -qq nginx
        # Nach der Installation erneut prüfen, ob nginx jetzt verfügbar ist
        if ! command -v nginx >/dev/null 2>&1; then
            log "$chk_nginx_installation_txt_0004"
            if [ "$mode" = "json" ]; then
                json_out "error" "$chk_nginx_installation_txt_0004" 2
            else
                log "$chk_nginx_installation_txt_0004"
            fi
            return 2
        fi
        log "$chk_nginx_installation_txt_0005"
        if [ "$mode" = "json" ]; then
            json_out "success" "$chk_nginx_installation_txt_0005" 0
        else
            log "$chk_nginx_installation_txt_0005"
        fi
    else
        # nginx ist bereits installiert
        log "$chk_nginx_installation_txt_0006"
    fi
    return 0
}

chk_nginx_reload() {
    # -----------------------------------------------------------------------
    # chk_nginx_reload
    # -----------------------------------------------------------------------
    # Funktion: Testet die NGINX-Konfiguration und lädt sie neu, falls fehlerfrei.
    local mode="$1"
    log "${chk_nginx_reload_txt_0001}"
    # Prüfen, ob die NGINX-Konfiguration fehlerfrei ist
    if nginx -t; then
        # Konfiguration ist fehlerfrei
        if systemctl reload nginx; then
            # Reload erfolgreich
            log "${chk_nginx_reload_txt_0002}"
            if [ "$mode" = "json" ]; then
                json_out "success" "${chk_nginx_reload_txt_0002}" 0
            else
                log "${chk_nginx_reload_txt_0002}"
            fi
            return 0
        else
            # Reload fehlgeschlagen, Fehlerdetails ausgeben
            local status_out
            status_out=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 10)
            log "NGINX konnte nicht neu geladen werden! Statusauszug:\n$status_out"
            if [ "$mode" = "json" ]; then
                json_out "error" "NGINX konnte nicht neu geladen werden!" 2
            else
                log "NGINX konnte nicht neu geladen werden!"
            fi
            return 2
        fi
    else
        # Konfiguration fehlerhaft
        log "${chk_nginx_reload_txt_0004}"
        if [ "$mode" = "json" ]; then
            json_out "error" "${chk_nginx_reload_txt_0004}" 1
        else
            log "${chk_nginx_reload_txt_0004}"
        fi
        return 1
    fi
}

chk_nginx_port() {
    # -----------------------------------------------------------------------
    # chk_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob der gewünschte Port belegt ist oder frei.
    local port=${1:-80}
    log "${chk_nginx_port_txt_0001}"
    # Prüfen, ob lsof verfügbar ist
    if ! command -v lsof >/dev/null 2>&1; then
        # lsof nicht verfügbar
        log "${chk_nginx_port_txt_0002}"
        if [ "$MODE" = "json" ]; then
            json_out "error" "${chk_nginx_port_txt_0002}" 2
        else
            log "${chk_nginx_port_txt_0002}"
        fi
        return 2
    fi
    # Prüfen, ob der Port belegt ist
    if lsof -i :$port | grep LISTEN > /dev/null; then
        # Port ist belegt
        log "${chk_nginx_port_txt_0003}"
        return 1
    else
        # Port ist frei
        log "${chk_nginx_port_txt_0004}"
        return 0
    fi
}

chk_nginx_activ() {
    # -----------------------------------------------------------------------
    # chk_nginx_activ
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX nur im Default-Modus läuft oder weitere Sites aktiv sind.
    local mode="$1"
    local enabled_sites
    enabled_sites=$(ls /etc/nginx/sites-enabled 2>/dev/null | wc -l)
    # Prüfen, ob nur die Default-Site aktiv ist
    if [ "$enabled_sites" -eq 1 ] && [ -f /etc/nginx/sites-enabled/default ]; then
        # Nur Default-Site aktiv
        if [ "$mode" = "json" ]; then
            json_out "success" "Nur Default-Site ist aktiv." 0
        else
            log "Nur Default-Site ist aktiv."
        fi
        log "${chk_nginx_activ_txt_0004}"
        return 0
    elif [ "$enabled_sites" -gt 1 ]; then
        # Mehrere Sites aktiv
        if [ "$mode" = "json" ]; then
            json_out "success" "Weitere Sites sind aktiv." 1
        else
            log "Weitere Sites sind aktiv."
        fi
        log "${chk_nginx_activ_txt_0005}"
        return 1
    else
        # Status unklar
        if [ "$mode" = "json" ]; then
            json_out "error" "Konnte aktive NGINX-Sites nicht eindeutig ermitteln." 2
        else
            log "Konnte aktive NGINX-Sites nicht eindeutig ermitteln."
        fi
        log "Fehler: NGINX-Site-Status unklar."
        return 2
    fi
}

get_nginx_url() {
    # -----------------------------------------------------------------------
    # get_nginx_url
    # -----------------------------------------------------------------------
    # Funktion: Ermittelt die tatsächlich aktive URL der Fotobox anhand der NGINX-Konfiguration.
    local mode="$1"
    local url=""
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}')
    # Prüfen, ob eine IP-Adresse ermittelt werden konnte
    if [ -z "$ip_addr" ]; then
        # IP-Adresse konnte nicht ermittelt werden
        if [ "$mode" = "json" ]; then
            json_out "error" "${get_nginx_url_txt_0001}" 1
        else
            log "${get_nginx_url_txt_0001}"
        fi
        return 1
    fi
    # Prüfen, ob eigene Fotobox-Site oder Default-Konfiguration aktiv ist
    if [ -L /etc/nginx/sites-enabled/fotobox ] && grep -q "listen" /etc/nginx/sites-enabled/fotobox; then
        local port
        port=$(grep -Eo 'listen[[:space:]]+[0-9.]*(:[0-9]+)?' /etc/nginx/sites-enabled/fotobox | head -n1 | grep -Eo '[0-9]+$')
        [ -z "$port" ] && port=80
        url="http://$ip_addr:$port/"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        local port
        port=$(grep -Eo 'listen[[:space:]]+[0-9.]*(:[0-9]+)?' /etc/nginx/sites-enabled/default | head -n1 | grep -Eo '[0-9]+$')
        [ -z "$port" ] && port=80
        url="http://$ip_addr/fotobox/"
    else
        url="http://$ip_addr:80/ oder http://$ip_addr/fotobox/"
    fi
    log "${get_nginx_url_txt_0002}"
    if [ "$mode" = "json" ]; then
        json_out "success" "$url" 0
    else
        log "$url"
    fi
    return 0
}

set_nginx_port() {
    # -----------------------------------------------------------------------
    # set_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Fragt gewünschten Port und Abbruchentscheidung als Parameter ab, prüft Port und gibt Ergebnis zurück.
    # HINWEIS: Interaktive Schleifenlogik (z.B. wiederholte Portabfrage) wurde entfernt. Wiederholungen/Benutzereingaben müssen im aufrufenden Programm erfolgen!
    local mode="$1"
    local port="${2:-80}"
    local abort_decision="${3:-N}"
    log "$set_nginx_port_txt_0001"
    # Port prüfen (keine Schleife/Interaktivität mehr)
    if [[ -z "$port" ]]; then
        port=80
    elif ! [[ "$port" =~ ^[0-9]+$ ]]; then
        # Ungültige Eingabe
        log "$(printf "$set_nginx_port_txt_0003" "$port")"
        if [ "$mode" = "json" ]; then
            json_out "error" "$set_nginx_port_txt_0004" 12
        else
            log "$set_nginx_port_txt_0004"
        fi
        return 1
    fi
    # Port prüfen
    chk_nginx_port "$port"
    if [ $? -eq 0 ]; then
        # Port ist frei und wird verwendet
        log "$(printf "$set_nginx_port_txt_0005" "$port")"
        if [ "$mode" = "json" ]; then
            json_out "success" "$(printf "$set_nginx_port_txt_0005" "$port")" 0
        else
            log "$(printf "$set_nginx_port_txt_0005" "$port")"
        fi
        export FOTOBOX_PORT=$port
        return 0
    else
        # Port ist belegt, ggf. Abbruch prüfen
        log "$(printf "$set_nginx_port_txt_0006" "$port")"
        if [ "$mode" = "json" ]; then
            json_out "error" "$(printf "$set_nginx_port_txt_0006" "$port")" 13
            json_out "prompt" "$set_nginx_port_txt_0007" 14
            # Kein read mehr, Entscheidung kommt als Parameter
        else
            log "$(printf "$set_nginx_port_txt_0006" "$port")"
            log "$set_nginx_port_txt_0007"
            # Kein read mehr, Entscheidung kommt als Parameter
        fi
        if [[ "$abort_decision" =~ ^([jJ]|[yY])$ ]]; then
            # Abbruch durch Benutzer/Parameter
            log "$set_nginx_port_txt_0008"
            return 1
        fi
    fi
    return 1
}

set_nginx_cnf_internal() {
    # -----------------------------------------------------------------------
    # set_nginx_cnf_internal
    # -----------------------------------------------------------------------
    # Funktion: Integriert Fotobox in die Default-Konfiguration von NGINX
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Backup-Fehler, 3 = Reload-Fehler
    local mode="$1"
    local default_conf="/etc/nginx/sites-available/default"
    local backup="/opt/fotobox/backup/default.bak.$(date +%Y%m%d%H%M%S)"

    log "${set_nginx_cnf_internal_txt_0001}"
    # Prüfen, ob Default-Konfiguration existiert
    if [ ! -f "$default_conf" ]; then
        log "${set_nginx_cnf_internal_txt_0002}"
        if [ "$mode" = "json" ]; then
            json_out "error" "${set_nginx_cnf_internal_txt_0002}" 1
        else
            log "${set_nginx_cnf_internal_txt_0002}"
        fi
        return 1
    fi

    # Backup der Default-Konfiguration anlegen
    cp "$default_conf" "$backup" || { log "${set_nginx_cnf_internal_txt_0003}"; if [ "$mode" = "json" ]; then json_out "error" "Backup fehlgeschlagen!" 2; else log "Backup fehlgeschlagen!"; fi; return 2; }
    log "${set_nginx_cnf_internal_txt_0004}"
    if [ "$mode" = "json" ]; then
        json_out "success" "${set_nginx_cnf_internal_txt_0004}" 0
    else
        log "${set_nginx_cnf_internal_txt_0004}"
    fi

    # Prüfen, ob Fotobox-Block bereits vorhanden ist
    if ! grep -q "# Fotobox-Integration BEGIN" "$default_conf"; then
        sed -i '/^}/i \\n    # Fotobox-Integration BEGIN\n    location /fotobox/ {\n        alias /opt/fotobox/frontend/;\n        index start.html index.html;\n    }\n    location /fotobox/api/ {\n        proxy_pass http://127.0.0.1:5000/;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n    }\n    # Fotobox-Integration END\n' "$default_conf"
        log "${set_nginx_cnf_internal_txt_0005}"
        if [ "$mode" = "json" ]; then
            json_out "success" "${set_nginx_cnf_internal_txt_0005}" 0
        else
            log "${set_nginx_cnf_internal_txt_0005}"
        fi
    else
        log "${set_nginx_cnf_internal_txt_0006}"
        if [ "$mode" = "json" ]; then
            json_out "info" "${set_nginx_cnf_internal_txt_0006}" 0
        else
            log "${set_nginx_cnf_internal_txt_0006}"
        fi
    fi

    # Konfiguration neu laden
    chk_nginx_reload "$mode" || { log "NGINX-Konfiguration konnte nach Integration nicht neu geladen werden!"; return 3; }
    return 0
}

set_nginx_cnf_external() {
    # -----------------------------------------------------------------------
    # set_nginx_cnf_external
    # -----------------------------------------------------------------------
    # Funktion: Legt eigene Fotobox-Konfiguration an, bindet sie ein 
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Backup-Fehler, 
    # ........  3 = Symlink-Fehler, 4 = Reload-Fehler
    local mode="$1"
    local nginx_dst="/etc/nginx/sites-available/fotobox"
    local conf_src="/opt/fotobox/conf/nginx-fotobox.conf"
    local backup="/opt/fotobox/backup/nginx-fotobox.conf.bak.$(date +%Y%m%d%H%M%S)"

    log "${set_nginx_cnf_external_txt_0001}"
    # Prüfen, ob bereits eine Zielkonfiguration existiert
    if [ -f "$nginx_dst" ]; then
        cp "$nginx_dst" "$backup" || { log "${set_nginx_cnf_external_txt_0002}"; if [ "$mode" = "json" ]; then json_out "error" "Backup fehlgeschlagen!" 2; else log "Backup fehlgeschlagen!"; fi; return 2; }
        log "${set_nginx_cnf_external_txt_0003}"
        if [ "$mode" = "json" ]; then
            json_out "success" "${set_nginx_cnf_external_txt_0003}" 0
        else
            log "${set_nginx_cnf_external_txt_0003}"
        fi
    fi

    # Neue Konfiguration kopieren
    cp "$conf_src" "$nginx_dst" || { log "${set_nginx_cnf_external_txt_0004}"; if [ "$mode" = "json" ]; then json_out "error" "Kopieren der Konfiguration fehlgeschlagen!" 1; else log "Kopieren der Konfiguration fehlgeschlagen!"; fi; return 1; }
    log "${set_nginx_cnf_external_txt_0005}"

    # Prüfen, ob Symlink existiert, sonst anlegen
    if [ ! -L /etc/nginx/sites-enabled/fotobox ]; then
        ln -s "$nginx_dst" /etc/nginx/sites-enabled/fotobox || { log "${set_nginx_cnf_external_txt_0006}"; if [ "$mode" = "json" ]; then json_out "error" "Symlink konnte nicht erstellt werden!" 3; else log "Symlink konnte nicht erstellt werden!"; fi; return 3; }
        log "${set_nginx_cnf_external_txt_0007}"
        if [ "$mode" = "json" ]; then
            json_out "success" "${set_nginx_cnf_external_txt_0007}" 0
        else
            log "${set_nginx_cnf_external_txt_0007}"
        fi
    fi

    # Konfiguration neu laden
    chk_nginx_reload "$mode" || { log "NGINX-Konfiguration konnte nach externer Integration nicht neu geladen werden!"; return 4; }
    return 0
}

# Logging-Hilfsskript einbinden 
if [ -f "$(dirname "$0")/log_helper.sh" ]; then
    source "$(dirname "$0")/log_helper.sh"
else
    echo "WARNUNG: Logging-Hilfsskript nicht gefunden! Logging deaktiviert." >&2
    log() { :; }
fi

# Ausgabe-Modus prüfen (Text oder JSON)
MODE="text"
if [ "$1" = "--json" ]; then
    MODE="json"
    shift
fi

# Skript-Start
# main "$@"
