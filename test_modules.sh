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

# test_function
test_function_debug_0001="INFO: Test Funktion: %s"
test_function_debug_0002="INFO: Parameter: %s"
test_function_debug_0003="ERROR: Modul nicht verfügbar! Variable: %s, Pfad: %s"
test_function_debug_0004="ERROR: Funktion '%s' wurde nicht gefunden"
test_function_debug_0005="INFO: Funktion '%s' in Modul %s gefunden"
test_function_debug_0006="INFO: Führe Funktion '%s' aus mit Parametern: %s"
test_function_debug_0007="INFO: Führe Funktion '%s' aus"
test_function_debug_0008="INFO: Ausgabe: %s"
test_function_debug_0009="INFO: Rückgabewert: %d"

test_function() {
    # Erweiterte Testfunktion für flexible Modulaufrufe und Ergebnisanalyse
    # Parameter verarbeiten
    local module_path_var="$1"        # Name der Modul-Pfad-Variable (z.B. manage_folders_sh)
    local module_path_var_upper="${module_path_var^^}"  # Wandelt nur den Variablennamen in Großbuchstaben um
    local function_name="$2"          # Name der zu testenden Funktion
    local params=("${@:3}")           # Alle weiteren Parameter für die Funktion

    debug "$(printf "$test_function_debug_0001" "$function_name")"

    # DEBUG: Informationen über den Aufruf, wenn Parameter vorhanden sind
    if [ ${#params[@]} -gt 0 ]; then
        debug "$(printf "$test_function_debug_0002" "${params[*]}")"
    fi

    # Prüfe, ob das Modul verfügbar ist
    if [ -z "${!module_path_var_upper}" ] || [ ! -f "${!module_path_var_upper}" ]; then
        debug "$(printf "$test_function_debug_0003" "$module_path_var_upper" "${!module_path_var_upper:-nicht gesetzt}")" "CLI" "test_function"
        echo "❌ ERROR: Modul $module_path_var_upper nicht verfügbar oder Pfad ungültig!" &>2
        return 1
    fi

    # Prüfe, ob die Funktion existiert (bereits geladen)
    if ! declare -f "$function_name" > /dev/null 2>&1; then
        debug "$(printf "$test_function_debug_0004" "$function_name")"
        echo "❌ ERROR: Funktion '$function_name' wurde nicht gefunden!" &>2
        return 2
    fi

    debug "$(printf "$test_function_debug_0005" "$function_name" "$module_path_var_upper")"

    # Führe die Funktion aus und erfasse Rückgabewert und Ausgabe
    local output
    local result

    # Führe die Funktion DIREKT mit den übergebenen Parametern aus
    set +e  # Deaktiviere Fehlerabbruch
    if [ ${#params[@]} -gt 0 ]; then
        debug "$(printf "$test_function_debug_0006" "$function_name" "${params[*]}")"
        output=$("$function_name" "${params[@]}" 2>&1)
        result=$?
    else
        debug "$(printf "$test_function_debug_0007" "$function_name")"
        output=$("$function_name" 2>&1)
        result=$?
    fi
    set -e  # Reaktiviere Fehlerabbruch

    # Rest der Funktion bleibt gleich...
    if [ -n "$output" ]; then
        debug "$(printf "$test_function_debug_0008" "$output")"
        debug "$(printf "$test_function_debug_0009" "$result")"
        if [ "${DEBUG_MOD_GLOBAL:-0}" = "0" ] && [ "${DEBUG_MOD_LOCAL:-0}" = "0" ]; then
            echo "✅ SUCCES: Ausgabe der Funktion '$function_name': $output"
            echo "✅ SUCCES: Rückgabewert der Funktion '$function_name': $result"
            echo
        fi
    else
        debug "$(printf "$test_function_debug_0009" "$result")"
        if [ "${DEBUG_MOD_GLOBAL:-0}" = "0" ] && [ "${DEBUG_MOD_LOCAL:-0}" = "0" ]; then
            echo "✅ SUCCES: Keine Ausgabe von Funktion '$function_name', Rückgabewert: $result"
            echo
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

# Debug-Ausgabe zum Anzeigen der vorhandenen Dateien
echo "---------------------------------------------------------------------------"
echo "Vorhandene Dateien im Skriptverzeichnis:"
echo
# Setze den Pfad zum Skriptverzeichnis
TEST_SCRIPT_DIR="/opt/fotobox/backend/scripts"
ls -la "$TEST_SCRIPT_DIR"
echo "---------------------------------------------------------------------------"

# Laden der erforderlichen Module
echo
echo "---------------------------------------------------------------------------"
echo "Lade Module aus Verzeichnis: $TEST_SCRIPT_DIR"
# Lade lib_core.sh, was automatisch alle anderen Module laden sollte
echo "Versuche lib_core.sh und alle anderen Module zu laden..."
source "$TEST_SCRIPT_DIR/lib_core.sh"
if [ $? -eq 0 ]; then
    echo "✅ SUCCES: Modul lib_core.sh wurde geladen und sollte alle anderen Module mitgeladen haben."
else
    echo "❌ FEHLER: Beim Laden von lib_core.sh ist ein Fehler aufgetreten."
    exit 1
fi
echo "---------------------------------------------------------------------------"
echo

set_config_value "nginx.port" "80" "int" "Port für den Nginx-Server" 10 "grp_nginx_config"
echo "$(get_config_value "nginx.port")"

set_config_value "nginx.port" "443" "int" "Port für den Nginx-Server" 10 "grp_nginx_config"
echo "$(get_config_value "nginx.port")"

set_config_value "nginx.port" "8080" "int" "Port für den Nginx-Server" 10 "grp_nginx_config"
echo "$(get_config_value "nginx.port")"

exit

# Zeige alle verfügbaren Funktionen in manage_folders.sh
echo "+-----------------------------------------------------------------------+"
echo "| Alle verfügbaren Funktionen                                           |" 
echo "+-----------------------------------------------------------------------+"
declare -F | grep -E '(get_|set_|bind_|check_|log_)'
echo "-------------------------------------------------------------------------"
echo


# -------------------------------
# Test der manage_folders.sh Funktionen
# -------------------------------
echo "========================================================================="
echo "  Test der Funktionen in manage_folders.sh                               "
echo "========================================================================="
# Test: get_install_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_install_dir                                                 |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_install_dir"
debug "INFO: INSTALL_DIR: ${INSTALL_DIR:-nicht gesetzt}"
# Test: get_backend_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backend_dir                                                 |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_backend_dir"
debug "INFO: BACKEND_DIR: ${BACKEND_DIR:-nicht gesetzt}"
# Test: get_script_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_script_dir                                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_script_dir"
debug "INFO: SCRIPT_DIR: ${SCRIPT_DIR:-nicht gesetzt}"
# Test: get_venv_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_venv_dir                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_venv_dir"
debug "INFO: BACKEND_VENV_DIR: ${BACKEND_VENV_DIR:-nicht gesetzt}"
# Test: get_python_path
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_python_path                                                 |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_python_path"
debug "INFO: PYTHON_EXEC: ${PYTHON_EXEC:-nicht gesetzt}"
# Test: get_pip_path
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_pip_path                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_pip_path"
debug "INFO: PIP_EXEC: ${PIP_EXEC:-nicht gesetzt}"
# Test: get_backup_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_dir                                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_backup_dir"
debug "INFO: BACKUP_DIR: ${BACKUP_DIR:-nicht gesetzt}"
# Test: get_nginx_backup_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_nginx_backup_dir                                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_nginx_backup_dir"
debug "INFO: BACKUP_DIR_NGINX: ${BACKUP_DIR_NGINX:-nicht gesetzt}"
# Test: get_https_backup_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_https_backup_dir                                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_https_backup_dir"
debug "INFO: BACKUP_DIR_HTTPS: ${BACKUP_DIR_HTTPS:-nicht gesetzt}"
# Test: get_config_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_config_dir                                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_config_dir"
debug "INFO: CONF_DIR: ${CONF_DIR:-nicht gesetzt}"
# Test: get_camera_conf_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_camera_conf_dir                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_camera_conf_dir"
debug "INFO: CONF_DIR_CAMERA: ${CONF_DIR_CAMERA:-nicht gesetzt}"
# Test: get_https_conf_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_https_conf_dir                                              |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_https_conf_dir"
debug "INFO: CONF_DIR_HTTPS: ${CONF_DIR_HTTPS:-nicht gesetzt}"
# Test: get_nginx_conf_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_nginx_conf_dir                                              |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_nginx_conf_dir"
debug "INFO: CONF_DIR_NGINX: ${CONF_DIR_NGINX:-nicht gesetzt}"
# Test: get_template_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_dir (ohne Modul)                                   |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_template_dir"
debug "INFO: CONF_DIR_TEMPLATES: ${CONF_DIR_TEMPLATES:-nicht gesetzt}"
# Test: get_template_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_dir (mit Modul)                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_template_dir" "nginx"
debug "INFO: TEMPLATE_DIR: ${TEMPLATE_DIR:-nicht gesetzt}"
# Test: get_data_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_data_dir                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_data_dir"
debug "INFO: DATA_DIR: ${DATA_DIR:-nicht gesetzt}"
# Test: get_frontend_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_frontend_dir                                                |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_frontend_dir"
debug "INFO: FRONTEND_DIR: ${FRONTEND_DIR:-nicht gesetzt}"
# Test: get_frontend_css_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_frontend_css_dir                                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_frontend_css_dir"
debug "INFO: FRONTEND_DIR_CSS: ${FRONTEND_DIR_CSS:-nicht gesetzt}"
# Test: get_frontend_fonts_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_frontend_fonts_dir                                          |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_frontend_fonts_dir"
debug "INFO: FRONTEND_DIR_FONTS: ${FRONTEND_DIR_FONTS:-nicht gesetzt}"
# Test: get_frontend_js_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_frontend_js_dir                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_frontend_js_dir"
debug "INFO: FRONTEND_DIR_JS: ${FRONTEND_DIR_JS:-nicht gesetzt}"
# Test: get_photos_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_photos_dir                                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_photos_dir"
debug "INFO: FRONTEND_DIR_PHOTOS: ${FRONTEND_DIR_PHOTOS:-nicht gesetzt}"
# Test: get_photos_original_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_photos_original_dir (ohne Event)                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_photos_originals_dir"
debug "INFO: FRONTEND_DIR_PHOTOS_ORIGINAL: ${FRONTEND_DIR_PHOTOS_ORIGINAL:-nicht gesetzt}"
# Test: get_photos_originals_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_photos_originals_dir (mit Event)                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_photos_originals_dir" "Mein Event"
# Test: get_photos_gallery_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_photos_gallery_dir (ohne Event)                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_photos_gallery_dir"
debug "INFO: FRONTEND_DIR_PHOTOS_THUMBNAILS: ${FRONTEND_DIR_PHOTOS_THUMBNAILS:-nicht gesetzt}"
# Test: get_photos_originals_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_photos_gallery_dir (mit Event)                              |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_photos_gallery_dir" "Mein Event"
# Test: get_frontend_picture_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_frontend_picture_dir                                        |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_frontend_picture_dir"
debug "INFO: FRONTEND_DIR_PICTURE: ${FRONTEND_DIR_PICTURE:-nicht gesetzt}"
# Test: get_log_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_log_dir                                                     |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_log_dir"
debug "INFO: LOG_DIR: ${LOG_DIR:-nicht gesetzt}"
# Test: get_tmp_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_tmp_dir                                                     |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_tmp_dir"
debug "INFO: TMP_DIR: ${TMP_DIR:-nicht gesetzt}"
# Test: get_nginx_systemdir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_nginx_systemdir                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_nginx_systemdir"
debug "INFO: SYSTEM_PATH_NGINX: ${SYSTEM_PATH_NGINX:-nicht gesetzt}"
# Test: get_systemd_systemdir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_systemd_systemdir                                           |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_systemd_systemdir"
debug "INFO: SYSTEM_PATH_SYSTEMD: ${SYSTEM_PATH_SYSTEMD:-nicht gesetzt}"
# Test: get_ssl_systemdir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_ssl_systemdir                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_ssl_systemdir"
debug "INFO: SYSTEM_PATH_SSL: ${SYSTEM_PATH_SSL:-nicht gesetzt}"
# Test: get_ssl_cert_systemdir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_ssl_cert_systemdir                                         |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_ssl_cert_systemdir"
debug "INFO: SYSTEM_PATH_SSL_CERTS: ${SYSTEM_PATH_SSL_CERTS:-nicht gesetzt}"
# Test: get_ssl_key_systemdir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_ssl_key_systemdir                                           |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_ssl_key_systemdir"
debug "INFO: SYSTEM_PATH_SSL_KEY: ${SYSTEM_PATH_SSL_KEY:-nicht gesetzt}"
# Test: ensure_folder_structure
echo "+-----------------------------------------------------------------------+"
echo "| Test: ensure_folder_structure                                         |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "ensure_folder_structure"

# -------------------------------
# Test der manage_files.sh Funktionen
# -------------------------------
echo
echo "========================================================================="
echo "  Test der Funktionen in manage_files.sh"
echo "========================================================================="
# Test: get_config_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_config_file                                                 |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_config_file"
# Test: get_log_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_log_file                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_log_file"
# Test: get_tmp_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_tmp_file                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_tmp_file"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (NGINX)                                       |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "nginx" "nginx-fotobox"
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
