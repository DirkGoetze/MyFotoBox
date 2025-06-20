#!/bin/bash
#
# test_manage_files.sh - Test-Skript für die manage_files.sh Funktionalität
# 
# Teil der Fotobox2 Anwendung
# Copyright (c) 2023-2025 Dirk Götze
#

# Konstanten und Konfiguration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MANAGE_FILES_SH="$SCRIPT_DIR/backend/scripts/manage_files.sh"

# Farben für Ausgabe
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}======== Testing manage_files.sh ========${NC}"

# Prüfen, ob manage_files.sh existiert
if [ ! -f "$MANAGE_FILES_SH" ]; then
    echo -e "${RED}ERROR: $MANAGE_FILES_SH nicht gefunden!${NC}"
    exit 1
fi

# Version abrufen
version=$("$MANAGE_FILES_SH" version)
echo -e "${GREEN}Version von manage_files.sh: $version${NC}"

# Test: Konfigurationsdatei-Pfad abrufen
test_config_file() {
    local result
    
    echo -e "\n${YELLOW}Test: get_config_file${NC}"
    result=$("$MANAGE_FILES_SH" get_config_file "nginx" "fotobox")
    if [ -n "$result" ]; then
        echo -e "${GREEN}get_config_file nginx fotobox: $result${NC}"
    else
        echo -e "${RED}ERROR: get_config_file fehlgeschlagen${NC}"
        return 1
    fi
    
    result=$("$MANAGE_FILES_SH" get_config_file "camera" "default")
    if [ -n "$result" ]; then
        echo -e "${GREEN}get_config_file camera default: $result${NC}"
    else
        echo -e "${RED}ERROR: get_config_file fehlgeschlagen${NC}"
        return 1
    fi
    
    return 0
}

# Test: System-Datei-Pfad abrufen
test_system_file() {
    local result
    
    echo -e "\n${YELLOW}Test: get_system_file${NC}"
    result=$("$MANAGE_FILES_SH" get_system_file "nginx" "fotobox")
    if [ -n "$result" ]; then
        echo -e "${GREEN}get_system_file nginx fotobox: $result${NC}"
    else
        echo -e "${RED}ERROR: get_system_file fehlgeschlagen${NC}"
        return 1
    fi
    
    result=$("$MANAGE_FILES_SH" get_system_file "systemd" "fotobox-backend")
    if [ -n "$result" ]; then
        echo -e "${GREEN}get_system_file systemd fotobox-backend: $result${NC}"
    else
        echo -e "${RED}ERROR: get_system_file fehlgeschlagen${NC}"
        return 1
    fi
    
    return 0
}

# Test: Log-Datei-Pfad abrufen
test_log_file() {
    local result
    
    echo -e "\n${YELLOW}Test: get_log_file${NC}"
    result=$("$MANAGE_FILES_SH" get_log_file "test")
    if [ -n "$result" ]; then
        echo -e "${GREEN}get_log_file test: $result${NC}"
    else
        echo -e "${RED}ERROR: get_log_file fehlgeschlagen${NC}"
        return 1
    fi
    
    return 0
}

# Test: Template-Datei-Pfad abrufen
test_template_file() {
    local result
    
    echo -e "\n${YELLOW}Test: get_template_file${NC}"
    result=$("$MANAGE_FILES_SH" get_template_file "nginx" "backup_file.meta.json")
    if [ -n "$result" ]; then
        echo -e "${GREEN}get_template_file nginx backup_file.meta.json: $result${NC}"
    else
        echo -e "${RED}ERROR: get_template_file fehlgeschlagen${NC}"
        return 1
    fi
    
    return 0
}

# Test: Leere Datei erstellen
test_create_empty_file() {
    local result
    local temp_file="/tmp/fotobox_test_file_$$.tmp"
    
    echo -e "\n${YELLOW}Test: create_empty_file${NC}"
    "$MANAGE_FILES_SH" create_empty_file "$temp_file"
    
    if [ -f "$temp_file" ]; then
        echo -e "${GREEN}create_empty_file erfolgreich: $temp_file${NC}"
        rm -f "$temp_file"
        return 0
    else
        echo -e "${RED}ERROR: create_empty_file fehlgeschlagen${NC}"
        return 1
    fi
}

# Führe alle Tests aus
run_all_tests() {
    local failed=0
    
    test_config_file || ((failed++))
    test_system_file || ((failed++))
    test_log_file || ((failed++))
    test_template_file || ((failed++))
    test_create_empty_file || ((failed++))
    
    if [ $failed -eq 0 ]; then
        echo -e "\n${GREEN}Alle Tests erfolgreich!${NC}"
        return 0
    else
        echo -e "\n${RED}$failed Test(s) fehlgeschlagen!${NC}"
        return 1
    fi
}

# Führe alle Tests aus
run_all_tests
exit $?
