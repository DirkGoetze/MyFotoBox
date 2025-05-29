#!/bin/bash
# Update-Skript für MyFotoBox
# Aktualisiert das Projekt aus dem GitHub-Repository und setzt Systemdateien korrekt
# Ausführen als root: sudo bash update_fotobox.sh

set -e

PROJECT_DIR="/opt/fotobox"
BACKUP_DIR="$PROJECT_DIR/backup-update-$(date +%Y%m%d%H%M%S)"
REPO_URL="https://github.com/DirkGoetze/fotobox2.git"

# 1. Backup der aktuellen Installation
mkdir -p "$BACKUP_DIR"
cp -r "$PROJECT_DIR/backend" "$BACKUP_DIR/" || true
cp -r "$PROJECT_DIR/frontend" "$BACKUP_DIR/" || true
if [ -f /etc/nginx/sites-available/fotobox ]; then
    cp /etc/nginx/sites-available/fotobox "$BACKUP_DIR/nginx-fotobox.conf.bak"
fi
if [ -L /etc/nginx/sites-enabled/fotobox ]; then
    cp --remove-destination /etc/nginx/sites-enabled/fotobox "$BACKUP_DIR/nginx-fotobox.link.bak"
fi
if [ -f /etc/systemd/system/fotobox-backend.service ]; then
    cp /etc/systemd/system/fotobox-backend.service "$BACKUP_DIR/fotobox-backend.service.bak"
fi

# 2. Projekt aktualisieren
# Unversionierte README.md sichern, falls vorhanden
if [ -f "$PROJECT_DIR/documentation/README.md" ]; then
    mv "$PROJECT_DIR/documentation/README.md" "$PROJECT_DIR/documentation/README.md.bak.$(date +%Y%m%d%H%M%S)"
fi
cd "$PROJECT_DIR"
git config --global --add safe.directory "$PROJECT_DIR"
if [ -d .git ]; then
    git pull origin main || git pull origin master
else
    echo "Kein Git-Repository gefunden. Klone neu."
    rm -rf "$PROJECT_DIR"
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# 3. Python-Abhängigkeiten ggf. aktualisieren
cd "$PROJECT_DIR/backend"
if [ -d venv ]; then
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r requirements.txt
else
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r requirements.txt
fi

# 4. NGINX und systemd-Service neu laden
if [ -f "$PROJECT_DIR/conf/nginx-fotobox.conf" ]; then
    cp "$PROJECT_DIR/conf/nginx-fotobox.conf" /etc/nginx/sites-available/fotobox
    ln -sf /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox
    systemctl restart nginx
else
    echo "Warnung: $PROJECT_DIR/conf/nginx-fotobox.conf nicht gefunden! NGINX-Konfiguration wurde nicht aktualisiert."
fi
systemctl restart fotobox-backend || true

# Nach dem Update: SQLite-Datenbank initialisieren, falls nicht vorhanden
if [ ! -f "$PROJECT_DIR/backend/fotobox_settings.db" ]; then
    cd "$PROJECT_DIR/backend"
    ./venv/bin/python -c "import sqlite3; con=sqlite3.connect('fotobox_settings.db'); con.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)'); con.close()"
fi

# Abschlussmeldung
cat <<EOM
Update abgeschlossen.
Backup der vorherigen Version liegt unter:
  $BACKUP_DIR

Bitte prüfen Sie nach dem Update die Funktionalität der Fotobox.
EOM
