# Installationsskript für NGINX und Projektstruktur
# Für Ubuntu/Debian-basierte Systeme

sudo apt update
sudo apt install -y nginx

# Projektverzeichnis anlegen (falls nicht vorhanden)
PROJECT_DIR="/opt/fotobox"
sudo mkdir -p $PROJECT_DIR/frontend
sudo mkdir -p $PROJECT_DIR/backend

# Beispiel: Kopieren der aktuellen Dateien (anpassen je nach Deployment)
sudo cp -r ./frontend/* $PROJECT_DIR/frontend/
sudo cp -r ./backend/* $PROJECT_DIR/backend/

# NGINX-Konfiguration bereitstellen
sudo cp ./nginx-fotobox.conf /etc/nginx/sites-available/fotobox
sudo ln -sf /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox

# Standardseite deaktivieren
sudo rm -f /etc/nginx/sites-enabled/default

# NGINX neu starten
sudo systemctl restart nginx

echo "Fotobox-Frontend ist jetzt über NGINX erreichbar."
