#!/bin/bash
# -----------------------------------------------------------------------------
# prepare_install.sh - Vorbereitungsskript für die Fotobox-Installation
# -----------------------------------------------------------------------------
# Dieses Skript führt die notwendigen Vorbereitungsschritte für die Installation
# der Fotobox durch: Repository klonen, Installationsskript ausführbar machen.
# -----------------------------------------------------------------------------
# Autor: [Ihr Name]
# Datum: $(date +%d.%m.%Y)
# Lizenz: MIT (siehe LICENSE)
# -----------------------------------------------------------------------------

# Farben für Ausgaben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zum Anzeigen von Erfolgsmeldungen
print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

# Funktion zum Anzeigen von Fehlermeldungen
print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Funktion zum Anzeigen von Informationen
print_info() {
    echo -e "${BLUE}[i] $1${NC}"
}

# Funktion zum Anzeigen von Warnungen
print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Prüfen, ob das Skript mit Root-Rechten ausgeführt wird
if [ "$(id -u)" -ne 0 ]; then
    print_error "Dieses Skript muss mit Root-Rechten ausgeführt werden."
    print_info "Bitte mit 'sudo' erneut ausführen: sudo $0"
    exit 1
fi

# Konfigurationsvariablen
INSTALL_DIR="/opt/fotobox"

echo "====================== Fotobox - Installationsvorbereitung ======================"
echo "                 Dieses Skript bereitet die Installation vor."
echo "================================================================================="

# Prüfen, ob das Zielverzeichnis bereits existiert
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Das Verzeichnis $INSTALL_DIR existiert bereits."
    
    # Nachfragen, ob das Verzeichnis überschrieben werden soll
    read -p "Möchten Sie fortfahren und das Verzeichnis überschreiben? [j/N] " answer
    
    if [[ "$answer" != [jJ] ]]; then
        print_info "Installation abgebrochen."
        exit 0
    else
        print_info "Bestehende Installation wird gelöscht..."
        rm -rf "$INSTALL_DIR"
    fi
fi

# Schritt 1: Repository klonen
print_info "Klone Repository nach $INSTALL_DIR..."
git clone https://github.com/DirkGoetze/MyFotoBox.git "$INSTALL_DIR"

# Prüfen, ob das Klonen erfolgreich war
if [ $? -ne 0 ]; then
    print_error "Fehler beim Klonen des Repositories."
    print_error "Bitte stellen Sie sicher, dass Git installiert ist und die URL korrekt ist."
    exit 1
else
    print_success "Repository erfolgreich geklont."
fi

# Schritt 2: Installationsskript ausführbar machen
print_info "Mache das Installationsskript ausführbar..."
chmod +x "$INSTALL_DIR/install.sh"

if [ $? -ne 0 ]; then
    print_error "Fehler beim Ändern der Ausführungsberechtigung."
    exit 1
else
    print_success "Installationsskript ist jetzt ausführbar."
fi

# Bildschirm bereinigen
clear

print_success "Vorbereitung abgeschlossen!"
print_success "Das Fotobox-Repository wurde erfolgreich nach $INSTALL_DIR geklont."
print_success "Das Installationsskript ist nun ausführbar."
echo ""
print_info "Sie können die Installation jetzt mit folgendem Befehl starten:"
echo ""
echo "   sudo $INSTALL_DIR/install.sh"
echo ""
print_warning "Hinweis: Die Installation muss mit Root-Rechten ausgeführt werden."

exit 0
