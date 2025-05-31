#!/bin/bash
# Fotobox Multi-Tool: Installation und Update
# Für Ubuntu/Debian-basierte Systeme
# Nutzung:
#   ./fotobox.sh --install   # Erstinstallation
#   ./fotobox.sh --update    # Update auf aktuelle Version

set -e

PROJECT_DIR="/opt/fotobox"
REPO_URL="https://github.com/DirkGoetze/fotobox2.git"

# --- System aktualisieren ---
update_system() {
    echo "[1/9] Systempakete werden aktualisiert ..."
    apt-get update -qq > /dev/null
}

# --- Notwendige Software installieren ---
install_software() {
    echo "[2/9] Notwendige Software wird installiert ..."
    apt-get install -y -qq nginx python3 python3-pip python3.11-venv git sqlite3 lsof > /dev/null
}

# --- User und Gruppe anlegen ---
setup_user_group() {
    echo "[3/9] Systembenutzer und Gruppe prüfen ..."
    read -p "Bitte geben Sie den gewünschten System-User für die Fotobox ein [www-data]: " input_user
    FOTOBOX_USER=${input_user:-www-data}
    read -p "Bitte geben Sie die gewünschte System-Gruppe für die Fotobox ein [www-data]: " input_group
    FOTOBOX_GROUP=${input_group:-www-data}
    if ! id -u "$FOTOBOX_USER" &>/dev/null; then
        echo "  → Benutzer $FOTOBOX_USER wird angelegt ..."
        adduser --system --no-create-home "$FOTOBOX_USER" > /dev/null
    fi
    if ! getent group "$FOTOBOX_GROUP" &>/dev/null; then
        echo "  → Gruppe $FOTOBOX_GROUP wird angelegt ..."
        addgroup "$FOTOBOX_GROUP" > /dev/null
    fi
}

# --- Projekt klonen oder aktualisieren (Self-Bootstrap) ---
bootstrap_project() {
    echo "[4/9] Projektdateien werden bereitgestellt ..."
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "  → Repository wird geklont ..."
        if ! command -v git &>/dev/null; then
            echo "  → git wird installiert ..."
            apt-get update -qq > /dev/null && apt-get install -y -qq git > /dev/null
        fi
        git clone -q "$REPO_URL" "$PROJECT_DIR" > /dev/null
    else
        echo "  → Projektverzeichnis existiert bereits."
    fi
    chown -R "$FOTOBOX_USER":"$FOTOBOX_GROUP" "$PROJECT_DIR" > /dev/null 2>&1
}

# --- Python venv und Abhängigkeiten ---
setup_python_backend() {
    echo "[5/9] Python-Umgebung und Backend-Abhängigkeiten werden eingerichtet ..."
    cd "$PROJECT_DIR/backend"
    python3 -m venv venv > /dev/null 2>&1
    ./venv/bin/pip install --upgrade pip > /dev/null
    ./venv/bin/pip install -r requirements.txt > /dev/null
    if [ ! -f "$PROJECT_DIR/backend/fotobox_settings.db" ]; then
        ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'); con.close()" > /dev/null
    fi
}

# --- Passwort für Konfiguration abfragen und speichern ---
setup_config_password() {
    echo "[6/9] Passwort für Konfigurationsseite wird gesetzt ..."
    echo "[SICHERHEIT] Zugang zur Konfigurationsseite"
    echo "Für den Zugang zur Konfigurationsseite der Fotobox wird ein Passwort benötigt."
    echo "Bitte wählen Sie ein sicheres Passwort. Dieses wird im Backend gespeichert und schützt Ihre Einstellungen vor unbefugtem Zugriff."
    echo "Das Passwort kann später über die Konfigurationsseite geändert werden."
    while true; do
        read -s -p "Neues Konfigurations-Passwort: " CONFIG_PW1; echo
        read -s -p "Passwort wiederholen: " CONFIG_PW2; echo
        if [ "$CONFIG_PW1" != "$CONFIG_PW2" ]; then
            echo "Die Passwörter stimmen nicht überein. Bitte erneut eingeben."
        elif [ -z "$CONFIG_PW1" ]; then
            echo "Das Passwort darf nicht leer sein."
        else
            break
        fi
    done
    # Passwort in die Datenbank schreiben (ersetzt bisherigen Wert)
    cd "$PROJECT_DIR/backend"
    ./venv/bin/python -c "import sqlite3, hashlib; con=sqlite3.connect('fotobox_settings.db'); con.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'); con.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', ('config_password', hashlib.sha256('$CONFIG_PW1'.encode()).hexdigest())); con.commit(); con.close()"
    echo "Das Passwort wurde sicher gespeichert. Bewahren Sie es gut auf!"
}

# --- Backup und Datei-Organisation ---
backup_and_organize() {
    echo "[7/9] Systemdateien werden gesichert ..."
    BACKUP_DIR="$PROJECT_DIR/backup-$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    if [ -f /etc/nginx/sites-available/fotobox ]; then
        cp /etc/nginx/sites-available/fotobox "$BACKUP_DIR/nginx-fotobox.conf.bak"
    fi
    if [ -L /etc/nginx/sites-enabled/fotobox ]; then
        cp --remove-destination /etc/nginx/sites-enabled/fotobox "$BACKUP_DIR/nginx-fotobox.link.bak"
    fi
    if [ -f /etc/nginx/sites-enabled/default ]; then
        cp /etc/nginx/sites-enabled/default "$BACKUP_DIR/nginx-default.link.bak"
    fi
    if [ -f /etc/systemd/system/fotobox-backend.service ]; then
        cp /etc/systemd/system/fotobox-backend.service "$BACKUP_DIR/fotobox-backend.service.bak"
    fi
    if [ -f "$PROJECT_DIR/README.md" ]; then
        mkdir -p "$PROJECT_DIR/documentation"
        mv "$PROJECT_DIR/README.md" "$PROJECT_DIR/documentation/README.md"
    fi
    if [ -f "$PROJECT_DIR/nginx-fotobox.conf" ]; then
        mkdir -p "$PROJECT_DIR/conf"
        mv "$PROJECT_DIR/nginx-fotobox.conf" "$PROJECT_DIR/conf/nginx-fotobox.conf"
    fi
}

# --- NGINX konfigurieren ---
configure_nginx() {
    echo "[8/9] NGINX-Konfiguration wird eingerichtet ..."
    if lsof -i :80 | grep LISTEN > /dev/null; then
        echo "  → Port 80 ist belegt. Alternativer Port wird abgefragt ..."
        read -p "Bitte geben Sie einen alternativen Port für NGINX ein [8080]: " ALT_PORT
        ALT_PORT=${ALT_PORT:-8080}
        NGINX_PORT=$ALT_PORT
    else
        NGINX_PORT=80
    fi
    CONF_SRC="$PROJECT_DIR/conf/nginx-fotobox.conf"
    CONF_DST="/etc/nginx/sites-available/fotobox"
    if [ "$NGINX_PORT" != "80" ]; then
        sed "s/listen 80;/listen $NGINX_PORT;/g" "$CONF_SRC" > "$CONF_DST"
    else
        cp "$CONF_SRC" "$CONF_DST"
    fi
    ln -sf "$CONF_DST" /etc/nginx/sites-enabled/fotobox
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx > /dev/null
}

# --- systemd-Service für Backend ---
setup_systemd_service() {
    echo "[9/9] Backend-Service wird eingerichtet und gestartet ..."
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
        systemctl daemon-reload > /dev/null
        systemctl enable --now fotobox-backend > /dev/null
    fi
}

# --- Abschlussmeldung ---
show_final_message() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ "$NGINX_PORT" != "80" ]; then
        FRONTEND_URL="http://$SERVER_IP:$NGINX_PORT/start.html (bzw. index.html)"
    else
        FRONTEND_URL="http://$SERVER_IP/start.html (bzw. index.html)"
    fi
    echo "\nInstallation abgeschlossen!"
    echo "------------------------------------------------------------"
    echo "Fotobox-Frontend:  $FRONTEND_URL"
    echo "Backend-API:      http://$SERVER_IP:5000/api/ (z.B. /api/photos)"
    echo "Fotos:            http://$SERVER_IP:5000/photos/<dateiname.jpg>"
    echo "------------------------------------------------------------"
    echo "Hinweis: Die ermittelte IP-Adresse ist ggf. nur im lokalen Netzwerk gültig."
}

# --- Update-Funktion ---
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
    cd "$PROJECT_DIR"
    git config --global --add safe.directory "$PROJECT_DIR"
    if [ -d .git ]; then
        echo "  → Repository wird aktualisiert ..."
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
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
    if [ -f "$PROJECT_DIR/conf/nginx-fotobox.conf" ]; then
        cp "$PROJECT_DIR/conf/nginx-fotobox.conf" /etc/nginx/sites-available/fotobox
        ln -sf /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox
        systemctl restart nginx > /dev/null
    else
        echo "Warnung: $PROJECT_DIR/conf/nginx-fotobox.conf nicht gefunden! NGINX-Konfiguration wurde nicht aktualisiert."
    fi
    systemctl restart fotobox-backend > /dev/null 2>&1 || true
    if [ ! -f "$PROJECT_DIR/backend/fotobox_settings.db" ]; then
        ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'); con.close()" > /dev/null
    fi
    echo "Update abgeschlossen. Backup der vorherigen Version liegt unter: $BACKUP_DIR"
}

# --- Deinstallations-Funktion ---
remove_fotobox() {
    echo "[Remove] Deinstallation und Rücksicherung werden durchgeführt ..."
    LATEST_BACKUP=$(ls -dt $PROJECT_DIR/backup-* 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        echo "  → Systemdateien werden aus Backup wiederhergestellt ..."
        if [ -f "$LATEST_BACKUP/nginx-fotobox.conf.bak" ]; then
            cp "$LATEST_BACKUP/nginx-fotobox.conf.bak" /etc/nginx/sites-available/fotobox
        fi
        if [ -f "$LATEST_BACKUP/nginx-fotobox.link.bak" ]; then
            cp "$LATEST_BACKUP/nginx-fotobox.link.bak" /etc/nginx/sites-enabled/fotobox
        fi
        if [ -f "$LATEST_BACKUP/nginx-default.link.bak" ]; then
            cp "$LATEST_BACKUP/nginx-default.link.bak" /etc/nginx/sites-enabled/default
        fi
        if [ -f "$LATEST_BACKUP/fotobox-backend.service.bak" ]; then
            cp "$LATEST_BACKUP/fotobox-backend.service.bak" /etc/systemd/system/fotobox-backend.service
        fi
        systemctl daemon-reload > /dev/null
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

# --- Hauptablauf ---
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
