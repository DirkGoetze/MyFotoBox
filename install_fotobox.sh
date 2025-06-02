#!/bin/bash
# ------------------------------------------------------------------------------
# install_fotobox.sh
# ------------------------------------------------------------------------------
# Funktion: Führt die Erstinstallation der Fotobox durch (Systempakete, User, Grundstruktur)
# Für Ubuntu/Debian-basierte Systeme, muss als root ausgeführt werden.
# Nach erfolgreicher Installation erfolgt die weitere Verwaltung (Update, Deinstallation)
# über die WebUI bzw. Python-Skripte im backend/.
# ------------------------------------------------------------------------------
# HINWEIS: Die Backup-/Restore-Strategie ist verbindlich in BACKUP_STRATEGIE.md dokumentiert
# und für alle neuen Features, API-Endpunkte und Systemintegrationen einzuhalten.
# ------------------------------------------------------------------------------
# HINWEIS: Für Shellskripte gilt zusätzlich:
# - Fehlerausgaben immer in Rot
# - Ausgaben zu auszuführenden Schritten in Gelb
# - Erfolgsmeldungen in Dunkelgrün
# - Aufforderungen zur Nutzeraktion in Blau
# - Alle anderen Ausgaben nach Systemstandard
# Siehe Funktionsbeispiele und DOKUMENTATIONSSTANDARD.md
# ------------------------------------------------------------------------------

set -e

# ------------------------------------------------------------------------------
# TODO: Verbesserungen und Optimierungen für zukünftige Versionen
# ------------------------------------------------------------------------------
# [x] Automatische Prüfung, ob NGINX-Default-Server auf Port 80 deaktiviert werden soll
# [ ] Optionale Firewall-Konfiguration (z.B. ufw) für den gewählten Port
# [ ] Automatische HTTPS-Konfiguration (Let's Encrypt)
# [ ] Fortschrittsanzeige für lange Operationen (z.B. git clone, pip install)
# [ ] Optionale E-Mail-Benachrichtigung nach erfolgreicher Installation
# [x] Bessere Fehlerausgabe und Logging in Logdatei
# [x] Unterstützung für weitere Linux-Distributionen prüfen
# [ ] Mehrsprachige Installationsausgabe (DE/EN)
# [x] Automatische Prüfung auf bereits laufende Fotobox-Instanz
# [x] Optionale Integration in bestehende NGINX-Konfiguration (statt eigene Site)
# [x] Verbesserte Rückabwicklung bei Fehlern (Rollback)
# [x] Automatische Prüfung und ggf. Korrektur von Dateirechten
# [ ] Optionale Installation als Docker-Container
# [ ] Automatische Prüfung der Erreichbarkeit der Weboberfläche nach der Installation (z.B. per curl) und Ausgabe einer entsprechenden Erfolgsmeldung oder eines Hinweises zur Fehlerbehebung
# ------------------------------------------------------------------------------

# ===========================================================================
# Globale Konstanten
# ===========================================================================
# ---------------------------------------------------------------------------
# Projekt Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_TOOLS=(git lsof)
GIT_REPO_URL="https://github.com/DirkGoetze/fotobox2.git"
INSTALL_DIR="/opt/fotobox"
README_MAIN="# fotobox\nDies ist das Hauptverzeichnis der Fotobox-Installation. Es enthält alle relevanten Unterverzeichnisse, Konfigurationen und Daten."
BACKUP_DIR="$INSTALL_DIR/backup"
README_BACKUP="# backup\nDieses Verzeichnis wird automatisch durch die Installations- und Update-Skripte erzeugt und enthält Backups von Konfigurationsdateien und Logs. Es ist nicht Teil des Repositorys."
CONF_DIR="$INSTALL_DIR/conf"
README_CONF="# conf\nDieses Verzeichnis enthält alle Konfigurationsdateien der Fotobox. Es wird automatisch angelegt und ist nicht Teil des Repositorys."
# ---------------------------------------------------------------------------
# NGINX Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_NGINX=(nginx)
NGINX_CONF="$CONF_DIR/nginx-fotobox.conf"
SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"
NGINX_DST="/etc/nginx/sites-available/fotobox"
FOTOBOX_PORT=80
SYSTEMD_DST="/etc/systemd/system/fotobox-backend.service"
# ---------------------------------------------------------------------------
# Python Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_PYTHON=(python3 python3-venv python3-pip)
# ---------------------------------------------------------------------------
# SQLite Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_SQLITE=(sqlite3)
DATA_DIR="$INSTALL_DIR/data"
README_DATA="# data\nDieses Verzeichnis enthält die persistenten Daten der Fotobox (z.B. SQLite-Datenbank, Fotos, Einstellungen). Es wird automatisch angelegt und ist nicht Teil des Repositorys."

# ==========================================================================='
# Hilfsfunktionen
# ==========================================================================='

print_step() {
    # -----------------------------------------------------------------------
    # print_step
    # -----------------------------------------------------------------------
    # Funktion: Gibt einen Hinweis auf einen auszuführenden Schritt in Gelb aus
    echo -e "\033[1;33m$1\033[0m"
}

print_error() {
    # -----------------------------------------------------------------------
    # print_error
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Fehlermeldung farbig aus
    echo -e "\033[1;31m  → Fehler: $1\033[0m"
}

print_success() {
    # -----------------------------------------------------------------------
    # print_success
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Erfolgsmeldung in Dunkelgrün aus
    echo -e "\033[1;32m  → $1\033[0m"
}

print_prompt() {
    # -----------------------------------------------------------------------
    # dlg_prompt
    # -----------------------------------------------------------------------
    # Funktion: Gibt eine Nutzeraufforderung in Blau aus
    echo -e "\033[1;34m$1\033[0m"
}

chk_is_root() {
    # -----------------------------------------------------------------------
    # chk_is_root
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das Skript als root ausgeführt wird
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
    return 0
}

chk_distribution() {
    # -----------------------------------------------------------------------
    # chk_distribution
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das System auf Debian/Ubuntu basiert
    if [ ! -f /etc/os-release ]; then
        return 1
    fi
    . /etc/os-release
    if [[ ! "$ID" =~ ^(debian|ubuntu|raspbian)$ && ! "$ID_LIKE" =~ (debian|ubuntu) ]]; then
        return 1
    fi
    return 0
}

make_dir() {
    # -----------------------------------------------------------------------
    # make_dir
    # -----------------------------------------------------------------------
    # Funktion: Legt ein Verzeichnis an, falls es nicht existiert und legt eine readme.md an
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = kein Verzeichnis angegeben
    local dir="$1"
    local readme_content="$2"

    if [ -z "$dir" ]; then
        return 2
    fi

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        if [ ! -d "$dir" ]; then
            return 1
        fi
    fi
    # readme.md anlegen, falls nicht vorhanden und Inhalt übergeben wurde
    if [ -n "$readme_content" ] && [ ! -f "$dir/readme.md" ]; then
        echo -e "$readme_content" > "$dir/readme.md"
    fi
    return 0
}

install_package() {
    # -----------------------------------------------------------------------
    # install_package
    # -----------------------------------------------------------------------
    # Funktion: Installiert ein einzelnes Systempaket in gewünschter Version 
    # (optional)
    local pkg="$1"
    local version="$2"

    if [ -n "$version" ]; then
        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        if [ "$installed_version" = "$version" ]; then
            return 0
        elif [ -n "$installed_version" ]; then
            return 2  # Version installiert, aber nicht passend
        fi
        apt-get install -y -qq "$pkg=$version" >/dev/null 2>&1
    else
        if dpkg -l | grep -q "^ii  $pkg "; then
            return 0
        fi
        apt-get install -y -qq "$pkg" >/dev/null 2>&1
    fi

    # Prüfe nach Installation
    if [ -n "$version" ]; then
        local new_version
        new_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        if [ "$new_version" = "$version" ]; then
            return 0
        else
            return 1
        fi
    else
        if dpkg -l | grep -q "^ii  $pkg "; then
            return 0
        else
            return 1
        fi
    fi
}

install_package_group() {
    # -----------------------------------------------------------------------
    # install_package_group
    # -----------------------------------------------------------------------
    # Funktion: Installiert alle Pakete einer übergebenen Gruppe
    # Parameter: Array-Name (z.B. PACKAGES_NGINX)
    local group_name="$1[@]"
    local group=("${!group_name}")

    for entry in "${group[@]}"; do
        local pkg
        local version
        if [[ "$entry" == *=* ]]; then
            pkg="${entry%%=*}"
            version="${entry#*=}"
        else
            pkg="$entry"
            version=""
        fi
        install_package "$pkg" "$version"
        result=$?
        if [ $result -eq 0 ]; then
            print_success "$pkg${version:+ ($version)} ist bereits installiert."
        elif [ $result -eq 2 ]; then
            local installed_version
            installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
            print_error "$pkg ist in Version $installed_version installiert, benötigt wird $version."
            print_prompt "Soll $pkg auf Version $version aktualisiert werden? [j/N]"
            read -r upgrade
            if [[ "$upgrade" =~ ^([jJ]|[yY])$ ]]; then
                apt-get install -y -qq "$pkg=$version"
                local new_version
                new_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
                if [ "$new_version" = "$version" ]; then
                    print_success "$pkg wurde erfolgreich auf $version aktualisiert."
                else
                    print_error "$pkg konnte nicht auf $version aktualisiert werden!"
                    exit 1
                fi
            else
                print_error "Installation abgebrochen, da $pkg nicht in passender Version installiert ist."
                exit 1
            fi
        else
            print_error "Das Programm $pkg${version:+ ($version)} konnte nicht installiert werden!"
            exit 1
        fi
    done
}

chk_nginx_reload() {
    # -----------------------------------------------------------------------
    # chk_nginx_reload
    # -----------------------------------------------------------------------
    # Funktion: Testet die NGINX-Konfiguration und lädt sie neu, falls fehlerfrei
    # Rückgabe: 0 = OK, 1 = Syntaxfehler, 2 = Reload-Fehler
    if nginx -t; then
        if systemctl reload nginx; then
            print_success "NGINX-Konfiguration erfolgreich neu geladen."
            return 0
        else
            print_error "NGINX konnte nicht neu geladen werden!"
            return 2
        fi
    else
        print_error "Fehler in der NGINX-Konfiguration! Bitte prüfen."
        return 1
    fi
}

chk_nginx_installation() {
    # -----------------------------------------------------------------------
    # chk_nginx_installation
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX installiert ist, installiert ggf. nach (mit Rückfrage)
    # Rückgabe: 0 = OK, 1 = Installation abgebrochen, 2 = Installationsfehler
    if ! command -v nginx >/dev/null 2>&1; then
        print_prompt "NGINX ist nicht installiert. Jetzt installieren? [J/n]"
        read -r antwort
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            print_error "NGINX-Installation abgebrochen."
            return 1
        fi
        apt-get update -qq && apt-get install -y -qq nginx
        if ! command -v nginx >/dev/null 2>&1; then
            print_error "NGINX konnte nicht installiert werden!"
            return 2
        fi
        print_success "NGINX wurde erfolgreich installiert."
    fi
    return 0
}

chk_nginx_activ() {
    # -----------------------------------------------------------------------
    # chk_nginx_activ
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob NGINX nur im Default-Modus läuft oder weitere Sites aktiv sind
    # Rückgabe: 0 = nur default aktiv, 1 = weitere Sites aktiv, 2 = Fehler
    local enabled_sites
    enabled_sites=$(ls /etc/nginx/sites-enabled 2>/dev/null | wc -l)
    if [ "$enabled_sites" -eq 1 ] && [ -f /etc/nginx/sites-enabled/default ]; then
        return 0
    elif [ "$enabled_sites" -gt 1 ]; then
        return 1
    else
        print_error "Konnte aktive NGINX-Sites nicht eindeutig ermitteln."
        return 2
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

get_nginx_url() {
    # -----------------------------------------------------------------------
    # get_nginx_url
    # -----------------------------------------------------------------------
    # Funktion: Ermittelt die tatsächlich aktive URL der Fotobox anhand
    # der NGINX-Konfiguration (Default-Integration oder eigene Site)
    # Rückgabe: Gibt die URL als String auf stdout aus
    local url=""
    local ip_addr

    ip_addr=$(hostname -I | awk '{print $1}')

    # Prüfe, ob eigene Fotobox-Site aktiv ist
    if [ -L /etc/nginx/sites-enabled/fotobox ] && grep -q "listen" /etc/nginx/sites-enabled/fotobox; then
        # Port aus listen-Direktive extrahieren
        local port
        port=$(grep -Eo 'listen[[:space:]]+[0-9.]*(:[0-9]+)?' /etc/nginx/sites-enabled/fotobox | head -n1 | grep -Eo '[0-9]+$')
        [ -z "$port" ] && port=80
        url="http://$ip_addr:$port/"
    elif [ -f /etc/nginx/sites-enabled/default ] && grep -q "# Fotobox-Integration BEGIN" /etc/nginx/sites-enabled/default; then
        # Default-Site mit Integration, prüfe Port (meist 80) und Pfad
        local port
        port=$(grep -Eo 'listen[[:space:]]+[0-9.]*(:[0-9]+)?' /etc/nginx/sites-enabled/default | head -n1 | grep -Eo '[0-9]+$')
        [ -z "$port" ] && port=80
        url="http://$ip_addr/fotobox/"
    else
        # Fallback: Zeige beide Varianten an
        url="http://$ip_addr:$FOTOBOX_PORT/ oder http://$ip_addr/fotobox/"
    fi

    echo "$url"
}

# ===========================================================================
# Einstellungen (Systemanpassungen)
# ===========================================================================

set_install_packages() {
    # -----------------------------------------------------------------------
    # set_install_packages
    # -----------------------------------------------------------------------
    # Funktion: Installiert alle benötigten Systempakete (ohne NGINX) und prüft den Erfolg
    apt-get update -qq || return 1
    install_package_group PACKAGES_TOOLS || return 2
    install_package_group PACKAGES_PYTHON || return 3
    install_package_group PACKAGES_SQLITE || return 4
    return 0
}

set_user_group() {
    # -----------------------------------------------------------------------
    # set_user_group
    # -----------------------------------------------------------------------
    # Funktion: Legt Benutzer und Gruppe 'fotobox' an, prüft Rechte
    if ! id -u fotobox &>/dev/null; then
        useradd -m fotobox || return 1
    fi
    if ! getent group fotobox &>/dev/null; then
        groupadd fotobox || return 2
    fi
    if ! id -nG fotobox | grep -qw fotobox; then
        usermod -aG fotobox fotobox || return 3
    fi
    return 0
}

set_structure() {
    # -----------------------------------------------------------------------
    # set_structure
    # -----------------------------------------------------------------------
    # Funktion: Erstellt alle benötigten Verzeichnisse, klont das Projekt per git (wenn leer), legt Backup- und Datenverzeichnis an und setzt die Rechte
    if ! make_dir "$INSTALL_DIR" "$README_MAIN"; then
        return 1
    fi
    if [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
        if ! command -v git >/dev/null 2>&1; then
            apt-get update -qq && apt-get install -y -qq git || return 2
        fi
        git clone "$GIT_REPO_URL" "$INSTALL_DIR" || return 3
    fi
    if ! make_dir "$BACKUP_DIR" "$README_BACKUP"; then
        return 4
    fi
    if ! make_dir "$CONF_DIR"; then
        return 5
    fi
    if ! make_dir "$DATA_DIR" "$README_DATA"; then
        return 6
    fi
    chown -R fotobox:fotobox "$INSTALL_DIR" || return 7
    return 0
}

set_nginx_port() {
    # -----------------------------------------------------------------------
    # set_nginx_port
    # -----------------------------------------------------------------------
    # Funktion: Fragt Nutzer nach Port, prüft Verfügbarkeit, setzt FOTOBOX_PORT
    # Rückgabe: 0 = Port gesetzt, 1 = Abbruch
    local port=80
    while true; do
        print_prompt "Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:"
        read -r eingabe
        if [ -z "$eingabe" ]; then
            port=80
        elif [[ "$eingabe" =~ ^[0-9]+$ ]]; then
            port=$eingabe
        else
            print_error "Ungültige Eingabe. Bitte nur Zahlen verwenden."
            continue
        fi
        chk_nginx_port "$port"
        if [ $? -eq 0 ]; then
            FOTOBOX_PORT=$port
            print_success "Port $FOTOBOX_PORT wird verwendet."
            return 0
        else
            print_error "Port $port ist bereits belegt. Bitte anderen Port wählen."
            print_prompt "Abbrechen? [j/N]"
            read -r abbruch
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
    # Funktion: Integriert Fotobox in die Default-Konfiguration (Backup, reversibel)
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Backup-Fehler, 3 = Reload-Fehler
    local default_conf="/etc/nginx/sites-available/default"
    local backup="$BACKUP_DIR/default.bak.$(date +%Y%m%d%H%M%S)"

    if [ ! -f "$default_conf" ]; then
        print_error "Default-Konfiguration nicht gefunden: $default_conf"
        return 1
    fi

    cp "$default_conf" "$backup" || { print_error "Backup fehlgeschlagen!"; return 2; }

    print_success "Backup der Default-Konfiguration nach $backup"

    # Fotobox-Block einfügen, falls nicht vorhanden
    if ! grep -q "# Fotobox-Integration BEGIN" "$default_conf"; then
        sed -i '/^}/i \\n    # Fotobox-Integration BEGIN\n    location /fotobox/ {\n        alias /opt/fotobox/frontend/;\n        index start.html index.html;\n    }\n    location /fotobox/api/ {\n        proxy_pass http://127.0.0.1:5000/;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n    }\n    # Fotobox-Integration END\n' "$default_conf"
        print_success "Fotobox-Block in Default-Konfiguration eingefügt."
    else
        print_success "Fotobox-Block bereits in Default-Konfiguration vorhanden."
    fi

    chk_nginx_reload || return 3

    return 0
}

set_nginx_cnf_external() {
    # -----------------------------------------------------------------------
    # set_nginx_cnf_external
    # -----------------------------------------------------------------------
    # Funktion: Legt eigene Fotobox-Konfiguration an, bindet sie ein (Backup, Symlink, reload)
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Backup-Fehler, 3 = Symlink-Fehler, 4 = Reload-Fehler
    local nginx_dst="$NGINX_DST"
    local backup="$BACKUP_DIR/nginx-fotobox.conf.bak.$(date +%Y%m%d%H%M%S)"

    if [ -f "$nginx_dst" ]; then
        cp "$nginx_dst" "$backup" || { print_error "Backup fehlgeschlagen!"; return 2; }
        print_success "Backup der bestehenden Fotobox-Konfiguration nach $backup"
    fi

    cp "$NGINX_CONF" "$nginx_dst" || { print_error "Kopieren der Konfiguration fehlgeschlagen!"; return 1; }

    if [ ! -L /etc/nginx/sites-enabled/fotobox ]; then
        ln -s "$nginx_dst" /etc/nginx/sites-enabled/fotobox || { print_error "Symlink konnte nicht erstellt werden!"; return 3; }
        print_success "Symlink für Fotobox-Konfiguration erstellt."
    fi

    chk_nginx_reload || return 4

    return 0
}

set_nginx_config() {
    # -----------------------------------------------------------------------
    # set_nginx_config
    # -----------------------------------------------------------------------
    # Funktion: Erstellt eine neue oder integriert Fotobox in bestehende 
    # NGINX-Konfiguration
    # Parameter: Modus ("new" oder "integrate"), optional: Zielpfad für Integration
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Datei nicht gefunden, 3 = NGINX-Reload/Syntaxfehler
    local mode="$1"
    local target="$2"
    local ip_addr
    
    ip_addr=$(hostname -I | awk '{print $1}')
    if [ "$mode" = "new" ]; then
        if [ -f "$NGINX_CONF" ]; then
            return 0
        fi
        cat > "$NGINX_CONF" <<EOF
server {
    listen 0.0.0.0:$FOTOBOX_PORT;
    server_name $ip_addr;
    root $INSTALL_DIR/frontend;
    index start.html index.html;
    location / {
        try_files $uri $uri/ =404;
    }
    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location /photos/ {
        proxy_pass http://127.0.0.1:5000/photos/;
    }
}
EOF
        # NGINX-Konfiguration testen und neu laden
        if nginx -t && systemctl reload nginx; then
            return 0
        else
            return 3
        fi
    elif [ "$mode" = "integrate" ]; then
        if [ ! -f "$target" ]; then
            return 2
        fi
        cp "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
        sed -i '/^}/i \\n    # Fotobox-Integration BEGIN\n    location /fotobox/ {\n        alias /opt/fotobox/frontend/;\n        index start.html index.html;\n    }\n    location /fotobox/api/ {\n        proxy_pass http://127.0.0.1:5000/;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n    }\n    # Fotobox-Integration END\n' "$target"
        nginx -t && systemctl reload nginx
        return 0
    else
        return 1
    fi
}

# set_systemd_service
# ------------------------------------------------------------------------------
# Funktion: Erstellt oder kopiert die systemd-Service-Datei
# ------------------------------------------------------------------------------
set_systemd_service() {
    if [ ! -f "$SYSTEMD_SERVICE" ]; then
        cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Fotobox Backend (Flask)
After=network.target

[Service]
Type=simple
User=fotobox
WorkingDirectory=$INSTALL_DIR/backend
ExecStart=$INSTALL_DIR/backend/venv/bin/python app.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        print_success "Standard-Service-Datei erzeugt: $SYSTEMD_SERVICE"
    fi
}

# set_systemd_install
# ------------------------------------------------------------------------------
# Funktion: Kopiert systemd-Service-Datei und startet Service
# ------------------------------------------------------------------------------
set_systemd_install() {
    local backup="$BACKUP_DIR/fotobox-backend.service.bak.$(date +%Y%m%d%H%M%S)"
    if [ -f "$SYSTEMD_DST" ]; then
        cp "$SYSTEMD_DST" "$backup"
        print_success "Backup der bestehenden systemd-Unit nach $backup"
    fi
    cp "$SYSTEMD_SERVICE" "$SYSTEMD_DST"
    systemctl daemon-reload
    systemctl enable fotobox-backend
    systemctl restart fotobox-backend
    print_success "systemd-Service installiert und gestartet."
}

# ===========================================================================
# Dialogfunktionen
# ===========================================================================

dlg_check_root() {
    # -----------------------------------------------------------------------
    # dlg_check_root
    # -----------------------------------------------------------------------
    # Funktion: Dialog für Root-Check, gibt Fehler aus und bricht ggf. ab
    print_step "[1/10] Prüfe Rechte zur Ausführung ..."
    if ! chk_is_root; then
        print_error "Bitte das Skript als root ausführen."
        exit 1
    fi
    print_success "Rechteprüfung erfolgreich."
}

dlg_check_distribution() {
    # -----------------------------------------------------------------------
    # dlg_check_distribution
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das System auf Debian/Ubuntu basiert
    print_step "[2/10] Prüfe Distribution ..."
    if ! chk_distribution; then
        print_error "Dieses Skript ist nur für Debian/Ubuntu-basierte Systeme geeignet."
        exit 1
    fi
    print_success "Distribution ist Debian/Ubuntu."
}

dlg_prepare_system() {
    # -----------------------------------------------------------------------
    # dlg_prepare_system
    # -----------------------------------------------------------------------
    # Funktion: Prüft installiert Pakete (ohne NGINX)
    print_step "[3/10] Installiere benötigte Systempakete (ohne NGINX) ..."
    set_install_packages
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Fehler bei apt-get update. Prüfen Sie Ihre Internetverbindung und Paketquellen."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler bei der Installation der Tools (git, lsof)."
        exit 1
    elif [ $rc -eq 3 ]; then
        print_error "Fehler bei der Installation der Python-Pakete."
        exit 1
    elif [ $rc -eq 4 ]; then
        print_error "Fehler bei der Installation von SQLite."
        exit 1
    elif [ $rc -ne 0 ]; then
        print_error "Unbekannter Fehler bei der Systempaket-Installation (Code $rc)."
        exit 1
    fi
    print_success "Systempakete (ohne NGINX) wurden erfolgreich installiert."
}

dlg_prepare_users() {
    # -----------------------------------------------------------------------
    # dlg_prepare_users
    # -----------------------------------------------------------------------
    # Funktion: Erstellen des Benutzer und der Gruppe 'fotobox'
    print_step "[4/10] Prüfe und lege Benutzer/Gruppe an ..."
    set_user_group
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Fehler beim Anlegen des Benutzers 'fotobox'."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler beim Anlegen der Gruppe 'fotobox'."
        exit 1
    elif [ $rc -eq 3 ]; then
        print_error "Fehler beim Hinzufügen des Benutzers zur Gruppe."
        exit 1
    elif [ $rc -ne 0 ]; then
        print_error "Unbekannter Fehler beim Anlegen von Benutzer/Gruppe (Code $rc)."
        exit 1
    fi
    print_success "Benutzer und Gruppe 'fotobox' wurden erfolgreich angelegt."
}

dlg_prepare_structure() {
    # -----------------------------------------------------------------------
    # dlg_prepare_structure
    # -----------------------------------------------------------------------
    # Funktion: Prüfen/Erstellen der Verzeichnisstruktur, Klonen des Projekt
    # Rechte setzem
    print_step "[5/10] Erstelle Verzeichnisstruktur und setze Rechte ..."
    set_structure
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Verzeichnis $INSTALL_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler beim Nachinstallieren von git."
        exit 1
    elif [ $rc -eq 3 ]; then
        print_error "Fehler beim Klonen des Projekts per git."
        exit 1
    elif [ $rc -eq 4 ]; then
        print_error "Backup-Verzeichnis $BACKUP_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 5 ]; then
        print_error "Konfigurationsverzeichnis $CONF_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 6 ]; then
        print_error "Datenverzeichnis $DATA_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 7 ]; then
        print_error "Rechte für $INSTALL_DIR konnten nicht gesetzt werden!"
        exit 1
    elif [ $rc -ne 0 ]; then
        print_error "Unbekannter Fehler bei der Verzeichnisstruktur (Code $rc)."
        exit 1
    fi
    print_success "Verzeichnisstruktur wurde erfolgreich erstellt."
}

dlg_nginx_installation() {
    # -----------------------------------------------------------------------
    # dlg_nginx_installation
    # -----------------------------------------------------------------------
    # Funktion: Führt die vollständige NGINX-Installation/Integration durch 
    # Prüft Installation, erkennt Default/Multi-Site, bietet Integration 
    # oder eigene Konfiguration an
    # Rückgabe: 0 = OK, !=0 = Fehler
    print_step "[6/10] NGINX-Installation und Konfiguration ..."

    chk_nginx_installation
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "NGINX-Installation abgebrochen."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "NGINX konnte nicht installiert werden."
        exit 1
    fi

    chk_nginx_activ
    rc=$?
    if [ $rc -eq 2 ]; then
        print_error "Konnte NGINX-Betriebsmodus nicht eindeutig ermitteln. Bitte prüfen Sie die Konfiguration."
        exit 1
    fi

    if [ $rc -eq 0 ]; then
        print_prompt "NGINX läuft nur im Default-Modus. Fotobox in Default-Konfiguration integrieren? [J/n]"
        read -r antwort
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            print_prompt "Stattdessen eigene Fotobox-Konfiguration anlegen? [J/n]"
            read -r antwort2
            if [[ "$antwort2" =~ ^([nN])$ ]]; then
                print_error "Abbruch: Keine NGINX-Integration gewählt."
                exit 1
            fi
            set_nginx_port || { print_error "Abbruch durch Nutzer."; exit 1; }
            set_nginx_cnf_external
            rc=$?
            if [ $rc -eq 0 ]; then
                print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
            else
                print_error "Fehler bei externer NGINX-Konfiguration (Code $rc)."
                exit 1
            fi
        else
            set_nginx_cnf_internal
            rc=$?
            if [ $rc -eq 0 ]; then
                print_success "Fotobox wurde in Default-Konfiguration integriert."
            else
                print_error "Fehler bei Integration in Default-Konfiguration (Code $rc)."
                exit 1
            fi
        fi
    elif [ $rc -eq 1 ]; then
        print_prompt "NGINX betreibt mehrere Sites. Eigene Fotobox-Konfiguration anlegen? [J/n]"
        read -r antwort
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            print_error "Abbruch: Keine NGINX-Integration gewählt."
            exit 1
        fi
        set_nginx_port || { print_error "Abbruch durch Nutzer."; exit 1; }
        set_nginx_cnf_external
        rc=$?
        if [ $rc -eq 0 ]; then
            print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
        else
            print_error "Fehler bei externer NGINX-Konfiguration (Code $rc)."
            exit 1
        fi
    fi
    return 0
}

# dlg_backend_integration
# ------------------------------------------------------------------------------
# Funktion: Richtet das Python-Backend (venv, requirements, systemd) ein und startet es
# Rückgabe: 0 = OK, !=0 = Fehler
# ------------------------------------------------------------------------------
dlg_backend_integration() {
    print_step "[Backend] Python-Umgebung und Backend-Service werden eingerichtet ..."
    # Python venv anlegen, falls nicht vorhanden
    if [ ! -d "$INSTALL_DIR/backend/venv" ]; then
        python3 -m venv "$INSTALL_DIR/backend/venv" || { print_error "Konnte venv nicht anlegen!"; exit 1; }
    fi
    # Abhängigkeiten installieren
    "$INSTALL_DIR/backend/venv/bin/pip" install --upgrade pip >/dev/null 2>&1
    "$INSTALL_DIR/backend/venv/bin/pip" install -r "$INSTALL_DIR/backend/requirements.txt" >/dev/null 2>&1 || { print_error "Konnte Python-Abhängigkeiten nicht installieren!"; exit 1; }
    # systemd-Service anlegen und starten
    set_systemd_service
    set_systemd_install
    print_success "Backend-Service wurde eingerichtet und gestartet."
    return 0
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
# Funktion: Hauptablauf der Erstinstallation
# ------------------------------------------------------------------------------
main() {
    dlg_check_root              # Prüfe, ob Skript als root ausgeführt wird
    dlg_check_distribution      # Prüfe, ob System auf Debian/Ubuntu basiert
    dlg_prepare_system          # Installiere Systempakete und prüfe Erfolg
    dlg_prepare_users           # Erstelle Benutzer und Gruppe 'fotobox'
    dlg_prepare_structure       # Erstelle Verzeichnisstruktur, klone Projekt und setze Rechte
    dlg_nginx_installation      # NGINX-Konfiguration (Integration oder eigene Site)
    dlg_backend_integration     # Python-Backend, venv, systemd-Service, Start
    print_success "Erstinstallation abgeschlossen."
    local web_url
    web_url=$(get_nginx_url)
    print_prompt "Bitte rufen Sie die Weboberfläche im Browser auf, um die Fotobox weiter zu konfigurieren und zu verwalten.\nURL: $web_url"
    echo "Weitere Wartung (Update, Deinstallation) erfolgt über die WebUI oder die Python-Skripte im backend/."
}

main