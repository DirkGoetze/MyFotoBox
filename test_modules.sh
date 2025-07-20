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
    echo "✅ SUCCES: Modul lib_core.sh und alle anderen Management-Module wurde geladen."
else
    echo "❌ FEHLER: Beim Laden von lib_core.sh ist ein Fehler aufgetreten."
    exit 1
fi
echo "---------------------------------------------------------------------------"
echo

# -------------------------------
# Test der manage_folders.sh Funktionen
# -------------------------------
test_modul "manage_folders.sh"
test_function "manage_folders_sh" "get_install_dir"
exit
list_module_functions "$MANAGE_FOLDERS_SH" false
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
# Test: get_backup_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_dir                                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_backup_dir"
debug "INFO: BACKUP_DIR: ${BACKUP_DIR:-nicht gesetzt}"
# Test: get_data_backup_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_data_backup_dir                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_data_backup_dir"
debug "INFO: BACKUP_DIR_DATA: ${BACKUP_DIR_DATA:-nicht gesetzt}"
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
# Test: get_system_backup_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_systemd_backup_dir                                          |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_systemd_backup_dir"
debug "INFO: BACKUP_DIR_SYSTEMD: ${BACKUP_DIR_SYSTEMD:-nicht gesetzt}"
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
echo "| Test: get_nginx_conf_dir [ohne Parameter - external]                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_nginx_conf_dir"
debug "INFO: CONF_DIR_NGINX: ${CONF_DIR_NGINX:-nicht gesetzt}"
# Test: get_nginx_conf_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_nginx_conf_dir (external)                                   |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_nginx_conf_dir" "external"
debug "INFO: CONF_DIR_NGINX: ${CONF_DIR_NGINX:-nicht gesetzt}"
# Test: get_nginx_conf_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_nginx_conf_dir (internal)                                   |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_nginx_conf_dir" "internal"
debug "INFO: CONF_DIR_NGINX: ${CONF_DIR_NGINX:-nicht gesetzt}"
# Test: get_nginx_conf_dir
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_nginx_conf_dir (activated)                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_folders_sh" "get_nginx_conf_dir" "activated"
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
list_module_functions "$MANAGE_FILES_SH" false
echo
echo "========================================================================="
echo "  Test der Funktionen in manage_files.sh"
echo "========================================================================="
# Test: get_data_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_data_file                                                   |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_data_file"
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
# Test: get_requirements_system_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_requirements_system_file                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_requirements_system_file"
# Test: get_requirements_python_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_requirements_python_file                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_requirements_python_file"
# Test: get_tmp_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_tmp_file                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_tmp_file"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (NGINX local)                                 |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "nginx" "template_local"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (NGINX internal)                              |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "nginx" "template_internal"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (NGINX external)                              |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "nginx" "template_external"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SYSTEMD)                                     |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "systemd" "fotobox-backend"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SSL Zertifikat)                              |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "ssl_cert" "fotobox"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SSL Schlüssel)                               |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "ssl_key" "fotobox"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (Backup Metadata)                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "backup_meta" "fotobox-backup"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (Firewall)                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "firewall" "fotobox-firewall"
# Test: get_template_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_template_file (SSH)                                         |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_template_file" "ssh" "fotobox-ssh"
# Test: get_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_config_file_nginx [ohne Parameter - external]               |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_config_file_nginx"
# Test: get_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_config_file_nginx (default/local)                           |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_config_file_nginx" "local"
# Test: get_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_config_file_nginx (default/internal)                        |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_config_file_nginx" "internal"
# Test: get_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_config_file_nginx (multisite/external)                      |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_config_file_nginx" "external"
# Test: get_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_config_file_nginx (activated)                               |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_config_file_nginx" "activated"
# Test: get_backup_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_file [Ohne Parameter]                                |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_backup_file" "irgendwas" ".zip"
# Test: get_backup_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_file (Datenbank)                                     |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_backup_file" "data" "fotobox.db"
# Test: get_backup_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_file (NGINX)                                         |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_backup_file" "nginx" "default.conf"
# Test: get_backup_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_file (HTTPS)                                         |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_backup_file" "https" "fotobox"
# Test: get_backup_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_file (Systemd)                                         |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_files_sh" "get_backup_file" "systemd" "fotobox.service"
# Test: get_backup_meta_file
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_backup_meta_file (NGINX)                                    |"
echo "+-----------------------------------------------------------------------+"
backup_file=$(get_backup_file "nginx" "default.conf")
test_function "manage_files_sh" "get_backup_meta_file" "$backup_file"


# -------------------------------
# Test der manage_nginx.sh Funktionen
# -------------------------------
list_module_functions "$MANAGE_NGINX_SH" false
echo
echo "========================================================================="
echo "  Test der Funktionen in manage_nginx.sh"
echo "========================================================================="
# Test: chk_installation_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: chk_installation_nginx                                          |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "chk_installation_nginx" "N"
# Test: chk_config_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: chk_config_nginx                                                |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "chk_config_nginx"
# Test: chk_port_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: chk_port_nginx  [ohne Parameter]                                |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "chk_port_nginx" 
# Test: chk_port_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: chk_port_nginx (80)                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "chk_port_nginx" "$DEFAULT_HTTP_PORT"
# Test: chk_port_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: chk_port_nginx (443)                                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "chk_port_nginx" "$DEFAULT_HTTPS_PORT"
# Test: chk_port_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: chk_port_nginx (8080)                                           |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "chk_port_nginx" "$DEFAULT_HTTP_PORT_FALLBACK"
# Test: get_port_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_port_nginx                                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "get_port_nginx" 
# Test: set_port_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: set_port_nginx                                                  |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "set_port_nginx" "$DEFAULT_HTTP_PORT"
# Test: get_server_name_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_server_name_nginx                                           |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "get_server_name_nginx" 
# Test: set_server_name_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: set_server_name_nginx                                           |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "set_server_name_nginx" "$DEFAULT_SERVER_NAME"
# Test: get_frontend_dir_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_frontend_dir_nginx                                          |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "get_frontend_dir_nginx" 
# Test: set_frontend_dir_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: set_frontend_dir_nginx                                          |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "set_frontend_dir_nginx" "$DEFAULT_FRONTEND_DIR"
# Test: get_index_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_index_file_nginx                                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "get_index_file_nginx"
# Test: set_index_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: set_index_file_nginx                                            |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "set_index_file_nginx" "$DEFAULT_INDEX_FILES"
# Test: get_api_url_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: get_api_url_nginx                                               |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "get_api_url_nginx"
# Test: set_api_url_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: set_api_url_nginx                                               |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "set_api_url_nginx" "$DEFAULT_API_URL"
# Test: stop_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: stop_nginx                                                      |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "stop_nginx"
# Test: start_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: start_nginx                                                     |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "start_nginx"
# Test: reload_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: reload_nginx                                                    |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "reload_nginx"
# Test: backup_config_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: backup_config_nginx                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "backup_config_nginx" "$(get_config_file_nginx "local")" "Testaufruf-Backup NGINX"
# Test: write_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: write_config_file_nginx  (local)                                |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "write_config_file_nginx" "local"
# Test: write_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: write_config_file_nginx  (internal)                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "write_config_file_nginx" "internal"
# Test: write_config_file_nginx
echo "+-----------------------------------------------------------------------+"
echo "| Test: write_config_file_nginx  (external)                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "write_config_file_nginx" "external"
# Test: setup_nginx_service
echo "+-----------------------------------------------------------------------+"
echo "| Test: setup_nginx_service                                             |"
echo "+-----------------------------------------------------------------------+"
test_function "manage_nginx_sh" "setup_nginx_service"
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
