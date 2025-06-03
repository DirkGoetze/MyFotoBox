#!/bin/bash
# ------------------------------------------------------------------------------
# install_fotobox.sh
# ------------------------------------------------------------------------------
# Funktion: Führt die Erstinstallation der Fotobox durch (Systempakete, User, Grundstruktur)
# Für Ubuntu/Debian-basierte Systeme, muss als root ausgeführt werden.
# Nach erfolgreicher Installation erfolgt die weitere Verwaltung (Update, Deinstallation)
# über die WebUI bzw. Python-Skripte im backend/.
# ------------------------------------------------------------------------------
# HINWEIS: Die Backup-/Restore-Strategie ist verbindlich in BACKUP_STRATEGIE.md 
# dokumentiert und für alle neuen Features, API-Endpunkte und System-
# integrationen einzuhalten.
# ------------------------------------------------------------------------------

set -e

# ------------------------------------------------------------------------------
# TODO: Verbesserungen und Optimierungen für zukünftige Versionen
# ------------------------------------------------------------------------------
# [ ] Optionale Firewall-Konfiguration (z.B. ufw) für den gewählten Port
# [ ] Automatische HTTPS-Konfiguration (Let's Encrypt)
# [ ] Fortschrittsanzeige für lange Operationen (z.B. git clone, pip install)
# [ ] Optionale E-Mail-Benachrichtigung nach erfolgreicher Installation
# [ ] Mehrsprachige Installationsausgabe (DE/EN)
# [ ] Optionale Installation als Docker-Container
# [ ] Automatische Prüfung der Erreichbarkeit der Weboberfläche nach der 
#     Installation (z.B. per curl) und Ausgabe einer entsprechenden 
#     Erfolgsmeldung oder eines Hinweises zur Fehlerbehebung
# ------------------------------------------------------------------------------

# ===========================================================================
# Globale Konstanten
# ===========================================================================
# ---------------------------------------------------------------------------
# Projekt Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_TOOLS=(git lsof)
GIT_REPO_URL="https://github.com/DirkGoetze/MyFotoBox.git"
INSTALL_DIR="/opt/fotobox"
README_MAIN="# fotobox\nDies ist das Hauptverzeichnis der Fotobox-Installation. Es enthält alle relevanten Unterverzeichnisse, Konfigurationen und Daten."
BACKUP_DIR="$INSTALL_DIR/backup"
README_BACKUP="# backup\nDieses Verzeichnis wird automatisch durch die Installations- und Update-Skripte erzeugt und enthält Backups von Konfigurationsdateien und Logs. Es ist nicht Teil des Repositorys."
CONF_DIR="$INSTALL_DIR/conf"
README_CONF="# conf\nDieses Verzeichnis enthält alle Konfigurationsdateien der Fotobox. Es wird automatisch angelegt und ist nicht Teil des Repositorys."
# ---------------------------------------------------------------------------
# NGINX Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_NGINX=(nginx)
NGINX_CONF="$CONF_DIR/nginx-fotobox.conf"
SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"
NGINX_DST="/etc/nginx/sites-available/fotobox"
FOTOBOX_PORT=80
SYSTEMD_DST="/etc/systemd/system/fotobox-backend.service"
# ---------------------------------------------------------------------------
# Python Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_PYTHON=(python3 python3-venv python3-pip)
# ---------------------------------------------------------------------------
# SQLite Einstellungen
# ---------------------------------------------------------------------------
PACKAGES_SQLITE=(sqlite3)
DATA_DIR="$INSTALL_DIR/data"
README_DATA="# data\nDieses Verzeichnis enthält die persistenten Daten der Fotobox (z.B. SQLite-Datenbank, Fotos, Einstellungen). Es wird automatisch angelegt und ist nicht Teil des Repositorys."

# ==========================================================================='
# Hilfsfunktionen
# ==========================================================================='

check_script_location() {
    # -----------------------------------------------------------------------
    # check_script_location
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das Skript im Zielverzeichnis ($INSTALL_DIR) liegt
    # ......... und bricht mit Fehler ab, falls ja (Self-Overwrite-Schutz 
    # ......... für git clone)
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    if [ "$script_dir" = "$INSTALL_DIR" ]; then
        echo "[ERROR] Das Installationsskript darf nicht direkt im Zielverzeichnis ($INSTALL_DIR) ausgeführt werden!"
        echo "Bitte das Skript z.B. aus dem Home- oder einem temporären Verzeichnis starten."
        exit 99
    fi
}

chk_is_root() {
    # -----------------------------------------------------------------------
    # chk_is_root
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das Skript als root ausgeführt wird
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
    return 0
}

chk_distribution() {
    # -----------------------------------------------------------------------
    # chk_distribution
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das System auf Debian/Ubuntu basiert
    if [ ! -f /etc/os-release ]; then
        return 1
    fi
    . /etc/os-release
    if [[ ! "$ID" =~ ^(debian|ubuntu|raspbian)$ && ! "$ID_LIKE" =~ (debian|ubuntu) ]]; then
        return 1
    fi
    return 0
}

make_dir() {
    # -----------------------------------------------------------------------
    # make_dir
    # -----------------------------------------------------------------------
    # Funktion: Legt ein Verzeichnis an, falls es nicht existiert
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = kein Verzeichnis angegeben
    local dir="$1"

    # Kein Verzeichnis angegeben
    if [ -z "$dir" ]; then return 2; fi

    # Prüfe, ob das Verzeichnis bereits existiert
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        if [ ! -d "$dir" ]; then return 1; fi
    fi

    return 0
}

install_package() {
    # -----------------------------------------------------------------------
    # install_package
    # -----------------------------------------------------------------------
    # Funktion: Installiert ein einzelnes Systempaket in gewünschter Version
    # ......... (optional, prüft Version und installiert ggf. gezielt)
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Version installiert, nicht passend
    # Parameter: $1 = Paketname, $2 = Version (optional)
    # Extras...: Nutzt apt-get, prüft nach Installation erneut
    local pkg="$1"
    local version="$2"

    if [ -n "$version" ]; then
        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        if [ "$installed_version" = "$version" ]; then
            return 0
        elif [ -n "$installed_version" ]; then
            return 2
        fi
        apt-get install -y -qq "$pkg=$version" >/dev/null 2>&1
    else
        if dpkg -l | grep -q "^ii  $pkg "; then
            return 0
        fi
        apt-get install -y -qq "$pkg" >/dev/null 2>&1
    fi

    if [ -n "$version" ]; then
        local new_version
        new_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        if [ "$new_version" = "$version" ]; then
            return 0
        else
            return 1
        fi
    else
        if dpkg -l | grep -q "^ii  $pkg "; then
            return 0
        else
            return 1
        fi
    fi
}

install_package_group() {
    # -----------------------------------------------------------------------
    # install_package_group
    # -----------------------------------------------------------------------
    # Funktion: Installiert alle Pakete einer übergebenen Gruppe
    # Parameter: $1 = Array-Name (z.B. PACKAGES_NGINX)
    # Rückgabe: 0 = OK, 1 = Fehler, 2 = Version installiert, nicht passend
    # Extras...: Ruft install_package für jedes Element auf, prüft Versionen
    local group_name="$1[@]"
    local group=("${!group_name}")

    for entry in "${group[@]}"; do
        local pkg
        local version
        if [[ "$entry" == *=* ]]; then
            pkg="${entry%%=*}"
            version="${entry#*=}"
        else
            pkg="$entry"
            version=""
        fi
        install_package "$pkg" "$version"
        result=$?
        if [ $result -eq 0 ]; then
            print_success "$pkg${version:+ ($version)} ist bereits installiert."
        elif [ $result -eq 2 ]; then
            local installed_version
            installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
            print_error "$pkg ist in Version $installed_version installiert, benötigt wird $version."
            if [ "$UNATTENDED" -eq 1 ]; then
                upgrade="n"
                log "Automatische Antwort (unattended) auf Upgrade-Rückfrage: $upgrade"
            else
                print_prompt "Soll $pkg auf Version $version aktualisiert werden? [j/N]"
                read -r upgrade
            fi
            if [[ "$upgrade" =~ ^([jJ]|[yY])$ ]]; then
                apt-get install -y -qq "$pkg=$version"
                local new_version
                new_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
                if [ "$new_version" = "$version" ]; then
                    print_success "$pkg wurde erfolgreich auf $version aktualisiert."
                else
                    print_error "$pkg konnte nicht auf $version aktualisiert werden!"
                    exit 1
                fi
            else
                print_error "Installation abgebrochen, da $pkg nicht in passender Version installiert ist."
                exit 1
            fi
        else
            print_error "Das Programm $pkg${version:+ ($version)} konnte nicht installiert werden!"
            exit 1
        fi
    done
}

# ===========================================================================
# Einstellungen (Systemanpassungen)
# ===========================================================================

set_install_packages() {
    # -----------------------------------------------------------------------
    # set_install_packages
    # -----------------------------------------------------------------------
    # Funktion: Installiert alle benötigten Systempakete (ohne NGINX) und 
    # ........  prüft den Erfolg
    # Rückgabe: 0 = OK, 1 = Fehler bei apt-get update, 2 = Fehler Tools,
    # ......... 3 = Fehler Python-Pakete, 4 = Fehler SQLite
    apt-get update -qq || return 1
    install_package_group PACKAGES_TOOLS || return 2
    install_package_group PACKAGES_PYTHON || return 3
    install_package_group PACKAGES_SQLITE || return 4
    return 0
}

set_user_group() {
    # -----------------------------------------------------------------------
    # set_user_group
    # -----------------------------------------------------------------------
    # Funktion: Legt Benutzer und Gruppe 'fotobox' an, prüft Rechte
    # Rückgabe: 0 = OK, 1 = Fehler Benutzer, 2 = Fehler Gruppe, 
    # ........  3 = Fehler Gruppenzuordnung
    if ! id -u fotobox &>/dev/null; then
        useradd -m fotobox || return 1
    fi
    if ! getent group fotobox &>/dev/null; then
        groupadd fotobox || return 2
    fi
    if ! id -nG fotobox | grep -qw fotobox; then
        usermod -aG fotobox fotobox || return 3
    fi
    return 0
}

set_structure() {
    # -----------------------------------------------------------------------
    # set_structure
    # -----------------------------------------------------------------------
    # Funktion: Erstellt alle benötigten Verzeichnisse, klont das Projekt 
    # ......... per git (wenn nötig), legt Backup- und Datenverzeichnis an
    # ......... und setzt die notwendigen Rechte
    # Rückgabe: 0 = OK, 1 = Fehler Installationsverzeichnis, 
    # ......... 2 = Fehler git, 3 = Fehler git clone,
    # ......... 4 = Fehler Backup, 5 = Fehler Konfiguration, 
    # ......... 6 = Fehler Daten, 7 = Fehler Rechte
    if [ ! -d "$INSTALL_DIR" ]; then
        make_dir "$INSTALL_DIR" || return 1
    fi
    echo "DEBUG: Inhalt von $INSTALL_DIR vor Prüfung auf Projektstruktur:"
    ls -la "$INSTALL_DIR"
    if [ ! -d "$INSTALL_DIR/backend" ]; then
        echo "DEBUG: Starte git clone, da backend/ nicht existiert"
        if ! command -v git >/dev/null 2>&1; then
            apt-get update -qq && apt-get install -y -qq git || return 2
        fi
        git clone "$GIT_REPO_URL" "$INSTALL_DIR" || return 3
    fi
    if ! make_dir "$BACKUP_DIR"; then
        return 4
    fi
    if ! make_dir "$CONF_DIR"; then
        return 5
    fi
    if ! make_dir "$DATA_DIR"; then
        return 6
    fi
    chown -R fotobox:fotobox "$INSTALL_DIR" || return 7
    return 0
}

# set_systemd_service
# ------------------------------------------------------------------------------
# Funktion: Erstellt oder kopiert die systemd-Service-Datei für das Backend
# Rückgabe: keine (Seitenwirkung: legt Datei an, gibt Erfolgsmeldung aus)
set_systemd_service() {
    if [ ! -f "$SYSTEMD_SERVICE" ]; then
        cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Fotobox Backend (Flask)
After=network.target

[Service]
Type=simple
User=fotobox
WorkingDirectory=$INSTALL_DIR/backend
ExecStart=$INSTALL_DIR/backend/venv/bin/python app.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        print_success "Standard-Service-Datei erzeugt: $SYSTEMD_SERVICE"
    fi
}

# set_systemd_install
# ------------------------------------------------------------------------------
# Funktion: Kopiert systemd-Service-Datei und startet Service
# Rückgabe: keine (Seitenwirkung: kopiert, startet und aktiviert Service)
set_systemd_install() {
    local backup="$BACKUP_DIR/fotobox-backend.service.bak.$(date +%Y%m%d%H%M%S)"
    if [ -f "$SYSTEMD_DST" ]; then
        cp "$SYSTEMD_DST" "$backup"
        print_success "Backup der bestehenden systemd-Unit nach $backup"
    fi
    cp "$SYSTEMD_SERVICE" "$SYSTEMD_DST"
    systemctl daemon-reload
    systemctl enable fotobox-backend
    systemctl restart fotobox-backend
    print_success "systemd-Service installiert und gestartet."
}

# ===========================================================================
# Dialogfunktionen
# ===========================================================================

dlg_check_root() {
    # -----------------------------------------------------------------------
    # dlg_check_root
    # -----------------------------------------------------------------------
    # Funktion: Dialog für Root-Check, gibt Fehler aus und bricht ggf. ab
    print_step "[1/10] Prüfe Rechte zur Ausführung ..."
    if ! chk_is_root; then
        print_error "Bitte das Skript als root ausführen."
        exit 1
    fi
    print_success "Rechteprüfung erfolgreich."
}

dlg_check_distribution() {
    # -----------------------------------------------------------------------
    # dlg_check_distribution
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das System auf Debian/Ubuntu basiert
    print_step "[2/10] Prüfe Distribution ..."
    if ! chk_distribution; then
        print_error "Dieses Skript ist nur für Debian/Ubuntu-basierte Systeme geeignet."
        exit 1
    fi
    print_success "Distribution ist Debian/Ubuntu."
}

dlg_prepare_system() {
    # -----------------------------------------------------------------------
    # dlg_prepare_system
    # -----------------------------------------------------------------------
    # Funktion: Prüft installiert Pakete (ohne NGINX)
    print_step "[3/10] Installiere benötigte Systempakete (ohne NGINX) ..."
    set_install_packages
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Fehler bei apt-get update. Prüfen Sie Ihre Internetverbindung und Paketquellen."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler bei der Installation der Tools (git, lsof)."
        exit 1
    elif [ $rc -eq 3 ]; then
        print_error "Fehler bei der Installation der Python-Pakete."
        exit 1
    elif [ $rc -eq 4 ]; then
        print_error "Fehler bei der Installation von SQLite."
        exit 1
    elif [ $rc -ne 0 ]; then
        print_error "Unbekannter Fehler bei der Systempaket-Installation (Code $rc)."
        exit 1
    fi
    print_success "Systempakete (ohne NGINX) wurden erfolgreich installiert."
}

dlg_prepare_users() {
    # -----------------------------------------------------------------------
    # dlg_prepare_users
    # -----------------------------------------------------------------------
    # Funktion: Erstellen des Benutzer und der Gruppe 'fotobox'
    print_step "[4/10] Prüfe und lege Benutzer/Gruppe an ..."
    set_user_group
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Fehler beim Anlegen des Benutzers 'fotobox'."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler beim Anlegen der Gruppe 'fotobox'."
        exit 1
    elif [ $rc -eq 3 ]; then
        print_error "Fehler beim Hinzufügen des Benutzers zur Gruppe."
        exit 1
    elif [ $rc -ne 0 ]; then
        print_error "Unbekannter Fehler beim Anlegen von Benutzer/Gruppe (Code $rc)."
        exit 1
    fi
    print_success "Benutzer und Gruppe 'fotobox' wurden erfolgreich angelegt."
}

dlg_prepare_structure() {
    # -----------------------------------------------------------------------
    # dlg_prepare_structure
    # -----------------------------------------------------------------------
    # Funktion: Prüfen/Erstellen der Verzeichnisstruktur, Klonen des Projekt
    # Rechte setzem
    print_step "[5/10] Erstelle Verzeichnisstruktur und setze Rechte ..."
    set_structure
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Verzeichnis $INSTALL_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler beim Nachinstallieren von git."
        exit 1
    elif [ $rc -eq 3 ]; then
        print_error "Fehler beim Klonen des Projekts per git."
        exit 1
    elif [ $rc -eq 4 ]; then
        print_error "Backup-Verzeichnis $BACKUP_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 5 ]; then
        print_error "Konfigurationsverzeichnis $CONF_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 6 ]; then
        print_error "Datenverzeichnis $DATA_DIR konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 7 ]; then
        print_error "Rechte für $INSTALL_DIR konnten nicht gesetzt werden!"
        exit 1
    elif [ $rc -ne 0 ]; then
        print_error "Unbekannter Fehler bei der Verzeichnisstruktur (Code $rc)."
        exit 1
    fi
    print_success "Verzeichnisstruktur wurde erfolgreich erstellt."
}

dlg_nginx_installation() {
    # -----------------------------------------------------------------------
    # dlg_nginx_installation
    # -----------------------------------------------------------------------
    # Funktion: Führt die vollständige NGINX-Installation/Integration durch
    #           (nur noch zentrale Logik via manage_nginx.sh)
    # Rückgabe: 0 = OK, !=0 = Fehler
    # ------------------------------------------------------------------------------
    print_step "[6/10] NGINX-Installation und Konfiguration ..."

    # Prüfen, ob manage_nginx.sh existiert
    if [ ! -f "$INSTALL_DIR/backend/scripts/manage_nginx.sh" ]; then
        print_error "manage_nginx.sh nicht gefunden! Die Projektstruktur wurde vermutlich noch nicht geklont."
        exit 1
    fi

    # NGINX-Installation prüfen/ausführen (zentral)
    if [ "$UNATTENDED" -eq 1 ]; then
        install_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json install)
        install_rc=$?
    else
        install_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" install)
        install_rc=$?
    fi
    if [ $install_rc -ne 0 ]; then
        print_error "NGINX-Installation fehlgeschlagen: $install_result"
        exit 1
    fi

    # Betriebsmodus abfragen (default/multisite)
    if [ "$UNATTENDED" -eq 1 ]; then
        activ_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json activ)
        activ_rc=$?
    else
        activ_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" activ)
        activ_rc=$?
    fi
    if [ $activ_rc -eq 2 ]; then
        print_error "Konnte NGINX-Betriebsmodus nicht eindeutig ermitteln. Bitte prüfen Sie die Konfiguration."
        exit 1
    fi

    # Dialog: Default-Integration oder eigene Konfiguration
    if [ $activ_rc -eq 0 ]; then
        if [ "$UNATTENDED" -eq 1 ]; then
            antwort="j"
            log "Automatische Antwort (unattended) auf Default-Integration: $antwort"
        else
            print_prompt "NGINX läuft nur im Default-Modus. Fotobox in Default-Konfiguration integrieren? [J/n]"
            read -r antwort
        fi
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            if [ "$UNATTENDED" -eq 1 ]; then
                antwort2="j"
                log "Automatische Antwort (unattended) auf eigene Konfiguration: $antwort2"
            else
                print_prompt "Stattdessen eigene Fotobox-Konfiguration anlegen? [J/n]"
                read -r antwort2
            fi
            if [[ "$antwort2" =~ ^([nN])$ ]]; then
                print_error "Abbruch: Keine NGINX-Integration gewählt."
                exit 1
            fi
            # Portwahl und externe Konfiguration (zentral)
            if [ "$UNATTENDED" -eq 1 ]; then
                port_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json setport)
                port_rc=$?
            else
                port_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" setport)
                port_rc=$?
            fi
            if [ $port_rc -ne 0 ]; then
                print_error "Portwahl/Setzen fehlgeschlagen: $port_result"
                exit 1
            fi
            if [ "$UNATTENDED" -eq 1 ]; then
                ext_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json external)
                ext_rc=$?
            else
                ext_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" external)
                ext_rc=$?
            fi
            if [ $ext_rc -eq 0 ]; then
                print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
            else
                print_error "Fehler bei externer NGINX-Konfiguration (Code $ext_rc): $ext_result"
                exit 1
            fi
        else
            # Default-Integration (zentral)
            if [ "$UNATTENDED" -eq 1 ]; then
                int_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json internal)
                int_rc=$?
            else
                int_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" internal)
                int_rc=$?
            fi
            if [ $int_rc -eq 0 ]; then
                print_success "Fotobox wurde in Default-Konfiguration integriert."
            else
                print_error "Fehler bei Integration in Default-Konfiguration (Code $int_rc): $int_result"
                exit 1
            fi
        fi
    elif [ $activ_rc -eq 1 ]; then
        if [ "$UNATTENDED" -eq 1 ]; then
            antwort="j"
            log "Automatische Antwort (unattended) auf eigene Konfiguration: $antwort"
        else
            print_prompt "NGINX betreibt mehrere Sites. Eigene Fotobox-Konfiguration anlegen? [J/n]"
            read -r antwort
        fi
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            print_error "Abbruch: Keine NGINX-Integration gewählt."
            exit 1
        fi
        # Portwahl und externe Konfiguration (zentral)
        if [ "$UNATTENDED" -eq 1 ]; then
            port_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json setport)
            port_rc=$?
        else
            port_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" setport)
            port_rc=$?
        fi
        if [ $port_rc -ne 0 ]; then
            print_error "Portwahl/Setzen fehlgeschlagen: $port_result"
            exit 1
        fi
        if [ "$UNATTENDED" -eq 1 ]; then
            ext_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json external)
            ext_rc=$?
        else
            ext_result=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" external)
            ext_rc=$?
        fi
        if [ $ext_rc -eq 0 ]; then
            print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
        else
            print_error "Fehler bei externer NGINX-Konfiguration (Code $ext_rc): $ext_result"
            exit 1
        fi
    fi
    return 0
}

# dlg_backend_integration
# ------------------------------------------------------------------------------
# Funktion: Richtet das Python-Backend (venv, requirements, systemd) ein und startet es
# Rückgabe: 0 = OK, !=0 = Fehler
# ------------------------------------------------------------------------------
dlg_backend_integration() {
    print_step "[Backend] Python-Umgebung und Backend-Service werden eingerichtet ..."
    # Python venv anlegen, falls nicht vorhanden
    if [ ! -d "$INSTALL_DIR/backend/venv" ]; then
        python3 -m venv "$INSTALL_DIR/backend/venv" || { print_error "Konnte venv nicht anlegen!"; exit 1; }
    fi
    # Abhängigkeiten installieren
    "$INSTALL_DIR/backend/venv/bin/pip" install --upgrade pip >/dev/null 2>&1
    "$INSTALL_DIR/backend/venv/bin/pip" install -r "$INSTALL_DIR/backend/requirements.txt" >/dev/null 2>&1 || { print_error "Konnte Python-Abhängigkeiten nicht installieren!"; exit 1; }
    # systemd-Service anlegen und starten
    set_systemd_service
    set_systemd_install
    print_success "Backend-Service wurde eingerichtet und gestartet."
    return 0
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
# Funktion: Hauptablauf der Erstinstallation
# ------------------------------------------------------------------------------
main() {
    check_script_location         # Prüfe, ob Skript im Zielverzeichnis liegt
    dlg_check_root               # Prüfe, ob Skript als root ausgeführt wird
    dlg_check_distribution       # Prüfe, ob System auf Debian/Ubuntu basiert
    dlg_prepare_system           # Installiere Systempakete und prüfe Erfolg
    dlg_prepare_users            # Erstelle Benutzer und Gruppe 'fotobox'
    dlg_prepare_structure        # Erstelle Verzeichnisstruktur, klone Projekt und setze Rechte
    dlg_nginx_installation       # NGINX-Konfiguration (Integration oder eigene Site)
    dlg_backend_integration      # Python-Backend, venv, systemd-Service, Start
    if [ "$UNATTENDED" -eq 1 ]; then
        local logfile
        logfile=$(get_log_file)
        echo "Installation abgeschlossen. Details siehe Logfile: $logfile"
        local web_url
        web_url=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" --json geturl | grep -o 'http[s]*://[^" ]*')
        echo "Weboberfläche: $web_url"
    else
        print_success "Erstinstallation abgeschlossen."
        local web_url
        web_url=$(bash "$INSTALL_DIR/backend/scripts/manage_nginx.sh" geturl)
        print_prompt "Bitte rufen Sie die Weboberfläche im Browser auf, um die Fotobox weiter zu konfigurieren und zu verwalten.\nURL: $web_url"
        echo "Weitere Wartung (Update, Deinstallation) erfolgt über die WebUI oder die Python-Skripte im backend/."
    fi
}

# ------------------------------------------------------------------------------
# UNATTENDED-Variable initialisieren, falls nicht gesetzt
: "${UNATTENDED:=0}"

# Fallback-Definitionen für Logging/Print-Funktionen (werden ggf. überschrieben)
print_step()    { echo "[STEP] $*"; }
print_error()   { echo "[ERROR] $*" >&2; }
print_success() { echo "[OK] $*"; }
print_prompt()  { echo "[PROMPT] $*"; }
log()           { :; }

# Logging-Hilfsskript einbinden (zentral für alle Fotobox-Skripte)
if [ -f "$(dirname "$0")/backend/scripts/log_helper.sh" ]; then
    source "$(dirname "$0")/backend/scripts/log_helper.sh"
else
    echo "WARNUNG: Logging-Hilfsskript nicht gefunden! Logging deaktiviert." >&2
    log() { :; }
fi

# Log-Initialisierung (Rotation) direkt nach Skriptstart 
log
# Hauptfunktion aufrufen 
main