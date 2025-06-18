#!/bin/bash
# -----------------------------------------------------------------------------
# fix_symlinks.sh - Korrigiert die Symlinks in der Fotobox-Installation
# -----------------------------------------------------------------------------

# Prüfe, ob das Skript mit Root-Rechten ausgeführt wird
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Dieses Skript muss mit Root-Rechten ausgeführt werden (sudo)."
    exit 1
fi

echo "=== Symlink-Reparaturprogramm für Fotobox ==="
echo "Dieses Skript korrigiert die Symlinks für Log- und Temp-Verzeichnisse."

# Bestimme Installationsverzeichnis dynamisch
find_installation_dir() {
    local possible_dirs=("/opt/fotobox" "/var/lib/fotobox" "/usr/local/fotobox")
    
    # Überprüfe Konfigurations-Datei
    if [ -f "/etc/fotobox/config" ]; then
        echo "Konfigurationsdatei gefunden, lese Installationsverzeichnis..."
        source "/etc/fotobox/config"
        if [ -n "$FOTOBOX_INSTALL_DIR" ] && [ -d "$FOTOBOX_INSTALL_DIR" ]; then
            echo "Installationsverzeichnis aus Konfiguration: $FOTOBOX_INSTALL_DIR"
            echo "$FOTOBOX_INSTALL_DIR"
            return 0
        fi
    fi
    
    # Überprüfe mögliche Standardverzeichnisse
    for dir in "${possible_dirs[@]}"; do
        if [ -d "$dir" ] && [ -f "$dir/backend/app.py" ]; then
            echo "Fotobox-Installation gefunden in: $dir"
            echo "$dir"
            return 0
        fi
    done
    
    # Fallback auf das wahrscheinlichste Verzeichnis
    for dir in "${possible_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "Mögliche Fotobox-Installation gefunden in: $dir"
            echo "$dir"
            return 0
        fi
    done
    
    # Wenn alles fehlschlägt, Standard verwenden
    echo "/opt/fotobox"
    return 1
}

# Ermittle Installationsverzeichnis
INSTALL_DIR=$(find_installation_dir)
echo "Verwende Installationsverzeichnis: $INSTALL_DIR"

# Prüfe, ob das Installationsverzeichnis existiert
if [ ! -d "$INSTALL_DIR" ]; then
    echo "FEHLER: Das Verzeichnis $INSTALL_DIR existiert nicht."
    echo "Die Fotobox-Installation scheint fehlerhaft zu sein."
    mkdir -p "$INSTALL_DIR"
    echo "Verzeichnis wurde erstellt, setze Reparatur fort..."
fi

# Setze benötigte Umgebungsvariablen
export INSTALL_DIR="$INSTALL_DIR"

# Ermittle Standard-Quellverzeichnisse
LOG_DIR="$INSTALL_DIR/log"
TMP_DIR="$INSTALL_DIR/tmp"

# Prüfe, ob manage_folders.sh verfügbar ist und verwendet werden kann
MANAGE_FOLDERS="$INSTALL_DIR/backend/scripts/manage_folders.sh"
LIB_CORE="$INSTALL_DIR/backend/scripts/lib_core.sh"

if [ -f "$LIB_CORE" ] && [ -f "$MANAGE_FOLDERS" ]; then
    echo "Lade Kernbibliotheken und Verzeichnisfunktionen..."
    source "$LIB_CORE"
    source "$MANAGE_FOLDERS"
    
    if type -t get_log_dir &>/dev/null; then
        LOG_DIR=$(get_log_dir)
        echo "Log-Verzeichnis laut get_log_dir(): $LOG_DIR"
    else
        echo "WARNUNG: get_log_dir() nicht verfügbar, verwende Standardpfad: $LOG_DIR"
    fi
    
    if type -t get_tmp_dir &>/dev/null; then
        TMP_DIR=$(get_tmp_dir)
        echo "Temp-Verzeichnis laut get_tmp_dir(): $TMP_DIR"
    else
        echo "WARNUNG: get_tmp_dir() nicht verfügbar, verwende Standardpfad: $TMP_DIR"
    fi
else
    echo "WARNUNG: Kernbibliotheken nicht gefunden. Verwende Standard-Verzeichnisse."
    # Stellen sicher, dass Verzeichnisse den Standardwerten entsprechen
    LOG_DIR="$INSTALL_DIR/log"
    TMP_DIR="$INSTALL_DIR/tmp"
fi

# Prüfe, ob die ermittelten Verzeichnisse existieren
if [ ! -d "$LOG_DIR" ]; then
    echo "WARNUNG: Das Log-Verzeichnis $LOG_DIR existiert nicht, wird erstellt."
    mkdir -p "$LOG_DIR"
    chown fotobox:fotobox "$LOG_DIR" 2>/dev/null || true
    chmod 755 "$LOG_DIR" 2>/dev/null || true
fi

if [ ! -d "$TMP_DIR" ]; then
    echo "WARNUNG: Das Temp-Verzeichnis $TMP_DIR existiert nicht, wird erstellt."
    mkdir -p "$TMP_DIR"
    chown fotobox:fotobox "$TMP_DIR" 2>/dev/null || true
    chmod 755 "$TMP_DIR" 2>/dev/null || true
fi

# Log-Verzeichnis Korrektur
echo ""
echo "== Korrektur des Log-Verzeichnisses =="
if [ -L "/var/log/fotobox" ]; then
    echo "Der Symlink /var/log/fotobox existiert bereits. Überprüfe Ziel..."
    TARGET=$(readlink -f "/var/log/fotobox")
    if [ "$TARGET" != "$LOG_DIR" ]; then
        echo "Der Symlink /var/log/fotobox zeigt auf $TARGET, sollte aber auf $LOG_DIR zeigen."
        echo "Korrigiere Symlink..."
        rm -f "/var/log/fotobox"
        ln -sf "$LOG_DIR" "/var/log/fotobox"
        echo "✓ Symlink korrigiert."
    else
        echo "✓ Der Symlink /var/log/fotobox ist korrekt."
    fi
elif [ -d "/var/log/fotobox" ]; then
    echo "Das Verzeichnis /var/log/fotobox existiert, ist aber kein Symlink."
    echo "Sichere Inhalte..."
    
    # Erstellen des Zielverzeichnisses, falls es noch nicht existiert
    mkdir -p "$LOG_DIR"
    
    # Sichere alle Dateien aus /var/log/fotobox nach $LOG_DIR
    echo "Kopiere Dateien von /var/log/fotobox nach $LOG_DIR..."
    find /var/log/fotobox -type f -exec cp -f {} "$LOG_DIR/" \; 2>/dev/null || echo "Keine Dateien zu kopieren"
    
    echo "Entferne Verzeichnis und erstelle Symlink..."
    rm -rf "/var/log/fotobox"
    ln -sf "$LOG_DIR" "/var/log/fotobox"
    echo "✓ Symlink erstellt."
else
    echo "Das Verzeichnis /var/log/fotobox existiert nicht. Erstelle Symlink..."
    ln -sf "$LOG_DIR" "/var/log/fotobox"
    echo "✓ Symlink erstellt."
fi

# Temp-Verzeichnis Korrektur
echo ""
echo "== Korrektur des Temp-Verzeichnisses =="

if [ -L "/tmp/fotobox" ]; then
    echo "Der Symlink /tmp/fotobox existiert bereits. Überprüfe Ziel..."
    TARGET=$(readlink -f "/tmp/fotobox")
    if [ "$TARGET" != "$TMP_DIR" ]; then
        echo "Der Symlink /tmp/fotobox zeigt auf $TARGET, sollte aber auf $TMP_DIR zeigen."
        echo "Korrigiere Symlink..."
        rm -f "/tmp/fotobox"
        ln -sf "$TMP_DIR" "/tmp/fotobox"
        echo "✓ Symlink korrigiert."
    else
        echo "✓ Der Symlink /tmp/fotobox ist korrekt."
    fi
elif [ -d "/tmp/fotobox" ]; then
    echo "Das Verzeichnis /tmp/fotobox existiert, ist aber kein Symlink."
    echo "Sichere Inhalte..."
    
    # Erstellen des Zielverzeichnisses, falls es noch nicht existiert
    mkdir -p "$TMP_DIR"
    
    # Sichere alle Dateien aus /tmp/fotobox nach $TMP_DIR
    echo "Kopiere Dateien von /tmp/fotobox nach $TMP_DIR..."
    find /tmp/fotobox -type f -exec cp -f {} "$TMP_DIR/" \; 2>/dev/null || echo "Keine Dateien zu kopieren"
    
    echo "Entferne Verzeichnis und erstelle Symlink..."
    rm -rf "/tmp/fotobox"
    ln -sf "$TMP_DIR" "/tmp/fotobox"
    echo "✓ Symlink erstellt."
else
    echo "Das Verzeichnis /tmp/fotobox existiert nicht. Erstelle Symlink..."
    ln -sf "$TMP_DIR" "/tmp/fotobox"
    echo "✓ Symlink erstellt."
fi

# Setze Berechtigungen für die Verzeichnisse
echo ""
echo "== Setze Berechtigungen für die Verzeichnisse =="
chown -R fotobox:fotobox "$LOG_DIR" 2>/dev/null || echo "Warnung: Berechtigungen für $LOG_DIR konnten nicht gesetzt werden"
chmod -R 755 "$LOG_DIR" 2>/dev/null || echo "Warnung: Berechtigungen für $LOG_DIR konnten nicht gesetzt werden"

chown -R fotobox:fotobox "$TMP_DIR" 2>/dev/null || echo "Warnung: Berechtigungen für $TMP_DIR konnten nicht gesetzt werden"
chmod -R 755 "$TMP_DIR" 2>/dev/null || echo "Warnung: Berechtigungen für $TMP_DIR konnten nicht gesetzt werden"

# Prüfe, ob wir ein Backend-Update auslösen sollten
if [ -f "$INSTALL_DIR/backend/app.py" ]; then
    echo ""
    echo "== Neustarten des Backend-Dienstes =="
    if systemctl is-active --quiet fotobox-backend; then
        echo "Backend-Dienst wird neu gestartet..."
        systemctl restart fotobox-backend
        echo "✓ Backend-Dienst wurde neu gestartet."
    else
        echo "Backend-Dienst ist nicht aktiv."
    fi
fi

echo ""
echo "=== Symlinks wurden erfolgreich repariert ==="
echo "Bitte überprüfen Sie die Funktion mit folgenden Befehlen:"
echo "ls -la /var/log/fotobox"
echo "ls -la /tmp/fotobox"

# Zeige aktuelle Status-Informationen
echo ""
echo "== Aktuelle Symlink-Konfiguration =="
echo "Log-Symlink:"
ls -la /var/log/fotobox
echo ""
echo "Temp-Symlink:"
ls -la /tmp/fotobox

exit 0
