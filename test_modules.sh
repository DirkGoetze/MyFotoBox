#!/bin/bash
# ---------------------------------------------------------------------------
# test_modules.sh
# ---------------------------------------------------------------------------
# Funktion: Testet die Funktionen in manage_folders.sh und manage_files.sh
# ......... mit gültigen Parametern und überprüft deren Rückgabewerte.
# ---------------------------------------------------------------------------

# Skriptpfad für korrekte Ausführung aus dem Root-Verzeichnis
CURRENT_DIR=$(pwd)
SCRIPT_DIR="$CURRENT_DIR/backend/scripts"

# Prüfen, ob im Root-Verzeichnis des Projekts ausgeführt
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "FEHLER: Dieses Skript muss aus dem Root-Verzeichnis des Fotobox-Projekts ausgeführt werden."
    exit 1
fi

echo "==========================================================================="
echo "               Test der Module lib_core.sh, manage_folders.sh"
echo "                      und manage_files.sh"
echo "==========================================================================="
echo

# Laden der erforderlichen Module
if [ ! -f "$SCRIPT_DIR/lib_core.sh" ]; then
    echo "FEHLER: lib_core.sh nicht gefunden!"
    exit 1
fi

# Laden von lib_core.sh
source "$SCRIPT_DIR/lib_core.sh"
echo "Modul lib_core.sh wurde geladen."

# Laden von manage_folders.sh
if [ ! -f "$SCRIPT_DIR/manage_folders.sh" ]; then
    echo "FEHLER: manage_folders.sh nicht gefunden!"
    exit 1
fi

source "$SCRIPT_DIR/manage_folders.sh"
if [ $MANAGE_FOLDERS_LOADED -eq 0 ]; then
    echo "FEHLER: manage_folders.sh konnte nicht korrekt geladen werden!"
    exit 1
fi
echo "Modul manage_folders.sh wurde geladen."

# Laden von manage_files.sh
if [ ! -f "$SCRIPT_DIR/manage_files.sh" ]; then
    echo "FEHLER: manage_files.sh nicht gefunden!"
    exit 1
fi

source "$SCRIPT_DIR/manage_files.sh"
if [ $MANAGE_FILES_LOADED -eq 0 ]; then
    echo "FEHLER: manage_files.sh konnte nicht korrekt geladen werden!"
    exit 1
fi
echo "Modul manage_files.sh wurde geladen."
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
create_directory "$test_dir"
test_function $? "create_directory" 0

# Test: create_symlink_to_standard_path
echo -n "Test create_symlink_to_standard_path: "
source_dir="$CURRENT_DIR/tmp/symlink_source"
target_dir="$CURRENT_DIR/tmp/symlink_target"
create_directory "$target_dir"
create_symlink_to_standard_path "$source_dir" "$target_dir"
test_function $? "create_symlink_to_standard_path" 0

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
config_file=$(get_config_file "system" "version")
if [ -n "$config_file" ]; then
    echo "✅ Die Funktion get_config_file wurde erfolgreich ausgeführt. Ergebnis: $config_file"
else
    echo "❌ Die Funktion get_config_file ist fehlgeschlagen."
fi

# Test: get_template_file
echo -n "Test get_template_file: "
template_file=$(get_template_file "nginx" "fotobox")
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
system_file=$(get_system_file "nginx" "fotobox")
if [ -n "$system_file" ]; then
    echo "✅ Die Funktion get_system_file wurde erfolgreich ausgeführt. Ergebnis: $system_file"
else
    echo "❌ Die Funktion get_system_file ist fehlgeschlagen."
fi

# Test: file_exists
echo -n "Test file_exists: "
# Erstelle eine temporäre Datei
temp_test_file="$CURRENT_DIR/tmp/test_file.txt"
touch "$temp_test_file"
file_exists "$temp_test_file"
test_function $? "file_exists" 0

# Test: create_empty_file
echo -n "Test create_empty_file: "
empty_file="$CURRENT_DIR/tmp/empty_test_file.txt"
create_empty_file "$empty_file"
test_function $? "create_empty_file" 0

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
