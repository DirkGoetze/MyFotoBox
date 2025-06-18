#!/bin/bash
# -----------------------------------------------------------------------------
# prepaecho "================================================================================="

# Informationen zum Installationsmodus anzeigen
if [ "$UNATTENDED" -eq 1 ]; then
    print_info "Installationsmodus: Unbeaufsichtigt (keine Benutzerinteraktion)"
    print_info "HTTP-Port: $HTTP_PORT"
    print_info "HTTPS-Port: $HTTPS_PORT"
else
    print_info "Installationsmodus: Interaktiv"
fi

# Prüfen, ob das Zielverzeichnis bereits existiert
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Das Verzeichnis $INSTALL_DIR existiert bereits."
    
    if [ "$UNATTENDED" -eq 1 ]; then
        print_info "Im unbeaufsichtigten Modus wird das Verzeichnis automatisch überschrieben."
    else
        # Nachfragen, ob das Verzeichnis überschrieben werden soll
        read -p "Möchten Sie fortfahren und das Verzeichnis überschreiben? [j/N] " answer
        
        if [[ "$answer" != [jJ] ]]; then.sh - Vorbereitungsskript für die Fotobox-Installation
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
REPO_URL="https://github.com/DirkGoetze/MyFotoBox.git"

# Unterstützte Kommandozeilenoptionen
UNATTENDED=0
HTTP_PORT=80
HTTPS_PORT=443

echo "====================== Fotobox - Installationsvorbereitung ======================"
echo "                 Dieses Skript bereitet die Installation vor."

# Funktion zum Anzeigen der Hilfe
show_help() {
    echo "Verwendung: $0 [OPTIONEN]"
    echo ""
    echo "Optionen:"
    echo "  -u, --unattended       Unbeaufsichtigter Modus (keine Benutzerinteraktion)"
    echo "  --http-port PORT       HTTP-Port für den Webserver (Standard: 80)"
    echo "  --https-port PORT      HTTPS-Port für den Webserver (Standard: 443)"
    echo "  -h, --help             Zeigt diese Hilfe an"
    echo ""
    echo "Beispiele:"
    echo "  $0 --unattended --http-port 8080"
    echo "  $0 --help"
    exit 0
}

# Kommandozeilenparameter auswerten
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--unattended)
            UNATTENDED=1
            shift
            ;;
        --http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        --https-port)
            HTTPS_PORT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_error "Unbekannte Option: $1"
            print_info "Verwenden Sie --help für weitere Informationen."
            exit 1
            ;;
    esac
done
echo "================================================================================="

# Informationen zum Installationsmodus anzeigen
if [ "$UNATTENDED" -eq 1 ]; then
    print_info "Installationsmodus: Unbeaufsichtigt (keine Benutzerinteraktion)"
    print_info "HTTP-Port: $HTTP_PORT"
    print_info "HTTPS-Port: $HTTPS_PORT"
else
    print_info "Installationsmodus: Interaktiv"
fi

# Prüfen, ob das Zielverzeichnis bereits existiert
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Das Verzeichnis $INSTALL_DIR existiert bereits."
    
    if [ "$UNATTENDED" -eq 1 ]; then
        # Im unbeaufsichtigten Modus automatisch überschreiben
        print_info "Im unbeaufsichtigten Modus wird das Verzeichnis automatisch überschrieben."
        rm -rf "$INSTALL_DIR"
    else
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
print_info "Klone Repository von $REPO_URL nach $INSTALL_DIR..."
git clone "$REPO_URL" "$INSTALL_DIR"

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

# Bei unbeaufsichtigtem Modus direkt starten
if [ "$UNATTENDED" -eq 1 ]; then
    print_info "Starte unbeaufsichtigte Installation mit folgenden Parametern:"
    print_info "- HTTP-Port: $HTTP_PORT"
    print_info "- HTTPS-Port: $HTTPS_PORT"
    
    # Umgebungsvariablen exportieren
    export HTTP_PORT
    export HTTPS_PORT
    
    # Installationsskript starten
    cd "$INSTALL_DIR" || exit 1
    ./install.sh --unattended
    
    exit $?
else
    # Bildschirm für die interaktive Zusammenfassung bereinigen
    clear
    
    print_success "Vorbereitung abgeschlossen!"
    print_success "Das Fotobox-Repository wurde erfolgreich nach $INSTALL_DIR geklont."
    print_success "Das Installationsskript ist nun ausführbar."
    echo ""
    print_info "Sie können die Installation jetzt mit folgendem Befehl starten:"
    echo ""
    echo "   sudo $INSTALL_DIR/install.sh"
    echo ""
    
    # Nachfragen, ob Installation direkt gestartet werden soll
    read -p "Möchten Sie die Installation jetzt starten? [j/N] " answer
    if [[ "$answer" =~ ^([jJ])$ ]]; then
        cd "$INSTALL_DIR" || exit 1
        ./install.sh
    else
        print_info "Installation wurde nicht gestartet. Sie können diese später mit dem obigen Befehl ausführen."
        print_warning "Hinweis: Die Installation muss mit Root-Rechten ausgeführt werden."
    fi
fi

exit 0
