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
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt
# Debug-Modus für dieses Skript (lokales Flag)

# ===========================================================================

# ===========================================================================
# Funktionen zur Template-Verarbeitung
# ===========================================================================

# apply_template
apply_template_txt_0001="Template-Datei nicht gefunden: %s"
apply_template_txt_0002="Template-Datei erfolgreich verarbeitet"
apply_template_txt_0003="Ersetzung ausgeführt: %s"

apply_template() {
    # -----------------------------------------------------------------------
    # apply_template
    # -----------------------------------------------------------------------
    # Funktion: Lädt eine Template-Datei und ersetzt Platzhalter
    # Parameter: $1 = Pfad zur Template-Datei
    #            $2 = Ausgabepfad
    #            Rest: Name-Wert-Paare für Ersetzungen (NAME=value)
    # Rückgabe:  0 = OK, 1 = Template nicht gefunden
    # Seiteneffekte: Schreibt die verarbeitete Template-Datei
    # -----------------------------------------------------------------------
    local template_file="$1"
    local output_file="$2"
    shift 2
    
    if [ ! -f "$template_file" ]; then
        log "$(printf "$apply_template_txt_0001" "$template_file")"
        return 1
    fi
    
    # Template in Variable laden
    local content
    content=$(cat "$template_file")
    
    # Ersetzungen durchführen
    for pair in "$@"; do
        local name="${pair%%=*}"
        local value="${pair#*=}"
        # Platzhalter im Format {{NAME}} ersetzen
        content=$(echo "$content" | sed "s|{{$name}}|$value|g")
    done
    
    # In Ausgabedatei schreiben
    echo "$content" > "$output_file"
    return 0
}

# get_nginx_template_path
get_nginx_template_path_txt_0001="Template-Datei nicht gefunden: %s"
get_nginx_template_path_txt_0002="manage_folders.sh nicht verfügbar"
get_nginx_template_path_txt_0003="Template-Datei im Fallback-Pfad nicht gefunden: %s"

get_nginx_template_path() {
    # -----------------------------------------------------------------------
    # get_nginx_template_path
    # -----------------------------------------------------------------------
    # Funktion: Ermittelt den Pfad zu einer bestimmten NGINX-Template-Datei
    # Parameter: $1 = Template-Typ (local, internal, external)
    # Rückgabe:  Pfad zur NGINX-Template-Datei
    # -----------------------------------------------------------------------
    local template_type="${1:-internal}"
    local manage_folders_sh
    local template_file
    
    # Verwende manage_folders.sh, falls verfügbar
    manage_folders_sh="$(dirname "$0")/manage_folders.sh"
    
    if [ -f "$manage_folders_sh" ] && [ -x "$manage_folders_sh" ]; then
        # Hole NGINX-Konfigurationsverzeichnis
        local nginx_conf_dir
        nginx_conf_dir="$("$manage_folders_sh" get_nginx_conf_dir)"
        template_file="$nginx_conf_dir/template_${template_type}.conf"
        
        # Prüfe, ob die Datei existiert
        if [ ! -f "$template_file" ]; then
            log "$(printf "$get_nginx_template_path_txt_0001" "$template_file")"
            template_file="" # Leerer String als Fehlerindikator
        fi
    else
        log "$get_nginx_template_path_txt_0002"
        
        # Fallback: Versuche manuelle Pfaderstellung
        if [ -n "$DEFAULT_DIR_CONF_NGINX" ]; then
            template_file="$DEFAULT_DIR_CONF_NGINX/template_${template_type}.conf"
        else
            template_file="" # Leerer String als Fehlerindikator
        fi
        
        # Prüfe, ob die Datei existiert im Fallback
        if [ -n "$template_file" ] && [ ! -f "$template_file" ]; then
            log "$(printf "$get_nginx_template_path_txt_0003" "$template_file")"
            template_file="" # Leerer String als Fehlerindikator
        fi
    fi
    
    echo "$template_file"
}

# ===========================================================================
# Externe Funktionen zur NGINX-Verwaltung
# ===========================================================================

# backup_nginx_config
backup_nginx_config_txt_0001="Backup und Metadaten angelegt: %s"
backup_nginx_config_txt_0002="Backup fehlgeschlagen: %s"
backup_nginx_config_txt_0003="Fallback-Backup-Verzeichnis wird verwendet"

backup_nginx_config() {
    # -----------------------------------------------------------------------
    # backup_nginx_config
    # -----------------------------------------------------------------------
    # Funktion: Legt ein Backup der übergebenen NGINX-Konfigurationsdatei im zentralen Backup-Ordner an
    #           und erzeugt eine maschinenlesbare Metadaten-Datei (.meta.json)
    # Parameter: $1 = Quellpfad der Konfigurationsdatei
    #            $2 = Konfigurationstyp (internal/external)
    #            $3 = Aktion (z.B. set_port)
    #            $4 = Modus (text|json)
    # Rückgabe:  0 = OK, 1 = Fehler
    # Seiteneffekte: Schreibt Backup- und Metadaten-Dateien ins Dateisystem
    local src="$1"
    local config_type="$2"
    local action="$3"
    local mode="${4:-text}"

    local backup_dir
    local manage_folders_sh
    
    # Verwende manage_folders.sh, falls verfügbar
    manage_folders_sh="$(dirname "$0")/manage_folders.sh"
    if [ -f "$manage_folders_sh" ] && [ -x "$manage_folders_sh" ]; then
        # Hole Backup-Verzeichnis über manage_folders.sh mit der neuen get_nginx_backup_dir Funktion
        backup_dir="$("$manage_folders_sh" get_nginx_backup_dir)"
    else
        # Fallback zur alten Methode
        backup_dir="$FALLBACK_DIR_BACKUP_NGINX"
        # Falls auch FALLBACK_DIR_BACKUP_NGINX nicht definiert ist
        [ -z "$backup_dir" ] && backup_dir="/opt/fotobox/backup/nginx"
        log "$backup_nginx_config_txt_0003: $backup_dir"
    fi
    
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local base_name
    base_name="$(basename "$src")"
    local backup_file="$backup_dir/${base_name}.bak.$timestamp"
    local meta_file="$backup_file.meta.json"
    
    # Verwende manage_folders.sh zur Verzeichniserstellung, falls verfügbar
    if [ -f "$manage_folders_sh" ] && [ -x "$manage_folders_sh" ]; then
        # Die Verzeichniserstellung wird automatisch durch get_nginx_backup_dir erledigt,
        # aber um sicherzugehen, verwenden wir create_directory
        "$manage_folders_sh" create_directory "$backup_dir"
    else
        mkdir -p "$backup_dir"
    fi
    if cp "$src" "$backup_file"; then
        # Metadaten über Template-Datei erstellen
        local template_file
        template_file="$(get_nginx_template_path "backup_file.meta.json")"
        
        # Falls Template nicht gefunden wurde, verwende Fallback-Pfad direkt
        if [ -z "$template_file" ]; then
            local nginx_conf_dir
            if [ -f "$manage_folders_sh" ] && [ -x "$manage_folders_sh" ]; then
                nginx_conf_dir="$("$manage_folders_sh" get_nginx_conf_dir)"
            else
                nginx_conf_dir="${DEFAULT_DIR_CONF_NGINX:-/opt/fotobox/conf/nginx}"
            fi
            template_file="$nginx_conf_dir/template_backup_file.meta.json"
        fi
        
        # Wende Template an
        apply_template "$template_file" "$meta_file" \
            "timestamp=$timestamp" \
            "source=$src" \
            "backup=$backup_file" \
            "config_type=$config_type" \
            "action=$action"
        if [ "$mode" = "json" ]; then
            json_out "success" "$(printf "$backup_nginx_config_txt_0001" "$backup_file")" 0
        else
            log "$(printf "$backup_nginx_config_txt_0001" "$backup_file")"
        fi
        return 0
    else
        if [ "$mode" = "json" ]; then
            json_out "error" "$(printf "$backup_nginx_config_txt_0002" "$src")" 1
        else
            log "$(printf "$backup_nginx_config_txt_0002" "$src")"
        fi
        return 1
    fi
}

# chk_nginx_installation
chk_nginx_installation_txt_0001="NGINX nicht installiert, Installation wird gestartet."
chk_nginx_installation_txt_0002="NGINX ist nicht installiert. Jetzt installieren? [J/n]"
chk_nginx_installation_txt_0003="NGINX-Installation abgebrochen."
chk_nginx_installation_txt_0004="NGINX konnte nicht installiert werden!"
chk_nginx_installation_txt_0005="NGINX wurde erfolgreich installiert."
chk_nginx_installation_txt_0006="NGINX ist bereits installiert."

chk_nginx_installation() {
    # -----------------------------------------------------------------------
    # chk_nginx_installation
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX installiert ist, installiert ggf. nach (mit Rückfrage)
    # Parameter: $1 = Modus (text|json)
    #            $2 = Installationsentscheidung (J/n), optional (Default: J)
    # Rückgabe:  0 = OK, 1 = Installation abgebrochen, 2 = Installationsfehler
    # Seiteneffekte: Installiert ggf. nginx über apt-get
    local mode="$1"
    local install_decision="${2:-J}"
    # Prüfen, ob nginx installiert ist
    if ! command -v nginx >/dev/null 2>&1; then  # Falls nicht installiert
        log_or_json "$mode" "prompt" "$chk_nginx_installation_txt_0002" 10
        # Kein read mehr, Entscheidung kommt als Parameter
        # Prüfen, ob der Nutzer die Installation abgelehnt hat
        if [[ "$install_decision" =~ ^([nN])$ ]]; then
            log_or_json "$mode" "error" "$chk_nginx_installation_txt_0003" 1
            return 1
        fi
        # Installation von nginx durchführen mit manage_update.py, das die Abhängigkeiten aus conf/requirements_system.inf verwendet
        python3 "$SCRIPT_DIR/../manage_update.py" --install-system-deps
        # Nach der Installation erneut prüfen, ob nginx jetzt verfügbar ist
        if ! command -v nginx >/dev/null 2>&1; then
            log_or_json "$mode" "error" "$chk_nginx_installation_txt_0004" 2
            return 2
        fi
        log_or_json "$mode" "success" "$chk_nginx_installation_txt_0005" 0
    else
        log "$chk_nginx_installation_txt_0006"
    fi
    return 0
}

# chk_nginx_reload
chk_nginx_reload_txt_0001="NGINX-Konfiguration wird getestet ..."
chk_nginx_reload_txt_0002="NGINX-Konfiguration erfolgreich neu geladen."
chk_nginx_reload_txt_0003="NGINX konnte nicht neu geladen werden! Statusauszug:"
chk_nginx_reload_txt_0004="Fehler in der NGINX-Konfiguration!"
chk_nginx_reload_txt_0005="Fehler in der NGINX-Konfiguration! Bitte prüfen."
chk_nginx_reload_txt_0006="NGINX konnte nicht neu geladen werden!"

chk_nginx_reload() {
    # -----------------------------------------------------------------------
    # chk_nginx_reload
    # -----------------------------------------------------------------------
    # Funktion: Testet die NGINX-Konfiguration und lädt sie neu, falls fehlerfrei.
    # Parameter: $1 = Modus (text|json)
    # Rückgabe:  0 = OK, 1 = Konfigurationsfehler, 2 = Reload-Fehler
    # Seiteneffekte: Reload von nginx (systemctl reload nginx)
    local mode="$1"
    log "${chk_nginx_reload_txt_0001}"
    # Prüfen, ob die NGINX-Konfiguration fehlerfrei ist
    if nginx -t; then
        # Konfiguration ist fehlerfrei
        if systemctl reload nginx; then
            # Reload erfolgreich
            log_or_json "$mode" "success" "${chk_nginx_reload_txt_0002}" 0
            return 0
        else
            # Reload fehlgeschlagen, Fehlerdetails ausgeben
            local status_out
            status_out=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 10)
            log_or_json "$mode" "error" "${chk_nginx_reload_txt_0006}" 2
            return 2
        fi
    else
        # Konfiguration fehlerhaft
        log_or_json "$mode" "error" "${chk_nginx_reload_txt_0004}" 1
        return 1
    fi
}

# chk_nginx_port
chk_nginx_port_txt_0001="Port-Prüfung starten ..."
chk_nginx_port_txt_0002="lsof ist nicht verfügbar. Portprüfung nicht möglich."
chk_nginx_port_txt_0003="Port %s ist belegt."
chk_nginx_port_txt_0004="Port %s ist frei."
chk_nginx_port_txt_0005="Portprüfung abgeschlossen."
chk_nginx_port_txt_0006="Fehler bei der Portprüfung."

chk_nginx_port() {
    # -----------------------------------------------------------------------
    # chk_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob der gewünschte Port belegt ist oder frei.
    # Parameter: $1 = Port (Default: 80)
    #            $2 = Modus (text|json), optional (Standard: text)
    # Rückgabe:  0 = frei, 1 = belegt, 2 = Fehler
    # Seiteneffekte: keine
    local port=${1:-80}
    local mode="${2:-text}"
    # Prüfen, ob lsof, ss oder netstat verfügbar ist
    if command -v lsof >/dev/null 2>&1; then
        # Prüfen, ob der Port belegt ist (lsof)
        if lsof -i :$port | grep LISTEN > /dev/null; then
            log "$(printf "$chk_nginx_port_txt_0003" "$port")"
            return 1
        else
            log "$(printf "$chk_nginx_port_txt_0004" "$port")"
            return 0
        fi
    elif command -v ss >/dev/null 2>&1; then
        # Prüfen, ob der Port belegt ist (ss)
        if ss -tuln | grep -E ":$port[[:space:]]" > /dev/null; then
            log "$(printf "$chk_nginx_port_txt_0003" "$port")"
            return 1
        else
            log "$(printf "$chk_nginx_port_txt_0004" "$port")"
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # Prüfen, ob der Port belegt ist (netstat)
        if netstat -tuln | grep -E ":$port[[:space:]]" > /dev/null; then
            log "$(printf "$chk_nginx_port_txt_0003" "$port")"
            return 1
        else
            log "$(printf "$chk_nginx_port_txt_0004" "$port")"
            return 0
        fi
    else
        # Keines der Tools verfügbar
        log_or_json "$mode" "error" "${chk_nginx_port_txt_0002} (lsof/ss/netstat fehlen)" 2
        return 2
    fi
    # log "${chk_nginx_port_txt_0005}"  # ENTFERNT
}

# chk_nginx_activ
chk_nginx_activ_txt_0001="Nur Default-Site ist aktiv."
chk_nginx_activ_txt_0002="Weitere Sites sind aktiv."
chk_nginx_activ_txt_0003="Konnte aktive NGINX-Sites nicht eindeutig ermitteln."
chk_nginx_activ_txt_0004="NGINX-Status: Nur Default-Site aktiv."
chk_nginx_activ_txt_0005="NGINX-Status: Mehrere Sites aktiv."
chk_nginx_activ_txt_0006="Fehler: NGINX-Site-Status unklar."
chk_nginx_activ_txt_0007="Statusabfrage abgeschlossen."
chk_nginx_activ_txt_0008="Fehler bei der Statusabfrage."

chk_nginx_activ() {
    # -----------------------------------------------------------------------
    # chk_nginx_activ
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX nur im Default-Modus läuft oder weitere Sites aktiv sind.
    # Parameter: $1 = Modus (text|json)
    # Rückgabe:  0 = Nur Default-Site aktiv, 1 = Mehrere Sites aktiv, 2 = Status unklar
    # Seiteneffekte: keine
    local mode="$1"
    local enabled_sites
    enabled_sites=$(ls /etc/nginx/sites-enabled 2>/dev/null | wc -l)
    # Prüfen, ob nur die Default-Site aktiv ist
    if [ "$enabled_sites" -eq 1 ] && [ -f /etc/nginx/sites-enabled/default ]; then
        # Nur Default-Site aktiv
        log_or_json "$mode" "success" "${chk_nginx_activ_txt_0001}" 0
        log "${chk_nginx_activ_txt_0004}"
        log "${chk_nginx_activ_txt_0007}"
        return 0
    elif [ "$enabled_sites" -gt 1 ]; then
        # Mehrere Sites aktiv
        log_or_json "$mode" "success" "${chk_nginx_activ_txt_0002}" 1
        log "${chk_nginx_activ_txt_0005}"
        log "${chk_nginx_activ_txt_0007}"
        return 1
    else
        # Status unklar
        log_or_json "$mode" "error" "${chk_nginx_activ_txt_0003}" 2
        log "${chk_nginx_activ_txt_0006}"
        log "${chk_nginx_activ_txt_0008}"
        return 2
    fi
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

# set_nginx_cnf_internal
set_nginx_cnf_internal_txt_0001="Integration der Fotobox in Default-NGINX-Konfiguration gestartet."
set_nginx_cnf_internal_txt_0002="Default-Konfiguration nicht gefunden: %s"
set_nginx_cnf_internal_txt_0003="Backup der Default-Konfiguration fehlgeschlagen!"
set_nginx_cnf_internal_txt_0004="Backup der Default-Konfiguration nach %s"
set_nginx_cnf_internal_txt_0005="Fotobox-Block in Default-Konfiguration eingefügt."
set_nginx_cnf_internal_txt_0006="Fotobox-Block bereits in Default-Konfiguration vorhanden."
set_nginx_cnf_internal_txt_0007="NGINX-Konfiguration konnte nach Integration nicht neu geladen werden!"

set_nginx_cnf_internal() {
    # -----------------------------------------------------------------------
    # set_nginx_cnf_internal
    # -----------------------------------------------------------------------
    # Funktion: Integriert Fotobox in die Default-Konfiguration von NGINX
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Backup-Fehler, 4 = Reload-Fehler
    local mode="$1"
    local default_conf="/etc/nginx/sites-available/default"

    log "${set_nginx_cnf_internal_txt_0001}"
    # Prüfen, ob Default-Konfiguration existiert
    if [ ! -f "$default_conf" ]; then
        log_or_json "$mode" "error" "$set_nginx_cnf_internal_txt_0002" 1
        return 1
    fi

    # Backup der Default-Konfiguration anlegen
    backup_nginx_config "$default_conf" "internal" "set_nginx_cnf_internal" "$mode" || return 2
    log_or_json "$mode" "success" "$set_nginx_cnf_internal_txt_0004" 0
    # Prüfen, ob Fotobox-Block bereits vorhanden ist
    if ! grep -q "# Fotobox-Integration BEGIN" "$default_conf"; then
        # Bestimme den Frontend-Pfad über manage_folders
        local frontend_path
        if [ -f "$(dirname "$0")/manage_folders.sh" ] && [ -x "$(dirname "$0")/manage_folders.sh" ]; then
            frontend_path="$($(dirname "$0")/manage_folders.sh get_frontend_dir)"
        else
            frontend_path="${DEFAULT_DIR_FRONTEND:-/opt/fotobox/frontend}"
        fi
        
        sed -i "/^}/i \\n    # Fotobox-Integration BEGIN\\n    location /fotobox/ {\\n        alias $frontend_path/;\\n        index start.html index.html;\\n    }\\n    location /fotobox/api/ {\\n        proxy_pass http://127.0.0.1:5000/;\\n        proxy_set_header Host \$host;\\n        proxy_set_header X-Real-IP \$remote_addr;\\n        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\\n        proxy_set_header X-Forwarded-Proto \$scheme;\\n    }\\n    # Fotobox-Integration END\\n" "$default_conf"
        log_or_json "$mode" "success" "$set_nginx_cnf_internal_txt_0005" 0
    else
        log_or_json "$mode" "info" "$set_nginx_cnf_internal_txt_0006" 0
    fi
    local reload_result
    reload_result=$(chk_nginx_reload "$mode")
    local reload_status=$?
    
    if [ $reload_status -ne 0 ]; then 
        log_or_json "$mode" "error" "NGINX-Konfiguration konnte nach Integration nicht neu geladen werden!" 4
        return 4
    fi
    
    # Firewall-Regeln aktualisieren
    update_firewall_rules "$mode"
    
    return 0
}

# set_nginx_cnf_external
set_nginx_cnf_external_txt_0001="Externe Fotobox-NGINX-Konfiguration wird eingerichtet."
set_nginx_cnf_external_txt_0002="Backup der bestehenden Fotobox-Konfiguration fehlgeschlagen!"
set_nginx_cnf_external_txt_0003="Backup der bestehenden Fotobox-Konfiguration nach %s"
set_nginx_cnf_external_txt_0004="Kopieren der Fotobox-Konfiguration fehlgeschlagen!"
set_nginx_cnf_external_txt_0005="Fotobox-Konfiguration nach %s kopiert."
set_nginx_cnf_external_txt_0006="Symlink für Fotobox-Konfiguration konnte nicht erstellt werden!"
set_nginx_cnf_external_txt_0007="Symlink für Fotobox-Konfiguration erstellt."
set_nginx_cnf_external_txt_0008="NGINX-Konfiguration konnte nach externer Integration nicht neu geladen werden!"

set_nginx_cnf_external() {
    # -----------------------------------------------------------------------
    # set_nginx_cnf_external
    # -----------------------------------------------------------------------
    # Funktion: Legt eigene Fotobox-Konfiguration an, bindet sie ein 
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Backup-Fehler, 4 = Reload-Fehler, 10 = Symlink-Fehler
    local mode="$1"
    local nginx_dst="/etc/nginx/sites-available/fotobox"
    local conf_src="$(get_nginx_template_file fotobox)"

    log "${set_nginx_cnf_external_txt_0001}"
    # Prüfen, ob bereits eine Zielkonfiguration existiert
    if [ -f "$nginx_dst" ]; then
        backup_nginx_config "$nginx_dst" "external" "set_nginx_cnf_external" "$mode" || return 2
        log_or_json "$mode" "success" "$set_nginx_cnf_external_txt_0003" 0
    fi
    # Neue Konfiguration kopieren
    cp "$conf_src" "$nginx_dst" || { log_or_json "$mode" "error" "$set_nginx_cnf_external_txt_0004" 1; return 1; }
    log_or_json "$mode" "success" "$set_nginx_cnf_external_txt_0005" 0
    # Prüfen, ob Symlink existiert, sonst anlegen
    if [ ! -L /etc/nginx/sites-enabled/fotobox ]; then
        ln -s "$nginx_dst" /etc/nginx/sites-enabled/fotobox || { log_or_json "$mode" "error" "$set_nginx_cnf_external_txt_0006" 10; return 10; }
        log_or_json "$mode" "success" "$set_nginx_cnf_external_txt_0007" 0
    fi
    local reload_result
    reload_result=$(chk_nginx_reload "$mode")
    local reload_status=$?
    
    if [ $reload_status -ne 0 ]; then 
        log_or_json "$mode" "error" "$set_nginx_cnf_external_txt_0008" 4
        return 4
    fi
    
    # Firewall-Regeln aktualisieren
    update_firewall_rules "$mode"
    
    return 0
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

# is_nginx_available
is_nginx_available_txt_0001="NGINX ist installiert."
is_nginx_available_txt_0002="NGINX ist nicht installiert."
is_nginx_available_txt_0003="Prüfe NGINX-Installation..."

is_nginx_available() {
    # -----------------------------------------------------------------------
    # is_nginx_available
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX installiert ist
    # Parameter: $1 = Modus (text|json), optional (Default: text)
    # Rückgabe:  0 = NGINX installiert, 1 = NGINX nicht installiert
    # Seiteneffekte: keine
    
    local mode="${1:-text}"
    
    log_debug "${is_nginx_available_txt_0003}"
    
    if command -v nginx >/dev/null 2>&1; then
        # NGINX ist installiert
        log_or_json "$mode" "success" "${is_nginx_available_txt_0001}" 0
        return 0
    else
        # NGINX ist nicht installiert
        log_or_json "$mode" "info" "${is_nginx_available_txt_0002}" 1
        return 1
    fi
}

# is_nginx_running
is_nginx_running_txt_0001="NGINX-Dienst läuft."
is_nginx_running_txt_0002="NGINX-Dienst ist gestoppt."
is_nginx_running_txt_0003="Prüfe NGINX-Status..."

is_nginx_running() {
    # -----------------------------------------------------------------------
    # is_nginx_running
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob der NGINX-Dienst aktiv läuft
    # Parameter: $1 = Modus (text|json), optional (Default: text)
    # Rückgabe:  0 = NGINX läuft, 1 = NGINX gestoppt/Fehler
    # Seiteneffekte: keine
    
    local mode="${1:-text}"
    
    log_debug "${is_nginx_running_txt_0003}"
    
    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if is_nginx_available >/dev/null; then
        # NGINX ist installiert, jetzt Status prüfen
        if systemctl is-active nginx >/dev/null 2>&1; then
            # NGINX läuft
            log_or_json "$mode" "success" "${is_nginx_running_txt_0001}" 0
            return 0
        else
            # NGINX ist gestoppt oder hat Fehler
            log_or_json "$mode" "warning" "${is_nginx_running_txt_0002}" 1
            return 1
        fi
    else
        # NGINX ist nicht installiert
        log_or_json "$mode" "warning" "${is_nginx_available_txt_0002}" 1
        return 1
    fi
}

# is_nginx_default
is_nginx_default_txt_0001="NGINX verwendet Default-Konfiguration."
is_nginx_default_txt_0002="NGINX verwendet angepasste Konfiguration."
is_nginx_default_txt_0003="NGINX-Konfigurationsstatus unklar."
is_nginx_default_txt_0004="Prüfe NGINX-Konfigurationsstatus..."

is_nginx_default() {
    # -----------------------------------------------------------------------
    # is_nginx_default
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX in Default-Konfiguration vorliegt
    # Parameter: $1 = Modus (text|json), optional (Default: text)
    # Rückgabe:  0 = Default-Konfiguration, 1 = angepasste Konfiguration, 2 = Status unklar
    # Seiteneffekte: keine
    
    local mode="${1:-text}"
    
    log_debug "${is_nginx_default_txt_0004}"
    
    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if ! is_nginx_available >/dev/null; then
        log_or_json "$mode" "warning" "${is_nginx_available_txt_0002}" 2
        return 2
    fi
    
    local enabled_sites
    enabled_sites=$(ls /etc/nginx/sites-enabled 2>/dev/null | wc -l)
    
    # Prüfen, ob nur die Default-Site aktiv ist
    if [ "$enabled_sites" -eq 1 ] && [ -f /etc/nginx/sites-enabled/default ]; then
        # Nur Default-Site aktiv
        log_or_json "$mode" "success" "${is_nginx_default_txt_0001}" 0
        return 0
    elif [ "$enabled_sites" -ge 1 ]; then
        # Eine oder mehrere Sites aktiv, die nicht der Default entsprechen
        log_or_json "$mode" "info" "${is_nginx_default_txt_0002}" 1
        return 1
    else
        # Status unklar
        log_or_json "$mode" "warning" "${is_nginx_default_txt_0003}" 2
        return 2
    fi
}

# nginx_start
nginx_start_txt_0001="Starte NGINX-Dienst..."
nginx_start_txt_0002="NGINX-Dienst erfolgreich gestartet."
nginx_start_txt_0003="NGINX-Dienst konnte nicht gestartet werden!"
nginx_start_txt_0004="NGINX ist nicht installiert."

nginx_start() {
    # -----------------------------------------------------------------------
    # nginx_start
    # -----------------------------------------------------------------------
    # Funktion: Startet den NGINX-Dienst
    # Parameter: $1 = Modus (text|json), optional (Default: text)
    # Rückgabe:  0 = erfolgreich gestartet, 1 = Fehler
    # Seiteneffekte: Startet den NGINX-Dienst (systemctl start nginx)
    
    local mode="${1:-text}"
    
    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if ! is_nginx_available >/dev/null; then
        log_or_json "$mode" "error" "${nginx_start_txt_0004}" 1
        return 1
    fi
    
    log_or_json "$mode" "info" "${nginx_start_txt_0001}" 0
    
    # NGINX-Dienst starten
    if systemctl start nginx; then
        # Start erfolgreich
        log_or_json "$mode" "success" "${nginx_start_txt_0002}" 0
        return 0
    else
        # Start fehlgeschlagen, Fehlerdetails ausgeben
        local status_out
        status_out=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 10)
        log_or_json "$mode" "error" "${nginx_start_txt_0003}" 1
        log "$status_out"
        return 1
    fi
}

# nginx_stop
nginx_stop_txt_0001="Stoppe NGINX-Dienst..."
nginx_stop_txt_0002="NGINX-Dienst erfolgreich gestoppt."
nginx_stop_txt_0003="NGINX-Dienst konnte nicht gestoppt werden!"
nginx_stop_txt_0004="NGINX ist nicht installiert."

nginx_stop() {
    # -----------------------------------------------------------------------
    # nginx_stop
    # -----------------------------------------------------------------------
    # Funktion: Stoppt den NGINX-Dienst
    # Parameter: $1 = Modus (text|json), optional (Default: text)
    # Rückgabe:  0 = erfolgreich gestoppt, 1 = Fehler
    # Seiteneffekte: Stoppt den NGINX-Dienst (systemctl stop nginx)
    
    local mode="${1:-text}"
    
    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if ! is_nginx_available >/dev/null; then
        log_or_json "$mode" "error" "${nginx_stop_txt_0004}" 1
        return 1
    fi
    
    log_or_json "$mode" "info" "${nginx_stop_txt_0001}" 0
    
    # NGINX-Dienst stoppen
    if systemctl stop nginx; then
        # Stop erfolgreich
        log_or_json "$mode" "success" "${nginx_stop_txt_0002}" 0
        return 0
    else
        # Stop fehlgeschlagen, Fehlerdetails ausgeben
        local status_out
        status_out=$(systemctl status nginx 2>&1 | grep -E 'Active:|Loaded:|Main PID:|nginx.service|error|failed' | head -n 10)
        log_or_json "$mode" "error" "${nginx_stop_txt_0003}" 1
        log "$status_out"
        return 1
    fi
}

# nginx_test_config
nginx_test_config_txt_0001="Prüfe NGINX-Konfiguration..."
nginx_test_config_txt_0002="NGINX-Konfiguration ist fehlerfrei."
nginx_test_config_txt_0003="Fehler in der NGINX-Konfiguration gefunden!"
nginx_test_config_txt_0004="NGINX ist nicht installiert."

nginx_test_config() {
    # -----------------------------------------------------------------------
    # nginx_test_config
    # -----------------------------------------------------------------------
    # Funktion: Prüft die NGINX-Konfiguration auf Syntaxfehler
    # Parameter: $1 = Modus (text|json), optional (Default: text)
    # Rückgabe:  0 = Konfiguration gültig, 1 = Fehler
    # Seiteneffekte: keine
    
    local mode="${1:-text}"
    
    # Zuerst prüfen, ob NGINX überhaupt installiert ist
    if ! is_nginx_available >/dev/null; then
        log_or_json "$mode" "error" "${nginx_test_config_txt_0004}" 1
        return 1
    fi
    
    log_or_json "$mode" "info" "${nginx_test_config_txt_0001}" 0
    
    # NGINX-Konfiguration testen
    if nginx -t 2>&1 | grep -q "syntax is ok"; then
        # Konfiguration ist fehlerfrei
        log_or_json "$mode" "success" "${nginx_test_config_txt_0002}" 0
        return 0
    else
        # Konfiguration fehlerhaft, Fehlerdetails ausgeben
        local error_out
        error_out=$(nginx -t 2>&1)
        log_or_json "$mode" "error" "${nginx_test_config_txt_0003}" 1
        log "$error_out"
        return 1
    fi
}

# ===========================================================================
# Erweiterte NGINX-Konfigurationsverwaltung
# ===========================================================================

#nginx_add_config
nginx_add_config_txt_0001="Füge neue NGINX-Konfiguration hinzu: %s"
nginx_add_config_txt_0002="Konfigurationsdatei %s erfolgreich erstellt."
nginx_add_config_txt_0003="Fehler beim Erstellen der Konfigurationsdatei %s"
nginx_add_config_txt_0004="Symlink für Konfiguration %s erstellt."
nginx_add_config_txt_0005="Fehler beim Erstellen des Symlinks für Konfiguration %s"
nginx_add_config_txt_0006="NGINX-Konfiguration konnte nach dem Hinzufügen nicht neu geladen werden!"
nginx_add_config_txt_0007="Prioritätswert muss eine Zahl zwischen 10 und 99 sein"
nginx_add_config_txt_0008="Konfigurationsname darf nur alphanumerische Zeichen und Bindestriche enthalten"
nginx_add_config_txt_0009="Konfigurationsinhalt darf nicht leer sein"
nginx_add_config_txt_0010="NGINX-Konfiguration %s wurde erfolgreich hinzugefügt und aktiviert."
nginx_add_config_txt_0011="NGINX ist nicht installiert. Installation erforderlich."

nginx_add_config() {
    # -----------------------------------------------------------------------
    # nginx_add_config
    # -----------------------------------------------------------------------
    # Funktion: Fügt eine neue NGINX-Konfiguration hinzu und aktiviert sie
    # Parameter: $1 = Konfigurationsinhalt
    #            $2 = Konfigurationsname (default: fotobox)
    #            $3 = Priorität (10-99, niedrigere Zahl = höhere Priorität)
    #            $4 = Modus (text|json), optional (Default: text)
    # Rückgabe: 0 = OK, >0 = Fehler
    # -----------------------------------------------------------------------
    local config_content="$1"
    local config_name="${2:-fotobox}"
    local priority="${3:-50}"
    local mode="${4:-text}"
    
    local sites_available="/etc/nginx/sites-available"
    local sites_enabled="/etc/nginx/sites-enabled"
    
    # Prüfen, ob NGINX installiert ist
    if ! is_nginx_available >/dev/null; then
        log_or_json "$mode" "error" "$nginx_add_config_txt_0011" 1
        return 1
    fi
    
    # Validierungen
    if [ -z "$config_content" ]; then
        log_or_json "$mode" "error" "$nginx_add_config_txt_0009" 2
        return 2
    fi
    
    if ! [[ "$config_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_or_json "$mode" "error" "$nginx_add_config_txt_0008" 3
        return 3
    fi
    
    if ! [[ "$priority" =~ ^[0-9]+$ ]] || [ "$priority" -lt 10 ] || [ "$priority" -gt 99 ]; then
        log_or_json "$mode" "error" "$nginx_add_config_txt_0007" 4
        return 4
    fi
    
    local config_file="$sites_available/$config_name"
    local enabled_link="$sites_enabled/${priority}-$config_name"
    
    log_or_json "$mode" "info" "$(printf "$nginx_add_config_txt_0001" "$config_name")" 0
    
    # Existierende Konfiguration sichern, falls vorhanden
    if [ -f "$config_file" ]; then
        backup_nginx_config "$config_file" "add_config" "nginx_add_config" "$mode" || return 5
    fi
    
    # Konfiguration schreiben
    echo "$config_content" > "$config_file"
    if [ $? -ne 0 ]; then
        log_or_json "$mode" "error" "$(printf "$nginx_add_config_txt_0003" "$config_file")" 6
        return 6
    fi
    log_or_json "$mode" "success" "$(printf "$nginx_add_config_txt_0002" "$config_file")" 0
    
    # Alte Symlinks entfernen, falls vorhanden
    find "$sites_enabled" -name "*-$config_name" -type l -delete
    
    # Neuen Symlink erstellen
    ln -s "$config_file" "$enabled_link"
    if [ $? -ne 0 ]; then
        log_or_json "$mode" "error" "$(printf "$nginx_add_config_txt_0005" "$config_name")" 7
        return 7
    fi
    log_or_json "$mode" "success" "$(printf "$nginx_add_config_txt_0004" "$config_name")" 0
    
    # NGINX neu laden
    local reload_result
    reload_result=$(chk_nginx_reload "$mode")
    local reload_status=$?
    
    if [ $reload_status -ne 0 ]; then 
        log_or_json "$mode" "error" "$nginx_add_config_txt_0006" 8
        return 8
    fi
    
    # Firewall-Regeln aktualisieren
    update_firewall_rules "$mode"
    
    log_or_json "$mode" "success" "$(printf "$nginx_add_config_txt_0010" "$config_name")" 0
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
        if ! chk_nginx_installation "$mode" $is_interactive; then
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

# Einstellungshierarchie für Manage Modul erstellen
DEBUG_MOD_GLOBAL=1
register_config_hierarchy "nginx" "NGINX-Konfigurationsmodul" "manage_nginx" 
DEBUG_MOD_GLOBAL=0