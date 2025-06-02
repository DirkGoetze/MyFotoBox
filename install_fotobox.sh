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
# Globale Konstanten für zentrale Einstellungen
# ------------------------------------------------------------------------------
GIT_REPO_URL="https://github.com/DirkGoetze/fotobox2.git"
INSTALL_DIR="/opt/fotobox"
BACKUP_DIR="$INSTALL_DIR/backup"
CONF_DIR="$INSTALL_DIR/conf"
NGINX_CONF="$CONF_DIR/nginx-fotobox.conf"
SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"
NGINX_DST="/etc/nginx/sites-available/fotobox"
SYSTEMD_DST="/etc/systemd/system/fotobox-backend.service"

# ------------------------------------------------------------------------------
# Globale Konstanten für Konfiguration und Verzeichnisse
# ------------------------------------------------------------------------------
# GIT_REPO_URL="https://github.com/DEIN-REPO/fotobox2.git"
# INSTALL_DIR="/opt/fotobox"
# BACKUP_DIR="$INSTALL_DIR/backup"
# CONF_DIR="$INSTALL_DIR/conf"
# NGINX_CONF="$CONF_DIR/nginx-fotobox.conf"
# SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"

# ------------------------------------------------------------------------------
# print_error
# ------------------------------------------------------------------------------
# Funktion: Gibt eine Fehlermeldung farbig aus
# ------------------------------------------------------------------------------
print_error() {
    echo -e "\033[1;31m$1\033[0m"
}

# ----------------------------------------------------------------------------
# print_step
# ----------------------------------------------------------------------------
# Funktion: Gibt einen Hinweis auf einen auszuführenden Schritt in Gelb aus
# ----------------------------------------------------------------------------
print_step() {
    echo -e "\033[1;33m$1\033[0m"
}

# ----------------------------------------------------------------------------
# print_success
# ----------------------------------------------------------------------------
# Funktion: Gibt eine Erfolgsmeldung in Dunkelgrün aus
# ----------------------------------------------------------------------------
print_success() {
    echo -e "\033[1;32m$1\033[0m"
}

# ----------------------------------------------------------------------------
# print_prompt
# ----------------------------------------------------------------------------
# Funktion: Gibt eine Nutzeraufforderung in Blau aus
# ----------------------------------------------------------------------------
print_prompt() {
    echo -e "\033[1;34m$1\033[0m"
}

# ------------------------------------------------------------------------------
# check_root
# ------------------------------------------------------------------------------
# Funktion: Prüft, ob das Skript als root ausgeführt wird
# ------------------------------------------------------------------------------
check_root() {
    print_step "Prüfe, ob das Skript als root ausgeführt wird ..."
    if [ "$EUID" -ne 0 ]; then
        print_error "Bitte das Skript als root ausführen."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# check_distribution
# ------------------------------------------------------------------------------
# Funktion: Prüft, ob das System auf Debian/Ubuntu basiert
# ------------------------------------------------------------------------------
check_distribution() {
    print_step "Prüfe, ob das System auf Debian/Ubuntu basiert ..."
    if [ ! -f /etc/os-release ]; then
        print_error "Nicht unterstütztes System."
        exit 1
    fi
    . /etc/os-release
    if [[ ! "$ID" =~ ^(debian|ubuntu|raspbian)$ && ! "$ID_LIKE" =~ (debian|ubuntu) ]]; then
        print_error "Nur für Debian/Ubuntu-Systeme geeignet."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# install_packages
# ------------------------------------------------------------------------------
# Funktion: Installiert alle benötigten Systempakete und prüft Erfolg
# ------------------------------------------------------------------------------
install_packages() {
    print_step "Systempakete werden installiert ..."
    if ! apt-get update -qq; then
        print_error "Fehler bei apt-get update! Bitte prüfen Sie Ihre Internetverbindung und Paketquellen."
        exit 1
    fi
    if ! apt-get install -y -qq python3 python3-venv python3-pip nginx git sqlite3 lsof; then
        print_error "Fehler bei der Installation der Systempakete! Bitte prüfen Sie die Paketquellen."
        exit 1
    fi
    for prog in python3 python3-venv python3-pip nginx git sqlite3 lsof; do
        if ! dpkg -l | grep -q "$prog" && ! command -v "$prog" >/dev/null 2>&1; then
            print_error "Das Programm $prog konnte nicht installiert werden!"
            exit 1
        fi
    done
    print_success "Alle Systempakete wurden erfolgreich installiert."
}

# ------------------------------------------------------------------------------
# setup_user_group
# ------------------------------------------------------------------------------
# Funktion: Legt Benutzer und Gruppe 'fotobox' an, prüft Rechte
# ------------------------------------------------------------------------------
setup_user_group() {
    print_step "Prüfe, ob der Benutzer 'fotobox' und die Gruppe 'fotobox' existieren ..."
    if ! id -u fotobox &>/dev/null; then
        useradd -m fotobox
        print_success "Benutzer 'fotobox' wurde angelegt."
    else
        echo "Benutzer 'fotobox' existiert bereits."
    fi
    if ! getent group fotobox &>/dev/null; then
        groupadd fotobox
        print_success "Gruppe 'fotobox' wurde angelegt."
    fi
    # Rechte prüfen
    if ! id -nG fotobox | grep -qw fotobox; then
        usermod -aG fotobox fotobox
        print_success "Benutzer 'fotobox' zur Gruppe 'fotobox' hinzugefügt."
    fi
}

# ------------------------------------------------------------------------------
# setup_structure
# ------------------------------------------------------------------------------
# Funktion: Erstellt das Grundverzeichnis, klont das Projekt per git (wenn leer) und setzt die Rechte
# ------------------------------------------------------------------------------
setup_structure() {
    print_step "Erstelle Verzeichnisstruktur und prüfe Projektdateien ..."
    mkdir -p "$INSTALL_DIR"
    # Prüfe, ob das Zielverzeichnis leer ist
    if [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
        print_step "Klonen des Projekts per git nach $INSTALL_DIR ..."
        if ! command -v git >/dev/null 2>&1; then
            print_step "Installiere git ..."
            apt-get update -qq && apt-get install -y -qq git
        fi
        git clone "$GIT_REPO_URL" "$INSTALL_DIR"
        print_success "Projekt wurde per git nach $INSTALL_DIR geklont."
    else
        print_prompt "$INSTALL_DIR ist nicht leer. Überspringe Klonen."
    fi
    chown -R fotobox:fotobox "$INSTALL_DIR"
    print_success "Verzeichnisstruktur und Rechte wurden gesetzt."
}

# ------------------------------------------------------------------------------
# setup_backup_dir
# ------------------------------------------------------------------------------
# Funktion: Legt das Backup-Verzeichnis an, falls nicht vorhanden
# ------------------------------------------------------------------------------
setup_backup_dir() {
    print_step "Backup-Verzeichnis wird angelegt ..."
    mkdir -p "$BACKUP_DIR"
    if [ ! -f "$BACKUP_DIR/readme.md" ]; then
        echo "# backup
Dieses Verzeichnis wird automatisch durch die Installations- und Update-Skripte erzeugt und enthält Backups von Konfigurationsdateien und Logs. Es ist nicht Teil des Repositorys." > "$BACKUP_DIR/readme.md"
    fi
    print_success "Backup-Verzeichnis ($BACKUP_DIR/) wurde angelegt."
}

# ------------------------------------------------------------------------------
# backup_nginx_config
# ------------------------------------------------------------------------------
# Funktion: Sichert vorhandene NGINX-Konfiguration, falls vorhanden
# ------------------------------------------------------------------------------
backup_nginx_config() {
    print_step "Sichere vorhandene NGINX-Konfiguration ..."
    if [ -f "$NGINX_DST" ]; then
        cp "$NGINX_DST" "$NGINX_DST.bak.$(date +%Y%m%d%H%M%S)"
        print_success "Vorhandene NGINX-Konfiguration wurde gesichert."
    fi
}

# ------------------------------------------------------------------------------
# check_nginx_port
# ------------------------------------------------------------------------------
# Funktion: Prüft, ob Port 80 belegt ist, schlägt ggf. alternativen Port vor
# ------------------------------------------------------------------------------
check_nginx_port() {
    print_step "Prüfe, ob Port 80 belegt ist ..."
    if lsof -i :80 | grep LISTEN > /dev/null; then
        print_error "Port 80 ist bereits belegt."
        print_prompt "Möchten Sie einen alternativen Port (z.B. 8080) für NGINX verwenden? [j/N]"
        read -r antwort
        if [[ "$antwort" =~ ^([jJ]|[yY])$ ]]; then
            print_prompt "Bitte geben Sie den gewünschten Port ein (z.B. 8080):"
            read -r neuer_port
            if [[ ! "$neuer_port" =~ ^[0-9]+$ ]]; then
                print_error "Ungültige Eingabe. Es wird Port 8080 verwendet."
                neuer_port=8080
            fi
            # Passe die NGINX-Konfiguration an
            if [ ! -d "$CONF_DIR" ]; then
                mkdir -p "$CONF_DIR"
            fi
            if [ -f "$NGINX_CONF" ]; then
                # Korrigiere ggf. fehlerhafte proxy_set_header-Zeilen
                sed -i '/proxy_set_header[[:space:]]*$/d' "$NGINX_CONF"
                sed -i '/proxy_set_header[[:space:]]\+[^;]*$/!b' "$NGINX_CONF"
                sed -i '/proxy_set_header[[:space:]]\+[^;]*;/!b' "$NGINX_CONF"
                sed -i 's/[[:space:]]\{2,\}/ /g' "$NGINX_CONF"
                sed -i 's/;\{2,\}/;/g' "$NGINX_CONF"
                print_success "NGINX-Konfiguration auf Port $neuer_port angepasst und geprüft."
            else
                print_error "NGINX-Konfigurationsdatei ($NGINX_CONF) nicht gefunden!"
                print_prompt "Soll eine Standard-NGINX-Konfiguration für Port $neuer_port erzeugt werden? [j/N]"
                read -r genantwort
                if [[ "$genantwort" =~ ^([jJ]|[yY])$ ]]; then
                    cat > "$NGINX_CONF" <<EOF
server {
    listen $neuer_port;
    server_name _;
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
                    print_success "Standard-NGINX-Konfiguration für Port $neuer_port erzeugt."
                else
                    print_error "Installation abgebrochen. Bitte NGINX-Konfiguration manuell anlegen."
                    exit 1
                fi
            fi
        else
            print_error "Installation abgebrochen. Bitte Port 80 freigeben oder NGINX-Konfiguration manuell anpassen."
            exit 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# backup_and_install_systemd
# ------------------------------------------------------------------------------
# Funktion: Sichert bestehende systemd-Unit, kopiert neue aus conf/, aktiviert und startet Service
# ------------------------------------------------------------------------------
backup_and_install_systemd() {
    local src="$SYSTEMD_SERVICE"
    local dst="$SYSTEMD_DST"
    local backup="$BACKUP_DIR/fotobox-backend.service.bak.$(date +%Y%m%d%H%M%S)"
    if [ ! -f "$src" ]; then
        print_error "Service-Datei $src nicht gefunden!"
        print_prompt "Soll eine Standard-Service-Datei erzeugt werden? [j/N]"
        read -r genantwort
        if [[ "$genantwort" =~ ^([jJ]|[yY])$ ]]; then
            cat > "$src" <<EOF
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
            print_success "Standard-Service-Datei erzeugt: $src"
        else
            print_error "Installation abgebrochen. Bitte Service-Datei manuell anlegen."
            exit 1
        fi
    fi
    if [ -f "$dst" ]; then
        cp "$dst" "$backup"
        print_success "Backup der bestehenden systemd-Unit nach $backup"
    fi
    cp "$src" "$dst"
    print_step "Neue systemd-Unit installiert."
    systemctl daemon-reload
    systemctl enable fotobox-backend
    systemctl restart fotobox-backend
}

# ------------------------------------------------------------------------------
# backup_and_install_nginx
# ------------------------------------------------------------------------------
# Funktion: Sichert bestehende NGINX-Konfiguration, kopiert neue aus conf/, startet NGINX neu
# ------------------------------------------------------------------------------
backup_and_install_nginx() {
    local src="$NGINX_CONF"
    local dst="$NGINX_DST"
    local backup="$BACKUP_DIR/nginx-fotobox.conf.bak.$(date +%Y%m%d%H%M%S)"
    if [ -f "$dst" ]; then
        cp "$dst" "$backup"
        print_success "Backup der bestehenden NGINX-Konfiguration nach $backup"
    fi
    cp "$src" "$dst"
    print_step "Neue NGINX-Konfiguration installiert."
    systemctl restart nginx
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
# Funktion: Hauptablauf der Erstinstallation
# ------------------------------------------------------------------------------
main() {
    check_root
    check_distribution
    install_packages
    setup_user_group
    setup_structure
    setup_backup_dir
    backup_nginx_config
    check_nginx_port
    backup_and_install_systemd
    backup_and_install_nginx
    print_success "Erstinstallation abgeschlossen."
    print_prompt "Bitte rufen Sie die Weboberfläche im Browser auf, um die Fotobox weiter zu konfigurieren und zu verwalten."
    echo "Weitere Wartung (Update, Deinstallation) erfolgt über die WebUI oder die Python-Skripte im backend/."
}

main