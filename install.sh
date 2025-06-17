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
# Einstellungen: Installationsverzeichnis
# ---------------------------------------------------------------------------
INSTALL_DIR="/opt/fotobox"
# ---------------------------------------------------------------------------
# Einstellungen: Ordnerstruktur
# ---------------------------------------------------------------------------
BACKUP_DIR="$INSTALL_DIR/backup"
CONF_DIR="$INSTALL_DIR/conf"
BASH_DIR="$INSTALL_DIR/backend/scripts"
LOG_DIR="$INSTALL_DIR/log"
FRONTEND_DIR="$INSTALL_DIR/frontend"
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
# Neue Debug-Modi für zentralisiertes Debug-System
DEBUG_MOD_LOCAL=0
DEBUG_MOD_GLOBAL=0

# ===========================================================================
# Einbindung der zentralen Bibliothek (falls verfügbar)
# ===========================================================================
if [ -f "$BASH_DIR/lib_core.sh" ]; then
    source "$BASH_DIR/lib_core.sh"
    # Versuche, zentrale Ressourcen zu laden
    if type load_core_resources &>/dev/null; then
        load_core_resources || echo "Warnung: Kern-Ressourcen konnten nicht vollständig geladen werden."
    fi
fi

# ==========================================================================='
# Hilfsfunktionen
# ==========================================================================='

parse_args() {
    # -----------------------------------------------------------------------
    # Funktion: Verarbeitet Befehlszeilenargumente für das Skript
    # -----------------------------------------------------------------------
    # Standardwerte für alle Flags setzen
    UNATTENDED=0
    CONFIGURE_FIREWALL=0
    
    # Argumente durchlaufen
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unattended|-u|--headless|-q)
                UNATTENDED=1
                log "Unattended-Modus aktiviert"
                ;;
            --debug|-d)
                DEBUG_MOD_LOCAL=1
                log "Debug-Modus aktiviert"
                ;;
            --firewall|-f)
                CONFIGURE_FIREWALL=1
                log "Firewall-Konfiguration aktiviert"
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
    export DEBUG_MOD_LOCAL
    export DEBUG_MOD_GLOBAL
    export CONFIGURE_FIREWALL
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

chk_distribution_version() {
    # -----------------------------------------------------------------------
    # chk_distribution_version
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob die Distribution eine unterstützte Version ist
    # Rückgabe: 0 = unterstützte Version (VERSION_ID wird als globale Variable gesetzt)
    #           1 = /etc/os-release nicht gefunden
    #           2 = Version nicht unterstützt
    if [ ! -f /etc/os-release ]; then
        DIST_NAME="Unknown"
        DIST_VERSION="Unknown"
        return 1
    fi
    . /etc/os-release
    DIST_NAME="$NAME"
    DIST_VERSION="$VERSION_ID"
    case "$VERSION_ID" in
        10|11|12|20.04|22.04)
            return 0
            ;;
        *)
            return 2
            ;;
    esac
}

set_fallback_security_settings() {
    # -----------------------------------------------------------------------
    # set_fallback_security_settings
    # -----------------------------------------------------------------------
    # Funktion: Stellt die Verfügbarkeit aller kritischen Ressourcen sicher und
    # ......... setzt Fallback-Definitionen für Logging- und Print-Funktionen.
    # ......... Prüft außerdem die Verfügbarkeit von manage_nginx.sh.
    # ......... Prüft, ob das Skript im vorgegebenen INSTALL_DIR ausgeführt wird.
    # .........
    # Rückgabe: 0 = OK, 1 = fehlerhafte Umgebung, Skript sollte abgebrochen werden

    # --- 1. Prüfen, ob das Skript im vorgegebenen INSTALL_DIR ausgeführt wird
    local SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
    if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
        # Kein gültiges Verzeichnis, Abbruch
        echo -e "\033[1;31mFehler: Das Skript muss im Installationsverzeichnis ($INSTALL_DIR) ausgeführt werden.\033[0m"
        return 1
    fi
    
    # --- 2. Prüfen, ob die Kernressourcen geladen wurden
    if [ "$LIB_CORE_LOADED" != "1" ]; then
        echo -e "\033[1;31mFehler: Die zentrale Bibliothek (lib_core.sh) wurde nicht geladen.\033[0m"
        return 1
    fi
    
    # --- 3. Prüfen, ob alle benötigten Ressourcen verfügbar sind
    # Diese Prüfung ersetzt die direkten Einbindungen der Skripte,
    # da lib_core.sh dies bereits über load_core_resources erledigt hat
    if [ "$MANAGE_FOLDERS_LOADED" != "1" ] || [ "$MANAGE_LOGGING_LOADED" != "1" ] || [ "$MANAGE_NGINX_LOADED" != "1" ]; then
        echo -e "\033[1;31mFehler: Nicht alle benötigten Skripte konnten geladen werden.\033[0m"
        [ "$MANAGE_FOLDERS_LOADED" != "1" ] && echo -e "\033[1;31m  - manage_folders.sh fehlt oder ist fehlerhaft\033[0m"
        [ "$MANAGE_LOGGING_LOADED" != "1" ] && echo -e "\033[1;31m  - manage_logging.sh fehlt oder ist fehlerhaft\033[0m"
        [ "$MANAGE_NGINX_LOADED" != "1" ] && echo -e "\033[1;31m  - manage_nginx.sh fehlt oder ist fehlerhaft\033[0m"
        return 1
    fi
    
    return 0
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
        debug "Kein Verzeichnis angegeben!" "CLI" "make_dir"
        return 1
    fi
    if [ ! -d "$dir" ]; then
        debug "$dir existiert nicht, versuche mkdir -p" "CLI" "make_dir"
        mkdir -p "$dir"
        if [ ! -d "$dir" ]; then
            log "make_dir: Fehler beim Anlegen von $dir!"
            debug "Fehler beim Anlegen von $dir!" "CLI" "make_dir"
            return 2
        fi
        log "make_dir: Verzeichnis $dir wurde neu angelegt."
    else
        debug "$dir existiert bereits." "CLI" "make_dir"
    fi
    # Rechte prüfen und ggf. setzen
    local owner_group
    owner_group=$(stat -c '%U:%G' "$dir")
    if [ "$owner_group" != "$user:$group" ]; then
        chown "$user:$group" "$dir" || {
            log "make_dir: Fehler beim Setzen von chown $user:$group für $dir!"
            debug "Fehler beim Setzen von chown $user:$group für $dir!" "CLI" "make_dir"
            return 2
        }
        log "make_dir: chown $user:$group für $dir gesetzt."
    fi
    local perms
    perms=$(stat -c '%a' "$dir")
    if [ "$perms" != "$mode" ]; then
        chmod "$mode" "$dir" || {
            log "make_dir: Fehler beim Setzen von chmod $mode für $dir!"
            debug "Fehler beim Setzen von chmod $mode für $dir!" "CLI" "make_dir"
            return 2
        }
        log "make_dir: chmod $mode für $dir gesetzt."
    fi
    debug "$dir ist vorhanden, Rechte und Eigentümer korrekt." "CLI" "make_dir"
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

    debug "Prüfe $pkg $version" "CLI" "install_package"
    if [ -n "$version" ]; then
        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        debug "installierte Version von $pkg: $installed_version" "CLI" "install_package"
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
        debug "neue Version von $pkg: $new_version" "CLI" "install_package"
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

    debug "Starte für Gruppe $group_name" "CLI" "install_package_group"
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
        debug "Installiere $pkg $version" "CLI" "install_package_group"
        install_package "$pkg" "$version"
        result=$?
        debug "Ergebnis für $pkg: $result" "CLI" "install_package_group"
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
    # Funktion: Installiert alle benötigten Systempakete und prüft den Erfolg
    # Rückgabe: 0 = OK, 1 = Fehler bei apt-get update, 
    # ......... 2 = Fehler bei System-Requirements-Installation
    
    # Stelle sicher, dass das Logverzeichnis existiert
    mkdir -p "$LOG_DIR"
    
    print_step "Führe apt-get update aus ..."
    (apt-get update -qq) &> "$LOG_DIR/apt_update.log" &
    show_spinner $!
    if [ $? -ne 0 ]; then
        print_error "Fehler bei apt-get update. Log-Auszug:"
        tail -n 10 "$LOG_DIR/apt_update.log"
        return 1
    fi
    
    # Installiere Systempakete aus conf/requirements_system.inf
    install_system_requirements || return 2
    
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
    #           Verwaltet die vollständige Ordnerstruktur über manage_folders.sh
    set -e
    debug "Starte mit INSTALL_DIR=$INSTALL_DIR" "CLI" "set_structure"
    
    # Prüfe, ob das Backend-Verzeichnis und wichtige Dateien existieren
    if [ ! -d "$INSTALL_DIR/backend" ] || [ ! -d "$INSTALL_DIR/backend/scripts" ] || [ ! -f "$INSTALL_DIR/conf/requirements_python.inf" ]; then
        print_error "Fehler: Die Projektstruktur ist unvollständig. Bitte stellen Sie sicher, dass das Repository vollständig geklont wurde (inkl. backend/, backend/scripts/, conf/requirements_python.inf)."
        return 10
    fi
    
    # manage_folders.sh ausführbar machen
    chmod +x "$INSTALL_DIR"/backend/scripts/*.sh || true
    
    # Versuche, die Ordnerstruktur über manage_folders.sh zu erstellen
    if [ -f "$INSTALL_DIR/backend/scripts/manage_folders.sh" ]; then
        debug "Verwende manage_folders.sh zur Ordnererstellung" "CLI" "set_structure"
        
        # Setze globale Variablen für manage_folders.sh
        export INSTALL_DIR="$INSTALL_DIR"
        export DATA_DIR="$DATA_DIR"
        export BACKUP_DIR="$BACKUP_DIR"
        export LOG_DIR="$LOG_DIR"
        export FRONTEND_DIR="$FRONTEND_DIR"
        export CONFIG_DIR="$CONFIG_DIR"
        
        # Führe manage_folders.sh aus, um die Ordnerstruktur zu erstellen
        if "$INSTALL_DIR/backend/scripts/manage_folders.sh" ensure_structure; then
            debug "Ordnerstruktur erfolgreich über manage_folders.sh erstellt" "CLI" "set_structure"
        else
            print_error "Fehler bei der Erstellung der Ordnerstruktur über manage_folders.sh."
            debug "Fehler bei manage_folders.sh" "CLI" "set_structure"
            return 1
        fi
    else
        print_error "manage_folders.sh nicht gefunden. Die Projektstruktur scheint unvollständig zu sein."
        debug "manage_folders.sh nicht gefunden" "CLI" "set_structure"
        return 1
    fi
    
    # Policy: Nach jedem schreibenden Schritt im Projektverzeichnis Rechte prüfen und ggf. korrigieren.
    # Die Rechtevergabe für einzelne Verzeichnisse erfolgt bereits in make_dir oder manage_folders.sh.
    # Das folgende chown -R dient als zusätzlicher Schutz, um Policy-Konformität sicherzustellen.
    chown -R fotobox:fotobox "$INSTALL_DIR" || {
        debug "chown auf $INSTALL_DIR fehlgeschlagen" "CLI" "set_structure"
        return 7
    }
    debug "erfolgreich abgeschlossen" "CLI" "set_structure"
    return 0
}

# Die use_fallback_structure() Funktion wurde entfernt, da ihre Funktionalität jetzt
# vollständig in manage_folders.sh implementiert ist.

install_system_requirements() {
    # -----------------------------------------------------------------------
    # install_system_requirements
    # -----------------------------------------------------------------------
    # Funktion: Liest die Systempakete aus conf/requirements_system.inf und installiert sie
    # Rückgabe: 0 = OK, 1 = Fehler beim Lesen der Datei, 2 = Fehler bei der Installation
    
    # Sicherstellen, dass INSTALL_DIR gesetzt ist
    if [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR=$(dirname "$(readlink -f "$0")")
        log "WARNING: INSTALL_DIR war nicht gesetzt, setze auf: $INSTALL_DIR"
    fi
    
    local req_file="$INSTALL_DIR/conf/requirements_system.inf"
    
    if [ ! -f "$req_file" ]; then
        print_error "Datei nicht gefunden: $req_file"
        log "ERROR: Anforderungsdatei nicht gefunden: $req_file"
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
    
    # Stelle sicher, dass das Logverzeichnis existiert
    # LOG_DIR wird bereits in set_fallback_security_settings korrekt gesetzt
    
    # Erstelle die System-Requirements-Log-Datei wenn sie nicht existiert
    touch "$LOG_DIR/system_requirements.log" 2>/dev/null || {
        print_warning "Konnte Log-Datei nicht erstellen. Log-Ausgaben werden möglicherweise nicht gespeichert."
    }
    
    # Paketlisten aktualisieren
    print_step "Aktualisiere Paketlisten (apt update)..."
    apt-get update -q || {
        print_error "Fehler bei apt-get update. Bitte prüfen Sie Ihre Internetverbindung und Paketquellen."
        return 2
    }
    
    # Pakete einzeln installieren für bessere Fehlerbehandlung
    local failed_packages=()
    local successful_packages=0
    
    for pkg in "${packages[@]}"; do
        print_info "Installiere Paket: $pkg..."
        if apt-get install -y "$pkg" >> "$LOG_DIR/system_requirements.log" 2>&1; then
            print_success "Paket $pkg erfolgreich installiert."
            ((successful_packages++))
        else
            print_warning "Paket $pkg konnte nicht installiert werden. Das Skript wird versuchen, fortzufahren."
            failed_packages+=("$pkg")
            # In die Logdatei schreiben, dass das Paket nicht installiert werden konnte
            echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: Paket $pkg konnte nicht installiert werden" >> "$LOG_DIR/system_requirements.log"
        fi
    done
    
    # Zusammenfassung ausgeben
    if [ ${#failed_packages[@]} -eq 0 ]; then
        print_success "Alle $successful_packages Systempakete wurden erfolgreich installiert."
        return 0
    elif [ $successful_packages -gt 0 ]; then
        print_warning "$successful_packages Pakete wurden erfolgreich installiert, aber ${#failed_packages[@]} Pakete konnten nicht installiert werden: ${failed_packages[*]}"
        print_warning "Die Installation wird fortgesetzt, könnte aber unvollständig sein. Überprüfen Sie die Logdatei für Details."
        return 0  # Wir setzen hier 0, um fortzufahren, aber warnen den Benutzer
    else
        print_error "Fehler bei der Installation aller Systempakete. Fehlgeschlagene Pakete: ${failed_packages[*]}"
        return 2
    fi
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
    # Funktion: Prüft, ob das Skript als root ausgeführt wird
    print_step "[1/10] Prüfe Rechte zur Ausführung ..."
    if ! chk_is_root; then
        print_error "Dieses Skript muss mit Root-Rechten ausgeführt werden."
        exit 1
    fi
    print_success "Rechteprüfung erfolgreich (Root-Rechte vorhanden)."
}

dlg_check_distribution() {
    # -----------------------------------------------------------------------
    # dlg_check_distribution
    # -----------------------------------------------------------------------
    # Funktion: Prüft, ob das System auf Debian/Ubuntu basiert und zeigt Informationen an
    print_step "[2/10] Prüfe Distribution ..."
    
    # Prüfe Basis-Distribution
    if ! chk_distribution; then
        print_error "Dieses Skript ist nur für Debian/Ubuntu-basierte Systeme geeignet."
        exit 1
    fi
    
    # Versionsinfo-Variablen vorinitialisieren, falls sie später nicht gesetzt werden können
    : "${DIST_NAME:=Unbekannt}"
    : "${DIST_VERSION:=Unbekannt}"
    
    # Prüfe Versions-Kompatibilität
    chk_distribution_version
    version_check=$?
    
    case $version_check in
        0)
            print_success "Distribution erkannt: $DIST_NAME $DIST_VERSION (unterstützt)"
            log "INFO: Unterstützte Distribution erkannt: $DIST_NAME $DIST_VERSION"
            ;;
        1)
            print_warning "Distributionsversion konnte nicht erkannt werden (/etc/os-release nicht gefunden)."
            print_success "Distribution: Debian/Ubuntu-basiertes System"
            log "WARNING: Distributionsversion konnte nicht erkannt werden (/etc/os-release nicht gefunden)"
            ;;
        2)
            print_warning "Distribution erkannt: $DIST_NAME $DIST_VERSION (nicht offiziell unterstützt)"
            print_info "Die Installation wird fortgesetzt, aber es könnte zu unerwarteten Problemen kommen."
            log "WARNING: Nicht offiziell unterstützte Distribution erkannt: $DIST_NAME $DIST_VERSION"
            ;;
    esac
}

dlg_check_system_requirements() {
    # -----------------------------------------------------------------------
    # dlg_check_system_requirements
    # -----------------------------------------------------------------------
    # Funktion: Prüft die Systemvoraussetzungen und stellt Logging-Ressourcen bereit
    echo -e "\033[1;33mPrüfung der Systemvoraussetzungen ...\033[0m"    
    
    # Auf kritische Ressourcen prüfen und Logging einrichten
    if ! set_fallback_security_settings; then
        echo -e "\033[1;31m  → [ERROR]\033[0m Kritische Systemvoraussetzungen nicht erfüllt oder Logging konnte nicht eingerichtet werden."
        exit 1
    fi
    
    # Ab hier können die print_* Funktionen verwendet werden
    
    # Prüfe, ob externe Abhängigkeiten verfügbar sind
    if ! command -v apt-get &>/dev/null; then
        print_error "apt-get nicht gefunden. Dies ist ein kritischer Fehler."
        exit 1
    fi
    
    # Prüfen, ob die manage_logging.sh erfolgreich geladen wurde
    if type get_log_file &>/dev/null; then
        print_success "Log-Hilfsskript erfolgreich geladen, verwende zentrales Logging."
        log "INFO: Log-Hilfsskript erfolgreich geladen, verwende zentrales Logging."
    else
        print_warning "Zentrales Log-Hilfsskript nicht verfügbar, verwende Fallback-Logging in $LOG_DIR."
        log "WARNING: Zentrales Log-Hilfsskript nicht verfügbar, verwende Fallback-Logging in $LOG_DIR."
    fi
    
    print_step "[3/10] Prüfe Systemvoraussetzungen und richte Logging ein ..."

    # Befehlszeilenargumente verarbeiten
    parse_args "$@"
    
    # Log-Initialisierung (Rotation) direkt nach Skriptstart
    if type -t log | grep -q "function"; then
        log
        log "Installationsskript gestartet: $(date '+%Y-%m-%d %H:%M:%S')"
        log "Logverzeichnis: $LOG_DIR"
    else
        echo -e "\033[1;33mWarnung: Log-Rotation konnte nicht durchgeführt werden (log-Funktion nicht verfügbar)\033[0m"
    fi

    print_success "Systemvoraussetzungen erfüllt, Logging eingerichtet."
}

dlg_prepare_system() {
    # -----------------------------------------------------------------------
    # dlg_prepare_system
    # -----------------------------------------------------------------------
    # Funktion: Prüft installiert Pakete
    print_step "[4/10] Installiere benötigte Systempakete ..."
    set_install_packages
    rc=$?
    if [ $rc -eq 1 ]; then
        print_error "Fehler bei apt-get update. Prüfen Sie Ihre Internetverbindung und Paketquellen."
        exit 1
    elif [ $rc -eq 2 ]; then
        print_error "Fehler bei der Installation der Systempakete."
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
    print_step "[5/10] Prüfe und lege Benutzer/Gruppe an ..."
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
    print_step "[6/10] Erstelle Verzeichnisstruktur und setze Rechte ..."
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
    print_step "[7/10] NGINX-Installation und Konfiguration ..."

    debug "Starte NGINX-Dialog, UNATTENDED=$UNATTENDED, BASH_DIR=$BASH_DIR" "CLI" "dlg_nginx_installation"
    # Verwenden der globalen Variable zur Prüfung, ob manage_nginx.sh existiert
    if [ "$MANAGE_NGINX_AVAILABLE" -ne 1 ]; then
        debug "manage_nginx.sh ist nicht verfügbar (MANAGE_NGINX_AVAILABLE=$MANAGE_NGINX_AVAILABLE)" "CLI" "dlg_nginx_installation"
        print_error "manage_nginx.sh nicht gefunden! Die Projektstruktur wurde vermutlich noch nicht geklont."
        exit 1
    fi
    # NGINX-Installation prüfen/ausführen (zentral)
    # Verwende den in set_fallback_security_settings gespeicherten Pfad zu manage_nginx.sh
    if [ -n "$MANAGE_NGINX_PATH" ]; then
        NGINX_SCRIPT="$MANAGE_NGINX_PATH"
    else
        # Fallback auf den standardmäßigen Pfad
        NGINX_SCRIPT="$BASH_DIR/manage_nginx.sh"
    fi
    
    if [ "$UNATTENDED" -eq 1 ]; then
        debug "Starte $NGINX_SCRIPT --json install" "CLI" "dlg_nginx_installation"
        install_result=$(bash "$NGINX_SCRIPT" --json install)
        install_rc=$?
    else
        debug "Starte $NGINX_SCRIPT install" "CLI" "dlg_nginx_installation"
        install_result=$(bash "$NGINX_SCRIPT" install)
        install_rc=$?
    fi
    debug "install_rc=$install_rc, install_result=$install_result" "CLI" "dlg_nginx_installation"
    if [ $install_rc -ne 0 ]; then
        print_error "NGINX-Installation fehlgeschlagen: $install_result"
        exit 1
    fi
    # Betriebsmodus abfragen (default/multisite)
    if [ "$UNATTENDED" -eq 1 ]; then
        debug "Starte $NGINX_SCRIPT --json activ" "CLI" "dlg_nginx_installation"
        activ_result=$(bash "$NGINX_SCRIPT" --json activ)
        activ_rc=$?
    else
        debug "Starte $NGINX_SCRIPT activ" "CLI" "dlg_nginx_installation"
        activ_result=$(bash "$NGINX_SCRIPT" activ)
        activ_rc=$?
    fi
    debug "activ_rc=$activ_rc, activ_result=$activ_result" "CLI" "dlg_nginx_installation"
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
        debug "Antwort auf Default-Integration: $antwort" "CLI" "dlg_nginx_installation"
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            if [ "$UNATTENDED" -eq 1 ]; then
                antwort2="j"
                log "Automatische Antwort (unattended) auf eigene Konfiguration: $antwort2"
            else
                print_prompt "Stattdessen eigene Fotobox-Konfiguration anlegen? [J/n]"
                read -r antwort2
            fi
            debug "Antwort auf eigene Konfiguration: $antwort2" "CLI" "dlg_nginx_installation"
            if [[ "$antwort2" =~ ^([nN])$ ]]; then
                print_error "Abbruch: Keine NGINX-Integration gewählt."
                exit 1
            fi
            # Portwahl und externe Konfiguration (zentral, jetzt mit Schleife)
            port_rc=1
            while [ $port_rc -ne 0 ]; do
                if [ "$UNATTENDED" -eq 1 ]; then
                    debug "Starte $NGINX_SCRIPT --json setport 80 j (unattended)" "CLI" "dlg_nginx_installation"
                    port_result=$(bash "$NGINX_SCRIPT" --json setport 80 j)
                    port_rc=$?
                else
                    print_prompt "Bitte gewünschten Port für die Fotobox-Weboberfläche angeben [Default: 80]:"
                    read -r user_port
                    if [ -z "$user_port" ]; then user_port=80; fi
                    debug "Starte $NGINX_SCRIPT setport $user_port N (interaktiv)" "CLI" "dlg_nginx_installation"
                    port_result=$(bash "$NGINX_SCRIPT" setport "$user_port" N)
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
            debug "port_rc=$port_rc, port_result=$port_result" "CLI" "dlg_nginx_installation"
            if [ "$UNATTENDED" -eq 1 ]; then
                debug "Starte $NGINX_SCRIPT --json external" "CLI" "dlg_nginx_installation"
                ext_result=$(bash "$NGINX_SCRIPT" --json external)
                ext_rc=$?
            else
                debug "Starte $NGINX_SCRIPT external" "CLI" "dlg_nginx_installation"
                ext_result=$(bash "$NGINX_SCRIPT" external)
                ext_rc=$?
            fi
            debug "ext_rc=$ext_rc, ext_result=$ext_result" "CLI" "dlg_nginx_installation"
            if [ $ext_rc -eq 0 ]; then
                print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
            else
                print_error "Fehler bei externer NGINX-Konfiguration (Code $ext_rc): $ext_result"
                exit 1
            fi
        else
            # Default-Integration (zentral)
            if [ "$UNATTENDED" -eq 1 ]; then
                debug "Starte $NGINX_SCRIPT --json internal" "CLI" "dlg_nginx_installation"
                int_result=$(bash "$NGINX_SCRIPT" --json internal)
                int_rc=$?
            else
                debug "Starte $NGINX_SCRIPT internal" "CLI" "dlg_nginx_installation"
                int_result=$(bash "$NGINX_SCRIPT" internal)
                int_rc=$?
            fi
            debug "int_rc=$int_rc, int_result=$int_result" "CLI" "dlg_nginx_installation"
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
        debug "Antwort auf eigene Konfiguration (multisite): $antwort" "CLI" "dlg_nginx_installation"
        if [[ "$antwort" =~ ^([nN])$ ]]; then
            print_error "Abbruch: Keine NGINX-Integration gewählt."
            exit 1
        fi
        # Portwahl und externe Konfiguration (zentral)
        if [ "$UNATTENDED" -eq 1 ]; then
            debug "Starte $NGINX_SCRIPT --json setport" "CLI" "dlg_nginx_installation"
            port_result=$(bash "$NGINX_SCRIPT" --json setport)
            port_rc=$?
        else
            debug "Starte $NGINX_SCRIPT setport" "CLI" "dlg_nginx_installation"
            port_result=$(bash "$NGINX_SCRIPT" setport)
            port_rc=$?
        fi
        debug "port_rc=$port_rc, port_result=$port_result" "CLI" "dlg_nginx_installation"
        if [ $port_rc -ne 0 ]; then
            print_error "Portwahl/Setzen fehlgeschlagen: $port_result"
            exit 1
        fi
        if [ "$UNATTENDED" -eq 1 ]; then
            debug "Starte $NGINX_SCRIPT --json external" "CLI" "dlg_nginx_installation"
            ext_result=$(bash "$NGINX_SCRIPT" --json external)
            ext_rc=$?
        else
            debug "Starte $NGINX_SCRIPT external" "CLI" "dlg_nginx_installation"
            ext_result=$(bash "$NGINX_SCRIPT" external)
            ext_rc=$?
        fi
        debug "ext_rc=$ext_rc, ext_result=$ext_result" "CLI" "dlg_nginx_installation"
        if [ $ext_rc -eq 0 ]; then
            print_success "Eigene Fotobox-Konfiguration wurde angelegt und aktiviert."
        else
            print_error "Fehler bei externer NGINX-Konfiguration (Code $ext_rc): $ext_result"
            exit 1
        fi
    fi
    debug "Dialog erfolgreich abgeschlossen" "CLI" "dlg_nginx_installation"
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
    print_step "[8/10] Python-Umgebung und Backend-Service werden eingerichtet ..."
    # Stellen Sie sicher, dass das Logverzeichnis vorhanden ist
    # LOG_DIR wird bereits in set_fallback_security_settings korrekt gesetzt
    
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

dlg_firewall_config() {
    # ------------------------------------------------------------------------------
    # dlg_firewall_config
    # ------------------------------------------------------------------------------
    # Funktion: Konfiguriert die Firewall für die Fotobox
    # ------------------------------------------------------------------------------
    # Prüfe, ob die Fotobox-Verzeichnisstruktur schon angelegt wurde
    if [ ! -d "$BASH_DIR" ]; then
        print_error "Fotobox-Verzeichnisstruktur muss vor der Firewall-Konfiguration erstellt werden."
        return 1
    fi

    # Suche nach dem Firewall-Management-Skript
    local firewall_script="$BASH_DIR/manage_firewall.sh"
    if [ ! -f "$firewall_script" ]; then
        print_error "Firewall-Management-Skript nicht gefunden: $firewall_script"
        return 1
    fi

    print_step "[8/10] Firewall-Konfiguration ..."

    # Wenn im Unattended-Modus oder explizit angefordert, konfiguriere die Firewall automatisch
    if [ "$UNATTENDED" -eq 1 ] || [ "$CONFIGURE_FIREWALL" -eq 1 ]; then
        print_info "Firewall wird automatisch konfiguriert..."
        # Führe das Firewall-Skript mit --setup-Parameter aus
        if ! bash "$firewall_script" --setup; then
            print_warning "Firewall-Konfiguration fehlgeschlagen. Die Weboberfläche könnte nicht erreichbar sein."
            log "WARN: Firewall-Konfiguration fehlgeschlagen."
            return 1
        else
            print_success "Firewall erfolgreich konfiguriert."
            log "INFO: Firewall erfolgreich konfiguriert."
            return 0
        fi
    else
        # Im interaktiven Modus fragen wir den Benutzer
        if ! interactive_mode; then
            print_info "Interaktiver Modus deaktiviert, Firewall wird nicht automatisch konfiguriert."
            return 0
        fi

        print_info "Die Fotobox verwendet HTTP-Port 80 und HTTPS-Port 443 (anpassbar in der Konfigurationsdatei)."
        print_info "Diese Ports müssen in der Firewall freigegeben werden, damit auf die Weboberfläche zugegriffen werden kann."

        local configure_firewall=0
        if promptyn "Möchten Sie die Firewall jetzt automatisch konfigurieren?"; then
            configure_firewall=1
        fi

        if [ "$configure_firewall" -eq 1 ]; then
            # Firewall-Typ erkennen
            local firewall_type=$(bash "$firewall_script" --status 2>/dev/null | grep "Firewall-System:" | cut -d: -f2 | tr -d '[:space:]')
            
            if [ -z "$firewall_type" ] || [ "$firewall_type" = "none" ]; then
                print_warning "Kein unterstütztes Firewall-System gefunden."
                
                # Anbieten, ufw zu installieren
                if promptyn "Möchten Sie UFW (Uncomplicated Firewall) installieren?"; then
                    print_info "Installiere UFW..."
                    apt-get update -qq
                    apt-get install -y ufw
                    
                    if ! command -v ufw >/dev/null 2>&1; then
                        print_error "Installation von UFW fehlgeschlagen."
                        return 1
                    fi
                    
                    print_success "UFW erfolgreich installiert."
                else
                    print_info "Firewall-Konfiguration wird übersprungen."
                    return 0
                fi
            fi
            
            # Firewall konfigurieren
            print_info "Konfiguriere Firewall..."
            if ! bash "$firewall_script" --setup; then
                print_warning "Firewall-Konfiguration fehlgeschlagen. Die Weboberfläche könnte nicht erreichbar sein."
                log "WARN: Firewall-Konfiguration fehlgeschlagen."
                return 1
            else
                print_success "Firewall erfolgreich konfiguriert."
                log "INFO: Firewall erfolgreich konfiguriert."
                return 0
            fi
        else
            print_info "Firewall-Konfiguration wird übersprungen."
            log "INFO: Firewall-Konfiguration vom Benutzer übersprungen."
            return 0
        fi
    fi
}

dlg_show_summary() {
    # -----------------------------------------------------------------------
    # dlg_show_summary
    # -----------------------------------------------------------------------
    # Funktion: Zeigt die Zusammenfassung der Installation an
    # -----------------------------------------------------------------------
    print_step "[9/10] Installation abgeschlossen: Zusammenfassung ..."
    
    # NGINX-Konfiguration nach Installation ausgeben (Policy-konform, modular)
    if [ -n "$MANAGE_NGINX_PATH" ]; then
        source "$MANAGE_NGINX_PATH"
    else
        source "$BASH_DIR/manage_nginx.sh"
    fi
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
    # Führe die Prüfungen der Systemvoraussetzungen durch
    
    dlg_check_system_requirements "$@"  # Prüfe Systemvoraussetzungen und richte Logging ein
    dlg_check_root               # Prüfe Root-Rechte
    dlg_check_distribution       # Prüfe die Distribution
    dlg_prepare_system           # Installiere Systempakete und prüfe Erfolg
    dlg_prepare_users            # Erstelle Benutzer und Gruppe 'fotobox'
    dlg_prepare_structure        # Erstelle Verzeichnisstruktur, klone Projekt und setze Rechte
    dlg_nginx_installation       # NGINX-Konfiguration (Integration oder eigene Site)
    dlg_firewall_config          # Firewall-Konfiguration für HTTP/HTTPS-Ports
    dlg_backend_integration      # Python-Backend, venv, systemd-Service, Start
    dlg_show_summary             # Zeige Zusammenfassung der Installation an
}

# ------------------------------------------------------------------------------
# UNATTENDED-Variable initialisieren, falls nicht gesetzt
: "${UNATTENDED:=0}"

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
  --debug, -d                        Aktiviere den Debug-Modus für detaillierte Ausgaben
  --firewall, -f                     Konfiguriere die Firewall automatisch ohne nachzufragen
  --help, -h, --hilfe                Zeigt diese Hilfe an

EOF
}

# Hauptfunktion starten
main
