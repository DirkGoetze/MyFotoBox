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
#set -e  # Beende bei Fehlern
#set -u  # Beende bei Verwendung nicht gesetzter Variablen
#set +e  # Deaktiviere strict mode für die Initialisierung

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
# Lade lib_core.sh, was automatisch alle anderen Module laden sollte
echo "---------------------------------------------------------------------------"
echo "Versuche 'lib_core.sh' und alle anderen Module zu laden..."
TEST_SCRIPT_DIR="/opt/fotobox/backend/scripts"
source "$TEST_SCRIPT_DIR/lib_core.sh"
if [ $? -eq 0 ]; then
    print_success "Modul lib_core.sh und alle anderen Management-Module wurde geladen."
else
    print_error "Beim Laden von lib_core.sh ist ein Fehler aufgetreten."
    exit 1
fi
echo

# -------------------------------
# Test des Main-Modul lib_core.sh
# -------------------------------
test_lib_core
# -------------------------------
# Test der manage_folders.sh Funktionen
# -------------------------------
# test_manage_folders
# -------------------------------
# Test der manage_files.sh Funktionen
# -------------------------------
# test_manage_files
# -------------------------------
# Test der manage_nginx.sh Funktionen
# -------------------------------
# test_manage_nginx

exit



echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SYSTEMD)                                     |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "systemd" "systemd-fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SSL Zertifikat)                              |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "ssl_cert" "fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SSL Schlüssel)                               |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "ssl_key" "fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (Backup-Meta-File)                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "backup_meta" "backup-fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (Firewall)                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "firewall" "fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SSH File)                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "ssh" "fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (html Datei)                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "html" "fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (js Datei)                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "js" "fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (css Datei)                                   |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "css" "fotobox"
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (Allgemein)                                   |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "allgemein" "fotobox"

DEBUG_MOD_LOCAL=1  # Aktiviere lokalen Debug-Modus für detaillierte Ausgaben
# Test: get_python_path
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_python_path                                                 |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_python_path"
debug "INFO: PYTHON_EXEC: ${PYTHON_EXEC:-nicht gesetzt}"
DEBUG_MOD_LOCAL=0  # Aktiviere lokalen Debug-Modus für detaillierte Ausgaben
# Test: get_pip_path
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_pip_path                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_pip_path"
debug "INFO: PIP_EXEC: ${PIP_EXEC:-nicht gesetzt}"



set_config_value "nginx.port" "80" "int" "Port für den Nginx-Server" 10 "grp_nginx_config"
echo "$(get_config_value "nginx.port")"

set_config_value "nginx.port" "443" "int" "Port für den Nginx-Server" 10 "grp_nginx_config"
echo "$(get_config_value "nginx.port")"

set_config_value "nginx.port" "8080" "int" "Port für den Nginx-Server" 10 "grp_nginx_config"
echo "$(get_config_value "nginx.port")"

exit


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

# Test: get_temp_file
echo -n "Test get_temp_file: "
temp_file=$(call_module_function "$manage_files_sh" "get_temp_file" "testfile" ".txt")
if [ -n "$temp_file" ]; then
    echo "✅ Die Funktion get_temp_file wurde erfolgreich ausgeführt. Ergebnis: $temp_file"
else
    echo "❌ Die Funktion get_temp_file ist fehlgeschlagen."
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
