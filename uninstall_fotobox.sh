#!/bin/bash
# Deinstallationsskript für MyFotoBox
# Entfernt alle Projektdateien, Systemd-Service und NGINX-Konfiguration
# Stellt vorherige Systemdateien aus Backup wieder her
# Ausführen als root: sudo bash uninstall_fotobox.sh

set -e

# Backup-Verzeichnis suchen (jüngstes verwenden)
PROJECT_DIR="/opt/fotobox"
LATEST_BACKUP=$(ls -dt $PROJECT_DIR/backup-* 2>/dev/null | head -1)

if [ -n "$LATEST_BACKUP" ]; then
    echo "Stelle Systemdateien aus Backup wieder her: $LATEST_BACKUP"
    # NGINX-Konfiguration zurückspielen
    if [ -f "$LATEST_BACKUP/nginx-fotobox.conf.bak" ]; then
        cp "$LATEST_BACKUP/nginx-fotobox.conf.bak" /etc/nginx/sites-available/fotobox
    fi
    if [ -f "$LATEST_BACKUP/nginx-fotobox.link.bak" ]; then
        cp "$LATEST_BACKUP/nginx-fotobox.link.bak" /etc/nginx/sites-enabled/fotobox
    fi
    if [ -f "$LATEST_BACKUP/nginx-default.link.bak" ]; then
        cp "$LATEST_BACKUP/nginx-default.link.bak" /etc/nginx/sites-enabled/default
    fi
    # systemd-Service zurückspielen
    if [ -f "$LATEST_BACKUP/fotobox-backend.service.bak" ]; then
        cp "$LATEST_BACKUP/fotobox-backend.service.bak" /etc/systemd/system/fotobox-backend.service
    fi
    systemctl daemon-reload
    systemctl restart nginx
fi

PROJECT_DIR="/opt/fotobox"
NGINX_CONF="/etc/nginx/sites-available/fotobox"
NGINX_LINK="/etc/nginx/sites-enabled/fotobox"
SERVICE_FILE="/etc/systemd/system/fotobox-backend.service"
BACKUP_DIR="/opt/fotobox-backup-$(date +%Y%m%d%H%M%S)"

# Backup anlegen
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

# Systemd-Service stoppen und entfernen
if systemctl is-active --quiet fotobox-backend; then
    systemctl stop fotobox-backend
fi
if systemctl is-enabled --quiet fotobox-backend; then
    systemctl disable fotobox-backend
fi
rm -f "$SERVICE_FILE"
systemctl daemon-reload

# NGINX-Konfiguration entfernen
rm -f "$NGINX_CONF" "$NGINX_LINK"
if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "Standard-NGINX-Seite bleibt erhalten."
fi
systemctl restart nginx

# Projektverzeichnis entfernen
rm -rf "$PROJECT_DIR"

# Abschlussmeldung
cat <<EOM
Deinstallation abgeschlossen.
Alle Projektdateien und Konfigurationen wurden entfernt.
Backups der entfernten Dateien finden Sie unter:
  $BACKUP_DIR

Bitte prüfen Sie ggf. manuell, ob weitere benutzerdefinierte Einstellungen entfernt werden müssen.
EOM
