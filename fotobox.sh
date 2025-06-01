#!/bin/bash
# ------------------------------------------------------------------------------
# Fotobox Multi-Tool: Installation, Update, Deinstallation und Systemintegration
# ------------------------------------------------------------------------------
# Für Ubuntu/Debian-basierte Systeme
# Nutzung:
#   ./fotobox.sh --install   # Erstinstallation (inkl. User/Gruppe, Abhängigkeiten, Passwort, NGINX, systemd, Backup)
#   ./fotobox.sh --update    # Update (inkl. automatischer Skript-Selbstaktualisierung, Port-/Konfig-Prüfung, Backup)
#   ./fotobox.sh --remove    # Deinstallation und Rücksicherung (inkl. Port-/Konfig-Prüfung, Backup)
#
# Features:
# - Ein-Skript-Lösung für alle Lebenszyklus-Phasen
# - Automatische Port-Prüfung und dynamische NGINX-Konfiguration (auch bei Update/Restore)
# - Sicherung und Vergleich der NGINX-Konfiguration, Rücksicherung mit Port-Anpassung
# - Automatische Sicherung und Wiederherstellung aller Systemdateien (NGINX, systemd, DB)
# - Sichere Passwortverwaltung (SHA256-Hash in SQLite)
# - Automatische Selbstaktualisierung des Skripts bei Update
# - Benutzerführung, Fortschrittsanzeige, Fehlerbehandlung
# - Für produktiven Einsatz auf Linux vorbereitet

set -e

# Root-Prüfung
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31mFehler: Dieses Skript muss als root ausgeführt werden!\033[0m"
    exit 1
fi

# Distributionserkennung (Debian/Ubuntu)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ ! "$ID" =~ ^(debian|ubuntu|raspbian)$ && ! "$ID_LIKE" =~ (debian|ubuntu) ]]; then
        echo -e "\033[1;31mFehler: Dieses Skript unterstützt nur Debian, Ubuntu oder davon abgeleitete Distributionen!\033[0m"
        exit 1
    fi
else
    echo -e "\033[1;31mFehler: Konnte die Distribution nicht erkennen (fehlende /etc/os-release). Skript wird abgebrochen.\033[0m"
    exit 1
fi

PROJECT_DIR="/opt/fotobox"
REPO_URL="https://github.com/DirkGoetze/fotobox2.git"

# Farbdefinitionen für Ausgaben
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_YELLOW="\033[1;33m"
COLOR_RESET="\033[0m"

# ------------------------------------------------------------------------------
# log_message
# ------------------------------------------------------------------------------
# Funktion: Schreibt eine Lognachricht mit Zeitstempel in die zentrale Logdatei
# Parameter: $1 = Log-Level (INFO/WARN/ERROR), $2 = Nachricht
log_message() {
    local LEVEL="$1"
    local MSG="$2"
    local TS
    TS="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$TS] [$LEVEL] $MSG" >> "$LOGFILE"
}

# Logfile-Initialisierung (Pfad und Rechte setzen, Rotation bei >1MB)
LOGFILE="/var/log/fotobox_install.log"
if [ -f "$LOGFILE" ]; then
    if [ $(stat -c%s "$LOGFILE") -gt 1048576 ]; then
        mv "$LOGFILE" "/var/log/fotobox_install_$(date +%Y%m%d%H%M%S).log"
        touch "$LOGFILE"
    fi
else
    touch "$LOGFILE"
fi
chmod 640 "$LOGFILE"

# Farbige Ausgaben + Logging
print_success() {
    echo -e "${COLOR_GREEN}$1${COLOR_RESET}"
    log_message "INFO" "$1"
}
print_error() {
    echo -e "${COLOR_RED}$1${COLOR_RESET}"
    log_message "ERROR" "$1"
}
print_warning() {
    echo -e "${COLOR_RED}$1${COLOR_RESET}"
    log_message "WARN" "$1"
}
print_interactive() {
    echo -e "${COLOR_YELLOW}$1${COLOR_RESET}"
    log_message "INFO" "$1"
}

# ------------------------------------------------------------------------------
# update_system
# ------------------------------------------------------------------------------
# Funktion: Aktualisiert die Systempakete mit apt-get update (Schritt 1/9)
update_system() {
    print_interactive "[1/9] Systempakete werden aktualisiert ..."
    if run_and_log "apt-get update" apt-get update -qq; then
        print_success "  → Systempakete wurden erfolgreich aktualisiert."
    else
        print_error "  → Fehler: Systempakete konnten nicht aktualisiert werden!"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# install_software
# ------------------------------------------------------------------------------
# Funktion: Installiert alle benötigten Pakete für die Fotobox (Schritt 2/9)
install_software() {
    print_interactive "[2/9] Notwendige Software wird installiert ..."
    export DEBIAN_FRONTEND=noninteractive
    # Prüfe, ob nginx installiert ist, sonst nachinstallieren
    if ! command -v nginx >/dev/null 2>&1; then
        print_interactive "  → nginx wird installiert ..."
        if ! run_and_log "apt-get install nginx" apt-get install -y -qq nginx; then
            print_error "  → Fehler: nginx konnte nicht installiert werden!"
            exit 1
        fi
    fi
    # Prüfe, ob systemd vorhanden und aktiv ist (robustere Prüfung)
    if ! pgrep -x systemd >/dev/null 2>&1 && [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
        echo -e "\033[1;31mFehler: systemd ist nicht aktiv! Dieses Skript benötigt ein laufendes systemd.\033[0m"
        exit 1
    fi
    # Prüfe, ob python3-pip installiert ist, sonst nachinstallieren
    if ! command -v pip3 >/dev/null 2>&1; then
        print_interactive "  → python3-pip wird installiert ..."
        if ! run_and_log "apt-get install python3-pip" apt-get install -y -qq python3-pip; then
            print_error "  → Fehler: python3-pip konnte nicht installiert werden!"
            exit 1
        fi
    fi
    # Prüfe, ob python3-venv installiert ist, sonst nachinstallieren
    PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if ! python3 -m venv --help >/dev/null 2>&1; then
        print_interactive "  → python3-venv wird installiert ..."
        if ! run_and_log "apt-get install python3-$PY_VER-venv" apt-get install -y -qq python3-$PY_VER-venv; then
            print_warning "python3-$PY_VER-venv konnte nicht installiert werden, versuche python3-venv ..."
            if ! run_and_log "apt-get install python3-venv" apt-get install -y -qq python3-venv; then
                print_error "  → Fehler: python3-venv konnte nicht installiert werden!"
                exit 1
            fi
        fi
    fi
    if run_and_log "apt-get update für weitere Pakete" apt-get update -qq && \
       run_and_log "apt-get install python3 git sqlite3 lsof" apt-get install -y -qq python3 git sqlite3 lsof; then
        print_success "  → Alle benötigten Pakete wurden erfolgreich installiert."
    else
        print_error "  → Fehler: Die Installation der benötigten Pakete ist fehlgeschlagen! Siehe ggf. /var/log/apt/term.log."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# setup_user_group
# ------------------------------------------------------------------------------
# Funktion: Prüft und legt Systembenutzer und -gruppe für die Fotobox an (Schritt 3/9)
setup_user_group() {
    print_interactive "[3/9] Systembenutzer und Gruppe prüfen ..."
    local valid_user=0
    while [ $valid_user -eq 0 ]; do
        print_interactive "Bitte geben Sie den gewünschten System-User für die Fotobox ein [www-data]:"
        read -p "User [www-data]: " input_user
        FOTOBOX_USER=${input_user:-www-data}
        if [[ ! "$FOTOBOX_USER" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_error "Ungültiger Benutzername! Nur Buchstaben, Zahlen, - und _ erlaubt."
        elif [[ "$FOTOBOX_USER" == "root" || "$FOTOBOX_USER" == "admin" ]]; then
            print_error "Reservierter Benutzername! Bitte anderen Namen wählen."
        else
            valid_user=1
        fi
    done
    local valid_group=0
    while [ $valid_group -eq 0 ]; do
        print_interactive "Bitte geben Sie die gewünschte System-Gruppe für die Fotobox ein [www-data]:"
        read -p "Gruppe [www-data]: " input_group
        FOTOBOX_GROUP=${input_group:-www-data}
        if [[ ! "$FOTOBOX_GROUP" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_error "Ungültiger Gruppenname! Nur Buchstaben, Zahlen, - und _ erlaubt."
        elif [[ "$FOTOBOX_GROUP" == "root" || "$FOTOBOX_GROUP" == "admin" ]]; then
            print_error "Reservierter Gruppenname! Bitte anderen Namen wählen."
        else
            valid_group=1
        fi
    done
    if ! id -u "$FOTOBOX_USER" &>/dev/null; then
        if run_and_log "adduser $FOTOBOX_USER" adduser --system --no-create-home "$FOTOBOX_USER"; then
            print_success "  → Benutzer $FOTOBOX_USER wurde angelegt."
        else
            print_error "Fehler: Benutzer $FOTOBOX_USER konnte nicht angelegt werden!"
            exit 1
        fi
    else
        print_success "  → Benutzer $FOTOBOX_USER existiert bereits."
    fi
    if ! getent group "$FOTOBOX_GROUP" &>/dev/null; then
        if run_and_log "addgroup $FOTOBOX_GROUP" addgroup "$FOTOBOX_GROUP"; then
            print_success "  → Gruppe $FOTOBOX_GROUP wurde angelegt."
        else
            print_error "Fehler: Gruppe $FOTOBOX_GROUP konnte nicht angelegt werden!"
            exit 1
        fi
    else
        print_success "  → Gruppe $FOTOBOX_GROUP existiert bereits."
    fi
}

# ------------------------------------------------------------------------------
# bootstrap_project
# ------------------------------------------------------------------------------
# Funktion: Klont oder aktualisiert das Projekt-Repository und setzt Rechte (Schritt 4/9)
bootstrap_project() {
    print_interactive "[4/9] Projektdateien werden bereitgestellt ..."
    # Internetverbindung prüfen (maximal 3 Versuche)
    local net_ok=0
    for i in {1..3}; do
        if ping -c 1 -W 2 github.com > /dev/null 2>&1; then
            net_ok=1
            break
        else
            print_warning "  → Keine Internetverbindung oder github.com nicht erreichbar (Versuch $i/3)."
            sleep 2
        fi
    done
    if [ $net_ok -ne 1 ]; then
        print_error "Fehler: Keine Internetverbindung oder github.com nicht erreichbar! Bitte prüfen Sie Ihre Netzwerkverbindung."
        exit 1
    fi
    if [ ! -d "$PROJECT_DIR" ]; then
        print_interactive "  → Repository wird geklont ..."
        if ! command -v git &>/dev/null; then
            print_interactive "  → git wird installiert ..."
            run_and_log "apt-get update für git" apt-get update -qq
            run_and_log "apt-get install git" apt-get install -y -qq git
        fi
        # Git-Klonvorgang mit bis zu 3 Versuchen
        local clone_ok=0
        for i in {1..3}; do
            if run_and_log "git clone Versuch $i" git clone -q "$REPO_URL" "$PROJECT_DIR"; then
                print_success "  → Repository wurde erfolgreich geklont."
                clone_ok=1
                break
            else
                print_warning "  → Klonen fehlgeschlagen (Versuch $i/3). Prüfe Internet/DNS ..."
                sleep 2
            fi
        done
        if [ $clone_ok -ne 1 ]; then
            print_error "Fehler: Repository konnte nach mehreren Versuchen nicht geklont werden! Siehe $LOGFILE."
            exit 1
        fi
    else
        print_success "  → Projektverzeichnis existiert bereits."
    fi
    if [ ! -d "$PROJECT_DIR" ]; then
        if run_and_log "mkdir Projektverzeichnis" mkdir -p "$PROJECT_DIR"; then
            print_success "  → Projektverzeichnis wurde angelegt."
        else
            print_error "Fehler: Projektverzeichnis konnte nicht angelegt werden!"
            exit 1
        fi
    fi
    if run_and_log "chown Projektverzeichnis" chown -R "$FOTOBOX_USER":"$FOTOBOX_GROUP" "$PROJECT_DIR"; then
        print_success "  → Rechte wurden erfolgreich gesetzt."
    else
        print_error "Fehler: Rechte konnten nicht gesetzt werden!"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# configure_nginx
# ------------------------------------------------------------------------------
# Funktion: Richtet die NGINX-Konfiguration ein, fragt ggf. alternativen Port ab (Schritt 8/9)
configure_nginx() {
    print_interactive "[8/9] NGINX-Konfiguration wird eingerichtet ..."
    if lsof -i :80 | grep LISTEN > /dev/null; then
        # Prüfe, ob der fotobox-Service oder die NGINX-Default-Site Port 80 belegt
        local port80_info
        port80_info=$(lsof -i :80 | grep LISTEN)
        print_warning "Der Standard-Port [80] des NGINX Webserver ist bereits belegt."
        print_interactive "Dienst/Prozess auf Port 80:"
        if echo "$port80_info" | grep -q 'nginx'; then
            # Prüfe, ob es die fotobox-Site ist
            if [ -L /etc/nginx/sites-enabled/fotobox ]; then
                print_success "Port 80 wird bereits von der Fotobox (nginx/sites-enabled/fotobox) genutzt. Keine Aktion erforderlich."
                NGINX_PORT=80
                # Keine weitere Portabfrage, direkt fortfahren
            elif [ -L /etc/nginx/sites-enabled/default ]; then
                print_warning "Port 80 wird von der NGINX-Default-Site genutzt."
                print_interactive "Soll die Default-Site durch die Fotobox-Konfiguration ersetzt werden? [J/n]:"
                read -p "Antwort: " OVERWRITE_DEFAULT
                OVERWRITE_DEFAULT=${OVERWRITE_DEFAULT:-J}
                if [[ "$OVERWRITE_DEFAULT" =~ ^[JjYy]$ ]]; then
                    rm -f /etc/nginx/sites-enabled/default
                    print_success "Default-Site wurde entfernt. Fotobox übernimmt Port 80."
                    NGINX_PORT=80
                else
                    print_interactive "Bitte wählen Sie einen alternativen Port für die Fotobox."
                    while true; do
                        read -p "Port [8080]: " ALT_PORT
                        ALT_PORT=${ALT_PORT:-8080}
                        if lsof -i :$ALT_PORT | grep LISTEN > /dev/null; then
                            print_error "Port $ALT_PORT ist ebenfalls belegt. Bitte anderen Port wählen!"
                            print_interactive "Dienst/Prozess auf Port $ALT_PORT:"
                            lsof -i :$ALT_PORT | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port $ALT_PORT gefunden."
                        else
                            NGINX_PORT=$ALT_PORT
                            break
                        fi
                    done
                fi
            else
                # NGINX läuft, aber keine bekannte Site – Portwahl anbieten
                print_interactive "Bitte wählen Sie einen alternativen Port für die Fotobox."
                while true; do
                    read -p "Port [8080]: " ALT_PORT
                    ALT_PORT=${ALT_PORT:-8080}
                    if lsof -i :$ALT_PORT | grep LISTEN > /dev/null; then
                        print_error "Port $ALT_PORT ist ebenfalls belegt. Bitte anderen Port wählen!"
                        print_interactive "Dienst/Prozess auf Port $ALT_PORT:"
                        lsof -i :$ALT_PORT | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port $ALT_PORT gefunden."
                    else
                        NGINX_PORT=$ALT_PORT
                        break
                    fi
                done
            fi
        else
            # Port 80 wird von einem anderen Dienst belegt
            echo "$port80_info"
            print_interactive "Bitte wählen Sie einen alternativen Port für die Fotobox."
            while true; do
                read -p "Port [8080]: " ALT_PORT
                ALT_PORT=${ALT_PORT:-8080}
                if lsof -i :$ALT_PORT | grep LISTEN > /dev/null; then
                    print_error "Port $ALT_PORT ist ebenfalls belegt. Bitte anderen Port wählen!"
                    print_interactive "Dienst/Prozess auf Port $ALT_PORT:"
                    lsof -i :$ALT_PORT | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port $ALT_PORT gefunden."
                else
                    NGINX_PORT=$ALT_PORT
                    break
                fi
            done
        fi
    else
        NGINX_PORT=80
    fi
    if [ -f "$PROJECT_DIR/conf/nginx-fotobox.conf" ]; then
        if [ "$NGINX_PORT" != "80" ]; then
            # Ersetze alle relevanten listen-Direktiven (auch default_server und IPv6)
            run_and_log "sed Portanpassung nginx-fotobox.conf ($NGINX_PORT)" \
                sed -e "s/listen 80;/listen $NGINX_PORT;/g" \
                    -e "s/listen 80 default_server;/listen $NGINX_PORT default_server;/g" \
                    -e "s/listen [::]:80;/listen [::]:$NGINX_PORT;/g" \
                    -e "s/listen [::]:80 default_server;/listen [::]:$NGINX_PORT default_server;/g" \
                "$PROJECT_DIR/conf/nginx-fotobox.conf" > /etc/nginx/sites-available/fotobox
            # Default-Site deaktivieren, wenn alternativer Port genutzt wird
            if [ -L /etc/nginx/sites-enabled/default ]; then
                rm -f /etc/nginx/sites-enabled/default
                print_interactive "Default-Site wurde deaktiviert, da alternativer Port verwendet wird."
            fi
        else
            run_and_log "cp nginx-fotobox.conf" cp "$PROJECT_DIR/conf/nginx-fotobox.conf" /etc/nginx/sites-available/fotobox
        fi
        run_and_log "ln -sf nginx site enable" ln -sf /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox
        # NGINX-Konfiguration testen (robust, Fehlerausgabe immer sichtbar)
        nginx -t > /tmp/fotobox_nginx_test.log 2>&1
        local NGINX_TEST_STATUS=$?
        if [ $NGINX_TEST_STATUS -eq 0 ]; then
            print_success "NGINX-Konfigurationstest erfolgreich. NGINX wird neu gestartet."
            run_and_log "systemctl restart nginx" systemctl restart nginx
        else
            print_error "Fehler: NGINX-Konfigurationstest fehlgeschlagen! Siehe /tmp/fotobox_nginx_test.log."
            # Zeige an, welcher Dienst Port 80 belegt (nur wenn Port 80 verwendet werden soll)
            if [ "$NGINX_PORT" = "80" ]; then
                print_interactive "Dienst/Prozess auf Port 80:"
                lsof -i :80 | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port 80 gefunden."
            fi
            exit 1
        fi
        print_success "NGINX-Konfiguration wurde erfolgreich eingerichtet."
    else
        print_warning "Warnung: $PROJECT_DIR/conf/nginx-fotobox.conf nicht gefunden! NGINX-Konfiguration wurde nicht aktualisiert."
    fi
}

# ------------------------------------------------------------------------------
# setup_systemd_service
# ------------------------------------------------------------------------------
# Funktion: Richtet den systemd-Service für das Backend ein und startet ihn (Schritt 9/9)
setup_systemd_service() {
    # Prüfe, ob systemd vorhanden und aktiv ist
    if ! pidof systemd >/dev/null 2>&1; then
        print_error "Fehler: systemd ist nicht aktiv! Dieses Skript benötigt ein laufendes systemd."
        exit 1
    fi
    echo "[9/9] Backend-Service wird eingerichtet ..."
    SERVICE_FILE="/etc/systemd/system/fotobox-backend.service"
    if [ ! -f "$SERVICE_FILE" ]; then
cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=Fotobox Backend (Flask)
After=network.target

[Service]
User=$FOTOBOX_USER
WorkingDirectory=$PROJECT_DIR/backend
ExecStart=$PROJECT_DIR/backend/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL
        run_and_log "systemctl daemon-reload" systemctl daemon-reload
        run_and_log "systemctl enable --now fotobox-backend" systemctl enable --now fotobox-backend
    fi
    # Service-Status prüfen
    if systemctl is-active --quiet fotobox-backend; then
        print_success "  → systemd-Service fotobox-backend läuft."
    else
        print_error "Fehler: systemd-Service fotobox-backend konnte nicht gestartet werden!"
        run_and_log "journalctl fotobox-backend" journalctl -u fotobox-backend --no-pager | tail -20
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# setup_python_backend
# ------------------------------------------------------------------------------
# Funktion: Richtet die Python-Umgebung und Backend-Abhängigkeiten ein (Schritt 5/9)
setup_python_backend() {
    print_interactive "[5/9] Python-Umgebung und Backend-Abhängigkeiten werden eingerichtet ..."
    cd "$PROJECT_DIR/backend"
    if run_and_log "python3 -m venv venv" python3 -m venv venv; then
        print_success "  → Python-venv wurde erstellt."
    else
        print_error "Fehler: Python-venv konnte nicht erstellt werden!"
        exit 1
    fi

    if run_and_log "pip install --upgrade pip" ./venv/bin/pip install --upgrade pip && \
       run_and_log "pip install requirements.txt" ./venv/bin/pip install -r requirements.txt; then
        print_success "  → Python-Abhängigkeiten wurden installiert."
    else
        print_error "Fehler: Python-Abhängigkeiten konnten nicht installiert werden!"
        exit 1
    fi

    if [ ! -f "$PROJECT_DIR/backend/fotobox_settings.db" ]; then
        if run_and_log "sqlite3 DB initialisieren" ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'); con.close()"; then
            print_success "  → Datenbank wurde initialisiert."
        else
            print_error "Fehler: Datenbank konnte nicht initialisiert werden!"
            exit 1
        fi
    fi
    
    # SQLite-Schreibtest
    if run_and_log "sqlite3 Schreibtest" ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('test_write', 'ok')\"); con.commit(); con.close()"; then
        print_success "  → SQLite-Schreibtest erfolgreich."
    else
        print_error "Fehler: SQLite-Datenbank ist nicht schreibbar! Siehe /tmp/fotobox_sqlite_test.log."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# setup_config_password
# ------------------------------------------------------------------------------
# Funktion: Fragt das Passwort für die Konfigurationsseite ab und speichert es (Schritt 6/9)
setup_config_password() {
    print_interactive "[6/9] Passwort für Konfigurationsseite wird gesetzt ..."
    print_interactive "[SICHERHEIT] Zugang zur Konfigurationsseite"
    print_interactive "Für den Zugang zur Konfigurationsseite der Fotobox wird ein Passwort benötigt."
    print_interactive "Bitte wählen Sie ein sicheres Passwort. Dieses wird im Backend gespeichert und schützt Ihre Einstellungen vor unbefugtem Zugriff."
    print_interactive "Das Passwort kann später über die Konfigurationsseite geändert werden."
    while true; do
        print_interactive "Neues Konfigurations-Passwort:"
        read -s -p "Passwort: " CONFIG_PW1; echo
        print_interactive "Passwort wiederholen:"
        read -s -p "Wiederholen: " CONFIG_PW2; echo
        if [ "$CONFIG_PW1" != "$CONFIG_PW2" ]; then
            print_error "Die Passwörter stimmen nicht überein. Bitte erneut eingeben."
        elif [ -z "$CONFIG_PW1" ]; then
            print_error "Das Passwort darf nicht leer sein."
        else
            break
        fi
    done
    # Passwort in die Datenbank schreiben (ersetzt bisherigen Wert)
    cd "$PROJECT_DIR/backend"
    # Passwort-Hash berechnen, um Quoting-Probleme zu vermeiden
    CONFIG_PW_HASH=$(echo -n "$CONFIG_PW1" | ./venv/bin/python -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())")
    ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'); con.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', ('config_password', '$CONFIG_PW_HASH')); con.commit(); con.close()"
    # SQLite-Schreibtest nach Passwort-Setzen
    if ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('test_pw_write', 'ok')\"); con.commit(); con.close()" 2>/tmp/fotobox_sqlite_pw_test.log; then
        print_success "Das Passwort wurde sicher gespeichert. Bewahren Sie es gut auf!"
    else
        print_error "Fehler: Passwort konnte nicht in die SQLite-Datenbank geschrieben werden! Siehe /tmp/fotobox_sqlite_pw_test.log."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# backup_and_organize
# ------------------------------------------------------------------------------
# Funktion: Sichert wichtige Systemdateien und organisiert Projektdateien (Schritt 7/9)
backup_and_organize() {
    print_interactive "[7/9] Systemdateien werden gesichert ..."
    BACKUP_DIR="$PROJECT_DIR/backup-$(date +%Y%m%d%H%M%S)"
    if run_and_log "mkdir Backup-Verzeichnis" mkdir -p "$BACKUP_DIR"; then
        print_success "  → Backup-Verzeichnis wurde erstellt."
    else
        print_error "Fehler: Backup-Verzeichnis konnte nicht erstellt werden!"
        exit 1
    fi
    local ok=1
    if [ -f /etc/nginx/sites-available/fotobox ]; then
        run_and_log "cp nginx-fotobox.conf.bak" cp /etc/nginx/sites-available/fotobox "$BACKUP_DIR/nginx-fotobox.conf.bak" || ok=0
    fi
    if [ -L /etc/nginx/sites-enabled/fotobox ]; then
        run_and_log "cp nginx-fotobox.link.bak" cp --remove-destination /etc/nginx/sites-enabled/fotobox "$BACKUP_DIR/nginx-fotobox.link.bak" || ok=0
    fi
    if [ -f /etc/nginx/sites-enabled/default ]; then
        run_and_log "cp nginx-default.link.bak" cp /etc/nginx/sites-enabled/default "$BACKUP_DIR/nginx-default.link.bak" || ok=0
    fi
    if [ -f /etc/systemd/system/fotobox-backend.service ]; then
        run_and_log "cp fotobox-backend.service.bak" cp /etc/systemd/system/fotobox-backend.service "$BACKUP_DIR/fotobox-backend.service.bak" || ok=0
    fi
    if [ -f "$PROJECT_DIR/README.md" ]; then
        run_and_log "mkdir documentation" mkdir -p "$PROJECT_DIR/documentation"
        run_and_log "mv README.md" mv "$PROJECT_DIR/README.md" "$PROJECT_DIR/documentation/README.md" || ok=0
    fi
    if [ -f "$PROJECT_DIR/nginx-fotobox.conf" ]; then
        run_and_log "mkdir conf" mkdir -p "$PROJECT_DIR/conf"
        run_and_log "mv nginx-fotobox.conf" mv "$PROJECT_DIR/nginx-fotobox.conf" "$PROJECT_DIR/conf/nginx-fotobox.conf" || ok=0
    fi
    if [ $ok -eq 1 ]; then
        print_success "  → Systemdateien wurden erfolgreich gesichert und organisiert."
    else
        print_error "Warnung: Mindestens eine Datei konnte nicht gesichert/verschoben werden!"
    fi
}

# ------------------------------------------------------------------------------
# update_fotobox
# ------------------------------------------------------------------------------
# Funktion: Führt Backup und Aktualisierung der Fotobox durch
update_fotobox() {
    echo "[Update] Backup und Aktualisierung werden durchgeführt ..."
    BACKUP_DIR="$PROJECT_DIR/backup-update-$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$PROJECT_DIR/backend" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$PROJECT_DIR/frontend" "$BACKUP_DIR/" 2>/dev/null || true
    if [ -f /etc/nginx/sites-available/fotobox ]; then
        cp /etc/nginx/sites-available/fotobox "$BACKUP_DIR/nginx-fotobox.conf.bak"
    fi
    if [ -L /etc/nginx/sites-enabled/fotobox ]; then
        cp --remove-destination /etc/nginx/sites-enabled/fotobox "$BACKUP_DIR/nginx-fotobox.link.bak"
    fi
    if [ -f /etc/systemd/system/fotobox-backend.service ]; then
        cp /etc/systemd/system/fotobox-backend.service "$BACKUP_DIR/fotobox-backend.service.bak"
    fi
    if [ -f "$PROJECT_DIR/documentation/README.md" ]; then
        mv "$PROJECT_DIR/documentation/README.md" "$PROJECT_DIR/documentation/README.md.bak.$(date +%Y%m%d%H%M%S)"
    fi
    # Fehlerbehandlung: Rollback bei Fehler
    trap 'rollback_update; print_error "Update abgebrochen. Rollback durchgeführt."; exit 1' ERR
    cd "$PROJECT_DIR"
    git config --global --add safe.directory "$PROJECT_DIR"
    if [ -d .git ]; then
        echo "  → Repository wird aktualisiert ..."
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
        if [ -f "$PROJECT_DIR/fotobox.sh" ]; then
            if ! cmp -s "$PROJECT_DIR/fotobox.sh" "$SCRIPT_PATH"; then
                echo "\nHinweis: Es wurde eine neue Version von fotobox.sh im Repository gefunden."
                echo "Das Update wird jetzt beendet. Bitte starten Sie das Skript neu mit:"
                echo "  bash $PROJECT_DIR/fotobox.sh --update"
                exit 0
            fi
        fi
    else
        echo "  → Repository wird neu geklont ..."
        rm -rf "$PROJECT_DIR"
        git clone -q "$REPO_URL" "$PROJECT_DIR" > /dev/null
        cd "$PROJECT_DIR"
    fi
    cd "$PROJECT_DIR/backend"
    if [ -d venv ]; then
        ./venv/bin/pip install --upgrade pip > /dev/null
        ./venv/bin/pip install -r requirements.txt > /dev/null
    else
        python3 -m venv venv > /dev/null 2>&1
        ./venv/bin/pip install --upgrade pip > /dev/null
        ./venv/bin/pip install -r requirements.txt > /dev/null
    fi
    update_nginx_config_with_check
    save_nginx_config
    systemctl restart fotobox-backend > /dev/null 2>&1 || true
    if [ ! -f "$PROJECT_DIR/backend/fotobox_settings.db" ]; then
        ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'); con.close()" > /dev/null
    fi
    trap - ERR
    echo "Update abgeschlossen. Backup der vorherigen Version liegt unter: $BACKUP_DIR"
    # Weboberflächen-Check nach Update
    chk_webui
}

# ------------------------------------------------------------------------------
# remove_fotobox
# ------------------------------------------------------------------------------
# Funktion: Deinstalliert die Fotobox und stellt das System aus Backup wieder her
remove_fotobox() {
    echo "[Remove] Deinstallation und Rücksicherung werden durchgeführt ..."
    LATEST_BACKUP=$(ls -dt $PROJECT_DIR/backup-* 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        echo "  → Systemdateien werden aus Backup wiederhergestellt ..."
        if [ -f "$LATEST_BACKUP/nginx-fotobox.conf.bak" ]; then
            restore_nginx_config_with_port "$LATEST_BACKUP/nginx-fotobox.conf.bak"
        fi
        if [ -f "$LATEST_BACKUP/nginx-fotobox.link.bak" ]; then
            cp --remove-destination "$LATEST_BACKUP/nginx-fotobox.link.bak" /etc/nginx/sites-enabled/fotobox
        fi
        if [ -f "$LATEST_BACKUP/nginx-default.link.bak" ]; then
            cp "$LATEST_BACKUP/nginx-default.link.bak" /etc/nginx/sites-enabled/default
        fi
        if [ -f "$LATEST_BACKUP/fotobox-backend.service.bak" ]; then
            cp "$LATEST_BACKUP/fotobox-backend.service.bak" /etc/systemd/system/fotobox-backend.service
        fi
        systemctl daemon-reload > /dev/null
        # NGINX-Konfiguration nach Restore immer mit Port-Anpassung aktivieren
        if [ -f /etc/nginx/sites-available/fotobox ]; then
            # Port prüfen und ggf. anpassen
            if lsof -i :80 | grep LISTEN > /dev/null; then
                echo "  → Port 80 ist belegt. Alternativer Port wird abgefragt ..."
                read -p "Bitte geben Sie einen alternativen Port für NGINX ein [8080]: " ALT_PORT
                ALT_PORT=${ALT_PORT:-8080}
                NGINX_PORT=$ALT_PORT
            else
                NGINX_PORT=80
            fi
            # Prüfe, ob Quell- und Zieldatei identisch sind und Port 80 verwendet wird
            if [ "/etc/nginx/sites-available/fotobox" = "/etc/nginx/sites-available/fotobox" ] && [ "$NGINX_PORT" = "80" ]; then
                # Kein write_nginx_config_with_port nötig, da identisch und Port 80
                print_interactive "NGINX-Konfiguration bleibt unverändert (Port 80, identische Datei)."
            else
                write_nginx_config_with_port /etc/nginx/sites-available/fotobox /etc/nginx/sites-available/fotobox "$NGINX_PORT"
            fi
            ln -sf /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox
        fi
        systemctl restart nginx > /dev/null
    fi
    NGINX_CONF="/etc/nginx/sites-available/fotobox"
    NGINX_LINK="/etc/nginx/sites-enabled/fotobox"
    SERVICE_FILE="/etc/systemd/system/fotobox-backend.service"
    BACKUP_DIR="/opt/fotobox-backup-$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    if [ -f "$NGINX_CONF" ]; then
        cp "$NGINX_CONF" "$BACKUP_DIR/"
    fi
    if [ -L "$NGINX_LINK" ]; then
        cp --remove-destination "$NGINX_LINK" "$BACKUP_DIR/"
    fi
    if [ -f "$SERVICE_FILE" ]; then
        cp "$SERVICE_FILE" "$BACKUP_DIR/"
    fi
    if systemctl is-active --quiet fotobox-backend; then
        systemctl stop fotobox-backend > /dev/null
    fi
    if systemctl is-enabled --quiet fotobox-backend; then
        systemctl disable fotobox-backend > /dev/null
    fi
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload > /dev/null
    rm -f "$NGINX_CONF" "$NGINX_LINK"
    if [ -f /etc/nginx/sites-enabled/default ]; then
        echo "  → Standard-NGINX-Seite bleibt erhalten."
    fi
    systemctl restart nginx > /dev/null
    rm -rf "$PROJECT_DIR"
    rm -f "$PROJECT_DIR/backend/fotobox_settings.db"
    cat <<EOM
Deinstallation abgeschlossen.
Alle Projektdateien und Konfigurationen wurden entfernt.
Backups der entfernten Dateien finden Sie unter:
  $BACKUP_DIR
Bitte prüfen Sie ggf. manuell, ob weitere benutzerdefinierte Einstellungen entfernt werden müssen.
EOM
}

# ------------------------------------------------------------------------------
# save_nginx_config
# ------------------------------------------------------------------------------
# Funktion: Sichert die aktuell verwendete NGINX-Konfiguration im Projektverzeichnis
save_nginx_config() {
    # Speichert die aktuell verwendete NGINX-Konfiguration im Projektverzeichnis
    if [ -f /etc/nginx/sites-available/fotobox ]; then
        mkdir -p "$PROJECT_DIR/conf"
        cp /etc/nginx/sites-available/fotobox "$PROJECT_DIR/conf/nginx-fotobox.last.conf"
    fi
}

# ------------------------------------------------------------------------------
# write_nginx_config_with_port
# ------------------------------------------------------------------------------
# Funktion: Schreibe NGINX-Konfiguration mit Port-Anpassung
# $1 = Quell-Datei, $2 = Ziel-Datei, $3 = Port
write_nginx_config_with_port() {
    # $1 = Quell-Datei, $2 = Ziel-Datei, $3 = Port
    local SRC="$1"
    local DST="$2"
    local PORT="$3"
    if [ "$PORT" != "80" ]; then
        sed "s/listen 80;/listen $PORT;/g" "$SRC" > "$DST"
    else
        cp "$SRC" "$DST"
    fi
}

# ------------------------------------------------------------------------------
# update_nginx_config_with_check
# ------------------------------------------------------------------------------
# Funktion: Vergleicht die NGINX-Konfiguration und wendet Änderungen an (für Update)
update_nginx_config_with_check() {
    SYSTEM_CONF="/etc/nginx/sites-available/fotobox"
    PROJECT_CONF="$PROJECT_DIR/conf/nginx-fotobox.conf"
    LAST_CONF="$PROJECT_DIR/conf/nginx-fotobox.last.conf"
    # Port-Logik wie gehabt
    if lsof -i :80 | grep LISTEN > /dev/null; then
        print_warning "Der Standard-Port [80] des NGINX Webserver ist bereits belegt. Wählen Sie einen alternativen Port (z.B. 8080)"
        print_interactive "Dienst/Prozess auf Port 80:"
        lsof -i :80 | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port 80 gefunden."
        while true; do
            print_interactive "Port:"
            read -p "Port [8080]: " ALT_PORT
            ALT_PORT=${ALT_PORT:-8080}
            if lsof -i :$ALT_PORT | grep LISTEN > /dev/null; then
                print_error "Port $ALT_PORT ist ebenfalls belegt. Bitte anderen Port wählen!"
                print_interactive "Dienst/Prozess auf Port $ALT_PORT:"
                lsof -i :$ALT_PORT | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port $ALT_PORT gefunden."
            else
                NGINX_PORT=$ALT_PORT
                break
            fi
        done
    else
        NGINX_PORT=80
    fi
    # Vergleich: System vs. Projekt-Konfiguration
    if [ -f "$SYSTEM_CONF" ] && [ -f "$PROJECT_CONF" ]; then
        if ! diff -q "$SYSTEM_CONF" "$PROJECT_CONF" > /dev/null; then
            print_warning "Warnung: Die aktuelle NGINX-Konfiguration unterscheidet sich von der im Projekt gespeicherten!"
            print_interactive "Ein Backup der aktuellen Konfiguration wird angelegt."
            cp "$SYSTEM_CONF" "$SYSTEM_CONF.bak.$(date +%Y%m%d%H%M%S)"
            print_interactive "Soll die Projekt-Konfiguration übernommen werden? [J/n]:"
            read -p "Antwort: " OVERWRITE
            OVERWRITE=${OVERWRITE:-J}
            if [[ "$OVERWRITE" =~ ^[JjYy]$ ]]; then
                write_nginx_config_with_port "$PROJECT_CONF" "$SYSTEM_CONF" "$NGINX_PORT"
                print_success "Projekt-Konfiguration übernommen."
            else
                write_nginx_config_with_port "$SYSTEM_CONF" "$SYSTEM_CONF" "$NGINX_PORT"
                print_interactive "Die bestehende NGINX-Konfiguration bleibt erhalten (Port ggf. angepasst)."
            fi
        else
            # Keine Unterschiede, trotzdem Port anpassen
            write_nginx_config_with_port "$PROJECT_CONF" "$SYSTEM_CONF" "$NGINX_PORT"
            print_success "NGINX-Konfiguration wurde aktualisiert."
        fi
    elif [ -f "$PROJECT_CONF" ]; then
        write_nginx_config_with_port "$PROJECT_CONF" "$SYSTEM_CONF" "$NGINX_PORT"
        print_success "NGINX-Konfiguration wurde übernommen."
    else
        print_warning "Warnung: $PROJECT_CONF nicht gefunden! NGINX-Konfiguration wurde nicht aktualisiert."
    fi
    ln -sf "$SYSTEM_CONF" /etc/nginx/sites-enabled/fotobox
    systemctl restart nginx > /dev/null
}

# ------------------------------------------------------------------------------
# restore_nginx_config_with_port
# ------------------------------------------------------------------------------
# Funktion: Stellt die NGINX-Konfiguration aus einem Backup wieder her (mit Port-Anpassung)
# $1 = Backup-Datei
restore_nginx_config_with_port() {
    # $1 = Backup-Datei
    SYSTEM_CONF="/etc/nginx/sites-available/fotobox"
    BACKUP_CONF="$1"
    if lsof -i :80 | grep LISTEN > /dev/null; then
        print_warning "Der Standard-Port [80] des NGINX Webserver ist bereits belegt. Wählen Sie einen alternativen Port (z.B. 8080)"
        print_interactive "Dienst/Prozess auf Port 80:"
        lsof -i :80 | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port 80 gefunden."
        while true; do
            print_interactive "Port:"
            read -p "Port [8080]: " ALT_PORT
            ALT_PORT=${ALT_PORT:-8080}
            if lsof -i :$ALT_PORT | grep LISTEN > /dev/null; then
                print_error "Port $ALT_PORT ist ebenfalls belegt. Bitte anderen Port wählen!"
                print_interactive "Dienst/Prozess auf Port $ALT_PORT:"
                lsof -i :$ALT_PORT | grep LISTEN || print_warning "Keine Information zu Prozessen auf Port $ALT_PORT gefunden."
            else
                NGINX_PORT=$ALT_PORT
                break
            fi
        done
    else
        NGINX_PORT=80
    fi
    write_nginx_config_with_port "$BACKUP_CONF" "$SYSTEM_CONF" "$NGINX_PORT"
    ln -sf "$SYSTEM_CONF" /etc/nginx/sites-enabled/fotobox
    systemctl restart nginx > /dev/null
    print_success "NGINX-Konfiguration aus Backup wiederhergestellt."
}

# ------------------------------------------------------------------------------
# run_and_log
# ------------------------------------------------------------------------------
# Funktion: Führt einen Befehl aus, loggt Kommando, Exitcode und Fehlerausgabe
# Parameter: $1 = Beschreibung, $2... = Befehl und Argumente
run_and_log() {
    local DESC="$1"
    shift
    local CMD=("$@")
    log_message "INFO" "[RUN] $DESC: ${CMD[*]}"
    "${CMD[@]}" 1>>"$LOGFILE" 2>>"$LOGFILE"
    local STATUS=$?
    if [ $STATUS -eq 0 ]; then
        log_message "INFO" "[OK] $DESC erfolgreich (Exitcode $STATUS)"
    else
        log_message "ERROR" "[FAIL] $DESC fehlgeschlagen (Exitcode $STATUS)"
    fi
    return $STATUS
}

# ------------------------------------------------------------------------------
# show_final_message
# ------------------------------------------------------------------------------
# Funktion: Zeigt eine Abschlussmeldung nach erfolgreicher Installation an und prüft die Erreichbarkeit der Weboberfläche
show_final_message() {
    print_success "\nFotobox-Installation abgeschlossen!"
    print_interactive "\nSie können die Fotobox nun im Browser aufrufen."
    print_interactive "Beispiel: http://<IP-Adresse-oder-Hostname>:${NGINX_PORT}/"
    print_interactive "\nWeitere Hinweise finden Sie in der README.md im Projektverzeichnis."
    # Weboberflächen-Check
    chk_webui
}

# ------------------------------------------------------------------------------
# chk_webui
# ------------------------------------------------------------------------------
# Funktion: Prüft die Erreichbarkeit der Weboberfläche (start.html) per curl
# Rückgabewert: 0 = erreichbar (HTTP 200), 1 = Fehler/Problem
# Gibt Status und Troubleshooting-Hinweise aus
chk_webui() {
    local url="http://localhost:${NGINX_PORT}/start.html"
    print_interactive "\nPrüfe Erreichbarkeit der Weboberfläche (${url}) ..."
    if command -v curl >/dev/null 2>&1; then
        local CURL_RESULT
        CURL_RESULT=$(curl -s -o /dev/null -w "%{http_code}" "$url")
        if [ "$CURL_RESULT" = "200" ]; then
            print_success "Weboberfläche ist erreichbar (HTTP 200)."
            return 0
        else
            print_error "Weboberfläche ist NICHT erreichbar (HTTP $CURL_RESULT). Bitte prüfen Sie NGINX, systemd-Service und Firewall."
            print_interactive "Fehlerbehebung:"
            print_interactive "- Ist der Dienst 'fotobox-backend' aktiv? (systemctl status fotobox-backend)"
            print_interactive "- Ist NGINX aktiv? (systemctl status nginx)"
            print_interactive "- Ist der Port ${NGINX_PORT} offen? (lsof -i :${NGINX_PORT})"
            print_interactive "- Siehe auch das Logfile: /var/log/fotobox_install.log"
            return 1
        fi
    else
        print_warning "curl ist nicht installiert, Weboberflächen-Test wird übersprungen."
        return 2
    fi
}

# ------------------------------------------------------------------------------
# Hauptablauf
# ------------------------------------------------------------------------------
# Funktion: Steuert die Ausführung des Skripts je nach übergebenem Parameter
case "$1" in
    --install)
        update_system
        install_software
        setup_user_group
        bootstrap_project
        setup_python_backend
        setup_config_password
        backup_and_organize
        configure_nginx
        setup_systemd_service
        show_final_message
        ;;
    --update)
        update_fotobox
        ;;
    --remove)
        remove_fotobox
        ;;
    *)
        echo "Verwendung: $0 --install | --update | --remove"
        exit 1
        ;;
esac
