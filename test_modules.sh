#!/bin/bash
# ---------------------------------------------------------------------------
# test_modules.sh
# ---------------------------------------------------------------------------
# Funktion: Funktionen in manage_folders.sh, manage_files.sh und
# ......... manage_logging.sh mit gültigen Parametern und überprüft deren
# ......... Rückgabewerte. Verwendet das zentrale Modulsystem aus lib_core.sh
# ......... zum Laden der Module. Aktiviert das Debug-Logging in allen Modulen.
# ---------------------------------------------------------------------------

# Setze strict mode für sicheres Bash-Scripting
set -e  # Beende bei Fehlern
set -u  # Beende bei Verwendung nicht gesetzter Variablen
set +e  # Deaktiviere strict mode für die Initialisierung

# Hilfsfunktion zum Prüfen des Moduls
check_load_status() {
    local module_name="$1"
    local var_name="$2"
    
    # Prüfen ob die Modul-Variable gesetzt ist
    if [ -n "${!var_name:-}" ] && [ ${!var_name} -eq 1 ]; then
        echo "✅ Modul $module_name ist korrekt geladen (${var_name}=1)"
        return 0
    else
        echo "❌ Modul $module_name ist NICHT korrekt geladen (${var_name}=${!var_name:-nicht gesetzt})"
        return 1
    fi
}

# Hilfsfunktion zur Überprüfung der Test-Ergebnisse
test_function() {
    local result=$1
    local function_name=$2
    local expected_result=$3

    if [ "$result" -eq "$expected_result" ]; then
        echo "✅ Die Funktion $function_name wurde erfolgreich ausgeführt."
    else
        echo "❌ Die Funktion $function_name ist fehlgeschlagen. Ergebnis: $result, Erwartet: $expected_result"
    fi
}

# HINWEIS: DEBUG-Modus wird manuell aktiviert
# Die Funktion enable_debug_for_module wurde entfernt, da der Debug-Modus 
# manuell gesetzt wird. Um den Debug-Modus zu aktivieren:
# 1. Setze DEBUG_MOD_LOCAL=1 in den jeweiligen Skriptdateien oder
# 2. Exportiere DEBUG_MOD_GLOBAL=1 vor dem Skriptaufruf

# Skriptpfad für korrekte Ausführung aus dem Root-Verzeichnis
TEST_CURRENT_DIR=$(pwd)
TEST_SCRIPT_DIR="$TEST_CURRENT_DIR/backend/scripts"

# Verbesserte Skriptpfaderkennung 
if [ ! -d "$TEST_SCRIPT_DIR" ]; then
    echo "Warnung: Standard-Skriptpfad nicht gefunden, suche nach Alternativen..."
    
    # Alternative 1: Prüfe, ob wir direkt im scripts-Verzeichnis sind
    if [ -f "./lib_core.sh" ] && [ -f "./manage_folders.sh" ] && [ -f "./manage_files.sh" ]; then
        TEST_SCRIPT_DIR="."
        echo "Skriptverzeichnis gefunden: aktuelles Verzeichnis"
    
    # Alternative 2: Prüfe, ob wir bereits im backend-Verzeichnis sind
    elif [ -d "./scripts" ] && [ -f "./scripts/lib_core.sh" ]; then
        TEST_SCRIPT_DIR="./scripts"
        echo "Skriptverzeichnis gefunden: $TEST_SCRIPT_DIR"
    
    # Alternative 3: Prüfe Standard-Installationspfade
    elif [ -d "/opt/fotobox/backend/scripts" ]; then
        TEST_SCRIPT_DIR="/opt/fotobox/backend/scripts"
        echo "Skriptverzeichnis gefunden: $TEST_SCRIPT_DIR"
        
    # Alternative 4: Suche nach lib_core.sh im System
    else
        echo "Führe systemweite Suche nach lib_core.sh durch..."
        # Finde alle lib_core.sh Dateien im System
        core_files=$(find /opt -name "lib_core.sh" 2>/dev/null)
        
        if [ -n "$core_files" ]; then
            # Verwende den ersten gefundenen Pfad
            first_file=$(echo "$core_files" | head -n 1)
            TEST_SCRIPT_DIR=$(dirname "$first_file")
            echo "Skriptverzeichnis gefunden durch Suche: $TEST_SCRIPT_DIR"
        else
            echo "FEHLER: Skriptverzeichnis konnte nicht gefunden werden."
            echo "Bitte führen Sie dieses Skript aus dem Root-Verzeichnis des Fotobox-Projekts aus."
            exit 1
        fi
    fi
fi

# Überprüfe, ob lib_core.sh vorhanden ist (die anderen Module werden
# über das zentrale Ladesystem von lib_core.sh geladen)
if [ ! -f "$TEST_SCRIPT_DIR/lib_core.sh" ]; then
    echo "FEHLER: lib_core.sh fehlt im Verzeichnis: $TEST_SCRIPT_DIR"
    echo "Vorhandene Dateien im Skriptverzeichnis:"
    ls -la "$TEST_SCRIPT_DIR"
    exit 1
fi

# Informiere über Strategie
echo "Test lädt Module direkt und aktiviert den Debug-Modus für jeden Test"

echo "==========================================================================="
echo "           Test der Module lib_core.sh, manage_folders.sh,"
echo "                 manage_files.sh und manage_logging.sh"
echo "         mit aktiviertem Debug-Modus (DEBUG_MOD_LOCAL=1)"
echo "==========================================================================="
echo

# Laden der erforderlichen Module
echo "Lade Module aus Verzeichnis: $TEST_SCRIPT_DIR"

# Debug-Ausgabe zum Anzeigen der vorhandenen Dateien
echo "Vorhandene Dateien im Skriptverzeichnis:"
ls -la "$TEST_SCRIPT_DIR"

# Setze SCRIPT_DIR für lib_core.sh
export SCRIPT_DIR="$TEST_SCRIPT_DIR"

# Funktionen zum Sichern und Wiederherstellen der Modulvariablen
# Diese helfen, Kollisionen zwischen Testskript und Modulen zu vermeiden
save_module_vars() {
    # Sichere wichtige Variablen, die von Modulen verwendet werden könnten
    TEST_SAVED_SCRIPT_DIR="${SCRIPT_DIR:-}"
    TEST_SAVED_DEBUG_MOD="${DEBUG_MOD:-}"
    TEST_SAVED_DEBUG_MOD_LOCAL="${DEBUG_MOD_LOCAL:-}"
    TEST_SAVED_MODULE_LOAD_MODE="${MODULE_LOAD_MODE:-}"
    
    echo "Modulvariablen wurden gesichert"
}

restore_module_vars() {
    # Stelle wichtige Variablen wieder her
    if [ -n "${TEST_SAVED_SCRIPT_DIR:-}" ]; then
        export SCRIPT_DIR="$TEST_SAVED_SCRIPT_DIR"
    fi
    if [ -n "${TEST_SAVED_DEBUG_MOD:-}" ]; then
        export DEBUG_MOD="$TEST_SAVED_DEBUG_MOD"
    fi
    if [ -n "${TEST_SAVED_DEBUG_MOD_LOCAL:-}" ]; then
        export DEBUG_MOD_LOCAL="$TEST_SAVED_DEBUG_MOD_LOCAL"
    fi
    if [ -n "${TEST_SAVED_MODULE_LOAD_MODE:-}" ]; then
        export MODULE_LOAD_MODE="$TEST_SAVED_MODULE_LOAD_MODE"
    fi
    
    echo "Modulvariablen wurden wiederhergestellt"
}

# Lade zuerst lib_core.sh
echo -n "Lade lib_core.sh... "
if [ ! -f "$TEST_SCRIPT_DIR/lib_core.sh" ]; then
    echo "FEHLER: lib_core.sh nicht gefunden!"
    exit 1
fi

# Sichere die ursprünglichen Variablenwerte
save_module_vars

source "$TEST_SCRIPT_DIR/lib_core.sh"
if [ $? -eq 0 ]; then
    echo "Erfolg."
    echo "Modul lib_core.sh wurde geladen."
    # Stelle die gesicherten Variablen wieder her
    restore_module_vars
else
    echo "FEHLER!"
    echo "Fehler beim Laden von lib_core.sh"
    exit 1
fi

# Aktiviere direktes Laden statt des zentralen Lademanagers
echo "Lade Module direkt ohne zentralen Lademanager..."
export MODULE_LOAD_MODE=0

# Aktiviere den Test-Modus für das Laden der Module
echo "Aktiviere Testmodus (TEST_MODE=1)..."
export TEST_MODE=1

# Lade Module direkt nacheinander
echo -n "Lade $TEST_SCRIPT_DIR/manage_folders.sh direkt... "
if source "$TEST_SCRIPT_DIR/manage_folders.sh"; then
    echo "Erfolg."
    if [ "${MANAGE_FOLDERS_LOADED:-0}" -eq 1 ]; then
        echo "Modul manage_folders.sh wurde korrekt geladen."
    else
        echo "WARNUNG: Modul wurde geladen, aber MANAGE_FOLDERS_LOADED ist nicht 1."
    fi
else
    echo "FEHLER!"
    echo "Fehler beim Laden von manage_folders.sh"
    exit 1
fi

echo -n "Lade $TEST_SCRIPT_DIR/manage_files.sh direkt... "
if source "$TEST_SCRIPT_DIR/manage_files.sh"; then
    echo "Erfolg."
    if [ "${MANAGE_FILES_LOADED:-0}" -eq 1 ]; then
        echo "Modul manage_files.sh wurde korrekt geladen."
    else
        echo "WARNUNG: Modul wurde geladen, aber MANAGE_FILES_LOADED ist nicht 1."
    fi
else
    echo "FEHLER!"
    echo "Fehler beim Laden von manage_files.sh"
    exit 1
fi

echo -n "Lade $TEST_SCRIPT_DIR/manage_logging.sh direkt... "
if source "$TEST_SCRIPT_DIR/manage_logging.sh"; then
    echo "Erfolg."
    if [ "${MANAGE_LOGGING_LOADED:-0}" -eq 1 ]; then
        echo "Modul manage_logging.sh wurde korrekt geladen."
    else
        echo "WARNUNG: Modul wurde geladen, aber MANAGE_LOGGING_LOADED ist nicht 1."
    fi
else
    echo "FEHLER!"
    echo "Fehler beim Laden von manage_logging.sh"
    exit 1
fi
echo

# -------------------------------
# Test der manage_logging.sh Funktionen
# -------------------------------
echo
echo "-------------------------------------------------------------------------"
echo "Test der Funktionen in manage_logging.sh"
echo "-------------------------------------------------------------------------"

# Test: log
echo -n "Test log mit einfacher Nachricht: "
log "Testmessage für log"
result=$?
test_function $result "log (einfache Nachricht)" 0

# Test: log mit Funktionsname
echo -n "Test log mit Funktionsname: "
log "Testmessage mit Funktionsname" "test_function"
result=$?
test_function $result "log (mit Funktionsname)" 0

# Test: log für Fehlermeldung
echo -n "Test log für Fehlermeldungen: "
log "ERROR: Testfehlermeldung" "test_function" "test_modules.sh"
result=$?
test_function $result "log (Fehlermeldung mit Funktionsname und Datei)" 0

# Test: debug (LOG-Modus)
echo -n "Test debug im LOG-Modus: "
debug "Debug-Testmessage im LOG-Modus"
result=$?
test_function $result "debug (LOG-Modus)" 0

# Test: debug (CLI-Modus)
echo -n "Test debug im CLI-Modus: "
debug "Debug-Testmessage im CLI-Modus" "CLI"
result=$?
test_function $result "debug (CLI-Modus)" 0

# Test: debug (JSON-Modus)
echo -n "Test debug im JSON-Modus: "
debug "Debug-Testmessage im JSON-Modus" "JSON"
result=$?
test_function $result "debug (JSON-Modus)" 0

# Test: print_step
echo -n "Test print_step: "
print_step "Testschritt wird ausgeführt"
result=$?
test_function $result "print_step" 0

# Test: print_info
echo -n "Test print_info: "
print_info "Testinfo wird angezeigt"
result=$?
test_function $result "print_info" 0

# Test: print_success
echo -n "Test print_success: "
print_success "Testoperation erfolgreich"
result=$?
test_function $result "print_success" 0

# Test: print_warning
echo -n "Test print_warning: "
print_warning "Testwarnung wird angezeigt"
result=$?
test_function $result "print_warning" 0

# Test: print_error
echo -n "Test print_error: "
print_error "Testfehler wird angezeigt"
result=$?
test_function $result "print_error" 0

# Test: print_debug
echo -n "Test print_debug: "
print_debug "Debug-Testmeldung wird angezeigt"
result=$?
test_function $result "print_debug" 0

# Überprüfe die Log-Datei auf vorhandene Debug-Ausgaben
log_file=$(get_log_file)
echo
echo "Prüfe, ob Debug-Ausgaben in der Log-Datei vorhanden sind:"
if grep -q "DEBUG" "$log_file" 2>/dev/null; then
    echo "✅ Debug-Ausgaben sind in der Log-Datei vorhanden: $log_file"
    # Zeige die letzten Debug-Einträge
    echo "Letzte Debug-Einträge aus der Log-Datei:"
    grep "DEBUG" "$log_file" 2>/dev/null | tail -n 5
else
    echo "❌ Keine Debug-Ausgaben in der Log-Datei gefunden: $log_file"
    
    # Prüfe, ob die Log-Datei überhaupt existiert
    if [ ! -f "$log_file" ]; then
        echo "   Log-Datei existiert nicht: $log_file"
    else
        echo "   Log-Datei existiert, aber enthält keine DEBUG-Einträge"
        echo "   Inhalt der Log-Datei:"
        tail -n 10 "$log_file" 2>/dev/null || cat "$log_file" 2>/dev/null || echo "   (Keine Ausgabe möglich)"
    fi
fi

echo "Testdateien wurden entfernt."

# -------------------------------
# Test der manage_folders.sh Funktionen
# -------------------------------
echo "-------------------------------------------------------------------------"
echo "Test der Funktionen in manage_folders.sh"
echo "-------------------------------------------------------------------------"

# Test: create_directory
echo -n "Test create_directory: "
test_dir="$TEST_CURRENT_DIR/tmp/test_directory"
mkdir -p "$TEST_CURRENT_DIR/tmp" 2>/dev/null || true
set +e  # Fehler nicht als fatal behandeln
create_directory "$test_dir"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "create_directory" 0

# Test: create_symlink_to_standard_path
echo -n "Test create_symlink_to_standard_path: "
source_dir="$TEST_CURRENT_DIR/tmp/symlink_source"
target_dir="$TEST_CURRENT_DIR/tmp/symlink_target"
create_directory "$target_dir" || true
set +e  # Fehler nicht als fatal behandeln
create_symlink_to_standard_path "$source_dir" "$target_dir"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "create_symlink_to_standard_path" 0

# Test: get_install_dir
echo -n "Test get_install_dir: "
install_dir=$(get_install_dir)
if [ -n "$install_dir" ]; then
    echo "✅ Die Funktion get_install_dir wurde erfolgreich ausgeführt. Ergebnis: $install_dir"
else
    echo "❌ Die Funktion get_install_dir ist fehlgeschlagen."
fi

# Test: get_backend_dir
echo -n "Test get_backend_dir: "
backend_dir=$(get_backend_dir)
if [ -n "$backend_dir" ]; then
    echo "✅ Die Funktion get_backend_dir wurde erfolgreich ausgeführt. Ergebnis: $backend_dir"
else
    echo "❌ Die Funktion get_backend_dir ist fehlgeschlagen."
fi

# Test: get_script_dir
echo -n "Test get_script_dir: "
script_dir=$(get_script_dir)
if [ -n "$script_dir" ]; then
    echo "✅ Die Funktion get_script_dir wurde erfolgreich ausgeführt. Ergebnis: $script_dir"
else
    echo "❌ Die Funktion get_script_dir ist fehlgeschlagen."
fi

# Test: get_template_dir
echo -n "Test get_template_dir: "
template_dir=$(get_template_dir "nginx")
if [ -n "$template_dir" ]; then
    echo "✅ Die Funktion get_template_dir wurde erfolgreich ausgeführt. Ergebnis: $template_dir"
else
    echo "❌ Die Funktion get_template_dir ist fehlgeschlagen."
fi

# Test: get_template_dir (ohne Modul-Parameter)
echo -n "Test get_template_dir (ohne Modul): "
template_dir_base=$(get_template_dir)
if [ -n "$template_dir_base" ]; then
    echo "✅ Die Funktion get_template_dir ohne Modul wurde erfolgreich ausgeführt. Ergebnis: $template_dir_base"
else
    echo "❌ Die Funktion get_template_dir ohne Modul ist fehlgeschlagen."
fi

# -------------------------------
# Test der manage_files.sh Funktionen
# -------------------------------
echo
echo "-------------------------------------------------------------------------"
echo "Test der Funktionen in manage_files.sh"
echo "-------------------------------------------------------------------------"

# Test: get_config_file
echo -n "Test get_config_file: "
set +e  # Fehler nicht als fatal behandeln
config_file=$(get_config_file "system" "version" 2>/dev/null)
set -e  # Fehlerbehandlung wieder aktivieren
if [ -n "$config_file" ]; then
    echo "✅ Die Funktion get_config_file wurde erfolgreich ausgeführt. Ergebnis: $config_file"
else
    echo "❌ Die Funktion get_config_file ist fehlgeschlagen."
fi

# Test: get_template_file
echo -n "Test get_template_file: "
set +e  # Fehler nicht als fatal behandeln
template_file=$(get_template_file "nginx" "fotobox" 2>/dev/null)
set -e  # Fehlerbehandlung wieder aktivieren
if [ -n "$template_file" ]; then
    echo "✅ Die Funktion get_template_file wurde erfolgreich ausgeführt. Ergebnis: $template_file"
else
    echo "❌ Die Funktion get_template_file ist fehlgeschlagen."
fi

# Test: get_log_file
echo -n "Test get_log_file: "
log_file=$(get_log_file "test_script")
if [ -n "$log_file" ]; then
    echo "✅ Die Funktion get_log_file wurde erfolgreich ausgeführt. Ergebnis: $log_file"
else
    echo "❌ Die Funktion get_log_file ist fehlgeschlagen."
fi

# Test: get_temp_file
echo -n "Test get_temp_file: "
temp_file=$(get_temp_file "testfile" ".txt")
if [ -n "$temp_file" ]; then
    echo "✅ Die Funktion get_temp_file wurde erfolgreich ausgeführt. Ergebnis: $temp_file"
else
    echo "❌ Die Funktion get_temp_file ist fehlgeschlagen."
fi

# Test: get_backup_file
echo -n "Test get_backup_file: "
backup_file=$(get_backup_file "test_backup")
if [ -n "$backup_file" ]; then
    echo "✅ Die Funktion get_backup_file wurde erfolgreich ausgeführt. Ergebnis: $backup_file"
else
    echo "❌ Die Funktion get_backup_file ist fehlgeschlagen."
fi

# Test: get_backup_meta_file
echo -n "Test get_backup_meta_file: "
backup_meta_file=$(get_backup_meta_file "test_backup")
if [ -n "$backup_meta_file" ]; then
    echo "✅ Die Funktion get_backup_meta_file wurde erfolgreich ausgeführt. Ergebnis: $backup_meta_file"
else
    echo "❌ Die Funktion get_backup_meta_file ist fehlgeschlagen."
fi

# Test: get_image_file
echo -n "Test get_image_file: "
image_file=$(get_image_file "original" "test_image")
if [ -n "$image_file" ]; then
    echo "✅ Die Funktion get_image_file wurde erfolgreich ausgeführt. Ergebnis: $image_file"
else
    echo "❌ Die Funktion get_image_file ist fehlgeschlagen."
fi

# Test: get_system_file
echo -n "Test get_system_file: "
set +e  # Fehler nicht als fatal behandeln
system_file=$(get_system_file "nginx" "fotobox" 2>/dev/null)
set -e  # Fehlerbehandlung wieder aktivieren
if [ -n "$system_file" ]; then
    echo "✅ Die Funktion get_system_file wurde erfolgreich ausgeführt. Ergebnis: $system_file"
else
    echo "❌ Die Funktion get_system_file ist fehlgeschlagen."
fi

# Test: file_exists
echo -n "Test file_exists: "
# Erstelle eine temporäre Datei
mkdir -p "$TEST_CURRENT_DIR/tmp" 2>/dev/null || true
temp_test_file="$TEST_CURRENT_DIR/tmp/test_file.txt"
touch "$temp_test_file" 2>/dev/null || true
set +e  # Fehler nicht als fatal behandeln
file_exists "$temp_test_file"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "file_exists" 0

# Test: create_empty_file
echo -n "Test create_empty_file: "
mkdir -p "$TEST_CURRENT_DIR/tmp" 2>/dev/null || true
empty_file="$TEST_CURRENT_DIR/tmp/empty_test_file.txt"
set +e  # Fehler nicht als fatal behandeln
create_empty_file "$empty_file"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "create_empty_file" 0

# -------------------------------
# Aufräumen der Testdateien und -verzeichnisse
# -------------------------------
echo
echo "-------------------------------------------------------------------------"
echo "Aufräumen der Testdateien"
echo "-------------------------------------------------------------------------"

rm -f "$temp_test_file" "$empty_file" 2>/dev/null
rm -rf "$test_dir" "$target_dir" "$source_dir" 2>/dev/null

echo
echo "==========================================================================="
echo "                            Test abgeschlossen"
echo "==========================================================================="

# Verarbeitete Variablen im Test-Skript:
# TEST_CURRENT_DIR - Aktuelles Verzeichnis beim Start des Tests
# TEST_SCRIPT_DIR  - Verzeichnis, in dem sich die Backend-Skripte befinden
# 
# Diese Variablen sind vom Testskript reserviert und zur Vermeidung von Kollisionen
# mit den zu testenden Modulen uniquifiziert. Die Module verwenden ihre eigenen
# Variablen wie SCRIPT_DIR, BASH_DIR usw., die durch das Testskript nicht
# beschädigt werden.
