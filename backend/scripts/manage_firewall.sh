#!/bin/bash
# ---------------------------------------------------------------------------
# manage_firewall.sh
# ---------------------------------------------------------------------------
# Funktion: Verwaltung und Konfiguration der Firewall (z.B. ufw) für die 
# ......... Fotobox (Öffnen/Schließen von Ports, Statusabfrage, Policy-Check)
# ......... für Ubuntu/Debian-basierte Systeme, muss als root ausgeführt 
# ......... werden.
# ......... 
# ---------------------------------------------------------------------------
# HINWEIS: Dieses Skript ist Bestandteil der Backend-Logik und darf nur im
# Unterordner 'backend/scripts/' abgelegt werden 
# ---------------------------------------------------------------------------
# POLICY-HINWEIS: Dieses Skript ist ein reines Funktions-/Modulskript und 
# enthält keine main()-Funktion mehr. Die Nutzung als eigenständiges 
# CLI-Programm ist nicht vorgesehen. Die Policy zur main()-Funktion gilt nur 
# für Hauptskripte.
# ---------------------------------------------------------------------------

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_FIREWALL_LOADED=0

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

# Lade alle Basis-Ressourcen ------------------------------------------------
if [ -f "$BASH_DIR/lib_core.sh" ]; then
    source "$BASH_DIR/lib_core.sh"
    load_core_resources || {
        echo "Fehler beim Laden der Kernressourcen."
        exit 1
    }
else
    echo "Fehler: Zentrale Bibliothek lib_core.sh nicht gefunden!"
    exit 1
fi
# ===========================================================================

# ===========================================================================
# Globale Konstanten (Vorgaben und Defaults für die Installation)
# ===========================================================================
# Die meisten globalen Konstanten werden bereits durch lib_core.sh gesetzt.
# bereitgestellt. Hier definieren wir nur Konstanten, die noch nicht durch 
# lib_core.sh gesetzt wurden oder die speziell für die Installation 
# überschrieben werden müssen.
# ---------------------------------------------------------------------------
# Lokale Aliase für bessere Lesbarkeit
: "${HTTP_PORT:=$DEFAULT_HTTP_PORT}"
: "${HTTPS_PORT:=$DEFAULT_HTTPS_PORT}"
: "${CONFIG_FILE:=$DEFAULT_CONFIG_FILE}"

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

detect_firewall() {
    # -------------------------------------------------------------------------
    # detect_firewall
    # -------------------------------------------------------------------------
    # Funktion: Erkennt das auf dem System installierte Firewall-System
    # Rückgabe: String mit Namen des Firewall-Systems oder "none"
    # Fehlercode: 0=Erfolg, 1=Fehler
    
    if command -v ufw >/dev/null 2>&1; then
        echo "ufw"
        return 0
    elif command -v firewalld >/dev/null 2>&1; then
        echo "firewalld"
        return 0
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
        return 0
    else
        echo "none"
        return 1
    fi
}

check_root() {
    # -------------------------------------------------------------------------
    # check_root
    # -------------------------------------------------------------------------
    # Funktion: Prüft, ob das Skript mit Root-Rechten ausgeführt wird
    # Rückgabe: 0=Root-Rechte vorhanden, 1=Keine Root-Rechte
    
    if [ "$(id -u)" -ne 0 ]; then
        print_error "Dieses Skript muss mit Root-Rechten ausgeführt werden (sudo)."
        return 1
    fi
    return 0
}

read_config() {
    # -------------------------------------------------------------------------
    # read_config
    # -------------------------------------------------------------------------
    # Funktion: Liest Konfigurationswerte aus der Fotobox-Konfiguration
    # Parameter: $1 = Konfigurationsschlüssel
    # Rückgabe: Wert des Konfigurationsschlüssels oder leerer String
    
    local key="$1"
    local value=""
    
    # Prüfe, ob die Konfigurationsdatei existiert
    if [ -f "$CONFIG_FILE" ]; then
        # Extrahiere Wert (einfache Version, kann durch komplexere ersetzt werden)
        value=$(grep -E "^$key\s*=" "$CONFIG_FILE" | cut -d '=' -f 2 | tr -d '[:space:]')
    fi
    
    echo "$value"
}

get_required_ports() {
    # -------------------------------------------------------------------------
    # get_required_ports
    # -------------------------------------------------------------------------
    # Funktion: Ermittelt die für die Fotobox benötigten Ports
    # Rückgabe: Liste der Ports (durch Leerzeichen getrennt)
    
    local http_port=$(read_config "http_port")
    local https_port=$(read_config "https_port")
    
    # Fallback auf Standardports, falls nicht in der Konfiguration definiert
    [ -z "$http_port" ] && http_port="$DEFAULT_HTTP_PORT"
    [ -z "$https_port" ] && https_port="$DEFAULT_HTTPS_PORT"
    
    # Wenn Debug-Modus aktiv (lokal oder global), zusätzliche Debug-Informationen
    if [ "$DEBUG_MOD_GLOBAL" = "1" ] || [ "$DEBUG_MOD_LOCAL" = "1" ]; then
        print_debug "HTTP-Port: $http_port, HTTPS-Port: $https_port"
    fi
    
    echo "$http_port $https_port"
}

# ------------------------------------------------------------------------------
# Firewall-spezifische Funktionen
# ------------------------------------------------------------------------------

ufw_setup() {
    # -------------------------------------------------------------------------
    # ufw_setup
    # -------------------------------------------------------------------------
    # Funktion: Richtet UFW-Firewall für Fotobox ein
    # Parameter: $* = Liste der zu öffnenden Ports
    # Rückgabe: 0=Erfolg, 1=Fehler
    
    print_step "Konfiguriere UFW-Firewall für Fotobox"
    
    # Stelle sicher, dass UFW installiert ist
    if ! command -v ufw >/dev/null 2>&1; then
        print_error "UFW ist nicht installiert. Installation mit: apt-get install ufw"
        return 1
    fi
    
    # Aktiviere UFW, falls noch nicht aktiv
    if ! ufw status | grep -q "Status: active"; then
        print_info "Aktiviere UFW-Firewall..."
        echo "y" | ufw enable >/dev/null 2>&1
    fi
    
    # Öffne die angegebenen Ports
    for port in "$@"; do
        print_info "Öffne Port $port für TCP-Verbindungen..."
        ufw allow "$port/tcp" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_success "Port $port erfolgreich geöffnet"
        else
            print_warning "Problem beim Öffnen von Port $port"
        fi
    done
    
    print_success "UFW-Firewall für Fotobox konfiguriert"
    return 0
}

firewalld_setup() {
    # -------------------------------------------------------------------------
    # firewalld_setup
    # -------------------------------------------------------------------------
    # Funktion: Richtet FirewallD für Fotobox ein
    # Parameter: $* = Liste der zu öffnenden Ports
    # Rückgabe: 0=Erfolg, 1=Fehler
    
    print_step "Konfiguriere FirewallD für Fotobox"
    
    # Stelle sicher, dass FirewallD installiert ist
    if ! command -v firewall-cmd >/dev/null 2>&1; then
        print_error "FirewallD ist nicht installiert. Installation mit: yum install firewalld"
        return 1
    fi
    
    # Stelle sicher, dass FirewallD läuft
    if ! systemctl is-active --quiet firewalld; then
        print_info "Starte FirewallD-Dienst..."
        systemctl start firewalld
    fi
    
    # Öffne die angegebenen Ports
    for port in "$@"; do
        print_info "Öffne Port $port für TCP-Verbindungen..."
        firewall-cmd --zone=public --add-port="$port/tcp" --permanent >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_success "Port $port erfolgreich geöffnet"
        else
            print_warning "Problem beim Öffnen von Port $port"
        fi
    done
    
    # Lade Firewall-Regeln neu
    firewall-cmd --reload >/dev/null 2>&1
    
    print_success "FirewallD für Fotobox konfiguriert"
    return 0
}

iptables_setup() {
    # -------------------------------------------------------------------------
    # iptables_setup
    # -------------------------------------------------------------------------
    # Funktion: Richtet iptables für Fotobox ein
    # Parameter: $* = Liste der zu öffnenden Ports
    # Rückgabe: 0=Erfolg, 1=Fehler
    
    print_step "Konfiguriere iptables für Fotobox"
    
    # Stelle sicher, dass iptables installiert ist
    if ! command -v iptables >/dev/null 2>&1; then
        print_error "iptables ist nicht installiert."
        return 1
    fi
    
    # Öffne die angegebenen Ports
    for port in "$@"; do
        print_info "Öffne Port $port für TCP-Verbindungen..."
        # Füge nur eine Regel hinzu, falls sie nicht schon existiert
        if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1; then
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            if [ $? -eq 0 ]; then
                print_success "Port $port erfolgreich geöffnet"
            else
                print_warning "Problem beim Öffnen von Port $port"
            fi
        else
            print_info "Port $port ist bereits geöffnet"
        fi
    done
    
    # Speichere Regeln persistent (falls iptables-persistent installiert ist)
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1
    else
        print_warning "netfilter-persistent ist nicht installiert. Firewall-Regeln werden bei Neustart zurückgesetzt."
    fi
    
    print_success "iptables für Fotobox konfiguriert"
    return 0
}

setup_firewall() {
    # -------------------------------------------------------------------------
    # setup_firewall
    # -------------------------------------------------------------------------
    # Funktion: Richtet Firewall-Regeln für Fotobox ein
    # Rückgabe: 0=Erfolg, 1=Fehler
    
    local firewall_type=$(detect_firewall)
    local ports=$(get_required_ports)
    
    case "$firewall_type" in
        "ufw")
            ufw_setup $ports
            return $?
            ;;
        "firewalld")
            firewalld_setup $ports
            return $?
            ;;
        "iptables")
            iptables_setup $ports
            return $?
            ;;
        "none")
            print_warning "Kein unterstütztes Firewall-System gefunden."
            return 1
            ;;
        *)
            print_error "Unbekannter Firewall-Typ: $firewall_type"
            return 1
            ;;
    esac
}

status_firewall() {
    # -------------------------------------------------------------------------
    # status_firewall
    # -------------------------------------------------------------------------
    # Funktion: Zeigt den Status der Firewall und der Fotobox-bezogenen Regeln
    # Rückgabe: 0=Erfolg, 1=Fehler
    
    local firewall_type=$(detect_firewall)
    local ports=$(get_required_ports)
    
    print_step "Firewall-Status für Fotobox:"
    
    case "$firewall_type" in
        "ufw")
            print_info "Firewall-System: UFW"
            ufw status | grep -i "Status:" | sed 's/Status:/Firewall-Status:/'
            
            # Zeige Status der Fotobox-Ports
            for port in $ports; do
                if ufw status | grep -q "$port/tcp"; then
                    print_success "Port $port ist geöffnet"
                else
                    print_warning "Port $port ist NICHT geöffnet"
                fi
            done
            ;;
        "firewalld")
            print_info "Firewall-System: FirewallD"
            systemctl is-active --quiet firewalld && echo "Firewall-Status: aktiv" || echo "Firewall-Status: inaktiv"
            
            # Zeige Status der Fotobox-Ports
            for port in $ports; do
                if firewall-cmd --list-ports | grep -q "$port/tcp"; then
                    print_success "Port $port ist geöffnet"
                else
                    print_warning "Port $port ist NICHT geöffnet"
                fi
            done
            ;;
        "iptables")
            print_info "Firewall-System: iptables"
            
            # Zeige Status der Fotobox-Ports
            for port in $ports; do
                if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1; then
                    print_success "Port $port ist geöffnet"
                else
                    print_warning "Port $port ist NICHT geöffnet"
                fi
            done
            ;;
        "none")
            print_warning "Kein unterstütztes Firewall-System gefunden."
            return 1
            ;;
        *)
            print_error "Unbekannter Firewall-Typ: $firewall_type"
            return 1
            ;;
    esac
    
    return 0
}

reset_firewall() {
    # -------------------------------------------------------------------------
    # reset_firewall
    # -------------------------------------------------------------------------
    # Funktion: Entfernt die Fotobox-spezifischen Firewall-Regeln
    # Rückgabe: 0=Erfolg, 1=Fehler
    
    local firewall_type=$(detect_firewall)
    local ports=$(get_required_ports)
    
    print_step "Entferne Fotobox-Firewall-Regeln"
    
    case "$firewall_type" in
        "ufw")
            # Entferne Regeln für die angegebenen Ports
            for port in $ports; do
                print_info "Entferne Regel für Port $port..."
                ufw delete allow "$port/tcp" >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    print_success "Regel für Port $port entfernt"
                else
                    print_warning "Problem beim Entfernen der Regel für Port $port"
                fi
            done
            ;;
        "firewalld")
            # Entferne Regeln für die angegebenen Ports
            for port in $ports; do
                print_info "Entferne Regel für Port $port..."
                firewall-cmd --zone=public --remove-port="$port/tcp" --permanent >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    print_success "Regel für Port $port entfernt"
                else
                    print_warning "Problem beim Entfernen der Regel für Port $port"
                fi
            done
            
            # Lade Firewall-Regeln neu
            firewall-cmd --reload >/dev/null 2>&1
            ;;
        "iptables")
            # Entferne Regeln für die angegebenen Ports
            for port in $ports; do
                print_info "Entferne Regel für Port $port..."
                if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1; then
                    iptables -D INPUT -p tcp --dport "$port" -j ACCEPT
                    if [ $? -eq 0 ]; then
                        print_success "Regel für Port $port entfernt"
                    else
                        print_warning "Problem beim Entfernen der Regel für Port $port"
                    fi
                else
                    print_info "Keine Regel für Port $port gefunden"
                fi
            done
            
            # Speichere Regeln persistent (falls iptables-persistent installiert)
            if command -v netfilter-persistent >/dev/null 2>&1; then
                netfilter-persistent save >/dev/null 2>&1
            fi
            ;;
        "none")
            print_warning "Kein unterstütztes Firewall-System gefunden."
            return 1
            ;;
        *)
            print_error "Unbekannter Firewall-Typ: $firewall_type"
            return 1
            ;;
    esac
    
    print_success "Fotobox-Firewall-Regeln wurden entfernt"
    return 0
}

# ------------------------------------------------------------------------------
# Parameter-Verarbeitung und Hauptfunktion
# ------------------------------------------------------------------------------

show_help() {
    echo "Verwendung: $0 [OPTIONEN]"
    echo ""
    echo "Verwaltet und konfiguriert die Firewall für die Fotobox."
    echo ""
    echo "Optionen:"
    echo "  --setup, -s       Richtet Firewall-Regeln für die Fotobox ein"
    echo "  --reset, -r       Entfernt Fotobox-spezifische Firewall-Regeln"
    echo "  --status          Zeigt den Status der Firewall und der Fotobox-Regeln"
    echo "  --update, -u      Aktualisiert die Firewall-Regeln (entfernt alte und fügt neue hinzu)"
    echo "  --debug, -d       Aktiviert den Debug-Modus für detaillierte Ausgaben"
    echo "  --help, -h        Zeigt diese Hilfe an"
    echo ""
    echo "Beispiele:"
    echo "  $0 --setup        # Richtet Firewall-Regeln ein"
    echo "  $0 --status       # Zeigt den Status der Firewall-Regeln"
    echo ""
}

# Hauptfunktion
main() {
    local action=""
    
    # Parameter verarbeiten
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --setup|-s)
                action="setup"
                shift
                ;;
            --reset|-r)
                action="reset"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --update|-u)
                action="update"
                shift
                ;;
            --debug|-d)
                DEBUG_MOD_LOCAL=1
                shift
                ;;
            --unattended)
                UNATTENDED=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unbekannter Parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Prüfe Root-Rechte für alle Aktionen außer Hilfe und Status
    if [ "$action" != "status" ] && [ "$action" != "" ]; then
        check_root || exit 1
    fi
    
    # Führe die angeforderte Aktion aus
    case "$action" in
        "setup")
            setup_firewall
            exit $?
            ;;
        "reset")
            reset_firewall
            exit $?
            ;;
        "status")
            status_firewall
            exit $?
            ;;
        "update")
            # Bei Update zuerst alte Regeln entfernen, dann neue hinzufügen
            reset_firewall
            setup_firewall
            exit $?
            ;;
        "")
            # Wenn keine Aktion angegeben ist, interaktiven Modus starten
            if [ "$UNATTENDED" -eq 1 ]; then
                print_error "Im nicht-interaktiven Modus muss eine Aktion angegeben werden."
                exit 1
            fi
            
            echo "Fotobox Firewall-Verwaltung"
            echo "==========================="
            echo "Bitte wählen Sie eine Aktion:"
            echo "1) Firewall-Regeln einrichten"
            echo "2) Firewall-Status anzeigen"
            echo "3) Firewall-Regeln zurücksetzen"
            echo "4) Firewall-Regeln aktualisieren"
            echo "q) Beenden"
            
            read -p "Auswahl: " choice
            case "$choice" in
                1) setup_firewall ;;
                2) status_firewall ;;
                3) reset_firewall ;;
                4) reset_firewall && setup_firewall ;;
                q|Q) exit 0 ;;
                *) print_error "Ungültige Auswahl" ;;
            esac
            ;;
    esac
}

# Skript ausführen, Parameter weitergeben
main "$@"
