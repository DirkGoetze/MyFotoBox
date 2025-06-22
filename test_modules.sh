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

# Aktiviere Debug-Modus für alle Tests
export DEBUG_MOD_LOCAL=1

# Informiere über Strategie
echo "==========================================================================="
echo "           Test der Module lib_core.sh, manage_folders.sh,"
echo "                 manage_files.sh und manage_logging.sh"
echo "         mit aktiviertem Debug-Modus (DEBUG_MOD_LOCAL=1)"
echo "==========================================================================="
echo
echo "Test lädt alle Module zentral über lib_core.sh"

# Laden der erforderlichen Module
echo "Lade Module aus Verzeichnis: $TEST_SCRIPT_DIR"

# Debug-Ausgabe zum Anzeigen der vorhandenen Dateien
echo "Vorhandene Dateien im Skriptverzeichnis:"
ls -la "$TEST_SCRIPT_DIR"

# Setze SCRIPT_DIR für lib_core.sh
export SCRIPT_DIR="$TEST_SCRIPT_DIR"

# Hilfsfunktion zur Überprüfung der Modulpfade
check_module_path() {
    local module_var="$1"
    local expected_name="$2"
    
    if [ -n "${!module_var}" ] && [ -f "${!module_var}" ]; then
        echo "✅ Modulpfad-Variable $module_var ist korrekt definiert: ${!module_var}"
        return 0
    else
        echo "❌ Modulpfad-Variable $module_var ist NICHT korrekt definiert: ${!module_var:-nicht gesetzt}"
        return 1
    fi
}

# Lade lib_core.sh, was automatisch alle anderen Module laden sollte
echo -n "Lade lib_core.sh für zentrale Modulladelogik... "
if [ ! -f "$TEST_SCRIPT_DIR/lib_core.sh" ]; then
    echo "FEHLER: lib_core.sh nicht gefunden!"
    exit 1
fi

# Lade das zentrale Modul lib_core.sh
source "$TEST_SCRIPT_DIR/lib_core.sh"
if [ $? -eq 0 ]; then
    echo "Erfolg."
    echo "Modul lib_core.sh wurde geladen und sollte alle anderen Module mitgeladen haben."
else
    echo "FEHLER beim Laden von lib_core.sh"
    exit 1
fi

# Überprüfe, ob alle Module geladen wurden
echo
echo "Überprüfe, ob alle Module geladen wurden:"
check_all_modules_loaded

# Überprüfe, ob alle Modulpfad-Variablen definiert wurden
echo
echo "Überprüfe, ob alle Modulpfad-Variablen definiert wurden:"
check_module_path "manage_folders_sh" "manage_folders.sh"
check_module_path "manage_files_sh" "manage_files.sh"
check_module_path "manage_logging_sh" "manage_logging.sh"
echo

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
call_module_function "$manage_folders_sh" "create_directory" "$test_dir"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "create_directory" 0

# Test: create_symlink_to_standard_path
echo -n "Test create_symlink_to_standard_path: "
source_dir="$TEST_CURRENT_DIR/tmp/symlink_source"
target_dir="$TEST_CURRENT_DIR/tmp/symlink_target"
call_module_function "$manage_folders_sh" "create_directory" "$target_dir" || true
set +e  # Fehler nicht als fatal behandeln
call_module_function "$manage_folders_sh" "create_symlink_to_standard_path" "$source_dir" "$target_dir"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "create_symlink_to_standard_path" 0

# Test: get_install_dir
echo -n "Test get_install_dir: "
install_dir=$(call_module_function "$manage_folders_sh" "get_install_dir")
if [ -n "$install_dir" ]; then
    echo "✅ Die Funktion get_install_dir wurde erfolgreich ausgeführt. Ergebnis: $install_dir"
else
    echo "❌ Die Funktion get_install_dir ist fehlgeschlagen."
fi

# Test: get_backend_dir
echo -n "Test get_backend_dir: "
backend_dir=$(call_module_function "$manage_folders_sh" "get_backend_dir")
if [ -n "$backend_dir" ]; then
    echo "✅ Die Funktion get_backend_dir wurde erfolgreich ausgeführt. Ergebnis: $backend_dir"
else
    echo "❌ Die Funktion get_backend_dir ist fehlgeschlagen."
fi

# Test: get_script_dir
echo -n "Test get_script_dir: "
script_dir=$(call_module_function "$manage_folders_sh" "get_script_dir")
if [ -n "$script_dir" ]; then
    echo "✅ Die Funktion get_script_dir wurde erfolgreich ausgeführt. Ergebnis: $script_dir"
else
    echo "❌ Die Funktion get_script_dir ist fehlgeschlagen."
fi

# Test: get_template_dir
echo -n "Test get_template_dir: "
template_dir=$(call_module_function "$manage_folders_sh" "get_template_dir" "nginx")
if [ -n "$template_dir" ]; then
    echo "✅ Die Funktion get_template_dir wurde erfolgreich ausgeführt. Ergebnis: $template_dir"
else
    echo "❌ Die Funktion get_template_dir ist fehlgeschlagen."
fi

# Test: get_template_dir (ohne Modul-Parameter)
echo -n "Test get_template_dir (ohne Modul): "
template_dir_base=$(call_module_function "$manage_folders_sh" "get_template_dir")
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
config_file=$(call_module_function "$manage_files_sh" "get_config_file" "system" "version" 2>/dev/null)
set -e  # Fehlerbehandlung wieder aktivieren
if [ -n "$config_file" ]; then
    echo "✅ Die Funktion get_config_file wurde erfolgreich ausgeführt. Ergebnis: $config_file"
else
    echo "❌ Die Funktion get_config_file ist fehlgeschlagen."
fi

# Test: get_template_file
echo -n "Test get_template_file: "
set +e  # Fehler nicht als fatal behandeln
template_file=$(call_module_function "$manage_files_sh" "get_template_file" "nginx" "fotobox" 2>/dev/null)
set -e  # Fehlerbehandlung wieder aktivieren
if [ -n "$template_file" ]; then
    echo "✅ Die Funktion get_template_file wurde erfolgreich ausgeführt. Ergebnis: $template_file"
else
    echo "❌ Die Funktion get_template_file ist fehlgeschlagen."
fi

# Test: get_log_file
echo -n "Test get_log_file: "
log_file=$(call_module_function "$manage_files_sh" "get_log_file" "test_script")
if [ -n "$log_file" ]; then
    echo "✅ Die Funktion get_log_file wurde erfolgreich ausgeführt. Ergebnis: $log_file"
else
    echo "❌ Die Funktion get_log_file ist fehlgeschlagen."
fi

# Test: get_temp_file
echo -n "Test get_temp_file: "
temp_file=$(call_module_function "$manage_files_sh" "get_temp_file" "testfile" ".txt")
if [ -n "$temp_file" ]; then
    echo "✅ Die Funktion get_temp_file wurde erfolgreich ausgeführt. Ergebnis: $temp_file"
else
    echo "❌ Die Funktion get_temp_file ist fehlgeschlagen."
fi

# Test: get_backup_file
echo -n "Test get_backup_file: "
backup_file=$(call_module_function "$manage_files_sh" "get_backup_file" "test_backup")
if [ -n "$backup_file" ]; then
    echo "✅ Die Funktion get_backup_file wurde erfolgreich ausgeführt. Ergebnis: $backup_file"
else
    echo "❌ Die Funktion get_backup_file ist fehlgeschlagen."
fi

# Test: get_backup_meta_file
echo -n "Test get_backup_meta_file: "
backup_meta_file=$(call_module_function "$manage_files_sh" "get_backup_meta_file" "test_backup")
if [ -n "$backup_meta_file" ]; then
    echo "✅ Die Funktion get_backup_meta_file wurde erfolgreich ausgeführt. Ergebnis: $backup_meta_file"
else
    echo "❌ Die Funktion get_backup_meta_file ist fehlgeschlagen."
fi

# Test: get_image_file
echo -n "Test get_image_file: "
image_file=$(call_module_function "$manage_files_sh" "get_image_file" "original" "test_image")
if [ -n "$image_file" ]; then
    echo "✅ Die Funktion get_image_file wurde erfolgreich ausgeführt. Ergebnis: $image_file"
else
    echo "❌ Die Funktion get_image_file ist fehlgeschlagen."
fi

# Test: get_system_file
echo -n "Test get_system_file: "
set +e  # Fehler nicht als fatal behandeln
system_file=$(call_module_function "$manage_files_sh" "get_system_file" "nginx" "fotobox" 2>/dev/null)
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
call_module_function "$manage_files_sh" "file_exists" "$temp_test_file"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "file_exists" 0

# Test: create_empty_file
echo -n "Test create_empty_file: "
mkdir -p "$TEST_CURRENT_DIR/tmp" 2>/dev/null || true
empty_file="$TEST_CURRENT_DIR/tmp/empty_test_file.txt"
set +e  # Fehler nicht als fatal behandeln
call_module_function "$manage_files_sh" "create_empty_file" "$empty_file"
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

# -------------------------------
# Test der manage_logging.sh Funktionen
# -------------------------------
echo
echo "-------------------------------------------------------------------------"
echo "Test der Funktionen in manage_logging.sh"
echo "-------------------------------------------------------------------------"

# Test: log
echo -n "Test log mit einfacher Nachricht: "
call_module_function "$manage_logging_sh" "log" "Testmessage für log"
result=$?
test_function $result "log (einfache Nachricht)" 0

# Test: log mit Funktionsname
echo -n "Test log mit Funktionsname: "
call_module_function "$manage_logging_sh" "log" "Testmessage mit Funktionsname" "test_function"
result=$?
test_function $result "log (mit Funktionsname)" 0

# Test: log für Fehlermeldung
echo -n "Test log für Fehlermeldungen: "
call_module_function "$manage_logging_sh" "log" "ERROR: Testfehlermeldung" "test_function" "test_modules.sh"
result=$?
test_function $result "log (Fehlermeldung mit Funktionsname und Datei)" 0

# Test: debug (LOG-Modus)
echo -n "Test debug im LOG-Modus: "
call_module_function "$manage_logging_sh" "debug" "Debug-Testmessage im LOG-Modus"
result=$?
test_function $result "debug (LOG-Modus)" 0

# Test: debug (CLI-Modus)
echo -n "Test debug im CLI-Modus: "
call_module_function "$manage_logging_sh" "debug" "Debug-Testmessage im CLI-Modus" "CLI"
result=$?
test_function $result "debug (CLI-Modus)" 0

# Test: debug (JSON-Modus)
echo -n "Test debug im JSON-Modus: "
call_module_function "$manage_logging_sh" "debug" "Debug-Testmessage im JSON-Modus" "JSON"
result=$?
test_function $result "debug (JSON-Modus)" 0

# Test: print_step
echo -n "Test print_step: "
call_module_function "$manage_logging_sh" "print_step" "Testschritt wird ausgeführt"
result=$?
test_function $result "print_step" 0

# Test: print_info
echo -n "Test print_info: "
call_module_function "$manage_logging_sh" "print_info" "Testinfo wird angezeigt"
result=$?
test_function $result "print_info" 0

# Test: print_success
echo -n "Test print_success: "
call_module_function "$manage_logging_sh" "print_success" "Testoperation erfolgreich"
result=$?
test_function $result "print_success" 0

# Test: print_warning
echo -n "Test print_warning: "
call_module_function "$manage_logging_sh" "print_warning" "Testwarnung wird angezeigt"
result=$?
test_function $result "print_warning" 0

# Test: print_error
echo -n "Test print_error: "
call_module_function "$manage_logging_sh" "print_error" "Testfehler wird angezeigt"
result=$?
test_function $result "print_error" 0

# Test: print_debug
echo -n "Test print_debug: "
call_module_function "$manage_logging_sh" "print_debug" "Debug-Testmeldung wird angezeigt"
result=$?
test_function $result "print_debug" 0

# Überprüfe die Log-Datei auf vorhandene Debug-Ausgaben
log_file=$(call_module_function "$manage_logging_sh" "get_log_file")
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

# -------------------------------
# Automatischer Test aller Module
# -------------------------------
echo
echo "-------------------------------------------------------------------------"
echo "Automatische Überprüfung aller gefundenen Module"
echo "-------------------------------------------------------------------------"

# Alle Guard-Variablen finden und prüfen
echo "Überprüfung des Ladestatus aller Module (Guard-Variablen):"
all_guards_ok=true
module_count=0
modules_loaded=0
modules_failed=0
failed_modules=""

# Finde alle MANAGE_*_LOADED Variablen
for var in $(compgen -v MANAGE_*_LOADED); do
    module_count=$((module_count + 1))
    module_name=$(echo "$var" | sed 's/_LOADED//' | tr '[:upper:]' '[:lower:]')
    module_name="${module_name#manage_}.sh"
    
    if [ "${!var}" -eq 1 ]; then
        echo "✅ $var=1 : $module_name ist korrekt geladen"
        modules_loaded=$((modules_loaded + 1))
    else
        echo "❌ $var=${!var} : $module_name ist NICHT korrekt geladen"
        all_guards_ok=false
        modules_failed=$((modules_failed + 1))
        failed_modules+=" $module_name"
    fi
done

echo
echo "Überprüfung der Modulpfad-Variablen für alle erkannten Module:"
all_paths_ok=true

# Finde alle manage_*_sh Variablen
for var in $(compgen -v manage_*_sh); do
    if [ -n "${!var}" ] && [ -f "${!var}" ]; then
        echo "✅ $var=${!var} : Pfad existiert"
    else
        echo "❌ $var=${!var:-nicht gesetzt} : Pfad fehlt oder ist ungültig"
        all_paths_ok=false
    fi
done

# Zusammenfassung der automatischen Überprüfung
echo
echo "Zusammenfassung des automatischen Modultests:"
echo "Gesamt: $module_count Module, Geladen: $modules_loaded, Fehlerhaft: $modules_failed"

if $all_guards_ok; then
    echo "✅ Alle Guard-Variablen sind korrekt gesetzt (MANAGE_*_LOADED=1)"
else
    echo "❌ Einige Guard-Variablen sind nicht korrekt gesetzt: $failed_modules"
fi

if $all_paths_ok; then
    echo "✅ Alle Modulpfad-Variablen sind korrekt definiert"
else
    echo "❌ Einige Modulpfad-Variablen fehlen oder zeigen auf nicht existierende Dateien"
fi

# Hilfsfunktion für den korrekten Aufruf von Funktionen aus dem Modul
call_module_function() {
    local module_path="$1"
    local function_name="$2"
    shift 2  # Entferne die ersten beiden Parameter
    
    # Führe die Funktion aus dem Modul aus
    if [ -x "$module_path" ]; then
        # Führe das Skript direkt aus mit der Funktion als erstem Argument
        "$module_path" "$function_name" "$@"
        return $?
    else
        # Sourcing-Fallback (sollte nicht benötigt werden, wenn Skripte ausführbar sind)
        echo "WARNUNG: Modul $module_path hat keine Ausführungsrechte, versuche Sourcing-Methode"
        # shellcheck disable=SC1090
        source "$module_path" >/dev/null 2>&1
        "$function_name" "$@"
        return $?
    fi
}
