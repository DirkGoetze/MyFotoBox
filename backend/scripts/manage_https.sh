#!/bin/bash
# ------------------------------------------------------------------------------
# manage_https.sh
# ------------------------------------------------------------------------------
# Funktion: Verwaltung und Konfiguration von HTTPS (TLS/SSL) für die Fotobox
# ......... (Zertifikatsanforderung, -erneuerung, Einbindung in NGINX, 
# ......... Policy-Check) für Ubuntu/Debian-basierte Systeme, muss als root 
# ......... ausgeführt werden.
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
MANAGE_HTTPS_LOADED=0

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ ! -f "$BASH_DIR/lib_core.sh" ]; then
    echo "KRITISCHER FEHLER: Zentrale Bibliothek lib_core.sh nicht gefunden!" >&2
    echo "Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch." >&2
    exit 1
fi

source "$BASH_DIR/lib_core.sh"
load_core_resources || {
    echo "KRITISCHER FEHLER: Die Kernressourcen konnten nicht geladen werden." >&2
    echo "Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch." >&2
    exit 1
}
# ===========================================================================

# ===========================================================================
# Globale Konstanten (Vorgaben und Defaults für die Installation)
# ===========================================================================
# Die meisten globalen Konstanten werden bereits durch lib_core.sh gesetzt.
# bereitgestellt. Hier definieren wir nur Konstanten, die noch nicht durch 
# lib_core.sh gesetzt wurden oder die speziell für die Installation 
# überschrieben werden müssen.
# ---------------------------------------------------------------------------
DEFAULT_HTTPS_CONF_DIR="${CONF_DIR}/https"
DEFAULT_HTTPS_BACKUP_DIR="${BACKUP_DIR}/https"

# SSL-Konfigurationsstandards
DEFAULT_SSL_PROTOCOLS="TLSv1.2 TLSv1.3"
DEFAULT_SSL_CIPHERS="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"
DEFAULT_SSL_PREFER_SERVER_CIPHERS="on"
DEFAULT_SSL_SESSION_TIMEOUT="1d"
DEFAULT_SSL_SESSION_CACHE="shared:SSL:10m"
DEFAULT_SSL_DHPARAM_BITS=2048

# Zertifikatspfade
SSL_CERT_DIR="${DEFAULT_HTTPS_CONF_DIR}/certs"
SSL_KEY_DIR="${DEFAULT_HTTPS_CONF_DIR}/private"
SSL_DHPARAM_FILE="${DEFAULT_HTTPS_CONF_DIR}/dhparam.pem"

# Let's Encrypt Konfiguration
LETSENCRYPT_CONFIG_DIR="/etc/letsencrypt"
LETSENCRYPT_LIVE_DIR="${LETSENCRYPT_CONFIG_DIR}/live"

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

# ---------------------------------------------------------------------------
# Funktion: is_ssl_available
# ---------------------------------------------------------------------------
# Beschreibung: Prüft, ob SSL-Tools installiert sind
# Parameter: keine
# Rückgabewert: 0 = verfügbar, 1 = nicht verfügbar
# ---------------------------------------------------------------------------
function is_ssl_available() {
    log_debug "Prüfe, ob SSL-Tools verfügbar sind..."
    
    # Prüfe, ob openssl installiert ist
    if ! command -v openssl &> /dev/null; then
        log_debug "OpenSSL ist nicht installiert."
        return 1
    fi
    
    log_debug "SSL-Tools sind verfügbar."
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: is_https_configured
# ---------------------------------------------------------------------------
# Beschreibung: Prüft, ob HTTPS bereits konfiguriert ist
# Parameter: keine
# Rückgabewert: 0 = konfiguriert, 1 = nicht konfiguriert
# ---------------------------------------------------------------------------
function is_https_configured() {
    log_debug "Prüfe, ob HTTPS bereits konfiguriert ist..."
    
    # Verzeichnisse prüfen
    if [ ! -d "$SSL_CERT_DIR" ] || [ ! -d "$SSL_KEY_DIR" ]; then
        log_debug "SSL-Verzeichnisse existieren nicht."
        return 1
    fi
    
    # Prüfe, ob Zertifikate vorhanden sind
    local cert_files=($(find "$SSL_CERT_DIR" -type f -name "*.crt" 2>/dev/null))
    local key_files=($(find "$SSL_KEY_DIR" -type f -name "*.key" 2>/dev/null))
    
    if [ ${#cert_files[@]} -eq 0 ] || [ ${#key_files[@]} -eq 0 ]; then
        log_debug "Keine SSL-Zertifikate gefunden."
        return 1
    fi
    
    # Prüfe, ob NGINX mit SSL konfiguriert ist
    if ! grep -q "listen 443 ssl" "$(get_nginx_conf_dir)/sites-enabled/"* 2>/dev/null; then
        log_debug "NGINX ist nicht für SSL konfiguriert."
        return 1
    fi
    
    log_debug "HTTPS ist konfiguriert."
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: has_valid_certificate
# ---------------------------------------------------------------------------
# Beschreibung: Prüft Gültigkeit vorhandener Zertifikate
# Parameter: keine
# Rückgabewert: 0 = gültig, 1 = ungültig oder abgelaufen, 2 = nicht vorhanden
# ---------------------------------------------------------------------------
function has_valid_certificate() {
    log_debug "Prüfe Gültigkeit vorhandener Zertifikate..."
    
    # Prüfe, ob Zertifikatsdateien existieren
    local cert_files=($(find "$SSL_CERT_DIR" -type f -name "*.crt" 2>/dev/null))
    
    if [ ${#cert_files[@]} -eq 0 ]; then
        log_debug "Keine Zertifikate gefunden."
        return 2
    fi
    
    local now=$(date +%s)
    local valid=0
    
    for cert_file in "${cert_files[@]}"; do
        # Ablaufdatum des Zertifikats prüfen
        local end_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
        
        if [ -z "$end_date" ]; then
            log_debug "Konnte Ablaufdatum für $cert_file nicht ermitteln."
            valid=1
            continue
        fi
        
        local end_epoch=$(date -d "$end_date" +%s 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            log_debug "Fehler beim Konvertieren des Ablaufdatums für $cert_file."
            valid=1
            continue
        fi
        
        # Prüfe, ob das Zertifikat abgelaufen ist
        if [ "$now" -ge "$end_epoch" ]; then
            log_debug "Zertifikat $cert_file ist abgelaufen."
            valid=1
            continue
        fi
        
        # Prüfe, ob das Zertifikat innerhalb der nächsten 30 Tage abläuft
        local thirty_days=$((30 * 24 * 60 * 60))
        if [ $(($end_epoch - $now)) -lt "$thirty_days" ]; then
            log_debug "Zertifikat $cert_file läuft innerhalb der nächsten 30 Tage ab."
            # Wir markieren es nicht als ungültig, aber loggen einen Hinweis
        fi
        
        log_debug "Zertifikat $cert_file ist gültig."
    done
    
    return $valid
}

# ---------------------------------------------------------------------------
# Funktion: create_https_dirs
# ---------------------------------------------------------------------------
# Beschreibung: Erstellt nötige Verzeichnisse für SSL-Dateien
# Parameter: keine
# Rückgabewert: 0 = erfolgreich, 1 = Fehler
# ---------------------------------------------------------------------------
function create_https_dirs() {
    log_debug "Erstelle SSL-Verzeichnisse..."
    
    # Erstelle Konfigurationsverzeichnisse
    mkdir -p "$SSL_CERT_DIR" "$SSL_KEY_DIR" "$DEFAULT_HTTPS_CONF_DIR" || {
        log_error "Konnte SSL-Konfigurationsverzeichnisse nicht erstellen."
        return 1
    }
    
    # Erstelle Backup-Verzeichnisse
    mkdir -p "$DEFAULT_HTTPS_BACKUP_DIR/certs" "$DEFAULT_HTTPS_BACKUP_DIR/private" || {
        log_error "Konnte SSL-Backup-Verzeichnisse nicht erstellen."
        return 1
    }
    
    # Setze Berechtigungen
    chmod -R 755 "$DEFAULT_HTTPS_CONF_DIR" "$DEFAULT_HTTPS_BACKUP_DIR" || {
        log_error "Konnte Berechtigungen für SSL-Verzeichnisse nicht setzen."
        return 1
    }
    
    # Private Keys besonders schützen
    chmod 700 "$SSL_KEY_DIR" "$DEFAULT_HTTPS_BACKUP_DIR/private" || {
        log_error "Konnte Berechtigungen für private Schlüssel-Verzeichnisse nicht setzen."
        return 1
    }
    
    log_debug "SSL-Verzeichnisse wurden erfolgreich erstellt."
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: generate_self_signed_certificate
# ---------------------------------------------------------------------------
# Beschreibung: Erstellt ein selbstsigniertes SSL-Zertifikat
# Parameter:    $1 - Domainname (z.B. example.com oder localhost)
#               $2 - Gültigkeitsdauer in Tagen (optional, Standard: 365)
#               $3 - Ausgabepräfix für Dateien (optional)
# Rückgabewert: 0 = erfolgreich, >0 = Fehler
# Ausgabe:      Pfad zum generierten Zertifikat und Schlüssel
# ---------------------------------------------------------------------------
function generate_self_signed_certificate() {
    local domain="${1:-localhost}"
    local validity="${2:-365}"
    local out_prefix="${3:-${domain/\*./wildcard_}}"
    
    log_debug "Generiere selbstsigniertes Zertifikat für $domain (gültig für $validity Tage)..."
    
    # Erstelle SSL-Verzeichnisse falls notwendig
    create_https_dirs || return 1
    
    local key_file="${SSL_KEY_DIR}/${out_prefix}.key"
    local cert_file="${SSL_CERT_DIR}/${out_prefix}.crt"
    local config_file="${DEFAULT_HTTPS_CONF_DIR}/openssl_${out_prefix}.cnf"
    
    # Erstelle OpenSSL-Konfigurationsdatei
    cat > "$config_file" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = DE
L = Unbekannt
O = Fotobox
OU = Fotobox2
CN = ${domain}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = www.${domain}
EOF
    
    # Bei Wildcard-Zertifikaten die entsprechenden Einträge hinzufügen
    if [[ "$domain" == *"*."* ]]; then
        local base_domain="${domain#\*.}"
        echo "DNS.3 = ${base_domain}" >> "$config_file"
        echo "DNS.4 = *.${base_domain}" >> "$config_file"
    fi
    
    # Generiere private key und Zertifikat
    if ! openssl req -x509 -nodes -days "$validity" -newkey rsa:2048 \
         -keyout "$key_file" -out "$cert_file" -config "$config_file" 2>/dev/null; then
        log_error "Fehler beim Generieren des selbstsignierten Zertifikats."
        return 1
    fi
    
    # Setze korrekte Berechtigungen
    chmod 600 "$key_file" || {
        log_error "Konnte Berechtigungen für den privaten Schlüssel nicht setzen."
        return 2
    }
    
    chmod 644 "$cert_file" || {
        log_error "Konnte Berechtigungen für das Zertifikat nicht setzen."
        return 3
    }
    
    log_info "Selbstsigniertes Zertifikat für $domain wurde erstellt:"
    log_info "  - Private Key: $key_file"
    log_info "  - Zertifikat: $cert_file"
    
    echo "{\"cert\": \"$cert_file\", \"key\": \"$key_file\"}"
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: install_self_signed_certificate
# ---------------------------------------------------------------------------
# Beschreibung: Installiert selbstsigniertes Zertifikat für NGINX
# Parameter:    $1 - Domainname (wird für die Konfiguration verwendet)
#               $2 - Pfad zum Zertifikat
#               $3 - Pfad zum privaten Schlüssel
# Rückgabewert: 0 = erfolgreich, >0 = Fehler
# ---------------------------------------------------------------------------
function install_self_signed_certificate() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    
    if [ -z "$domain" ] || [ -z "$cert_file" ] || [ -z "$key_file" ]; then
        log_error "Domain, Zertifikat und Schlüsselpfad müssen angegeben werden."
        return 1
    fi
    
    log_debug "Installiere selbstsigniertes Zertifikat für $domain..."
    
    # Überprüfe, ob Dateien existieren
    if [ ! -f "$cert_file" ]; then
        log_error "Zertifikatsdatei '$cert_file' wurde nicht gefunden."
        return 2
    fi
    
    if [ ! -f "$key_file" ]; then
        log_error "Schlüsseldatei '$key_file' wurde nicht gefunden."
        return 3
    fi
    
    # Überprüfe NGINX-Installation
    if ! command -v nginx &> /dev/null; then
        log_error "NGINX ist nicht installiert."
        return 4
    fi
    
    # Erstelle NGINX SSL-Konfiguration
    local nginx_ssl_conf="$(get_nginx_conf_dir)/ssl_params.conf"
    
    cat > "$nginx_ssl_conf" << EOF
# SSL-Parameter für Fotobox2
# Generiert von manage_https.sh

ssl_protocols $DEFAULT_SSL_PROTOCOLS;
ssl_prefer_server_ciphers $DEFAULT_SSL_PREFER_SERVER_CIPHERS;
ssl_ciphers $DEFAULT_SSL_CIPHERS;
ssl_session_timeout $DEFAULT_SSL_SESSION_TIMEOUT;
ssl_session_cache $DEFAULT_SSL_SESSION_CACHE;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Sicherheitsheader
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options SAMEORIGIN;
add_header X-XSS-Protection "1; mode=block";

# Diffie-Hellman-Parameter wenn vorhanden
EOF
    
    # Wenn DH-Parameter vorhanden sind, füge sie hinzu
    if [ -f "$SSL_DHPARAM_FILE" ]; then
        echo "ssl_dhparam $SSL_DHPARAM_FILE;" >> "$nginx_ssl_conf"
    fi
    
    log_info "SSL-Parameter für NGINX wurden konfiguriert."
    
    # Erstelle oder aktualisiere die NGINX-Serverkonfiguration für die Domain
    local server_name="${domain}"
    local config_name="fotobox-https-${domain/\*./wildcard-}"
    local site_config="$(get_nginx_conf_dir)/sites-available/${config_name}"
    
    # Sichere bestehende Konfiguration, falls vorhanden
    if [ -f "$site_config" ]; then
        local backup_file="${site_config}.bak.$(date +%s)"
        log_debug "Sichere bestehende Konfiguration nach $backup_file..."
        cp "$site_config" "$backup_file" || log_warn "Konnte bestehende Konfiguration nicht sichern."
    fi
    
    # Erstelle die HTTPS-Konfiguration
    log_debug "Erstelle HTTPS-Konfiguration für $domain in $site_config..."
    
    cat > "$site_config" << EOF
# HTTPS-Konfiguration für $domain
# Generiert von Fotobox2 manage_https.sh

server {
    listen 443 ssl http2;
    server_name $server_name;
    
    # SSL-Konfiguration
    ssl_certificate     $cert_file;
    ssl_certificate_key $key_file;
    
    # Einbindung der SSL-Parameter
    include $(get_nginx_conf_dir)/ssl_params.conf;
    
    # Root-Verzeichnis und Index-Dateien
    root /opt/fotobox/frontend;
    index start.html index.html;
    
    # Standard-Location
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # API-Weiterleitung
    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # WebSocket-Unterstützung
    location /ws/ {
        proxy_pass http://127.0.0.1:5000/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

# HTTP zu HTTPS Umleitung
server {
    listen 80;
    server_name $server_name;
    
    # Umleitung aller HTTP-Anfragen auf HTTPS
    return 301 https://\$host\$request_uri;
}
EOF
    
    # Prüfe die NGINX-Konfiguration
    if ! nginx -t &>/dev/null; then
        log_error "Die erstellte NGINX-Konfiguration ist ungültig. Überprüfen Sie die Einstellungen."
        return 5
    fi
    
    # Aktiviere die Site, wenn sie nicht bereits aktiviert ist
    local enabled_link="$(get_nginx_conf_dir)/sites-enabled/${config_name}"
    if [ ! -L "$enabled_link" ]; then
        ln -s "$site_config" "$enabled_link" || {
            log_error "Konnte die HTTPS-Konfiguration nicht aktivieren."
            return 6
        }
    fi
    
    # Starte NGINX neu oder lade die Konfiguration neu
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || {
            log_error "Konnte NGINX-Konfiguration nicht neu laden."
            return 7
        }
    else
        systemctl restart nginx || {
            log_error "Konnte NGINX nicht starten."
            return 8
        }
    fi
    
    log_info "Selbstsigniertes Zertifikat für $domain wurde erfolgreich installiert."
    log_info "Die Website ist nun über https://$domain erreichbar."
    
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: create_https_nginx_config
# ---------------------------------------------------------------------------
# Beschreibung: Erstellt HTTPS-spezifische NGINX-Konfiguration
# Parameter:    $1 - Zertifikatspfad
#               $2 - Schlüsselpfad
#               $3 - Domainname oder IP-Adresse
#               $4 - HTTPS-Port (optional, Standard: 443)
#               $5 - Weitere SSL-Optionen als JSON-String (optional)
# Rückgabewert: 0 = erfolgreich, >0 = Fehler
# ---------------------------------------------------------------------------
function create_https_nginx_config() {
    local cert_file="$1"
    local key_file="$2"
    local domain="$3"
    local https_port="${4:-443}"
    local ssl_options="$5"
    
    if [ -z "$cert_file" ] || [ -z "$key_file" ] || [ -z "$domain" ]; then
        log_error "Zertifikat, Schlüssel und Domain müssen angegeben werden."
        return 1
    fi
    
    log_debug "Erstelle HTTPS-Konfiguration für $domain auf Port $https_port..."
    
    # Überprüfe, ob Dateien existieren
    if [ ! -f "$cert_file" ]; then
        log_error "Zertifikatsdatei '$cert_file' wurde nicht gefunden."
        return 2
    fi
    
    if [ ! -f "$key_file" ]; then
        log_error "Schlüsseldatei '$key_file' wurde nicht gefunden."
        return 3
    fi
    
    # Konfiguriere SSL-Parameter, falls noch nicht vorhanden
    local nginx_ssl_conf="$(get_nginx_conf_dir)/ssl_params.conf"
    
    if [ ! -f "$nginx_ssl_conf" ]; then
        log_debug "Erstelle SSL-Parameter-Datei $nginx_ssl_conf..."
        
        cat > "$nginx_ssl_conf" << EOF
# SSL-Parameter für Fotobox2
# Generiert von manage_https.sh

ssl_protocols $DEFAULT_SSL_PROTOCOLS;
ssl_prefer_server_ciphers $DEFAULT_SSL_PREFER_SERVER_CIPHERS;
ssl_ciphers $DEFAULT_SSL_CIPHERS;
ssl_session_timeout $DEFAULT_SSL_SESSION_TIMEOUT;
ssl_session_cache $DEFAULT_SSL_SESSION_CACHE;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Sicherheitsheader
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options SAMEORIGIN;
add_header X-XSS-Protection "1; mode=block";
EOF
        
        # Wenn DH-Parameter vorhanden sind, füge sie hinzu
        if [ -f "$SSL_DHPARAM_FILE" ]; then
            echo -e "\n# Diffie-Hellman Parameter\nssl_dhparam $SSL_DHPARAM_FILE;" >> "$nginx_ssl_conf"
        fi
    fi
    
    # Extrahiere zusätzliche Optionen, falls vorhanden
    local api_port="5000"
    local root_dir="/opt/fotobox/frontend"
    local index_files="start.html index.html"
    local http_redirect="yes"
    
    if [ -n "$ssl_options" ]; then
        # Verarbeite JSON-Optionen wenn vorhanden
        if command -v jq &> /dev/null; then
            if echo "$ssl_options" | jq -e . &>/dev/null; then
                api_port=$(echo "$ssl_options" | jq -r '.api_port // "5000"')
                root_dir=$(echo "$ssl_options" | jq -r '.root_dir // "/opt/fotobox/frontend"')
                index_files=$(echo "$ssl_options" | jq -r '.index_files // "start.html index.html"')
                http_redirect=$(echo "$ssl_options" | jq -r '.http_redirect // "yes"')
            else
                log_warn "Ungültiges JSON-Format für SSL-Optionen. Verwende Standardwerte."
            fi
        else
            log_warn "jq ist nicht installiert. Kann JSON-Optionen nicht verarbeiten. Verwende Standardwerte."
        fi
    fi
    
    # Erstelle Konfigurationsdatei
    local config_name="fotobox-https-${domain/\*./wildcard-}"
    config_name="${config_name//./-}"  # Ersetze Punkte durch Bindestriche für sichere Dateinamen
    local site_config="$(get_nginx_conf_dir)/sites-available/${config_name}"
    
    # Sichere bestehende Konfiguration, falls vorhanden
    if [ -f "$site_config" ]; then
        local backup_file="${site_config}.bak.$(date +%s)"
        log_debug "Sichere bestehende Konfiguration nach $backup_file..."
        cp "$site_config" "$backup_file" || log_warn "Konnte bestehende Konfiguration nicht sichern."
    fi
    
    # Erstelle HTTPS-Konfiguration
    log_debug "Erstelle HTTPS-Konfiguration in $site_config..."
    
    cat > "$site_config" << EOF
# HTTPS-Konfiguration für $domain auf Port $https_port
# Generiert von Fotobox2 manage_https.sh

server {
    listen $https_port ssl http2;
    server_name $domain;
    
    # SSL-Konfiguration
    ssl_certificate     $cert_file;
    ssl_certificate_key $key_file;
    
    # Einbindung der SSL-Parameter
    include $(get_nginx_conf_dir)/ssl_params.conf;
    
    # Root-Verzeichnis und Index-Dateien
    root $root_dir;
    index $index_files;
    
    # Standard-Location
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # API-Weiterleitung
    location /api/ {
        proxy_pass http://127.0.0.1:$api_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # WebSocket-Unterstützung
    location /ws/ {
        proxy_pass http://127.0.0.1:$api_port/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    # Erstelle HTTP zu HTTPS-Umleitung, falls gewünscht
    if [ "$http_redirect" = "yes" ]; then
        cat >> "$site_config" << EOF

# HTTP zu HTTPS Umleitung
server {
    listen 80;
    server_name $domain;
    
    # Umleitung aller HTTP-Anfragen auf HTTPS
    return 301 https://\$host\$request_uri;
}
EOF
    fi
    
    # Prüfe die NGINX-Konfiguration
    if ! nginx -t &>/dev/null; then
        log_error "Die erstellte NGINX-Konfiguration ist ungültig. Überprüfen Sie die Einstellungen."
        nginx -t  # Zeigt detaillierte Fehlermeldung
        return 4
    fi
    
    # Aktiviere die Site, wenn sie nicht bereits aktiviert ist
    local enabled_link="$(get_nginx_conf_dir)/sites-enabled/${config_name}"
    if [ ! -L "$enabled_link" ]; then
        ln -s "$site_config" "$enabled_link" || {
            log_error "Konnte die HTTPS-Konfiguration nicht aktivieren."
            return 5
        }
    fi
    
    log_info "HTTPS-Konfiguration für $domain auf Port $https_port wurde erfolgreich erstellt."
    log_info "Die Konfigurationsdatei befindet sich in: $site_config"
    
    # Konfiguration wurde erstellt, aber NGINX wurde noch nicht neu geladen
    log_debug "HTTPS-Konfiguration ist bereit. Verwenden Sie 'nginx -s reload' oder 'systemctl reload nginx', um die Konfiguration zu aktivieren."
    
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: setup_http_to_https_redirect
# ---------------------------------------------------------------------------
# Beschreibung: Richtet HTTP nach HTTPS Umleitung ein
# Parameter:    $1 - Domainname oder IP-Adresse
#               $2 - HTTPS-Port (optional, Standard: 443)
#               $3 - HTTP-Port (optional, Standard: 80)
# Rückgabewert: 0 = erfolgreich, >0 = Fehler
# ---------------------------------------------------------------------------
function setup_http_to_https_redirect() {
    local domain="$1"
    local https_port="${2:-443}"
    local http_port="${3:-80}"
    
    if [ -z "$domain" ]; then
        log_error "Domainname muss angegeben werden."
        return 1
    fi
    
    log_debug "Richte HTTP zu HTTPS Umleitung für $domain ein (HTTP: $http_port -> HTTPS: $https_port)..."
    
    # Erstelle Konfigurationsdatei
    local config_name="fotobox-http-redirect-${domain/\*./wildcard-}"
    config_name="${config_name//./-}"  # Ersetze Punkte durch Bindestriche für sichere Dateinamen
    local site_config="$(get_nginx_conf_dir)/sites-available/${config_name}"
    
    # Prüfe, ob bereits eine bestehende HTTPS-Konfiguration mit Umleitung vorhanden ist
    if grep -q "return 301 https://\$host" "$(get_nginx_conf_dir)/sites-enabled/"*".conf" 2>/dev/null; then
        log_info "Es existiert bereits eine HTTP zu HTTPS Umleitung. Keine Änderung notwendig."
        return 0
    fi
    
    # Erstelle die HTTP zu HTTPS Umleitung
    cat > "$site_config" << EOF
# HTTP zu HTTPS Umleitung für $domain
# Generiert von Fotobox2 manage_https.sh

server {
    listen $http_port;
    server_name $domain;
    
    # Umleitung aller HTTP-Anfragen auf HTTPS
    return 301 https://\$host\$request_uri;
}
EOF
    
    # Prüfe die NGINX-Konfiguration
    if ! nginx -t &>/dev/null; then
        log_error "Die erstellte NGINX-Konfiguration ist ungültig. Überprüfen Sie die Einstellungen."
        return 2
    fi
    
    # Aktiviere die Site, wenn sie nicht bereits aktiviert ist
    local enabled_link="$(get_nginx_conf_dir)/sites-enabled/${config_name}"
    if [ ! -L "$enabled_link" ]; then
        ln -s "$site_config" "$enabled_link" || {
            log_error "Konnte die HTTP-Umleitungskonfiguration nicht aktivieren."
            return 3
        }
    fi
    
    # Starte NGINX neu oder lade die Konfiguration neu
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || {
            log_error "Konnte NGINX-Konfiguration nicht neu laden."
            return 4
        }
    else
        systemctl restart nginx || {
            log_error "Konnte NGINX nicht starten."
            return 5
        }
    fi
    
    log_info "HTTP zu HTTPS Umleitung für $domain wurde erfolgreich eingerichtet."
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: setup_hsts
# ---------------------------------------------------------------------------
# Beschreibung: Konfiguriert HTTP Strict Transport Security
# Parameter:    $1 - max-age Wert in Sekunden (optional, Standard: 31536000 = 1 Jahr)
#               $2 - includeSubDomains (yes/no, optional, Standard: yes)
#               $3 - preload (yes/no, optional, Standard: no)
# Rückgabewert: 0 = erfolgreich, >0 = Fehler
# ---------------------------------------------------------------------------
function setup_hsts() {
    local max_age="${1:-31536000}"
    local include_subdomains="${2:-yes}"
    local preload="${3:-no}"
    
    log_debug "Konfiguriere HTTP Strict Transport Security (HSTS)..."
    
    # Überprüfe, ob die SSL-Parameter-Datei existiert
    local nginx_ssl_conf="$(get_nginx_conf_dir)/ssl_params.conf"
    
    if [ ! -f "$nginx_ssl_conf" ]; then
        log_error "SSL-Parameter-Datei nicht gefunden: $nginx_ssl_conf"
        log_error "Bitte führen Sie zuerst install_self_signed_certificate oder create_https_nginx_config aus."
        return 1
    fi
    
    # Erstelle HSTS-Header-Wert
    local hsts_value="\"max-age=$max_age"
    
    if [ "$include_subdomains" = "yes" ]; then
        hsts_value+="; includeSubDomains"
    fi
    
    if [ "$preload" = "yes" ]; then
        hsts_value+="; preload"
    fi
    
    hsts_value+="\""
    
    # Entferne vorhandenen HSTS-Header falls vorhanden
    if grep -q "add_header Strict-Transport-Security" "$nginx_ssl_conf"; then
        log_debug "Ersetze vorhandenen HSTS-Header..."
        sed -i "/add_header Strict-Transport-Security/c\\add_header Strict-Transport-Security $hsts_value always;" "$nginx_ssl_conf"
    else
        log_debug "Füge HSTS-Header hinzu..."
        # Füge nach dem Header-Block ein, oder am Ende der Datei falls nicht vorhanden
        local insert_point=$(grep -n "# Sicherheitsheader" "$nginx_ssl_conf" | cut -d':' -f1)
        
        if [ -n "$insert_point" ]; then
            # Füge nach dem letzten Header ein
            local last_header=$(grep -n "add_header" "$nginx_ssl_conf" | tail -1 | cut -d':' -f1)
            if [ -n "$last_header" ]; then
                sed -i "${last_header}a\\add_header Strict-Transport-Security $hsts_value always;" "$nginx_ssl_conf"
            else
                # Füge nach dem Sicherheitsheader-Kommentar ein
                sed -i "${insert_point}a\\add_header Strict-Transport-Security $hsts_value always;" "$nginx_ssl_conf"
            fi
        else
            # Füge am Ende der Datei ein
            echo -e "\n# HSTS (HTTP Strict Transport Security)\nadd_header Strict-Transport-Security $hsts_value always;" >> "$nginx_ssl_conf"
        fi
    fi
    
    # Teste die NGINX-Konfiguration
    if ! nginx -t &>/dev/null; then
        log_error "Die NGINX-Konfiguration ist ungültig nach HSTS-Änderungen."
        return 2
    fi
    
    # Lade die NGINX-Konfiguration neu
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || {
            log_error "Konnte NGINX-Konfiguration nicht neu laden."
            return 3
        }
    fi
    
    if [ "$preload" = "yes" ]; then
        log_warn "Sie haben HSTS mit der preload-Option aktiviert. Beachten Sie, dass dies dazu führen kann,"
        log_warn "dass Browser ihre Domain für eine lange Zeit nur noch über HTTPS zugänglich machen."
        log_warn "Weitere Informationen: https://hstspreload.org/"
    fi
    
    log_info "HTTP Strict Transport Security (HSTS) wurde erfolgreich konfiguriert."
    log_info "HSTS-Header: $hsts_value"
    return 0
}
