#!/bin/bash
# ---------------------------------------------------------------------------
# test_modules.sh
# ---------------------------------------------------------------------------
# Funktion: Testet die Funktionen in manage_folders.sh und manage_files.sh
# ......... mit gültigen Parametern und überprüft deren Rückgabewerte.
# ---------------------------------------------------------------------------

# Setze strict mode für sicheres Bash-Scripting
set -e  # Beende bei Fehlern
set -u  # Beende bei Verwendung nicht gesetzter Variablen
set +e  # Deaktiviere strict mode für die Initialisierung

# Skriptpfad für korrekte Ausführung aus dem Root-Verzeichnis
CURRENT_DIR=$(pwd)
SCRIPT_DIR="$CURRENT_DIR/backend/scripts"

# Wenn das Standardverzeichnis nicht existiert, suchen wir nach Alternativen
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Warnung: Standard-Skriptpfad nicht gefunden, suche nach Alternativen..."
    
    # Alternative 1: Prüfe, ob wir direkt im scripts-Verzeichnis sind
    if [ -f "./lib_core.sh" ] && [ -f "./manage_folders.sh" ] && [ -f "./manage_files.sh" ]; then
        SCRIPT_DIR="."
        echo "Skriptverzeichnis gefunden: aktuelle Verzeichnis"
    
    # Alternative 2: Prüfe, ob wir bereits im backend-Verzeichnis sind
    elif [ -d "./scripts" ] && [ -f "./scripts/lib_core.sh" ]; then
        SCRIPT_DIR="./scripts"
        echo "Skriptverzeichnis gefunden: $SCRIPT_DIR"
    
    # Alternative 3: Prüfe Standard-Installationspfade
    elif [ -d "/opt/fotobox/backend/scripts" ]; then
        SCRIPT_DIR="/opt/fotobox/backend/scripts"
        echo "Skriptverzeichnis gefunden: $SCRIPT_DIR"
    
    # Wenn keine Alternative funktioniert, brechen wir ab
    else
        echo "FEHLER: Skriptverzeichnis konnte nicht gefunden werden."
        echo "Bitte führen Sie dieses Skript aus dem Root-Verzeichnis des Fotobox-Projekts aus."
        exit 1
    fi
fi

# Vergewissere uns, dass alle benötigten Skripte existieren
if [ ! -f "$SCRIPT_DIR/lib_core.sh" ] || [ ! -f "$SCRIPT_DIR/manage_folders.sh" ] || [ ! -f "$SCRIPT_DIR/manage_files.sh" ]; then
    echo "FEHLER: Benötigte Skriptdateien fehlen im Verzeichnis: $SCRIPT_DIR"
    echo "Vorhandene Dateien im Skriptverzeichnis:"
    ls -la "$SCRIPT_DIR"
    exit 1
fi

echo "==========================================================================="
echo "               Test der Module lib_core.sh, manage_folders.sh"
echo "                      und manage_files.sh"
echo "==========================================================================="
echo

# Laden der erforderlichen Module
echo "Lade Module aus Verzeichnis: $SCRIPT_DIR"

# Debug-Ausgabe zum Anzeigen der vorhandenen Dateien
echo "Vorhandene Dateien im Skriptverzeichnis:"
ls -la "$SCRIPT_DIR"

# Laden von lib_core.sh
echo -n "Lade lib_core.sh... "
source "$SCRIPT_DIR/lib_core.sh"
if [ $? -eq 0 ]; then
    echo "Erfolg."
    echo "Modul lib_core.sh wurde geladen."
else
    echo "FEHLER!"
    echo "Fehler beim Laden von lib_core.sh"
    exit 1
fi

# Laden von manage_folders.sh
echo -n "Lade manage_folders.sh... "
source "$SCRIPT_DIR/manage_folders.sh"
if [ $? -eq 0 ] && [ "${MANAGE_FOLDERS_LOADED:-0}" -eq 1 ]; then
    echo "Erfolg."
    echo "Modul manage_folders.sh wurde geladen."
else
    echo "FEHLER!"
    echo "Fehler beim Laden von manage_folders.sh oder MANAGE_FOLDERS_LOADED ist nicht 1"
    exit 1
fi

# Laden von manage_files.sh
echo -n "Lade manage_files.sh... "
source "$SCRIPT_DIR/manage_files.sh"
if [ $? -eq 0 ] && [ "${MANAGE_FILES_LOADED:-0}" -eq 1 ]; then
    echo "Erfolg."
    echo "Modul manage_files.sh wurde geladen."
else
    echo "FEHLER!"
    echo "Fehler beim Laden von manage_files.sh oder MANAGE_FILES_LOADED ist nicht 1"
    exit 1
fi
echo

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

# -------------------------------
# Test der manage_folders.sh Funktionen
# -------------------------------
echo "-------------------------------------------------------------------------"
echo "Test der Funktionen in manage_folders.sh"
echo "-------------------------------------------------------------------------"

# Test: create_directory
echo -n "Test create_directory: "
test_dir="$CURRENT_DIR/tmp/test_directory"
mkdir -p "$CURRENT_DIR/tmp" 2>/dev/null || true
set +e  # Fehler nicht als fatal behandeln
create_directory "$test_dir"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "create_directory" 0

# Test: create_symlink_to_standard_path
echo -n "Test create_symlink_to_standard_path: "
source_dir="$CURRENT_DIR/tmp/symlink_source"
target_dir="$CURRENT_DIR/tmp/symlink_target"
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
mkdir -p "$CURRENT_DIR/tmp" 2>/dev/null || true
temp_test_file="$CURRENT_DIR/tmp/test_file.txt"
touch "$temp_test_file" 2>/dev/null || true
set +e  # Fehler nicht als fatal behandeln
file_exists "$temp_test_file"
result=$?
set -e  # Fehlerbehandlung wieder aktivieren
test_function $result "file_exists" 0

# Test: create_empty_file
echo -n "Test create_empty_file: "
mkdir -p "$CURRENT_DIR/tmp" 2>/dev/null || true
empty_file="$CURRENT_DIR/tmp/empty_test_file.txt"
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

echo "Testdateien wurden entfernt."
echo
echo "==========================================================================="
echo "                            Test abgeschlossen"
echo "==========================================================================="
