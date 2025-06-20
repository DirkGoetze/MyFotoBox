#!/bin/bash
#
# manage_files.sh - Zentrale Stelle für alle Dateipfad-Operationen
# 
# Teil der Fotobox2 Anwendung
# Copyright (c) 2023-2025 Dirk Götze
#
# Abhängigkeiten:
# - manage_folders.sh für alle Verzeichnispfade
# - manage_logging.sh für Logging-Funktionen
#

# Konstanten und Konfiguration
readonly SCRIPT_NAME="manage_files.sh"
readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import von Hilfsskripten
readonly manage_folders_sh="$SCRIPT_DIR/manage_folders.sh"
readonly manage_logging_sh="$SCRIPT_DIR/manage_logging.sh"

# Prüfen, ob alle erforderlichen Skripte vorhanden sind
if [ ! -f "$manage_folders_sh" ]; then
  echo "FEHLER: $manage_folders_sh nicht gefunden!" >&2
  exit 1
fi

if [ ! -f "$manage_logging_sh" ]; then
  echo "FEHLER: $manage_logging_sh nicht gefunden!" >&2
  exit 1
fi

# Importiere Logging-Funktionen
source "$manage_logging_sh"

# Variablen für Mehrsprachigkeit
TEXT_GET_FILE_NOT_FOUND="Die angeforderte Datei wurde nicht gefunden"
TEXT_PARAM_MISSING="Erforderlicher Parameter fehlt"
TEXT_UNKNOWN_CATEGORY="Unbekannte Dateikategorie"
TEXT_PATH_CREATED="Dateipfad erstellt"
TEXT_FILE_CREATED="Datei erstellt"
TEXT_FILE_EXISTS="Datei existiert bereits"
TEXT_FILE_REMOVED="Datei entfernt"
TEXT_OPERATION_COMPLETED="Operation abgeschlossen"

# -----------------------------------------------
# HILFSFUNKTIONEN
# -----------------------------------------------

# Prüft, ob ein Parameter vorhanden ist
function check_param() {
  local param="$1"
  local param_name="$2"
  
  if [ -z "$param" ]; then
    log_or_json error "$TEXT_PARAM_MISSING: $param_name"
    return 1
  fi
  return 0
}

# Erstellt Verzeichnisse für einen Dateipfad falls nötig
function ensure_path_exists() {
  local file_path="$1"
  local dir_path
  
  dir_path="$(dirname "$file_path")"
  
  if [ ! -d "$dir_path" ]; then
    mkdir -p "$dir_path" 2>/dev/null
    if [ $? -ne 0 ]; then
      log_or_json error "Konnte Verzeichnis nicht erstellen: $dir_path"
      return 1
    fi
    log_or_json info "$TEXT_PATH_CREATED: $dir_path"
  fi
  
  return 0
}

# -----------------------------------------------
# HAUPTFUNKTIONEN FÜR DATEIPFADE
# -----------------------------------------------

# Gibt den Pfad zu einer Konfigurationsdatei zurück
function get_config_file() {
  local category="$1"
  local name="$2"
  local folder_path
  
  if ! check_param "$category" "category"; then return 1; fi
  if ! check_param "$name" "name"; then return 1; fi
  
  case "$category" in
    "nginx")
      folder_path="$("$manage_folders_sh" get_nginx_conf_dir)"
      echo "${folder_path}/${name}.conf"
      ;;
    "camera")
      folder_path="$("$manage_folders_sh" get_camera_conf_dir)"
      echo "${folder_path}/${name}.json"
      ;;
    "system")
      folder_path="$("$manage_folders_sh" get_conf_dir)"
      echo "${folder_path}/${name}.inf"
      ;;
    *)
      log_or_json error "$TEXT_UNKNOWN_CATEGORY: $category"
      return 1
      ;;
  esac
}

# Gibt den Pfad zu einer System-Konfigurationsdatei zurück (mit Fallback)
function get_system_file() {
  local file_type="$1"
  local name="$2"
  local primary_folder secondary_folder file_ext="conf"
  
  if ! check_param "$file_type" "file_type"; then return 1; fi
  if ! check_param "$name" "name"; then return 1; fi
  
  case "$file_type" in
    "nginx")
      # Primärer (System-)Pfad
      primary_folder="/etc/nginx/sites-available"
      # Fallback-Pfad aus manage_folders
      secondary_folder="$("$manage_folders_sh" get_nginx_conf_dir)"
      file_ext="conf"
      ;;
    "systemd")
      primary_folder="/etc/systemd/system"
      secondary_folder="$("$manage_folders_sh" get_conf_dir)"
      file_ext="service"
      ;;
    "ssl_cert")
      primary_folder="/etc/ssl/certs"
      secondary_folder="$("$manage_folders_sh" get_ssl_dir)"
      file_ext="crt"
      ;;
    "ssl_key")
      primary_folder="/etc/ssl/private"
      secondary_folder="$("$manage_folders_sh" get_ssl_dir)"
      file_ext="key"
      ;;
    *)
      log_or_json error "$TEXT_UNKNOWN_CATEGORY: $file_type"
      return 1
      ;;
  esac
  
  # Prüfen und Fallback-Logik anwenden
  if [ -f "${primary_folder}/${name}.${file_ext}" ]; then
    echo "${primary_folder}/${name}.${file_ext}"
  else
    echo "${secondary_folder}/${name}.${file_ext}"
  fi
}

# Gibt den Pfad zu einer Log-Datei zurück
function get_log_file() {
  local component="$1"
  local date_suffix
  local log_dir
  
  if ! check_param "$component" "component"; then return 1; fi
  
  date_suffix="$(date +%Y-%m-%d)"
  log_dir="$("$manage_folders_sh" get_log_dir)"
  
  echo "${log_dir}/${component}_${date_suffix}.log"
}

# Gibt den Pfad zu einer temporären Datei zurück
function get_temp_file() {
  local prefix="$1"
  local suffix="$2"
  local temp_dir
  
  if ! check_param "$prefix" "prefix"; then return 1; fi
  
  # Default-Suffix falls nicht angegeben
  suffix=${suffix:-.tmp}
  
  temp_dir="$("$manage_folders_sh" get_temp_dir)"
  echo "${temp_dir}/${prefix}_$(date +%Y%m%d%H%M%S)_$RANDOM$suffix"
}

# Gibt den Pfad zu einer Backup-Datei zurück
function get_backup_file() {
  local component="$1"
  local extension="${2:-.zip}"  # Default: .zip
  local backup_dir
  
  if ! check_param "$component" "component"; then return 1; fi
  
  backup_dir="$("$manage_folders_sh" get_backup_dir)"
  echo "${backup_dir}/$(date +%Y-%m-%d)_${component}${extension}"
}

# Gibt den Pfad zu einer Backup-Metadaten-Datei zurück
function get_backup_meta_file() {
  local component="$1"
  local backup_dir
  
  if ! check_param "$component" "component"; then return 1; fi
  
  backup_dir="$("$manage_folders_sh" get_backup_dir)"
  echo "${backup_dir}/$(date +%Y-%m-%d)_${component}.meta.json"
}

# Gibt den Pfad zu einer Template-Datei zurück
function get_template_file() {
  local category="$1"
  local name="$2"
  local folder_path
  
  if ! check_param "$category" "category"; then return 1; fi
  if ! check_param "$name" "name"; then return 1; fi
  
  case "$category" in
    "nginx")
      folder_path="$("$manage_folders_sh" get_nginx_conf_dir)"
      echo "${folder_path}/template_${name}"
      ;;
    "backup")
      folder_path="$("$manage_folders_sh" get_nginx_conf_dir)"  # Gemeinsamer Speicherort mit nginx Templates
      echo "${folder_path}/template_${name}"
      ;;
    *)
      log_or_json error "$TEXT_UNKNOWN_CATEGORY: $category"
      return 1
      ;;
  esac
}

# Gibt den Pfad zu einer Bilddatei zurück
function get_image_file() {
  local type="$1"    # z.B. "original", "thumbnail"
  local filename="$2"
  local folder_path
  
  if ! check_param "$type" "type"; then return 1; fi
  if ! check_param "$filename" "filename"; then return 1; fi
  
  case "$type" in
    "original")
      folder_path="$("$manage_folders_sh" get_photos_dir)"
      ;;
    "thumbnail")
      folder_path="$("$manage_folders_sh" get_thumbnails_dir)"
      ;;
    *)
      log_or_json error "$TEXT_UNKNOWN_CATEGORY: $type"
      return 1
      ;;
  esac
  
  echo "${folder_path}/${filename}"
}

# -----------------------------------------------
# DATEIVERWALTUNGSFUNKTIONEN
# -----------------------------------------------

# Prüft, ob eine Datei existiert
function file_exists() {
  local file_path="$1"
  
  if ! check_param "$file_path" "file_path"; then return 1; fi
  
  if [ -f "$file_path" ]; then
    return 0
  else
    return 1
  fi
}

# Erstellt eine leere Datei
function create_empty_file() {
  local file_path="$1"
  
  if ! check_param "$file_path" "file_path"; then return 1; fi
  
  if file_exists "$file_path"; then
    log_or_json info "$TEXT_FILE_EXISTS: $file_path"
    return 0
  fi
  
  ensure_path_exists "$file_path"
  touch "$file_path"
  
  if [ $? -eq 0 ]; then
    log_or_json info "$TEXT_FILE_CREATED: $file_path"
    return 0
  else
    log_or_json error "Konnte Datei nicht erstellen: $file_path"
    return 1
  fi
}

# -----------------------------------------------
# HAUPTFUNKTION
# -----------------------------------------------

function main() {
  local command="$1"
  shift
  
  if [ -z "$command" ]; then
    log_or_json error "Kein Befehl angegeben. Verfügbare Befehle: get_config_file, get_system_file, get_log_file, get_temp_file, get_backup_file, get_template_file, get_image_file, file_exists, create_empty_file"
    exit 1
  fi
  
  case "$command" in
    "get_config_file")
      get_config_file "$@"
      ;;
    "get_system_file")
      get_system_file "$@"
      ;;
    "get_log_file")
      get_log_file "$@"
      ;;
    "get_temp_file")
      get_temp_file "$@"
      ;;
    "get_backup_file")
      get_backup_file "$@"
      ;;
    "get_backup_meta_file")
      get_backup_meta_file "$@"
      ;;
    "get_template_file")
      get_template_file "$@"
      ;;
    "get_image_file")
      get_image_file "$@"
      ;;
    "file_exists")
      if file_exists "$@"; then
        echo "true"
        exit 0
      else
        echo "false"
        exit 1
      fi
      ;;
    "create_empty_file")
      create_empty_file "$@"
      exit $?
      ;;
    "version")
      echo "$VERSION"
      ;;
    *)
      log_or_json error "Unbekannter Befehl: $command"
      exit 1
      ;;
  esac
}

# Wenn das Skript direkt ausgeführt wird
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
