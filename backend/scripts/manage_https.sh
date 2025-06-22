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

# Textausgaben für das gesamte Skript
manage_https_log_0001="KRITISCHER FEHLER: Zentrale Bibliothek lib_core.sh nicht gefunden!"
manage_https_log_0002="Die Installation scheint beschädigt zu sein. Bitte führen Sie eine Reparatur durch."
manage_https_log_0003="KRITISCHER FEHLER: Die Kernressourcen konnten nicht geladen werden."

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ ! -f "$SCRIPT_DIR/lib_core.sh" ]; then
    echo "$manage_https_log_0001" >&2
    echo "$manage_https_log_0002" >&2
    exit 1
fi

source "$SCRIPT_DIR/lib_core.sh"

# Hybrides Ladeverhalten: 
# Bei MODULE_LOAD_MODE=1 (Installation/Update) werden alle Module geladen
# Bei MODULE_LOAD_MODE=0 (normaler Betrieb) werden Module individuell geladen
if [ "${MODULE_LOAD_MODE:-0}" -eq 1 ]; then
    load_core_resources || {
        echo "$manage_https_log_0003" >&2
        echo "$manage_https_log_0002" >&2
        exit 1
    }
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
# Verwende manage_folders.sh für konsistente Pfadverwaltung
DEFAULT_DIR_CONF_HTTPS="$(get_https_conf_dir 2>/dev/null || echo "${CONF_DIR}/https")"
DEFAULT_DIR_BACKUP_HTTPS="$(get_https_backup_dir 2>/dev/null || echo "${BACKUP_DIR}/https")"

# SSL-Konfigurationsstandards
DEFAULT_SSL_PROTOCOLS="TLSv1.2 TLSv1.3"
DEFAULT_SSL_CIPHERS="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"
DEFAULT_SSL_PREFER_SERVER_CIPHERS="on"
DEFAULT_SSL_SESSION_TIMEOUT="1d"
DEFAULT_SSL_SESSION_CACHE="shared:SSL:10m"
DEFAULT_SSL_DHPARAM_BITS=2048

# Zertifikatspfade
SSL_CERT_DIR="${DEFAULT_DIR_CONF_HTTPS}/certs"
SSL_KEY_DIR="${DEFAULT_DIR_CONF_HTTPS}/private"
SSL_DHPARAM_FILE="${DEFAULT_DIR_CONF_HTTPS}/dhparam.pem"

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
    mkdir -p "$SSL_CERT_DIR" "$SSL_KEY_DIR" "$DEFAULT_DIR_CONF_HTTPS" || {
        log_error "Konnte SSL-Konfigurationsverzeichnisse nicht erstellen."
        return 1
    }
    
    # Erstelle Backup-Verzeichnisse
    mkdir -p "$DEFAULT_DIR_BACKUP_HTTPS/certs" "$DEFAULT_DIR_BACKUP_HTTPS/private" || {
        log_error "Konnte SSL-Backup-Verzeichnisse nicht erstellen."
        return 1
    }
    
    # Setze Berechtigungen
    chmod -R 755 "$DEFAULT_DIR_CONF_HTTPS" "$DEFAULT_DIR_BACKUP_HTTPS" || {
        log_error "Konnte Berechtigungen für SSL-Verzeichnisse nicht setzen."
        return 1
    }
    
    # Private Keys besonders schützen
    chmod 700 "$SSL_KEY_DIR" "$DEFAULT_DIR_BACKUP_HTTPS/private" || {
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
    local config_file="${DEFAULT_DIR_CONF_HTTPS}/openssl_${out_prefix}.cnf"
    
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
    root $(get_frontend_dir);
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
    local root_dir="$(get_frontend_dir)"
    local index_files="start.html index.html"
    local http_redirect="yes"
    
    if [ -n "$ssl_options" ]; then
        # Verarbeite JSON-Optionen wenn vorhanden
        if command -v jq &> /dev/null; then
            if echo "$ssl_options" | jq -e . &>/dev/null; then
                api_port=$(echo "$ssl_options" | jq -r '.api_port // "5000"')
                root_dir=$(echo "$ssl_options" | jq -r ".root_dir // \"$(get_frontend_dir)\"")
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

# HTTP zu HTTPS Umleitung
server {
    listen 80;
    server_name $domain;
    
    # Umleitung aller HTTP-Anfragen auf HTTPS
    return 301 https://\$host\$request_uri;
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

# ---------------------------------------------------------------------------
# Funktion: setup_security_headers
# ---------------------------------------------------------------------------
# Beschreibung: Konfiguriert zusätzliche Sicherheitsheader für NGINX
# Parameter:
#   $1 - Content-Security-Policy-Level (strict|standard|relaxed) [standard]
#   $2 - Referrer-Policy-Einstellung (strict-origin|no-referrer-when-downgrade) [strict-origin]
#   $3 - Ausgabemodus (text|json) [text]
# Rückgabewert: 0 = erfolgreich, 1 = Fehler bei NGINX-Konfiguration, 2 = Konfigurationstest fehlgeschlagen
# ---------------------------------------------------------------------------
function setup_security_headers() {
    local csp_level="${1:-standard}"
    local referrer_policy="${2:-strict-origin}"
    local mode="${3:-text}"
    
    log_debug "Konfiguriere erweiterte Sicherheitsheader (CSP: $csp_level, Referrer: $referrer_policy)..."
    
    # Prüfen, ob NGINX konfiguriert ist
    local nginx_conf_dir
    nginx_conf_dir=$(get_nginx_conf_dir)
    
    local nginx_ssl_conf
    nginx_ssl_conf="${nginx_conf_dir}/sites-enabled/fotobox-https.conf"
    
    if [ ! -f "$nginx_ssl_conf" ]; then
        log_or_json "$mode" "error" "Keine HTTPS-Konfigurationsdatei für NGINX gefunden." 1
        return 1
    fi
    
    # Content-Security-Policy erstellen basierend auf gewähltem Level
    local csp_value
    case "$csp_level" in
        "strict")
            # Sehr restriktive CSP für maximale Sicherheit
            csp_value="default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; media-src 'self'; object-src 'none'; frame-src 'self'; worker-src 'self'; frame-ancestors 'self'; form-action 'self'; base-uri 'self'; manifest-src 'self'"
            ;;
        "relaxed")
            # Weniger restriktive CSP für mehr Flexibilität
            csp_value="default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' ws: wss:; media-src 'self' blob:; object-src 'none'; frame-src 'self'; worker-src 'self' blob:; frame-ancestors 'self'; form-action 'self'; base-uri 'self'; manifest-src 'self'"
            ;;
        *)
            # Standard CSP mit ausgewogener Sicherheit (default)
            csp_value="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' ws: wss:; media-src 'self'; object-src 'none'; frame-src 'self'; worker-src 'self'; frame-ancestors 'self'; form-action 'self'; base-uri 'self'; manifest-src 'self'"
            ;;
    esac
    
    # Referrer-Policy festlegen
    local referrer_value
    case "$referrer_policy" in
        "no-referrer")
            referrer_value="no-referrer"
            ;;
        "no-referrer-when-downgrade")
            referrer_value="no-referrer-when-downgrade"
            ;;
        "same-origin")
            referrer_value="same-origin"
            ;;
        "origin-when-cross-origin")
            referrer_value="origin-when-cross-origin"
            ;;
        "strict-origin-when-cross-origin")
            referrer_value="strict-origin-when-cross-origin"
            ;;
        *)
            # Standard-Einstellung (strict-origin) für ausgewogene Sicherheit
            referrer_value="strict-origin"
            ;;
    esac
    
    local temp_file
    temp_file=$(mktemp)
    
    # Füge CSP-Header hinzu oder aktualisiere bestehenden
    if grep -q "Content-Security-Policy" "$nginx_ssl_conf"; then
        log_debug "Ersetze vorhandenen CSP-Header..."
        sed "s|add_header Content-Security-Policy.*|add_header Content-Security-Policy \"$csp_value\" always;|" "$nginx_ssl_conf" > "$temp_file"
        cat "$temp_file" > "$nginx_ssl_conf"
    else
        log_debug "Füge CSP-Header hinzu..."
        # Suche nach dem Sicherheitsheader-Block
        if grep -q "# Sicherheitsheader" "$nginx_ssl_conf"; then
            # Füge nach dem letzten Header ein
            awk '/add_header/ {last_line=NR} END {if (last_line) {for (i=1; i<=NR; i++) {print $0; if (i==last_line) {print "    add_header Content-Security-Policy \"'"$csp_value"'\" always;"}} next} {print}' "$nginx_ssl_conf" > "$temp_file"
            cat "$temp_file" > "$nginx_ssl_conf"
        else
            # Füge nach den SSL-Einstellungen ein
            awk '/ssl_/ {last_line=NR} END {if (last_line) {for (i=1; i<=NR; i++) {print $0; if (i==last_line) {print "\n    # Sicherheitsheader\n    add_header Content-Security-Policy \"'"$csp_value"'\" always;"}} next} {print}' "$nginx_ssl_conf" > "$temp_file"
            cat "$temp_file" > "$nginx_ssl_conf"
        fi
    fi
    
    # Füge Referrer-Policy-Header hinzu oder aktualisiere bestehenden
    if grep -q "Referrer-Policy" "$nginx_ssl_conf"; then
        log_debug "Ersetze vorhandenen Referrer-Policy-Header..."
        sed "s|add_header Referrer-Policy.*|add_header Referrer-Policy \"$referrer_value\" always;|" "$nginx_ssl_conf" > "$temp_file"
        cat "$temp_file" > "$nginx_ssl_conf"
    else
        log_debug "Füge Referrer-Policy-Header hinzu..."
        # Suche nach dem Content-Security-Policy-Header
        if grep -q "Content-Security-Policy" "$nginx_ssl_conf"; then
            # Füge nach dem CSP-Header ein
            sed "/Content-Security-Policy/a\\    add_header Referrer-Policy \"$referrer_value\" always;" "$nginx_ssl_conf" > "$temp_file"
            cat "$temp_file" > "$nginx_ssl_conf"
        else
            # Füge nach dem letzten Header ein
            awk '/add_header/ {last_line=NR} END {if (last_line) {for (i=1; i<=NR; i++) {print $0; if (i==last_line) {print "    add_header Referrer-Policy \"'"$referrer_value"'\" always;"}} next} {print}' "$nginx_ssl_conf" > "$temp_file"
            cat "$temp_file" > "$nginx_ssl_conf"
        }
    fi
    
    # Temporäre Datei entfernen
    rm -f "$temp_file"
    
    # Teste die NGINX-Konfiguration
    if ! nginx -t &>/dev/null; then
        log_or_json "$mode" "error" "Die NGINX-Konfiguration ist ungültig nach den Sicherheitsheader-Änderungen." 2
        return 2
    fi
    
    # Lade die NGINX-Konfiguration neu
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || {
            log_or_json "$mode" "error" "Konnte NGINX-Konfiguration nicht neu laden." 1
            return 1
        }
    fi
    
    log_or_json "$mode" "success" "Sicherheitsheader wurden erfolgreich konfiguriert:" 0
    log_or_json "$mode" "info" "Content-Security-Policy: $csp_level" 0
    log_or_json "$mode" "info" "Referrer-Policy: $referrer_value" 0
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: optimize_ssl_configuration
# ---------------------------------------------------------------------------
# Beschreibung: Optimiert die SSL/TLS-Konfiguration für maximale Sicherheit und Performance
# Parameter:
#   $1 - Sicherheitslevel (high|medium|compatible) [high]
#   $2 - NGINX-Konfigurationspfad [auto-detected]
#   $3 - Ausgabemodus (text|json) [text]
# Rückgabewert: 0 = erfolgreich, 1 = Fehler bei NGINX-Konfiguration, 
#               2 = Konfigurationstest fehlgeschlagen, 3 = DH-Parameter konnten nicht erstellt werden
# ---------------------------------------------------------------------------
function optimize_ssl_configuration() {
    local security_level="${1:-high}"
    local nginx_conf_path="$2"
    local mode="${3:-text}"
    
    log_debug "Optimiere SSL-Konfiguration (Level: $security_level)..."
    
    # Wenn kein Konfigurationspfad angegeben wurde, automatisch erkennen
    if [ -z "$nginx_conf_path" ]; then
        local nginx_conf_dir
        nginx_conf_dir=$(get_nginx_conf_dir)
        nginx_conf_path="${nginx_conf_dir}/sites-enabled/fotobox-https.conf"
    fi
    
    if [ ! -f "$nginx_conf_path" ]; then
        log_or_json "$mode" "error" "Keine HTTPS-Konfigurationsdatei gefunden unter: $nginx_conf_path" 1
        return 1
    fi
    
    # SSL-Protokolle und Cipher-Suites basierend auf Sicherheitslevel festlegen
    local ssl_protocols
    local ssl_ciphers
    local ssl_prefer_server_ciphers="on"
    local ssl_session_timeout="1d"
    local ssl_session_cache="shared:SSL:10m"
    local ssl_session_tickets="off"
    local ssl_stapling="on"
    local ssl_stapling_verify="on"
    local dhparam_bits=2048
    
    case "$security_level" in
        "high")
            # Nur TLS 1.3 und moderne Cipher-Suites für maximale Sicherheit
            ssl_protocols="TLSv1.3"
            ssl_ciphers="TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
            dhparam_bits=4096
            ;;
        "compatible")
            # TLS 1.2 und 1.3 mit breiterer Cipher-Kompatibilität für ältere Clients
            ssl_protocols="TLSv1.2 TLSv1.3"
            ssl_ciphers="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305"
            ;;
        *)
            # Standard/Medium: TLS 1.2 und 1.3 mit starken, aber breiteren Cipher-Suites
            ssl_protocols="TLSv1.2 TLSv1.3"
            ssl_ciphers="ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
            ;;
    esac
    
    # Prüfen und ggf. erstellen der Diffie-Hellman Parameter
    if [ ! -f "$SSL_DHPARAM_FILE" ] || [ "$security_level" = "high" ]; then
        log_or_json "$mode" "info" "Generiere neue Diffie-Hellman Parameter mit $dhparam_bits Bits... (Dies kann einige Minuten dauern)" 0
        
        mkdir -p "$(dirname "$SSL_DHPARAM_FILE")"
        
        if ! openssl dhparam -out "$SSL_DHPARAM_FILE" "$dhparam_bits" 2>/dev/null; then
            log_or_json "$mode" "error" "Konnte keine Diffie-Hellman Parameter generieren." 3
            return 3
        fi
        
        chmod 644 "$SSL_DHPARAM_FILE"
        log_or_json "$mode" "success" "Diffie-Hellman Parameter erfolgreich erstellt." 0
    fi
    
    # Backup der aktuellen Konfiguration erstellen
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="${DEFAULT_DIR_BACKUP_HTTPS}/nginx-ssl-${timestamp}.conf"
    
    mkdir -p "$(dirname "$backup_file")"
    cp "$nginx_conf_path" "$backup_file"
    
    # Temporäre Datei für die Bearbeitung
    local temp_file=$(mktemp)
    
    # SSL-Parameter in der Konfiguration aktualisieren oder hinzufügen
    # Zuerst prüfen, ob ein SSL-Konfigurationsblock existiert
    if grep -q "ssl_protocols" "$nginx_conf_path"; then
        # Update vorhandene SSL-Einstellungen
        sed -e "s/ssl_protocols.*/ssl_protocols $ssl_protocols;/" \
            -e "s/ssl_ciphers.*/ssl_ciphers '$ssl_ciphers';/" \
            -e "s/ssl_prefer_server_ciphers.*/ssl_prefer_server_ciphers $ssl_prefer_server_ciphers;/" \
            -e "s/ssl_session_timeout.*/ssl_session_timeout $ssl_session_timeout;/" \
            -e "s/ssl_session_cache.*/ssl_session_cache $ssl_session_cache;/" \
            -e "s/ssl_session_tickets.*/ssl_session_tickets $ssl_session_tickets;/" \
            -e "s/ssl_stapling.*/ssl_stapling $ssl_stapling;/" \
            -e "s/ssl_stapling_verify.*/ssl_stapling_verify $ssl_stapling_verify;/" \
            "$nginx_conf_path" > "$temp_file"
        
        # DHParam-Konfiguration prüfen und ggf. hinzufügen
        if grep -q "ssl_dhparam" "$temp_file"; then
            sed -i "s|ssl_dhparam.*|ssl_dhparam $SSL_DHPARAM_FILE;|" "$temp_file"
        else
            # Nach dem letzten ssl_-Parameter einfügen
            awk '/ssl_/ {last_line=NR} END {if (last_line) {for (i=1; i<=NR; i++) {print $0; if (i==last_line) {print "    ssl_dhparam '"$SSL_DHPARAM_FILE"';"}} next} {print}' "$temp_file" > "${temp_file}.new"
            mv "${temp_file}.new" "$temp_file"
        fi
    else
        # Kein vorhandener SSL-Block, wir fügen einen neuen hinzu nach dem Listen-Block oder Server-Block
        cat "$nginx_conf_path" > "$temp_file"
        local ssl_config="
    # SSL-Konfiguration (Level: $security_level)
    ssl_protocols $ssl_protocols;
    ssl_ciphers '$ssl_ciphers';
    ssl_prefer_server_ciphers $ssl_prefer_server_ciphers;
    ssl_session_timeout $ssl_session_timeout;
    ssl_session_cache $ssl_session_cache;
    ssl_session_tickets $ssl_session_tickets;
    ssl_dhparam $SSL_DHPARAM_FILE;
    ssl_stapling $ssl_stapling;
    ssl_stapling_verify $ssl_stapling_verify;
"
        
        # Prüfen, ob es einen "listen" Eintrag gibt und dahinter einfügen
        if grep -q "listen.*ssl" "$temp_file"; then
            sed -i "/listen.*ssl/a\\$ssl_config" "$temp_file"
        else
            # Ansonsten nach dem server { Block einfügen
            sed -i "/server {/a\\$ssl_config" "$temp_file"
        fi
    fi
    
    # Finalen Konfig-Inhalt in die eigentliche Datei schreiben
    cat "$temp_file" > "$nginx_conf_path"
    rm -f "$temp_file"
    
    # NGINX-Konfiguration testen
    if ! nginx -t &>/dev/null; then
        log_or_json "$mode" "error" "Die NGINX-Konfiguration ist ungültig nach den SSL-Optimierungen." 2
        # Backup wiederherstellen
        cp "$backup_file" "$nginx_conf_path"
        log_or_json "$mode" "info" "Die ursprüngliche Konfiguration wurde wiederhergestellt." 0
        return 2
    fi
    
    # NGINX neu laden, wenn es läuft
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || {
            log_or_json "$mode" "error" "Konnte NGINX-Konfiguration nicht neu laden." 1
            # Backup wiederherstellen
            cp "$backup_file" "$nginx_conf_path"
            log_or_json "$mode" "info" "Die ursprüngliche Konfiguration wurde wiederhergestellt." 0
            return 1
        }
    fi
    
    log_or_json "$mode" "success" "SSL/TLS-Konfiguration wurde erfolgreich optimiert (Level: $security_level)." 0
    log_or_json "$mode" "info" "SSL-Protokolle: $ssl_protocols" 0
    log_or_json "$mode" "info" "Backup der vorherigen Konfiguration: $backup_file" 0
    
    # SSL-Labs-Bewertungshinweis
    log_or_json "$mode" "info" "Tipp: Testen Sie Ihre SSL-Konfiguration mit SSL Labs: https://www.ssllabs.com/ssltest/" 0
    
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: optimize_nginx_for_ssl
# ---------------------------------------------------------------------------
# Beschreibung: Optimiert NGINX für SSL-Performance basierend auf Systemressourcen
# Parameter:
#   $1 - Optimierungslevel (high|medium|auto) [auto]
#   $2 - Ausgabemodus (text|json) [text]
# Rückgabewert: 0 = erfolgreich, 1 = Fehler bei der NGINX-Konfiguration, 
#               2 = Konfigurationstest fehlgeschlagen
# ---------------------------------------------------------------------------
function optimize_nginx_for_ssl() {
    local optimization_level="${1:-auto}"
    local mode="${2:-text}"
    
    log_debug "Optimiere NGINX für SSL-Performance (Level: $optimization_level)..."
    
    # NGINX-Konfigurationsdatei für die Hauptkonfiguration
    local nginx_main_conf="/etc/nginx/nginx.conf"
    
    if [ ! -f "$nginx_main_conf" ]; then
        log_or_json "$mode" "error" "NGINX-Hauptkonfigurationsdatei nicht gefunden: $nginx_main_conf" 1
        return 1
    fi
    
    # Backup der aktuellen Konfiguration erstellen
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="${DEFAULT_DIR_BACKUP_HTTPS}/nginx-main-${timestamp}.conf"
    
    mkdir -p "$(dirname "$backup_file")"
    cp "$nginx_main_conf" "$backup_file"
    
    # CPU-Kerne und verfügbaren Arbeitsspeicher ermitteln
    local cpu_cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
    local mem_total_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 1024000)
    local mem_total_mb=$((mem_total_kb / 1024))
    
    # Worker-Prozesse basierend auf CPU-Kernen und Optimierungslevel
    local worker_processes
    local worker_connections
    local worker_rlimit_nofile
    local ssl_session_cache_size
    
    case "$optimization_level" in
        "high")
            # Maximale Performance für dedizierte Server
            worker_processes="$cpu_cores"
            worker_connections=$((mem_total_mb / 8))  # ~128k pro Verbindung
            worker_rlimit_nofile=$((worker_connections * 2))
            ssl_session_cache_size="50m"
            ;;
        "medium")
            # Ausgewogene Performance für gemischte Server
            worker_processes=$((cpu_cores / 2 + 1))
            worker_connections=$((mem_total_mb / 16))  # ~64k pro Verbindung
            worker_rlimit_nofile=$((worker_connections * 2))
            ssl_session_cache_size="20m"
            ;;
        *)
            # Auto/Standard - basierend auf verfügbaren Ressourcen
            if [ "$cpu_cores" -gt 4 ] && [ "$mem_total_mb" -gt 4096 ]; then
                # Größeres System
                worker_processes=$((cpu_cores - 2))
                worker_connections=$((mem_total_mb / 12))
                worker_rlimit_nofile=$((worker_connections * 2))
                ssl_session_cache_size="30m"
            else
                # Kleineres System
                worker_processes=2
                worker_connections=$((mem_total_mb / 24))
                worker_rlimit_nofile=$((worker_connections * 2))
                ssl_session_cache_size="10m"
            fi
            ;;
    esac
    
    # Sicherstellen, dass die Werte sinnvoll sind
    [ "$worker_processes" -lt 1 ] && worker_processes=1
    [ "$worker_connections" -lt 512 ] && worker_connections=512
    [ "$worker_rlimit_nofile" -lt 1024 ] && worker_rlimit_nofile=1024
    
    log_debug "Optimierung basierend auf $cpu_cores CPU-Kernen und $mem_total_mb MB RAM"
    log_debug "Worker-Prozesse: $worker_processes"
    log_debug "Worker-Verbindungen: $worker_connections"
    log_debug "Worker-RLIMIT-NOFILE: $worker_rlimit_nofile"
    log_debug "SSL-Session-Cache-Größe: $ssl_session_cache_size"
    
    # Temporäre Datei für die Bearbeitung
    local temp_file=$(mktemp)
    
    # Worker-Prozesse aktualisieren oder hinzufügen
    if grep -q "^worker_processes" "$nginx_main_conf"; then
        sed -i "s/^worker_processes .*/worker_processes $worker_processes;/" "$nginx_main_conf"
    else
        sed -i "/^user/a worker_processes $worker_processes;" "$nginx_main_conf"
    fi
    
    # Worker-Verbindungen aktualisieren oder hinzufügen
    if grep -q "worker_connections" "$nginx_main_conf"; then
        sed -i "/worker_connections/s/[0-9]\+/$worker_connections/" "$nginx_main_conf"
    else
        # Suche nach events { Block und füge worker_connections hinzu
        awk '/events {/ {print; print "    worker_connections '"$worker_connections"';"; next} {print}' "$nginx_main_conf" > "$temp_file"
        cat "$temp_file" > "$nginx_main_conf"
    fi
    
    # Worker-RLIMIT-NOFILE aktualisieren oder hinzufügen
    if grep -q "worker_rlimit_nofile" "$nginx_main_conf"; then
        sed -i "s/worker_rlimit_nofile .*/worker_rlimit_nofile $worker_rlimit_nofile;/" "$nginx_main_conf"
    else
        sed -i "/^worker_processes/a worker_rlimit_nofile $worker_rlimit_nofile;" "$nginx_main_conf"
    fi
    
    # SSL-Session-Cache aktualisieren
    # Finden und aktualisieren der http-Sektion
    awk -v cache_size="$ssl_session_cache_size" '
    BEGIN {in_http=0; found_ssl_cache=0}
    /^http {/ {in_http=1}
    /ssl_session_cache/ && in_http {found_ssl_cache=1; print "    ssl_session_cache shared:SSL:" cache_size ";"; next}
    /}/ && in_http {
        if(!found_ssl_cache) {
            print "    # SSL Performance Optimierungen"
            print "    ssl_session_cache shared:SSL:" cache_size ";"
            print "    ssl_session_timeout 10m;"
            print "    ssl_buffer_size 8k;"
        }
        in_http=0
        print
        next
    }
    {print}
    ' "$nginx_main_conf" > "$temp_file"
    
    cat "$temp_file" > "$nginx_main_conf"
    rm -f "$temp_file"
    
    # NGINX-Konfiguration testen
    if ! nginx -t &>/dev/null; then
        log_or_json "$mode" "error" "Die NGINX-Konfiguration ist ungültig nach den Optimierungen." 2
        # Backup wiederherstellen
        cp "$backup_file" "$nginx_main_conf"
        log_or_json "$mode" "info" "Die ursprüngliche Konfiguration wurde wiederhergestellt." 0
        return 2
    fi
    
    # NGINX neu laden, wenn es läuft
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || {
            log_or_json "$mode" "error" "Konnte NGINX-Konfiguration nicht neu laden." 1
            # Backup wiederherstellen
            cp "$backup_file" "$nginx_main_conf"
            log_or_json "$mode" "info" "Die ursprüngliche Konfiguration wurde wiederhergestellt." 0
            return 1
        }
    fi
    
    log_or_json "$mode" "success" "NGINX wurde erfolgreich für SSL-Performance optimiert:" 0
    log_or_json "$mode" "info" "Worker-Prozesse: $worker_processes" 0
    log_or_json "$mode" "info" "Worker-Verbindungen: $worker_connections" 0
    log_or_json "$mode" "info" "SSL-Session-Cache: $ssl_session_cache_size" 0
    
    return 0
}

# ---------------------------------------------------------------------------
# Funktion: update_system_for_https
# ---------------------------------------------------------------------------
# Beschreibung: Aktualisiert Systemeinstellungen für HTTPS (Firewall, Limits)
# Parameter:
#   $1 - HTTPS-Port [443]
#   $2 - Systemlimit für offene Dateien [65535]
#   $3 - Ausgabemodus (text|json) [text]
# Rückgabewert: 0 = erfolgreich, 1 = Firewall-Fehler, 2 = Limits-Fehler
# ---------------------------------------------------------------------------
function update_system_for_https() {
    local https_port="${1:-443}"
    local file_limit="${2:-65535}"
    local mode="${3:-text}"
    
    log_debug "Aktualisiere Systemeinstellungen für HTTPS (Port: $https_port, Limit: $file_limit)..."

    # Prüfen ob manage_firewall.sh bereits geladen ist
    if [ -z "$MANAGE_FIREWALL_LOADED" ] || [ "$MANAGE_FIREWALL_LOADED" -ne 1 ]; then
        load_module "manage_firewall" || {
            log_or_json "$mode" "error" "manage_firewall.sh Modul konnte nicht geladen werden." 1
            return 1
        }
    fi
    
    # Firewall-Konfiguration für HTTPS-Port
    log_or_json "$mode" "info" "Konfiguriere Firewall-Regeln für HTTPS (Port $https_port)..." 0
    if ! open_port "$https_port" "tcp" "HTTPS/SSL-Verbindungen" "$mode"; then
        log_or_json "$mode" "error" "Konnte Firewall-Regeln für Port $https_port nicht aktualisieren." 1
        return 1
    fi
    
    # Systemlimits für offene Dateien anpassen
    log_or_json "$mode" "info" "Aktualisiere Systemlimits für offene Dateien und Verbindungen..." 0
    
    # Prüfen, ob wir systemd verwenden
    if command -v systemctl &> /dev/null && systemctl is-active --quiet nginx; then
        # systemd-Limits für NGINX anpassen
        local systemd_dir="/etc/systemd/system"
        local nginx_override_dir="${systemd_dir}/nginx.service.d"
        
        mkdir -p "$nginx_override_dir"
        
        cat << EOF > "${nginx_override_dir}/limits.conf"
[Service]
LimitNOFILE=$file_limit
EOF
        
        # systemd neu laden und NGINX neu starten
        systemctl daemon-reload || {
            log_or_json "$mode" "error" "Konnte systemd nicht neu laden." 2
            return 2
        }
        
        systemctl restart nginx || {
            log_or_json "$mode" "error" "Konnte NGINX nicht neu starten nach Limit-Änderungen." 2
            return 2
        }
    else
        # Klassisches Limit über /etc/security/limits.conf
        local limits_file="/etc/security/limits.conf"
        
        if [ -f "$limits_file" ]; then
            # Prüfen und ggf. hinzufügen des Limits für den nginx-Benutzer
            if grep -q "^nginx" "$limits_file"; then
                sed -i "/^nginx.*nofile/d" "$limits_file"
            fi
            
            echo -e "\n# Limits für NGINX HTTPS-Verbindungen\nnginx soft nofile $file_limit\nnginx hard nofile $file_limit" >> "$limits_file"
            
            log_or_json "$mode" "info" "Systemlimits in $limits_file aktualisiert." 0
            log_or_json "$mode" "warn" "Ein Neustart des NGINX-Dienstes ist erforderlich, damit die neuen Limits wirksam werden." 0
        else
            log_or_json "$mode" "error" "Limits-Konfigurationsdatei nicht gefunden: $limits_file" 2
            return 2
        fi
    fi
    
    # Systemstatistiken zur Überprüfung ausgeben
    local nginx_user_limits=$(grep -i "open files" /proc/$(pgrep -o nginx)/limits 2>/dev/null || echo "Unbekannt")
    
    log_or_json "$mode" "success" "Systemeinstellungen für HTTPS wurden erfolgreich aktualisiert:" 0
    log_or_json "$mode" "info" "Firewall: Port $https_port (TCP) geöffnet für HTTPS-Verbindungen" 0
    log_or_json "$mode" "info" "Systemlimits für NGINX: $nginx_user_limits" 0
    
    return 0
}
