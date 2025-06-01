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
# print_error
# ------------------------------------------------------------------------------
# Funktion: Gibt eine Fehlermeldung farbig aus
# ------------------------------------------------------------------------------
print_error() {
    echo -e "\033[1;31m$1\033[0m"
}

# ----------------------------------------------------------------------------
# print_step
# ----------------------------------------------------------------------------
# Funktion: Gibt einen Hinweis auf einen auszuführenden Schritt in Gelb aus
# ----------------------------------------------------------------------------
print_step() {
    echo -e "\033[1;33m$1\033[0m"
}

# ----------------------------------------------------------------------------
# print_success
# ----------------------------------------------------------------------------
# Funktion: Gibt eine Erfolgsmeldung in Dunkelgrün aus
# ----------------------------------------------------------------------------
print_success() {
    echo -e "\033[1;32m$1\033[0m"
}

# ----------------------------------------------------------------------------
# print_prompt
# ----------------------------------------------------------------------------
# Funktion: Gibt eine Nutzeraufforderung in Blau aus
# ----------------------------------------------------------------------------
print_prompt() {
    echo -e "\033[1;34m$1\033[0m"
}

# ------------------------------------------------------------------------------
# check_root
# ------------------------------------------------------------------------------
# Funktion: Prüft, ob das Skript als root ausgeführt wird
# ------------------------------------------------------------------------------
check_root() {
    print_step "Prüfe, ob das Skript als root ausgeführt wird ..."
    if [ "$EUID" -ne 0 ]; then
        print_error "Bitte das Skript als root ausführen."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# check_distribution
# ------------------------------------------------------------------------------
# Funktion: Prüft, ob das System auf Debian/Ubuntu basiert
# ------------------------------------------------------------------------------
check_distribution() {
    print_step "Prüfe, ob das System auf Debian/Ubuntu basiert ..."
    if [ ! -f /etc/os-release ]; then
        print_error "Nicht unterstütztes System."
        exit 1
    fi
    . /etc/os-release
    if [[ ! "$ID" =~ ^(debian|ubuntu|raspbian)$ && ! "$ID_LIKE" =~ (debian|ubuntu) ]]; then
        print_error "Nur für Debian/Ubuntu-Systeme geeignet."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# install_packages
# ------------------------------------------------------------------------------
# Funktion: Installiert alle benötigten Systempakete und prüft Erfolg
# ------------------------------------------------------------------------------
install_packages() {
    print_step "Systempakete werden installiert ..."
    if ! apt-get update -qq; then
        print_error "Fehler bei apt-get update! Bitte prüfen Sie Ihre Internetverbindung und Paketquellen."
        exit 1
    fi
    if ! apt-get install -y -qq python3 python3-venv python3-pip nginx git sqlite3 lsof; then
        print_error "Fehler bei der Installation der Systempakete! Bitte prüfen Sie die Paketquellen."
        exit 1
    fi
    for prog in python3 python3-venv python3-pip nginx git sqlite3 lsof; do
        if ! dpkg -l | grep -q "$prog" && ! command -v "$prog" >/dev/null 2>&1; then
            print_error "Das Programm $prog konnte nicht installiert werden!"
            exit 1
        fi
    done
    print_success "Alle Systempakete wurden erfolgreich installiert."
}

# ------------------------------------------------------------------------------
# setup_user_group
# ------------------------------------------------------------------------------
# Funktion: Legt Benutzer und Gruppe 'fotobox' an, prüft Rechte
# ------------------------------------------------------------------------------
setup_user_group() {
    print_step "Prüfe, ob der Benutzer 'fotobox' und die Gruppe 'fotobox' existieren ..."
    if ! id -u fotobox &>/dev/null; then
        useradd -m fotobox
        print_success "Benutzer 'fotobox' wurde angelegt."
    else
        echo "Benutzer 'fotobox' existiert bereits."
    fi
    if ! getent group fotobox &>/dev/null; then
        groupadd fotobox
        print_success "Gruppe 'fotobox' wurde angelegt."
    fi
    # Rechte prüfen
    if ! id -nG fotobox | grep -qw fotobox; then
        usermod -aG fotobox fotobox
        print_success "Benutzer 'fotobox' zur Gruppe 'fotobox' hinzugefügt."
    fi
}

# ------------------------------------------------------------------------------
# setup_structure
# ------------------------------------------------------------------------------
# Funktion: Erstellt das Grundverzeichnis und setzt die Rechte
# ------------------------------------------------------------------------------
setup_structure() {
    print_step "Erstelle Verzeichnisstruktur und setze Rechte ..."
    mkdir -p /opt/fotobox
    chown -R fotobox:fotobox /opt/fotobox
    print_success "Verzeichnisstruktur wurde angelegt und Rechte gesetzt."
}

# ------------------------------------------------------------------------------
# backup_nginx_config
# ------------------------------------------------------------------------------
# Funktion: Sichert vorhandene NGINX-Konfiguration, falls vorhanden
# ------------------------------------------------------------------------------
backup_nginx_config() {
    print_step "Sichere vorhandene NGINX-Konfiguration ..."
    if [ -f /etc/nginx/sites-available/fotobox ]; then
        cp /etc/nginx/sites-available/fotobox "/etc/nginx/sites-available/fotobox.bak.$(date +%Y%m%d%H%M%S)"
        print_success "Vorhandene NGINX-Konfiguration wurde gesichert."
    fi
}

# ------------------------------------------------------------------------------
# check_nginx_port
# ------------------------------------------------------------------------------
# Funktion: Prüft, ob Port 80 belegt ist, schlägt ggf. alternativen Port vor
# ------------------------------------------------------------------------------
check_nginx_port() {
    print_step "Prüfe, ob Port 80 belegt ist ..."
    if lsof -i :80 | grep LISTEN > /dev/null; then
        print_error "Port 80 ist bereits belegt. Bitte passen Sie die NGINX-Konfiguration nach der Installation an (z.B. auf Port 8080)."
    fi
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
# Funktion: Hauptablauf der Erstinstallation
# ------------------------------------------------------------------------------
main() {
    check_root
    check_distribution
    install_packages
    setup_user_group
    setup_structure
    backup_nginx_config
    check_nginx_port
    print_success "Erstinstallation abgeschlossen."
    print_prompt "Bitte rufen Sie die Weboberfläche im Browser auf, um die Fotobox weiter zu konfigurieren und zu verwalten."
    echo "Weitere Wartung (Update, Deinstallation) erfolgt über die WebUI oder die Python-Skripte im backend/."
}

main