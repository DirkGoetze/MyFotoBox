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
# ---------------------------------------------------------------------------

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_NGINX_LOADED=0

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ -f "$BASH_DIR/lib_core.sh" ]; then
    source "$BASH_DIR/lib_core.sh"
    load_core_resources || {
        echo "Fehler beim Laden der Kernressourcen."
        exit 1
    }
else
    echo "Fehler: Zentrale Bibliothek lib_core.sh nicht gefunden!"
    exit 1
fi
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
chk_nginx_reload_txt_0003="NGINX konnte nicht neu geladen werden! Statusauszug:"
chk_nginx_reload_txt_0004="Fehler in der NGINX-Konfiguration!"
chk_nginx_reload_txt_0005="Fehler in der NGINX-Konfiguration! Bitte prüfen."
chk_nginx_reload_txt_0006="NGINX konnte nicht neu geladen werden!"

# chk_nginx_port
chk_nginx_port_txt_0001="Port-Prüfung starten ..."
chk_nginx_port_txt_0002="lsof ist nicht verfügbar. Portprüfung nicht möglich."
chk_nginx_port_txt_0003="Port %s ist belegt."
chk_nginx_port_txt_0004="Port %s ist frei."
chk_nginx_port_txt_0005="Portprüfung abgeschlossen."
chk_nginx_port_txt_0006="Fehler bei der Portprüfung."

# chk_nginx_activ
chk_nginx_activ_txt_0001="Nur Default-Site ist aktiv."
chk_nginx_activ_txt_0002="Weitere Sites sind aktiv."
chk_nginx_activ_txt_0003="Konnte aktive NGINX-Sites nicht eindeutig ermitteln."
chk_nginx_activ_txt_0004="NGINX-Status: Nur Default-Site aktiv."
chk_nginx_activ_txt_0005="NGINX-Status: Mehrere Sites aktiv."
chk_nginx_activ_txt_0006="Fehler: NGINX-Site-Status unklar."
chk_nginx_activ_txt_0007="Statusabfrage abgeschlossen."
chk_nginx_activ_txt_0008="Fehler bei der Statusabfrage."

# get_nginx_url
get_nginx_url_txt_0001="Konnte IP-Adresse nicht ermitteln."
get_nginx_url_txt_0002="Ermittelte Fotobox-URL: %s"
get_nginx_url_txt_0003="URL-Ermittlung abgeschlossen."
get_nginx_url_txt_0004="Fehler bei der URL-Ermittlung."

# set_nginx_port
set_nginx_port_txt_0001="Portauswahl für Fotobox-Weboberfläche gestartet."
set_nginx_port_txt_0002="Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:"
set_nginx_port_txt_0003="Ungültige Eingabe: '%s'. Bitte eine gültige Portnummer angeben."
set_nginx_port_txt_0004="Fehler beim Schreiben des Ports in die Konfiguration."
set_nginx_port_txt_0005="Port %s wird verwendet."
set_nginx_port_txt_0006="Keine passende NGINX-Konfiguration gefunden. Port kann nicht gesetzt werden."
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
# ===========================================================================

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

json_out() {
    # -----------------------------------------------------------------------
    # Hilfsfunktion JSON-Ausgabe
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine JSON-formatierte Antwort aus
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
        # Hole Backup-Verzeichnis über manage_folders.sh
        backup_dir="$("$manage_folders_sh" backup_dir)/nginx"
    else
        # Fallback zur alten Methode
        backup_dir="/opt/fotobox/backup/nginx"
    fi
    
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local base_name
    base_name="$(basename "$src")"
    local backup_file="$backup_dir/${base_name}.bak.$timestamp"
    local meta_file="$backup_file.meta.json"
    
    # Verwende manage_folders.sh zur Verzeichniserstellung, falls verfügbar
    if [ -f "$manage_folders_sh" ] && [ -x "$manage_folders_sh" ]; then
        "$manage_folders_sh" create_directory "$backup_dir"
    else
        mkdir -p "$backup_dir"
    fi
    if cp "$src" "$backup_file"; then
        # Metadaten schreiben
        cat > "$meta_file" <<EOF
{
  "timestamp": "$timestamp",
  "source": "$src",
  "backup": "$backup_file",
  "config_type": "$config_type",
  "action": "$action"
}
EOF
        if [ "$mode" = "json" ]; then
            json_out "success" "Backup und Metadaten angelegt: $backup_file" 0
        else
            log "Backup und Metadaten angelegt: $backup_file"
        fi
        return 0
    else
        if [ "$mode" = "json" ]; then
            json_out "error" "Backup fehlgeschlagen: $src" 1
        else
            log "Backup fehlgeschlagen: $src"
        fi
        return 1
    fi
}

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

get_nginx_url() {
    # -----------------------------------------------------------------------
    # get_nginx_url
    # -----------------------------------------------------------------------
    # Funktion: Ermittelt die tatsächlich aktive URL der Fotobox anhand der NGINX-Konfiguration.
    # Parameter: $1 = Modus (text|json), optional (Standard: text)
    # Rückgabe:  URL-String (http://IP:Port/) oder Fehlercode
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
        log "${get_nginx_url_txt_0004}"
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
    log "$(printf "$get_nginx_url_txt_0002" "$url")"
    log "${get_nginx_url_txt_0003}"
    if [ "$mode" = "json" ]; then
        json_out "success" "$url" 0
    else
        log "$url"
    fi
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
    chk_nginx_reload "$mode"
    return $?
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
    fi
    if [ -n "$conf_file" ]; then
        path=$(grep -Eo 'location[[:space:]]+/[^ ]*' "$conf_file" | grep -v '/api' | head -n1 | awk '{print $2}')
        [ -z "$path" ] && path="/fotobox/"
    else
        path="/fotobox/"
    fi
    if [ "$mode" = "json" ]; then
        json_out "success" "$path" 0
    else
        echo "$path"
    fi
}

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
        return 0
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
        sed -i '/^}/i \\n    # Fotobox-Integration BEGIN\n    location /fotobox/ {\n        alias /opt/fotobox/frontend/;\n        index start.html index.html;\n    }\n    location /fotobox/api/ {\n        proxy_pass http://127.0.0.1:5000/;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n    }\n    # Fotobox-Integration END\n' "$default_conf"
        log_or_json "$mode" "success" "$set_nginx_cnf_internal_txt_0005" 0
    else
        log_or_json "$mode" "info" "$set_nginx_cnf_internal_txt_0006" 0
    fi
    chk_nginx_reload "$mode" || { log_or_json "$mode" "error" "NGINX-Konfiguration konnte nach Integration nicht neu geladen werden!" 4; return 4; }
    return 0
}

set_nginx_cnf_external() {
    # -----------------------------------------------------------------------
    # set_nginx_cnf_external
    # -----------------------------------------------------------------------
    # Funktion: Legt eigene Fotobox-Konfiguration an, bindet sie ein 
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Backup-Fehler, 4 = Reload-Fehler, 10 = Symlink-Fehler
    local mode="$1"
    local nginx_dst="/etc/nginx/sites-available/fotobox"
    local conf_src="/opt/fotobox/conf/nginx-fotobox.conf"

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
    chk_nginx_reload "$mode" || { log_or_json "$mode" "error" "NGINX-Konfiguration konnte nach externer Integration nicht neu geladen werden!" 4; return 4; }
    return 0
}

