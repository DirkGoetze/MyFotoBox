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

echo "Teste load_module für manage_folders:"
load_module "manage_folders"
echo "Status: $?"

echo "Teste load_module für manage_logging:"
load_module "manage_logging"
echo "Status: $?"

echo "=== Test mit MODULE_LOAD_MODE=1 (Alle) ==="
export MODULE_LOAD_MODE=1
source "$BASH_DIR/lib_core.sh"

echo "Teste load_module für manage_folders:"
load_module "manage_folders"
echo "Status: $?"

echo "Teste load_module für manage_logging:"
load_module "manage_logging"
echo "Status: $?"

echo "=== Test der manage_logging Funktionen ==="
print_warning "Dies ist eine Test-Warnung"
print_info "Dies ist eine Test-Information"
print_success "Dies ist eine Test-Erfolgsmeldung"
print_error "Dies ist eine Test-Fehlermeldung"

echo "=== Test abgeschlossen ==="
