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
# [ ] Automatische Prüfung, ob NGINX-Default-Server auf Port 80 deaktiviert werden soll
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

# ===========================================================================
# Einstellungen (Systemanpassungen)
# ===========================================================================

set_install_packages() {
    # -----------------------------------------------------------------------
    # set_install_packages
    # -----------------------------------------------------------------------
    # Funktion: Installiert alle benötigten Systempakete und prüft den Erfolg
    apt-get update -qq || return 1
    install_package_group PACKAGES_TOOLS || return 2
    install_package_group PACKAGES_NGINX || return 3
    install_package_group PACKAGES_PYTHON || return 4
    install_package_group PACKAGES_SQLITE || return 5
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

# set_nginx_install
# ------------------------------------------------------------------------------
# Funktion: Kopiert NGINX-Konfiguration und startet NGINX neu
# ------------------------------------------------------------------------------
set_nginx_install() {
    local backup="$BACKUP_DIR/nginx-fotobox.conf.bak.$(date +%Y%m%d%H%M%S)"
    if [ -f "$NGINX_DST" ]; then
        cp "$NGINX_DST" "$backup"
        print_success "Backup der bestehenden NGINX-Konfiguration nach $backup"
    fi
    cp "$NGINX_CONF" "$NGINX_DST"
    systemctl restart nginx
    print_success "NGINX-Konfiguration installiert und NGINX neu gestartet."
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
    # Funktion: Prüft installiert Pakete
    print_step "[3/10] Installiere benötigte Systempakete ..."
    set_install_packages
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Fehler bei apt-get update. Prüfen Sie Ihre Internetverbindung und Paketquellen."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler bei der Installation der Tools (git, lsof)."
        exit 1
    elif [ $rc -eq 3 ]; then
        print_error "Fehler bei der Installation von NGINX."
        exit 1
    elif [ $rc -eq 4 ]; then
        print_error "Fehler bei der Installation der Python-Pakete."
        exit 1
    elif [ $rc -eq 5 ]; then
        print_error "Fehler bei der Installation von SQLite."
        exit 1
    elif [ $rc -ne 0 ]; then
        print_error "Unbekannter Fehler bei der Systempaket-Installation (Code $rc)."
        exit 1
    fi
    print_success "Systempakete wurden erfolgreich installiert."
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

# dlg_check_nginx_port
# ------------------------------------------------------------------------------
# Funktion: Prüft, ob Port 80 belegt ist, schlägt ggf. alternativen Port vor
# ------------------------------------------------------------------------------
dlg_check_nginx_port() {
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
            FOTOBOX_PORT=$neuer_port
        else
            print_error "Installation abgebrochen. Bitte Port 80 freigeben oder NGINX-Konfiguration manuell anpassen."
            exit 1
        fi
    else
        FOTOBOX_PORT=80
    fi
}

# dlg_nginx_installation
# ------------------------------------------------------------------------------
# Funktion: Führt die vollständige NGINX-Installation/Integration durch
# (Integration in bestehende Konfiguration oder eigene Konfiguration mit Portwahl)
# Rückgabe: 0 = OK, !=0 = Fehler
# ------------------------------------------------------------------------------
dlg_nginx_installation() {
    print_prompt "Soll die Fotobox in eine bestehende NGINX-Konfiguration integriert werden? [j/N]"
    read -r integration
    if [[ "$integration" =~ ^([jJ]|[yY])$ ]]; then
        print_step "Verfügbare NGINX-Konfigurationsdateien:"
        find /etc/nginx/sites-available -type f
        print_prompt "Bitte geben Sie den Pfad zur gewünschten Konfigurationsdatei ein:"
        read -r nginx_conf_target
        if [ ! -f "$nginx_conf_target" ]; then
            print_error "Datei nicht gefunden: $nginx_conf_target"
            exit 1
        fi
        set_nginx_config "integrate" "$nginx_conf_target"
        rc=$?
        if [ $rc -eq 0 ]; then
            print_success "Fotobox-Location-Blöcke wurden in $nginx_conf_target eingefügt und NGINX neu geladen."
        elif [ $rc -eq 2 ]; then
            print_error "Ziel-Konfigurationsdatei nicht gefunden: $nginx_conf_target."
            exit 1
        elif [ $rc -eq 3 ]; then
            print_error "Fehler beim Testen oder Neuladen der NGINX-Konfiguration. Bitte prüfen Sie die Konfiguration!"
            exit 1
        else
            print_error "Unbekannter Fehler bei der Integration in $nginx_conf_target (Code $rc)."
            exit 1
        fi
    else
        dlg_check_nginx_port
        set_nginx_config "new"
        rc=$?
        if [ $rc -ne 0 ]; then
            print_error "Fehler beim Erstellen oder Neuladen der NGINX-Konfiguration (Code $rc)."
            exit 1
        fi
        set_nginx_install
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
    ip_addr=$(hostname -I | awk '{print $1}')
    print_success "Erstinstallation abgeschlossen."
    print_prompt "Bitte rufen Sie die Weboberfläche im Browser auf, um die Fotobox weiter zu konfigurieren und zu verwalten.\nBeispiel: http://$ip_addr:$FOTOBOX_PORT/ oder http://$ip_addr/fotobox/ (bei Integration)"
    echo "Weitere Wartung (Update, Deinstallation) erfolgt über die WebUI oder die Python-Skripte im backend/."
}

main