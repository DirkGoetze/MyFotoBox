#!/bin/bash
# Installationsskript für Fotobox-Projekt mit NGINX und Python-Backend
# Für Ubuntu/Debian-basierte Systeme
# Ausführen als root: sudo bash install_fotobox.sh

set -e

# 1. Notwendige Pakete installieren
apt update
apt install -y nginx python3 python3-pip git

# 2. Projekt von GitHub klonen (URL ggf. anpassen)
PROJECT_DIR="/opt/fotobox"
REPO_URL="https://github.com/DirkGoetze/fotobox2.git" # <--- ANPASSEN!
if [ ! -d "$PROJECT_DIR" ]; then
    git clone "$REPO_URL" "$PROJECT_DIR"
else
    echo "Projektverzeichnis existiert bereits."
fi

# 3. Python-Abhängigkeiten installieren
cd "$PROJECT_DIR/backend"
pip3 install -r requirements.txt

# 4. NGINX-Konfiguration bereitstellen
cp "$PROJECT_DIR/nginx-fotobox.conf" /etc/nginx/sites-available/fotobox
ln -sf /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# 5. (Optional) systemd-Service für Backend anlegen
SERVICE_FILE="/etc/systemd/system/fotobox-backend.service"
if [ ! -f "$SERVICE_FILE" ]; then
cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=Fotobox Backend (Flask)
After=network.target

[Service]
User=www-data
WorkingDirectory=$PROJECT_DIR/backend
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL
    systemctl daemon-reload
    systemctl enable --now fotobox-backend
fi

echo "Fotobox-Frontend ist jetzt über NGINX erreichbar. Backend läuft als Service."
