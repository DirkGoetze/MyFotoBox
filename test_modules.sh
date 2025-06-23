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

# Erweiterte Testfunktion für flexible Modulaufrufe und Ergebnisanalyse
test_function() {
    # Parameter verarbeiten
    local module_path_var="$1"        # Name der Modul-Pfad-Variable (z.B. manage_folders_sh)
    local module_path_var_upper="${module_path_var^^}"  # Wandelt nur den Variablennamen in Großbuchstaben um
    local function_name="$2"          # Name der zu testenden Funktion
    local params=("${@:3}")           # Alle weiteren Parameter für die Funktion

    echo -n "Test $function_name: "

    # DEBUG: Informationen über den Aufruf
    echo -e "\n  → [DEBUG] test_function: Teste Funktion '$function_name' aus Modul '${!module_path_var_upper}'"
    echo "  → [DEBUG] test_function: Parameter: ${params[*]}"

    # Prüfe, ob das Modul verfügbar ist
    if [ -z "${!module_path_var_upper}" ] || [ ! -f "${!module_path_var_upper}" ]; then
        echo "  → [DEBUG] test_function: Modul nicht verfügbar. Variable: $module_path_var_upper, Pfad: ${!module_path_var_upper:-nicht gesetzt}"
        echo "❌ Die Funktion $function_name konnte nicht getestet werden: Modul nicht verfügbar."
        return 1
    fi
    
    echo "  → [DEBUG] test_function: Modul gefunden: '${!module_path_var_upper}'"
    
    # Prüfe, ob die Funktion im Modul existiert
    if ! grep -q "^$function_name[[:space:]]*()[[:space:]]*{" "${!module_path_var_upper}" 2>/dev/null; then
        echo "  → [DEBUG] test_function: Funktion '$function_name' wurde im Modul nicht gefunden"
        echo "❌ Die Funktion $function_name konnte nicht getestet werden: Funktion nicht im Modul gefunden."
        return 2
    fi
    
    echo "  → [DEBUG] test_function: Funktion '$function_name' im Modul gefunden"
    
    # Führe die Funktion aus und erfasse Rückgabewert und Ausgabe
    local output
    local result
    
    # Führe die Funktion mit den übergebenen Parametern aus
    set +e  # Deaktiviere Fehlerabbruch
    if [ ${#params[@]} -gt 0 ]; then
        echo "  → [DEBUG] test_function: Führe aus: ${!module_path_var_upper} $function_name ${params[*]}"
        output=$("${!module_path_var_upper}" "$function_name" "${params[@]}" 2>&1)
        result=$?
    else
        echo "  → [DEBUG] test_function: Führe aus: ${!module_path_var_upper} $function_name"
        output=$("${!module_path_var_upper}" "$function_name" 2>&1)
        result=$?
    fi
    set -e  # Reaktiviere Fehlerabbruch
    
    # Zeige Ergebnisse
    echo "  → [DEBUG] test_function: Rückgabewert: $result"
    if [ -n "$output" ]; then
        echo "  → [DEBUG] test_function: Ausgabe: $output"
    else
        echo "  → [DEBUG] test_function: Keine Ausgabe"
    fi
    
    # Zeige Ergebnis in Format "ERFOLG/FEHLER"
    if [ $result -eq 0 ]; then
        if [ -n "$output" ]; then
            echo "✅ Die Funktion $function_name wurde erfolgreich ausgeführt. Ausgabe: $output"
        else
            echo "✅ Die Funktion $function_name wurde erfolgreich ausgeführt."
        fi
    else
        if [ -n "$output" ]; then
            echo "❌ Die Funktion $function_name ist fehlgeschlagen. Rückgabewert: $result, Ausgabe: $output"
        else
            echo "❌ Die Funktion $function_name ist fehlgeschlagen. Rückgabewert: $result"
        fi
    fi
    
    # Gib den originalen Rückgabewert der getesteten Funktion zurück
    return $result
}

# Informiere über Strategie
echo "==========================================================================="
echo "           Test der Module lib_core.sh, manage_folders.sh,"
echo "                 manage_files.sh und manage_logging.sh"
echo "         mit aktiviertem Debug-Modus (DEBUG_MOD_LOCAL=1)"
echo "==========================================================================="
echo

# -------------------------------
# Test der core_lib.sh Funktionen
# -------------------------------
echo "-------------------------------------------------------------------------"
echo "Test für das Laden aller Module zentral über lib_core.sh"

# Setze den Pfad zum Skriptverzeichnis
TEST_SCRIPT_DIR="/opt/fotobox/backend/scripts"

# Debug-Ausgabe zum Anzeigen der vorhandenen Dateien
echo "---------------------------------------------------------------------------"
echo "Vorhandene Dateien im Skriptverzeichnis:"
ls -la "$TEST_SCRIPT_DIR"

# Laden der erforderlichen Module
echo
echo "---------------------------------------------------------------------------"
echo "Lade Module aus Verzeichnis: $TEST_SCRIPT_DIR"

# Lade lib_core.sh, was automatisch alle anderen Module laden sollte
echo
echo "Lade lib_core.sh für zentrale Modulladelogik ..."
if [ ! -f "$TEST_SCRIPT_DIR/lib_core.sh" ]; then
    echo "❌ ERROR: lib_core.sh nicht gefunden!"
    exit 1
else
    echo "✅ SUCCES: lib_core.sh wurde erfolgreich geladen."
fi

# Lade das zentrale Modul lib_core.sh
echo
echo "---------------------------------------------------------------------------"
echo "Versuche lib_core.sh und alle anderen Module zu laden..."
source "$TEST_SCRIPT_DIR/lib_core.sh"
if [ $? -eq 0 ]; then
    echo "✅ SUCCES: Modul lib_core.sh wurde geladen und sollte alle anderen Module mitgeladen haben."
else
    echo "❌ FEHLER: Beim Laden von lib_core.sh ist ein Fehler aufgetreten."
    exit 1
fi

# -------------------------------
# Test der manage_folders.sh Funktionen
# -------------------------------
echo "-------------------------------------------------------------------------"
echo "Test der Funktionen in manage_folders.sh"
echo "-------------------------------------------------------------------------"

# Zeige alle verfügbaren Funktionen in manage_folders.sh
echo "Alle im Skript verfügbaren Funktionen:"
declare -F | grep -E '(get_|bind_|check_|log_)'

# Test: get_install_dir
test_function "manage_folders_sh" "get_install_dir"
echo "Test direkter Aufruf:"
"$MANAGE_FOLDERS_SH" get_install_dir
echo "Status: $?"

exit

# Test: get_backend_dir
test_function "manage_folders_sh" "get_backend_dir"

# Test: get_script_dir
test_function "manage_folders_sh" "get_script_dir"

# Test: get_python_path
test_function "manage_folders_sh" "get_python_path"

# Test: get_venv_dir
test_function "manage_folders_sh" "get_venv_dir"

# Test: get_pip_path
test_function "manage_folders_sh" "get_pip_path"


# Test: get_template_dir
echo -n "Test get_template_dir: "
template_dir=$(call_module_function "$MANAGE_FOLDERS_SH" "get_template_dir" "nginx")
if [ -n "$template_dir" ]; then
    echo "✅ Die Funktion get_template_dir wurde erfolgreich ausgeführt. Ergebnis: $template_dir"
else
    echo "❌ Die Funktion get_template_dir ist fehlgeschlagen."
fi

# Test: get_template_dir (ohne Modul-Parameter)
echo -n "Test get_template_dir (ohne Modul): "
template_dir_base=$(call_module_function "$MANAGE_FOLDERS_SH" "get_template_dir")
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
