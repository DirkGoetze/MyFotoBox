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

# ==========================================================================='
# Hilfsfunktionen
# ==========================================================================='

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
    if ! command -v nginx >/dev/null 2>&1; then
        if [ "$mode" = "json" ]; then
            json_out "prompt" "NGINX ist nicht installiert. Jetzt installieren? [J/n]" 10
            read -r antwort
        else
            echo "NGINX ist nicht installiert. Jetzt installieren? [J/n]"
            read -r antwort
        fi
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            if [ "$mode" = "json" ]; then
                json_out "error" "NGINX-Installation abgebrochen." 1
            else
                echo "NGINX-Installation abgebrochen."
            fi
            return 1
        fi
        apt-get update -qq && apt-get install -y -qq nginx
        if ! command -v nginx >/dev/null 2>&1; then
            if [ "$mode" = "json" ]; then
                json_out "error" "NGINX konnte nicht installiert werden!" 2
            else
                echo "NGINX konnte nicht installiert werden!"
            fi
            return 2
        fi
        if [ "$mode" = "json" ]; then
            json_out "success" "NGINX wurde erfolgreich installiert." 0
        else
            echo "NGINX wurde erfolgreich installiert."
        fi
    fi
    return 0
}

chk_nginx_reload() {
    # -----------------------------------------------------------------------
    # chk_nginx_reload
    # -----------------------------------------------------------------------
    # Funktion: Testet die NGINX-Konfiguration und lädt sie neu, falls fehlerfrei
    # Rückgabe: 0 = OK, 1 = Syntaxfehler, 2 = Reload-Fehler
    local mode="$1"

    if nginx -t; then
        if systemctl reload nginx; then
            if [ "$mode" = "json" ]; then
                json_out "success" "NGINX-Konfiguration erfolgreich neu geladen." 0
            else
                echo "NGINX-Konfiguration erfolgreich neu geladen."
            fi
            return 0
        else
            if [ "$mode" = "json" ]; then
                json_out "error" "NGINX konnte nicht neu geladen werden!" 2
            else
                echo "NGINX konnte nicht neu geladen werden!"
            fi
            return 2
        fi
    else
        if [ "$mode" = "json" ]; then
            json_out "error" "Fehler in der NGINX-Konfiguration! Bitte prüfen." 1
        else
            echo "Fehler in der NGINX-Konfiguration! Bitte prüfen."
        fi
        return 1
    fi
}

chk_nginx_port() {
    # -----------------------------------------------------------------------
    # chk_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob der gewünschte Port (Default: 80) belegt ist
    # Rückgabe: 0 = frei, 1 = belegt
    local port=${1:-80}

    if lsof -i :$port | grep LISTEN > /dev/null; then
        return 1
    else
        return 0
    fi
}

chk_nginx_activ() {
    # -----------------------------------------------------------------------
    # chk_nginx_activ
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX nur im Default-Modus läuft oder weitere Sites aktiv sind
    # Rückgabe: 0 = nur default aktiv, 1 = weitere Sites aktiv, 2 = Fehler
    local mode="$1"
    local enabled_sites

    enabled_sites=$(ls /etc/nginx/sites-enabled 2>/dev/null | wc -l)
    if [ "$enabled_sites" -eq 1 ] && [ -f /etc/nginx/sites-enabled/default ]; then
        if [ "$mode" = "json" ]; then
            json_out "success" "Nur Default-Site ist aktiv." 0
        else
            echo "Nur Default-Site ist aktiv."
        fi
        log "NGINX-Status: Nur Default-Site aktiv."
        return 0
    elif [ "$enabled_sites" -gt 1 ]; then
        if [ "$mode" = "json" ]; then
            json_out "success" "Weitere Sites sind aktiv." 1
        else
            echo "Weitere Sites sind aktiv."
        fi
        log "NGINX-Status: Mehrere Sites aktiv."
        return 1
    else
        if [ "$mode" = "json" ]; then
            json_out "error" "Konnte aktive NGINX-Sites nicht eindeutig ermitteln." 2
        else
            echo "Konnte aktive NGINX-Sites nicht eindeutig ermitteln."
        fi
        log "Fehler: NGINX-Site-Status unklar."
        return 2
    fi
}

get_nginx_url() {
    # -----------------------------------------------------------------------
    # get_nginx_url
    # -----------------------------------------------------------------------
    # Funktion: Ermittelt die tatsächlich aktive URL der Fotobox anhand
    # der NGINX-Konfiguration (Default-Integration oder eigene Site)
    # Rückgabe: Gibt die URL als String aus
    local mode="$1"
    local url=""
    local ip_addr

    ip_addr=$(hostname -I | awk '{print $1}')

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

    log "Ermittelte Fotobox-URL: $url"
    if [ "$mode" = "json" ]; then
        json_out "success" "$url" 0
    else
        echo "$url"
    fi
}

# ==========================================================================='
# Einstellungen (Systemanpassungen)
# ==========================================================================='

set_nginx_port() {
    # -----------------------------------------------------------------------
    # set_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Fragt Nutzer nach Port, prüft Verfügbarkeit, gibt Port zurück
    # Rückgabe: 0 = Port gesetzt, 1 = Abbruch
    local mode="$1"
    local port=80

    while true; do
        if [ "$mode" = "json" ]; then
            json_out "prompt" "Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:" 11
            read -r eingabe
        else
            echo "Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:"
            read -r eingabe
        fi
        if [ -z "$eingabe" ]; then
            port=80
        elif [[ "$eingabe" =~ ^[0-9]+$ ]]; then
            port=$eingabe
        else
            if [ "$mode" = "json" ]; then
                json_out "error" "Ungültige Eingabe. Bitte nur Zahlen verwenden." 12
            else
                echo "Ungültige Eingabe. Bitte nur Zahlen verwenden."
            fi
            continue
        fi
        chk_nginx_port "$port"
        if [ $? -eq 0 ]; then
            if [ "$mode" = "json" ]; then
                json_out "success" "Port $port wird verwendet." 0
            else
                echo "Port $port wird verwendet."
            fi
            export FOTOBOX_PORT=$port
            return 0
        else
            if [ "$mode" = "json" ]; then
                json_out "error" "Port $port ist bereits belegt. Bitte anderen Port wählen." 13
                json_out "prompt" "Abbrechen? [j/N]" 14
                read -r abbruch
            else
                echo "Port $port ist bereits belegt. Bitte anderen Port wählen."
                echo "Abbrechen? [j/N]"
                read -r abbruch
            fi
            if [[ "$abbruch" =~ ^([jJ]|[yY])$ ]]; then
                return 1
            fi
        fi
    done
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

    if [ ! -f "$default_conf" ]; then
        if [ "$mode" = "json" ]; then
            json_out "error" "Default-Konfiguration nicht gefunden: $default_conf" 1
        else
            echo "Default-Konfiguration nicht gefunden: $default_conf"
        fi
        return 1
    fi

    cp "$default_conf" "$backup" || { if [ "$mode" = "json" ]; then json_out "error" "Backup fehlgeschlagen!" 2; else echo "Backup fehlgeschlagen!"; fi; return 2; }
    if [ "$mode" = "json" ]; then
        json_out "success" "Backup der Default-Konfiguration nach $backup" 0
    else
        echo "Backup der Default-Konfiguration nach $backup"
    fi

    if ! grep -q "# Fotobox-Integration BEGIN" "$default_conf"; then
        sed -i '/^}/i \\n    # Fotobox-Integration BEGIN\n    location /fotobox/ {\n        alias /opt/fotobox/frontend/;\n        index start.html index.html;\n    }\n    location /fotobox/api/ {\n        proxy_pass http://127.0.0.1:5000/;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n    }\n    # Fotobox-Integration END\n' "$default_conf"
        if [ "$mode" = "json" ]; then
            json_out "success" "Fotobox-Block in Default-Konfiguration eingefügt." 0
        else
            echo "Fotobox-Block in Default-Konfiguration eingefügt."
        fi
    else
        if [ "$mode" = "json" ]; then
            json_out "info" "Fotobox-Block bereits in Default-Konfiguration vorhanden." 0
        else
            echo "Fotobox-Block bereits in Default-Konfiguration vorhanden."
        fi
    fi

    chk_nginx_reload "$mode" || return 3
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

    if [ -f "$nginx_dst" ]; then
        cp "$nginx_dst" "$backup" || { if [ "$mode" = "json" ]; then json_out "error" "Backup fehlgeschlagen!" 2; else echo "Backup fehlgeschlagen!"; fi; return 2; }
        if [ "$mode" = "json" ]; then
            json_out "success" "Backup der bestehenden Fotobox-Konfiguration nach $backup" 0
        else
            echo "Backup der bestehenden Fotobox-Konfiguration nach $backup"
        fi
    fi

    cp "$conf_src" "$nginx_dst" || { if [ "$mode" = "json" ]; then json_out "error" "Kopieren der Konfiguration fehlgeschlagen!" 1; else echo "Kopieren der Konfiguration fehlgeschlagen!"; fi; return 1; }

    if [ ! -L /etc/nginx/sites-enabled/fotobox ]; then
        ln -s "$nginx_dst" /etc/nginx/sites-enabled/fotobox || { if [ "$mode" = "json" ]; then json_out "error" "Symlink konnte nicht erstellt werden!" 3; else echo "Symlink konnte nicht erstellt werden!"; fi; return 3; }
        if [ "$mode" = "json" ]; then
            json_out "success" "Symlink für Fotobox-Konfiguration erstellt." 0
        else
            echo "Symlink für Fotobox-Konfiguration erstellt."
        fi
    fi

    chk_nginx_reload "$mode" || return 4
    return 0
}




main() {
    # -----------------------------------------------------------------------
    # main
    # -----------------------------------------------------------------------
    # Funktion: Steuert den Aufruf des Skripts (install, update, backup)

    case "$1" in
        install)
            log "Starte NGINX-Installation (manage_nginx.sh)"
            chk_nginx_installation "$MODE" || { log "Fehler: NGINX-Installation fehlgeschlagen"; exit 1; }
            set_nginx_port "$MODE" || { log "Fehler: Portwahl fehlgeschlagen"; exit 1; }
            set_nginx_cnf_external "$MODE" || { log "Fehler: NGINX-Konfiguration fehlgeschlagen"; exit 1; }
            log "NGINX-Installation abgeschlossen."
            ;;
        update)
            log "Starte NGINX-Update (manage_nginx.sh)"
            chk_nginx_installation "$MODE" || { log "Fehler: NGINX-Update fehlgeschlagen"; exit 1; }
            set_nginx_cnf_external "$MODE" || { log "Fehler: NGINX-Konfiguration fehlgeschlagen"; exit 1; }
            log "NGINX-Update abgeschlossen."
            ;;
        backup)
            log "Starte NGINX-Backup (manage_nginx.sh)"
            local nginx_dst="/etc/nginx/sites-available/fotobox"
            local backup="/opt/fotobox/backup/nginx-fotobox.conf.bak.$(date +%Y%m%d%H%M%S)"
            if [ -f "$nginx_dst" ]; then
                cp "$nginx_dst" "$backup" && { echo "Backup der Konfiguration nach $backup"; log "Backup der Konfiguration nach $backup"; } || { echo "Backup fehlgeschlagen!"; log "Fehler: Backup fehlgeschlagen!"; }
            else
                echo "Keine Konfiguration zum Sichern gefunden."
                log "Keine Konfiguration zum Sichern gefunden."
            fi
            ;;
        rollback)
            log "Starte NGINX-Rollback (manage_nginx.sh)"
            local backup_dir="/opt/fotobox/backup"
            local nginx_dst="/etc/nginx/sites-available/fotobox"
            local last_backup
            last_backup=$(ls -1t "$backup_dir"/nginx-fotobox.conf.bak.* 2>/dev/null | head -n1)
            if [ -n "$last_backup" ] && [ -f "$last_backup" ]; then
                cp "$last_backup" "$nginx_dst" && { echo "Rollback durchgeführt: $last_backup -> $nginx_dst"; log "Rollback durchgeführt: $last_backup -> $nginx_dst"; } || { echo "Rollback fehlgeschlagen!"; log "Fehler: Rollback fehlgeschlagen!"; }
                chk_nginx_reload
            else
                echo "Kein Backup für Rollback gefunden."
                log "Kein Backup für Rollback gefunden."
            fi
            ;;
        *)
            if [ "$MODE" = "json" ]; then
                json_out "error" "Verwendung: $0 [--json] {install|update|backup|rollback}" 99
            else
                echo "Verwendung: $0 [--json] {install|update|backup|rollback}"
            fi
            log "Fehler: Falsche Skriptverwendung (manage_nginx.sh)"
            exit 1
            ;;
    esac
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
main "$@"
