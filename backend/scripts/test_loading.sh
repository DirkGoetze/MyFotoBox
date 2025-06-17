#!/bin/bash
# ------------------------------------------------------------------------------
# test_loading.sh
# ------------------------------------------------------------------------------
# Funktion: Testet das Hybrid-Ladesystem der Fotobox-Skripte
# ------------------------------------------------------------------------------

# Setze Debug-Modus
export DEBUG_MOD_GLOBAL=1

# Skript- und BASH-Verzeichnis festlegen
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BASH_DIR="${BASH_DIR:-$SCRIPT_DIR}"

echo "=== Test mit MODULE_LOAD_MODE=0 (Einzeln) ==="
export MODULE_LOAD_MODE=0
source "$BASH_DIR/lib_core.sh"
# Führe chk_resources aus, um Fallback-Funktionen zu initialisieren
chk_resources

echo "Teste load_module für manage_folders:"
load_module "manage_folders"
echo "Status: $?"

echo "Teste load_module für manage_logging:"
load_module "manage_logging"
echo "Status: $?"

echo "=== Test mit MODULE_LOAD_MODE=1 (Alle) ==="
export MODULE_LOAD_MODE=1
source "$BASH_DIR/lib_core.sh"
# Hier explizit load_core_resources aufrufen
load_core_resources

echo "Teste load_module für manage_folders:"
load_module "manage_folders"
echo "Status: $?"

echo "Teste load_module für manage_logging:"
load_module "manage_logging"
echo "Status: $?"

echo "=== Test der manage_logging Funktionen ==="
# Überprüfe, ob die Ausgabe-Funktionen verfügbar sind
if ! type print_warning &>/dev/null; then
    echo "Ausgabefunktionen nicht gefunden, definiere sie explizit..."
    
    # Farb-Konstanten für Ausgaben falls nicht definiert
    : "${COLOR_RESET:=\033[0m}"
    : "${COLOR_RED:=\033[1;31m}" 
    : "${COLOR_GREEN:=\033[1;32m}"
    : "${COLOR_YELLOW:=\033[1;33m}"
    : "${COLOR_BLUE:=\033[1;34m}"
    : "${COLOR_CYAN:=\033[1;36m}"
    
    # Minimale Ausgabefunktionen definieren
    print_warning() { echo -e "${COLOR_YELLOW}  → [WARN]${COLOR_RESET} $*"; }
    print_info() { echo -e "  $*"; }
    print_success() { echo -e "${COLOR_GREEN}  → [OK]${COLOR_RESET} $*"; }
    print_error() { echo -e "${COLOR_RED}  → [ERROR]${COLOR_RESET} $*" >&2; }
fi

print_warning "Dies ist eine Test-Warnung"
print_info "Dies ist eine Test-Information"
print_success "Dies ist eine Test-Erfolgsmeldung"
print_error "Dies ist eine Test-Fehlermeldung"

echo "=== Test abgeschlossen ==="
