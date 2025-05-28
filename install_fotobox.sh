#!/bin/bash
# Installationsskript für Fotobox-Projekt mit NGINX und Python-Backend
# Für Ubuntu/Debian-basierte Systeme
# Ausführen als root: sudo bash install_fotobox.sh

set -e

# 1. Notwendige Pakete installieren
apt update
apt install -y nginx python3 python3-pip python3.11-venv git

# 2. Projekt von GitHub klonen (URL ggf. anpassen)
PROJECT_DIR="/opt/fotobox"
REPO_URL="https://github.com/DirkGoetze/fotobox2.git" # <--- ANPASSEN!

# Interaktiver Dialog für User und Gruppe
read -p "Bitte geben Sie den gewünschten System-User für die Fotobox ein [www-data]: " input_user
FOTOBOX_USER=${input_user:-www-data}
read -p "Bitte geben Sie die gewünschte System-Gruppe für die Fotobox ein [www-data]: " input_group
FOTOBOX_GROUP=${input_group:-www-data}

# User anlegen, falls nicht vorhanden
if ! id -u "$FOTOBOX_USER" &>/dev/null
then
    echo "User $FOTOBOX_USER existiert nicht. Erstelle User..."
    adduser --system --no-create-home "$FOTOBOX_USER"
fi
# Gruppe anlegen, falls nicht vorhanden
if ! getent group "$FOTOBOX_GROUP" &>/dev/null
then
    echo "Gruppe $FOTOBOX_GROUP existiert nicht. Erstelle Gruppe..."
    addgroup "$FOTOBOX_GROUP"
fi

# Überprüfen, ob das Projektverzeichnis bereits existiert
if [ ! -d "$PROJECT_DIR" ]; then
    git clone "$REPO_URL" "$PROJECT_DIR"
else
    echo "Projektverzeichnis existiert bereits."
fi

# Besitzrechte anpassen
chown -R "$FOTOBOX_USER":"$FOTOBOX_GROUP" "$PROJECT_DIR"

# 3. Python-Abhängigkeiten in venv installieren
cd "$PROJECT_DIR/backend"
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

# Backup-Verzeichnis anlegen (mit Zeitstempel)
BACKUP_DIR="$PROJECT_DIR/backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Vorhandene NGINX-Konfiguration sichern
if [ -f /etc/nginx/sites-available/fotobox ]; then
    cp /etc/nginx/sites-available/fotobox "$BACKUP_DIR/nginx-fotobox.conf.bak"
fi
if [ -L /etc/nginx/sites-enabled/fotobox ]; then
    cp --remove-destination /etc/nginx/sites-enabled/fotobox "$BACKUP_DIR/nginx-fotobox.link.bak"
fi
# Standard-NGINX-Seite sichern
if [ -f /etc/nginx/sites-enabled/default ]; then
    cp /etc/nginx/sites-enabled/default "$BACKUP_DIR/nginx-default.link.bak"
fi
# Vorhandene systemd-Service-Datei sichern
if [ -f /etc/systemd/system/fotobox-backend.service ]; then
    cp /etc/systemd/system/fotobox-backend.service "$BACKUP_DIR/fotobox-backend.service.bak"
fi

# README.md ins documentation-Verzeichnis verschieben
if [ -f "$PROJECT_DIR/README.md" ]; then
    mkdir -p "$PROJECT_DIR/documentation"
    mv "$PROJECT_DIR/README.md" "$PROJECT_DIR/documentation/README.md"
fi
# nginx-fotobox.conf in conf-Verzeichnis verschieben
if [ -f "$PROJECT_DIR/nginx-fotobox.conf" ]; then
    mkdir -p "$PROJECT_DIR/conf"
    mv "$PROJECT_DIR/nginx-fotobox.conf" "$PROJECT_DIR/conf/nginx-fotobox.conf"
fi

# 4. NGINX-Konfiguration bereitstellen
cp "$PROJECT_DIR/conf/nginx-fotobox.conf" /etc/nginx/sites-available/fotobox
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
User=$FOTOBOX_USER
WorkingDirectory=$PROJECT_DIR/backend
ExecStart=$PROJECT_DIR/backend/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL
    systemctl daemon-reload
    systemctl enable --now fotobox-backend
fi

# IP-Adresse des Servers ermitteln (erste nicht-loopback IPv4-Adresse)
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "Fotobox-Frontend ist jetzt über NGINX erreichbar. Backend läuft als Service."
echo "------------------------------------------------------------"
echo "Zugriff auf die Fotobox:"
echo "Frontend:  http://$SERVER_IP/start.html (bzw. index.html)"
echo "Backend-API:  http://$SERVER_IP:5000/api/ (z.B. /api/photos)"
echo "Fotos:  http://$SERVER_IP:5000/photos/<dateiname.jpg>"
echo "------------------------------------------------------------"
echo "Hinweis: Die ermittelte IP-Adresse ist ggf. nur im lokalen Netzwerk gültig."
