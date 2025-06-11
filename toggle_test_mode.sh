#!/bin/bash
# filepath: c:\Users\HP 800 G1\OneDrive\Dokumente\Götze Dirk\Eigene Projekte\fotobox2\toggle_test_mode.sh

# Script zur Umschaltung des Testmodus für die Fotobox
# Im Testmodus werden alle Cache-Header-Einstellungen aktiviert
# um das Testen ohne Browser-Cache-Probleme zu ermöglichen

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ENV_FILE="${SCRIPT_DIR}/.env"

get_test_mode_status() {
    if [ -f "$ENV_FILE" ]; then
        grep -q "FOTOBOX_TEST_MODE=false" "$ENV_FILE"
        if [ $? -eq 0 ]; then
            return 1  # False
        fi
    fi
    return 0  # True (Default)
}

set_test_mode_status() {
    local enabled=$1
    
    # Entferne alte Einträge
    if [ -f "$ENV_FILE" ]; then
        grep -v "FOTOBOX_TEST_MODE=" "$ENV_FILE" > "${ENV_FILE}.tmp"
        mv "${ENV_FILE}.tmp" "$ENV_FILE"
    else
        touch "$ENV_FILE"
    fi
    
    # Füge neuen Eintrag hinzu
    echo "FOTOBOX_TEST_MODE=$enabled" >> "$ENV_FILE"
    
    # Nginx neu laden, falls verfügbar
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet nginx; then
            echo "Reloading Nginx configuration..."
            sudo systemctl reload nginx
        fi
    fi
    
    # Flask-Server neu starten, falls verfügbar
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet fotobox-backend; then
            echo "Restarting Fotobox service..."
            sudo systemctl restart fotobox-backend
        fi
    fi
}

# Argument-Verarbeitung
case "$1" in
    enable)
        set_test_mode_status "true"
        echo "Testmodus wurde AKTIVIERT. Cache-Kontrolle ist aktiv."
        echo "Browser-Caching ist deaktiviert für einfacheres Testen."
        ;;
    disable)
        set_test_mode_status "false"
        echo "Testmodus wurde DEAKTIVIERT. Cache-Kontrolle ist inaktiv."
        echo "Browser-Caching ist aktiviert für bessere Performance."
        ;;
    status|"")
        get_test_mode_status
        if [ $? -eq 0 ]; then
            echo "Testmodus ist aktiv. Cache-Kontrolle ist aktiviert."
        else
            echo "Testmodus ist inaktiv. Cache-Kontrolle ist deaktiviert."
        fi
        ;;
    *)
        echo "Unbekannte Option: $1"
        ;;
esac

echo ""
echo "Nutzung:"
echo "  ./toggle_test_mode.sh enable    # Aktiviert den Testmodus"
echo "  ./toggle_test_mode.sh disable   # Deaktiviert den Testmodus"
echo "  ./toggle_test_mode.sh status    # Zeigt den aktuellen Status"
echo ""
echo "Hinweis: Nach Änderung des Testmodus kann es erforderlich sein,"
echo "den Browser-Cache manuell zu leeren oder den Browser neu zu starten."
