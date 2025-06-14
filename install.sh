#!/bin/bash
# ------------------------------------------------------------------------------
# install.sh
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

# ===========================================================================
# Globale Konstanten (Vorgaben und Defaults für die Installation)
# ===========================================================================
# ---------------------------------------------------------------------------
# Einstellungen: Projekt und Repository
# ---------------------------------------------------------------------------
PACKAGES_TOOLS=(git lsof)
GIT_REPO_URL="https://github.com/DirkGoetze/MyFotoBox.git"
INSTALL_DIR="/opt/fotobox"
# ---------------------------------------------------------------------------
# Einstellungen: Ordnerstruktur
# ---------------------------------------------------------------------------
BACKUP_DIR="$INSTALL_DIR/backup"
CONF_DIR="$INSTALL_DIR/conf"
BASH_DIR="$INSTALL_DIR/backend/scripts"
LOG_DIR="$INSTALL_DIR/log"
# ---------------------------------------------------------------------------
# Einstellungen: NGINX 
# ---------------------------------------------------------------------------
PACKAGES_NGINX=(nginx)
# ---------------------------------------------------------------------------
# WICHTIG: Die Port-Konfiguration der Fotobox-Weboberfläche darf NICHT mehr
# über eine globale Variable (z.B. FOTOBOX_PORT) erfolgen. Der aktuell
# verwendete Port ist ausschließlich über die Getter-Funktion
#   get_nginx_port
# aus backend/scripts/manage_nginx.sh zu beziehen.
# Beispiel für Shell-Skripte:
#   source "$BASH_DIR/manage_nginx.sh"
#   port=$(get_nginx_port)
# Die Konfigurationspfade für NGINX werden ausschließlich über 
# manage_nginx.sh (Getter/Setter) verwaltet.
# Policy: Siehe policies/copilot-instructions.md
# ---------------------------------------------------------------------------
# Einstellungen: Backend Service 
# ---------------------------------------------------------------------------
SYSTEMD_SERVICE="$CONF_DIR/fotobox-backend.service"
SYSTEMD_DST="/etc/systemd/system/fotobox-backend.service"
# ---------------------------------------------------------------------------
# Einstellungen: Datenverzeichnis
# ---------------------------------------------------------------------------
DATA_DIR="$INSTALL_DIR/data"
# ---------------------------------------------------------------------------
# Einstellungen: Debug-Modus
# ---------------------------------------------------------------------------
DEBUG_MOD=0

# ==========================================================================='
# Hilfsfunktionen
# ==========================================================================='

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

set_fallback_security_settings() {
    # -----------------------------------------------------------------------
    # set_fallback_security_settings
    # -----------------------------------------------------------------------
    # Funktion: Setzt Fallback-Definitionen für Logging- und Print-Funktionen,
    # ......... falls diese nicht durch ein zentrales Logging-Hilfsskript 
    # ......... bereitgestellt werden. Kapselt alle sicherheitsrelevanten 
    # ......... und benutzerfreundlichen Defaults an einer zentralen Stelle.
    # .........
    # Farbgebung, Einrückung und Pfeile gemäß policies/cli_ausgabe_policy.md

    # - log: Dummy-Logger, falls kein Logging verfügbar ist
    type log &>/dev/null || log() {
        local LOG_FILE="fallback_install_$(date '+%Y-%m-%d').log"
        if [ -z "$1" ]; then
            # Keine Nachricht: Logrotation nicht implementiert im Fallback
            return
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
    }

    # - print_step: Schrittbezeichnung fett/gelb, am Zeilenanfang
    type print_step &>/dev/null || print_step()    {
        echo -e "\033[1;33m$*\033[0m"
        log "STEP: $*"
    }

    # - print_info: Information neutral, eingerückt, ohne Farbe/Tag
    type print_info &>/dev/null || print_info()    {
        echo -e "  $*"
        log "INFO: $*"
    }

    # - print_success: Erfolg grün, eingerückt, mit Pfeil und [OK]-Tag
    type print_success &>/dev/null || print_success() {
        echo -e "\033[1;32m  → [OK]\033[0m $*"
        log "SUCCESS: $*"
    }

    # - print_warning: Warnung gelb, eingerückt, mit Pfeil und Tag
    type print_warning &>/dev/null || print_warning() {
        echo -e "\033[1;33m  → [WARN]\033[0m $*"
        log "WARNING: $*"
    }
    
    # - print_error: Fehler rot, eingerückt, mit Pfeil und Tag
    type print_error &>/dev/null || print_error()   {
        echo -e "\033[1;31m  → [ERROR]\033[0m $*\033[0m" >&2
        log "ERROR: $*"
    }

    # - print_prompt: Prompt blau, Leerzeile davor und danach (nur wenn nicht unattended)
    type print_prompt &>/dev/null || print_prompt()  {
        if [ "$UNATTENDED" -eq 0 ]; then
            echo -e "\n\033[1;34m$*\033[0m\n"
        fi
        log "PROMPT: $*"
    }

}

debug_print() {
    # -----------------------------------------------------------------------
    # debug_print
    # -----------------------------------------------------------------------
    # Funktion: Gibt Debug-Ausgaben aus, wenn DEBUG_MOD=1 gesetzt ist
    # Parameter: $* = Debug-Nachricht
    # Extras...: Einheitliches Format, Policy-konform
    if [ "$DEBUG_MOD" -eq 1 ]; then
        echo -e "\033[1;35m  → [DEBUG]\033[0m $*"
        log "DEBUG: $*"
    fi
}

show_spinner() {
    # -----------------------------------------------------------------------
    # show_spinner
    # -----------------------------------------------------------------------
    # Funktion: Zeigt eine Animation, solange der übergebene Prozess läuft
    # Parameter: $1 = PID des zu überwachenden Prozesses
    # Rückgabe: keine
    local pid="$1"
    local delay=0.1
    local spinstr='|/-\\'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf " [${spinstr:$i:1}]\r"
        sleep $delay
    done
    printf "    \r"
}

make_dir() {
    # -----------------------------------------------------------------------
    # make_dir
    # -----------------------------------------------------------------------
    # Funktion: Legt ein Verzeichnis an, prüft und setzt Rechte, loggt alle Schritte
    # Rückgabe: 0 = OK, 1 = kein Verzeichnis angegeben, 2 = Fehler beim Anlegen oder Rechte setzen
    local dir="$1"
    local user="fotobox"
    local group="fotobox"
    local mode="755"

    if [ -z "$dir" ]; then
        log "make_dir: Kein Verzeichnis angegeben!"
        debug_print "make_dir: Kein Verzeichnis angegeben!"
        return 1
    fi
    if [ ! -d "$dir" ]; then
        debug_print "make_dir: $dir existiert nicht, versuche mkdir -p"
        mkdir -p "$dir"
        if [ ! -d "$dir" ]; then
            log "make_dir: Fehler beim Anlegen von $dir!"
            debug_print "make_dir: Fehler beim Anlegen von $dir!"
            return 2
        fi
        log "make_dir: Verzeichnis $dir wurde neu angelegt."
    else
        debug_print "make_dir: $dir existiert bereits."
    fi
    # Rechte prüfen und ggf. setzen
    local owner_group
    owner_group=$(stat -c '%U:%G' "$dir")
    if [ "$owner_group" != "$user:$group" ]; then
        chown "$user:$group" "$dir" || {
            log "make_dir: Fehler beim Setzen von chown $user:$group für $dir!"
            debug_print "make_dir: Fehler beim Setzen von chown $user:$group für $dir!"
            return 2
        }
        log "make_dir: chown $user:$group für $dir gesetzt."
    fi
    local perms
    perms=$(stat -c '%a' "$dir")
    if [ "$perms" != "$mode" ]; then
        chmod "$mode" "$dir" || {
            log "make_dir: Fehler beim Setzen von chmod $mode für $dir!"
            debug_print "make_dir: Fehler beim Setzen von chmod $mode für $dir!"
            return 2
        }
        log "make_dir: chmod $mode für $dir gesetzt."
    fi
    debug_print "make_dir: $dir ist vorhanden, Rechte und Eigentümer korrekt."
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

    debug_print "install_package: Prüfe $pkg $version"
    if [ -n "$version" ]; then
        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        debug_print "install_package: installierte Version von $pkg: $installed_version"
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
        debug_print "install_package: neue Version von $pkg: $new_version"
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

    debug_print "install_package_group: Starte für Gruppe $group_name"
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
        debug_print "install_package_group: Installiere $pkg $version"
        install_package "$pkg" "$version"
        result=$?
        debug_print "install_package_group: Ergebnis für $pkg: $result"
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
    # Rückgabe: 0 = OK, 1 = Fehler bei apt-get update, 2 = Fehler bei Tools-Installation,
    # ......... 3 = Fehler bei System-Requirements-Installation
    print_step "Führe apt-get update aus ..."
    (apt-get update -qq) &> "$LOG_DIR/apt_update.log" &
    show_spinner $!
    if [ $? -ne 0 ]; then
        print_error "Fehler bei apt-get update. Log-Auszug:"
        tail -n 10 "$LOG_DIR/apt_update.log"
        return 1
    fi
    install_package_group PACKAGES_TOOLS || return 2
    
    # Installiere Systempakete aus conf/requirements_system.inf
    install_system_requirements || return 3
    
    return 0
}

set_user_group() {
    # -----------------------------------------------------------------------
    # set_user_group
    # -----------------------------------------------------------------------
    # Funktion: Legt Systembenutzer und Gruppe 'fotobox' ohne Home-Verzeichnis an, prüft Rechte
    # Rückgabe: 0 = OK, 1 = Fehler Benutzer, 2 = Fehler Gruppe, 3 = Fehler Gruppenzuordnung
    if ! id -u fotobox &>/dev/null; then
        useradd -r -M -s /usr/sbin/nologin fotobox || return 1
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
    # Funktion: Erstellt alle benötigten Verzeichnisse und prüft, ob die Projektstruktur vorhanden ist.
    #           Klon-Logik wurde entfernt. Gibt Fehler aus, falls Kernverzeichnisse fehlen.
    set -e
    debug_print "set_structure: Starte mit INSTALL_DIR=$INSTALL_DIR"
    if ! make_dir "$INSTALL_DIR"; then
        debug_print "set_structure: INSTALL_DIR $INSTALL_DIR konnte nicht angelegt werden"
        return 1
    fi
    # Prüfe, ob das Backend-Verzeichnis und wichtige Dateien existieren
    if [ ! -d "$INSTALL_DIR/backend" ] || [ ! -d "$INSTALL_DIR/backend/scripts" ] || [ ! -f "$INSTALL_DIR/conf/requirements_python.inf" ]; then
        print_error "Fehler: Die Projektstruktur ist unvollständig. Bitte stellen Sie sicher, dass das Repository vollständig geklont wurde (inkl. backend/, backend/scripts/, conf/requirements_python.inf)."
        return 10
    fi
    debug_print "set_structure: Starte mit BACKUP_DIR=$BACKUP_DIR"
    if ! make_dir "$BACKUP_DIR"; then
        debug_print "set_structure: BACKUP_DIR $BACKUP_DIR konnte nicht angelegt werden"
        return 4
    fi
    debug_print "set_structure: Starte mit DATA_DIR=$DATA_DIR"
    if ! make_dir "$DATA_DIR"; then
        debug_print "set_structure: DATA_DIR $DATA_DIR konnte nicht angelegt werden"
        return 6
    fi
    debug_print "set_structure: Starte mit BASH_DIR=$BASH_DIR"
    if [ -d "$BASH_DIR" ]; then
        debug_print "set_structure: Setze Ausführbarkeitsrechte für $BASH_DIR/*.sh"
        chmod +x "$BASH_DIR"/*.sh
    fi
    debug_print "set_structure: Starte mit LOG_DIR=$LOG_DIR"
    if ! make_dir "$LOG_DIR"; then
        debug_print "set_structure: Logverzeichnis $LOG_DIR konnte nicht angelegt werden"
        return 8
    fi
    # Policy: Nach jedem schreibenden Schritt im Projektverzeichnis Rechte prüfen und ggf. korrigieren.
    # Die Rechtevergabe für einzelne Verzeichnisse erfolgt bereits in make_dir.
    # Das folgende chown -R dient als zusätzlicher Schutz, um Policy-Konformität sicherzustellen.
    chown -R fotobox:fotobox "$INSTALL_DIR" || {
        debug_print "set_structure: chown auf $INSTALL_DIR fehlgeschlagen"
        return 7
    }
    debug_print "set_structure: erfolgreich abgeschlossen"
    return 0
}

set_systemd_service() {
    # -----------------------------------------------------------------------
    # set_systemd_service
    # -----------------------------------------------------------------------
    # Funktion: Erstellt oder kopiert die systemd-Service-Datei für das Backend
    # Rückgabe: keine (Seitenwirkung: legt Datei an, gibt Erfolgsmeldung aus)

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

set_systemd_install() {
    # -----------------------------------------------------------------------
    # set_systemd_install
    # -----------------------------------------------------------------------
    # Funktion: Kopiert systemd-Service-Datei und startet Service
    # Rückgabe: keine (Seitenwirkung: kopiert, startet und aktiviert Service)

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
    # Funktion: Prüft installiert Pakete
    print_step "[3/10] Installiere benötigte Systempakete ..."
    set_install_packages
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Fehler bei apt-get update. Prüfen Sie Ihre Internetverbindung und Paketquellen."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler bei der Installation der Tools."
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
    print_success "Systempakete wurden erfolgreich installiert."
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
    elif [ $rc -eq 8 ]; then
        print_error "Logverzeichnis $INSTALL_DIR/log konnte nicht angelegt werden!"
        exit 1
    elif [ $rc -eq 10 ]; then
        print_warning "Klonen des Projekts per git fehlgeschlagen, aber Verzeichnisstruktur und Rechte wurden gesetzt.\nBitte prüfen Sie, ob das Zielverzeichnis bereits (teilweise) belegt ist oder eine abgebrochene Installation vorliegt."
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

    debug_print "dlg_nginx_installation: Starte NGINX-Dialog, UNATTENDED=$UNATTENDED, BASH_DIR=$BASH_DIR"
    # Prüfen, ob manage_nginx.sh existiert
    if [ ! -f "$BASH_DIR/manage_nginx.sh" ]; then
        debug_print "dlg_nginx_installation: manage_nginx.sh nicht gefunden unter $BASH_DIR"
        print_error "manage_nginx.sh nicht gefunden! Die Projektstruktur wurde vermutlich noch nicht geklont."
        exit 1
    fi
    # NGINX-Installation prüfen/ausführen (zentral)
    if [ "$UNATTENDED" -eq 1 ]; then
        debug_print "dlg_nginx_installation: Starte manage_nginx.sh --json install"
        install_result=$(bash "$BASH_DIR/manage_nginx.sh" --json install)
        install_rc=$?
    else
        debug_print "dlg_nginx_installation: Starte manage_nginx.sh install"
        install_result=$(bash "$BASH_DIR/manage_nginx.sh" install)
        install_rc=$?
    fi
    debug_print "dlg_nginx_installation: install_rc=$install_rc, install_result=$install_result"
    if [ $install_rc -ne 0 ]; then
        print_error "NGINX-Installation fehlgeschlagen: $install_result"
        exit 1
    fi
    # Betriebsmodus abfragen (default/multisite)
    if [ "$UNATTENDED" -eq 1 ]; then
        debug_print "dlg_nginx_installation: Starte manage_nginx.sh --json activ"
        activ_result=$(bash "$BASH_DIR/manage_nginx.sh" --json activ)
        activ_rc=$?
    else
        debug_print "dlg_nginx_installation: Starte manage_nginx.sh activ"
        activ_result=$(bash "$BASH_DIR/manage_nginx.sh" activ)
        activ_rc=$?
    fi
    debug_print "dlg_nginx_installation: activ_rc=$activ_rc, activ_result=$activ_result"
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
        debug_print "dlg_nginx_installation: Antwort auf Default-Integration: $antwort"
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            if [ "$UNATTENDED" -eq 1 ]; then
                antwort2="j"
                log "Automatische Antwort (unattended) auf eigene Konfiguration: $antwort2"
            else
                print_prompt "Stattdessen eigene Fotobox-Konfiguration anlegen? [J/n]"
                read -r antwort2
            fi
            debug_print "dlg_nginx_installation: Antwort auf eigene Konfiguration: $antwort2"
            if [[ "$antwort2" =~ ^([nN])$ ]]; then
                print_error "Abbruch: Keine NGINX-Integration gewählt."
                exit 1
            fi
            # Portwahl und externe Konfiguration (zentral, jetzt mit Schleife)
            port_rc=1
            while [ $port_rc -ne 0 ]; do
                if [ "$UNATTENDED" -eq 1 ]; then
                    debug_print "dlg_nginx_installation: Starte manage_nginx.sh --json setport 80 j (unattended)"
                    port_result=$(bash "$BASH_DIR/manage_nginx.sh" --json setport 80 j)
                    port_rc=$?
                else
                    print_prompt "Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:"
                    read -r user_port
                    if [ -z "$user_port" ]; then user_port=80; fi
                    debug_print "dlg_nginx_installation: Starte manage_nginx.sh setport $user_port N (interaktiv)"
                    port_result=$(bash "$BASH_DIR/manage_nginx.sh" setport "$user_port" N)
                    port_rc=$?
                    if [ $port_rc -ne 0 ]; then
                        print_error "Portwahl/Setzen fehlgeschlagen: $port_result"
                        print_prompt "Anderen Port wählen? [J/n]"
                        read -r retry
                        if [[ "$retry" =~ ^([nN])$ ]]; then
                            print_error "Abbruch durch Benutzer bei Portwahl."
                            exit 1
                        fi
                    fi
                fi
            done
            debug_print "dlg_nginx_installation: port_rc=$port_rc, port_result=$port_result"
            if [ "$UNATTENDED" -eq 1 ]; then
                debug_print "dlg_nginx_installation: Starte manage_nginx.sh --json external"
                ext_result=$(bash "$BASH_DIR/manage_nginx.sh" --json external)
                ext_rc=$?
            else
                debug_print "dlg_nginx_installation: Starte manage_nginx.sh external"
                ext_result=$(bash "$BASH_DIR/manage_nginx.sh" external)
                ext_rc=$?
            fi
            debug_print "dlg_nginx_installation: ext_rc=$ext_rc, ext_result=$ext_result"
            if [ $ext_rc -eq 0 ]; then
                print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
            else
                print_error "Fehler bei externer NGINX-Konfiguration (Code $ext_rc): $ext_result"
                exit 1
            fi
        else
            # Default-Integration (zentral)
            if [ "$UNATTENDED" -eq 1 ]; then
                debug_print "dlg_nginx_installation: Starte manage_nginx.sh --json internal"
                int_result=$(bash "$BASH_DIR/manage_nginx.sh" --json internal)
                int_rc=$?
            else
                debug_print "dlg_nginx_installation: Starte manage_nginx.sh internal"
                int_result=$(bash "$BASH_DIR/manage_nginx.sh" internal)
                int_rc=$?
            fi
            debug_print "dlg_nginx_installation: int_rc=$int_rc, int_result=$int_result"
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
        debug_print "dlg_nginx_installation: Antwort auf eigene Konfiguration (multisite): $antwort"
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            print_error "Abbruch: Keine NGINX-Integration gewählt."
            exit 1
        fi
        # Portwahl und externe Konfiguration (zentral)
        if [ "$UNATTENDED" -eq 1 ]; then
            debug_print "dlg_nginx_installation: Starte manage_nginx.sh --json setport"
            port_result=$(bash "$BASH_DIR/manage_nginx.sh" --json setport)
            port_rc=$?
        else
            debug_print "dlg_nginx_installation: Starte manage_nginx.sh setport"
            port_result=$(bash "$BASH_DIR/manage_nginx.sh" setport)
            port_rc=$?
        fi
        debug_print "dlg_nginx_installation: port_rc=$port_rc, port_result=$port_result"
        if [ $port_rc -ne 0 ]; then
            print_error "Portwahl/Setzen fehlgeschlagen: $port_result"
            exit 1
        fi
        if [ "$UNATTENDED" -eq 1 ]; then
            debug_print "dlg_nginx_installation: Starte manage_nginx.sh --json external"
            ext_result=$(bash "$BASH_DIR/manage_nginx.sh" --json external)
            ext_rc=$?
        else
            debug_print "dlg_nginx_installation: Starte manage_nginx.sh external"
            ext_result=$(bash "$BASH_DIR/manage_nginx.sh" external)
            ext_rc=$?
        fi
        debug_print "dlg_nginx_installation: ext_rc=$ext_rc, ext_result=$ext_result"
        if [ $ext_rc -eq 0 ]; then
            print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
        else
            print_error "Fehler bei externer NGINX-Konfiguration (Code $ext_rc): $ext_result"
            exit 1
        fi
    fi
    debug_print "dlg_nginx_installation: Dialog erfolgreich abgeschlossen"
    return 0
}

dlg_backend_integration() {
    # -----------------------------------------------------------------------
    # dlg_backend_integration
    # -----------------------------------------------------------------------
    # Funktion: Richtet das Python-Backend (venv, requirements, systemd) ein 
    # ........  und startet es
    # Rückgabe: 0 = OK, !=0 = Fehler
    # -----------------------------------------------------------------------
    print_step "[Backend] Python-Umgebung und Backend-Service werden eingerichtet ..."
    # Python venv anlegen, falls nicht vorhanden
    if [ ! -d "$INSTALL_DIR/backend/venv" ]; then
        python3 -m venv "$INSTALL_DIR/backend/venv" || { print_error "Konnte venv nicht anlegen!"; exit 1; }
    fi
    # Abhängigkeiten installieren
    print_step "Installiere/aktualisiere pip ..."
    ("$INSTALL_DIR/backend/venv/bin/pip" install --upgrade pip) &> "$LOG_DIR/pip_upgrade.log" &
    show_spinner $!
    if [ $? -ne 0 ]; then
        print_error "Fehler beim Upgrade von pip. Log-Auszug:"
        tail -n 10 "$LOG_DIR/pip_upgrade.log"
        exit 1
    fi
    print_step "Installiere Python-Abhängigkeiten ... (inkl. bcrypt für sichere Passwörter)"
    ("$INSTALL_DIR/backend/venv/bin/pip" install -r "$INSTALL_DIR/conf/requirements_python.inf") &> "$LOG_DIR/pip_requirements.log" &
    show_spinner $!
    if [ $? -ne 0 ]; then
        print_error "Konnte Python-Abhängigkeiten nicht installieren! Log-Auszug:"
        tail -n 10 "$LOG_DIR/pip_requirements.log"
        exit 1
    fi
    # systemd-Service anlegen und starten
    set_systemd_service
    set_systemd_install
    print_success "Backend-Service wurde eingerichtet und gestartet."
    return 0
}

install_system_requirements() {
    # -----------------------------------------------------------------------
    # install_system_requirements
    # -----------------------------------------------------------------------
    # Funktion: Liest die Systempakete aus conf/requirements_system.inf und installiert sie
    # Rückgabe: 0 = OK, 1 = Fehler beim Lesen der Datei, 2 = Fehler bei der Installation
    local req_file="$INSTALL_DIR/conf/requirements_system.inf"
    
    if [ ! -f "$req_file" ]; then
        print_error "Datei nicht gefunden: $req_file"
        return 1
    fi
    
    print_step "Lese System-Anforderungen aus $req_file ..."
    
    # Array für die zu installierenden Pakete
    local packages=()
    
    # Datei zeilenweise lesen und Kommentare und leere Zeilen überspringen
    while IFS= read -r line; do
        # Kommentare und leere Zeilen überspringen
        if [[ "$line" =~ ^[[:space:]]*# || -z "$line" || "$line" =~ ^// ]]; then
            continue
        fi
        
        # Version-Spezifikation entfernen (z.B. nginx>=1.18.0 -> nginx)
        local package="${line%%>=*}"
        package="${package%%[<>=]*}"  # Entferne alle Vergleichsoperatoren
        package="${package%%[[:space:]]*}"  # Entferne trailing spaces
        
        if [ -n "$package" ]; then
            packages+=("$package")
        fi
    done < "$req_file"
    
    if [ ${#packages[@]} -eq 0 ]; then
        print_warning "Keine Pakete in $req_file gefunden!"
        return 0
    fi
    
    print_step "Installiere ${#packages[@]} Systempakete: ${packages[*]} ..."
    
    # Installation der Pakete mit apt-get
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" &> "$LOG_DIR/system_requirements.log" &
    show_spinner $!
    
    if [ $? -ne 0 ]; then
        print_error "Fehler bei der Installation von Systempaketen. Log-Auszug:"
        tail -n 10 "$LOG_DIR/system_requirements.log"
        return 2
    fi
    
    print_success "Systempakete erfolgreich installiert."
    return 0
}

dlg_show_summary() {
    # -----------------------------------------------------------------------
    # dlg_show_summary
    # -----------------------------------------------------------------------
    # Funktion: Zeigt die Zusammenfassung der Installation an, insbesondere 
    # ........  die URL der Weboberfläche
    # Rückgabe: 0 = OK
    # -----------------------------------------------------------------------
    print_step "[7/10] Installation abgeschlossen: Zusammenfassung ..."
    
    # NGINX-Konfiguration nach Installation ausgeben (Policy-konform, modular)
    source "$BASH_DIR/manage_nginx.sh"
    local nginx_status_json
    nginx_status_json=$(get_nginx_status json)
    local nginx_port nginx_bind nginx_servername nginx_webroot nginx_url
    nginx_port=$(echo "$nginx_status_json" | grep -o '"port":[0-9]*' | grep -o '[0-9]*')
    nginx_bind=$(echo "$nginx_status_json" | grep -o '"bind_address":"[^"]*"' | cut -d'"' -f4)
    nginx_servername=$(echo "$nginx_status_json" | grep -o '"server_name":"[^"]*"' | cut -d'"' -f4)
    nginx_webroot=$(echo "$nginx_status_json" | grep -o '"webroot_path":"[^"]*"' | cut -d'"' -f4)
    nginx_url=$(echo "$nginx_status_json" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    
    # Prüfe auf Platzhalter und generiere ggf. alternative URL
    if [[ "$nginx_servername" == "_" || -z "$nginx_servername" ]]; then
        # Versuche, die lokale IP zu ermitteln
        local ipaddr
        ipaddr=$(hostname -I | awk '{print $1}')
        if [ -n "$ipaddr" ]; then
            nginx_url="http://$ipaddr:$nginx_port$nginx_webroot"
        else
            nginx_url="http://localhost:$nginx_port$nginx_webroot"
        fi
    fi
    
    log "NGINX-Konfiguration nach Installation: Port=$nginx_port, Bind=$nginx_bind, Servername=$nginx_servername, Webroot=$nginx_webroot, URL=$nginx_url"
    
    if [ "$UNATTENDED" -eq 1 ]; then
        local logfile
        logfile=$(get_log_file)
        echo "Installation abgeschlossen. Details siehe Logfile: $logfile"
        echo "Weboberfläche: $nginx_url"
    else
        print_success "Erstinstallation abgeschlossen."
        print_prompt "Bitte rufen Sie die Weboberfläche im Browser auf, um die Fotobox weiter zu konfigurieren und zu verwalten.\nURL: $nginx_url"
        echo "Weitere Wartung (Update, Deinstallation) erfolgt über die WebUI oder die Python-Skripte im backend/."
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
# Funktion: Hauptablauf der Erstinstallation
# ------------------------------------------------------------------------------
main() {
    dlg_check_root               # Prüfe, ob Skript als root ausgeführt wird
    dlg_check_distribution       # Prüfe, ob System auf Debian/Ubuntu basiert
    dlg_prepare_system           # Installiere Systempakete und prüfe Erfolg
    dlg_prepare_users            # Erstelle Benutzer und Gruppe 'fotobox'
    dlg_prepare_structure        # Erstelle Verzeichnisstruktur, klone Projekt und setze Rechte
    dlg_nginx_installation       # NGINX-Konfiguration (Integration oder eigene Site)
    dlg_backend_integration      # Python-Backend, venv, systemd-Service, Start
    dlg_show_summary             # Zeige Zusammenfassung der Installation an
}

# ------------------------------------------------------------------------------
# UNATTENDED-Variable initialisieren, falls nicht gesetzt
: "${UNATTENDED:=0}"

# ------------------------------------------------------------------------------
# Funktion: Verarbeitet Befehlszeilenargumente für das Skript
# ------------------------------------------------------------------------------
parse_args() {
    # Standardwerte für alle Flags setzen
    UNATTENDED=0
    
    # Argumente durchlaufen
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unattended|-u|--headless|-h|-q)
                UNATTENDED=1
                log "Unattended-Modus aktiviert"
                ;;
            --help|-h|--hilfe)
                show_help
                exit 0
                ;;
            *)
                print_warning "Unbekannte Option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    export UNATTENDED
}

# ------------------------------------------------------------------------------
# Funktion: Zeigt die Hilfe zu den verfügbaren Optionen an
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF
Verwendung: $0 [OPTIONEN]

Dieses Skript führt die Erstinstallation der Fotobox durch.

Optionen:
  --unattended, -u, --headless, -q   Starte die Installation im Unattended-Modus 
                                     (ohne Benutzerinteraktion, verwendet sichere Standardwerte)
  --help, -h, --hilfe                Zeigt diese Hilfe an

EOF
}

# Fallback-Definitionen für Logging/Print-Funktionen zentral setzen
set_fallback_security_settings

# Logging-Hilfsskript einbinden (zentral für alle Fotobox-Skripte)
if [ -f "$(dirname "$0")/backend/scripts/log_helper.sh" ]; then
    source "$(dirname "$0")/backend/scripts/log_helper.sh"
else
    print_warning "Logging-Hilfsskript nicht gefunden! Logging deaktiviert."
fi

# Befehlszeilenargumente verarbeiten
parse_args "$@"

# Log-Initialisierung (Rotation) direkt nach Skriptstart
log
log "Installationsskript gestartet: $(date '+%Y-%m-%d %H:%M:%S')"

# Hauptfunktion aufrufen 
main

