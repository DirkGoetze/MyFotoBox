"""
manage_camera_config.py - Modul zur Verwaltung von Kamera-Konfigurationen

Dieses Modul ist verantwortlich für das Laden, Speichern und Verwalten von
Kamera-Konfigurationssets, die für die Kamerasteuerung verwendet werden.
Es unterstützt sowohl JSON-Dateien als auch Datenbankeinträge als Konfigurationsquellen.
"""

import os
import json
import glob
import sqlite3
from typing import Dict, List, Optional, Any

import manage_logging
import manage_database
import manage_folders
import utils

# Pfad zum Konfigurationsordner
CONFIG_DIR = manage_folders.get_camera_conf_dir()

# Globale Variablen
_configs = {}  # Cache für geladene Konfigurationen
_active_config = None  # Aktuell ausgewählte Konfiguration

def initialize() -> bool:
    """Initialisiert das Kamera-Konfigurationsmodul
    
    Returns:
        bool: True wenn erfolgreich, False sonst
    """
    global _configs, _active_config
    
    try:
        # Stelle sicher, dass der Konfigurationsordner existiert
        os.makedirs(CONFIG_DIR, exist_ok=True)
        
        # Lade alle verfügbaren Konfigurationen
        _configs = {}
        _active_config = None
        
        # Lade die Konfigurationen aus den JSON-Dateien
        config_files = glob.glob(os.path.join(CONFIG_DIR, "*.json"))
        
        if not config_files:
            manage_logging.warn("Keine Kamera-Konfigurationsdateien gefunden", source="manage_camera_config")
        
        for config_file in config_files:
            try:
                config_id = os.path.splitext(os.path.basename(config_file))[0]
                with open(config_file, 'r', encoding='utf-8') as f:
                    config_data = json.load(f)
                
                # Füge die Konfiguration zum Cache hinzu
                if 'name' in config_data:
                    _configs[config_id] = config_data
                    manage_logging.debug(f"Kamera-Konfiguration geladen: {config_data['name']} (ID: {config_id})", 
                                        source="manage_camera_config")
            except Exception as e:
                manage_logging.error(f"Fehler beim Laden der Konfigurationsdatei {config_file}: {str(e)}", 
                                    exception=e, source="manage_camera_config")
        
        # Versuche, die aktive Konfiguration aus den Einstellungen zu laden
        _active_config = get_active_config_from_db()
        
        # Wenn keine aktive Konfiguration in der DB gefunden wurde, verwende die erste verfügbare
        if _active_config is None and _configs:
            _active_config = next(iter(_configs.keys()))
            save_active_config_to_db(_active_config)  # Speichere die Auswahl in der DB
        
        # Status melden
        if _configs:
            manage_logging.log(f"{len(_configs)} Kamera-Konfigurationen geladen", source="manage_camera_config")
            return True
        else:
            manage_logging.warn("Keine Kamera-Konfigurationen verfügbar", source="manage_camera_config")
            return False
    
    except Exception as e:
        manage_logging.error(f"Fehler bei der Initialisierung des Kamera-Konfigurationsmoduls: {str(e)}", 
                           exception=e, source="manage_camera_config")
        return False

def get_camera_configs() -> List[Dict]:
    """Gibt eine Liste aller verfügbaren Kamera-Konfigurationen zurück
    
    Returns:
        Liste mit Konfigurationen (ID und Name)
    """
    global _configs
    
    # Wenn der Cache leer ist, initialisiere
    if not _configs:
        initialize()
    
    result = []
    for config_id, config_data in _configs.items():
        result.append({
            'id': config_id,
            'name': config_data.get('name', 'Unbenannte Konfiguration'),
            'description': config_data.get('description', ''),
            'type': config_data.get('type', 'unknown')
        })
    
    return result

def get_config(config_id: str) -> Optional[Dict]:
    """Gibt eine bestimmte Kamera-Konfiguration zurück
    
    Args:
        config_id: ID der Konfiguration
    
    Returns:
        Dict mit Konfigurationseinstellungen oder None
    """
    global _configs
    
    # Wenn der Cache leer ist, initialisiere
    if not _configs:
        initialize()
    
    return _configs.get(config_id)

def get_active_config() -> Optional[Dict]:
    """Gibt die aktuell aktive Kamera-Konfiguration zurück
    
    Returns:
        Dict mit Konfigurationseinstellungen oder None
    """
    global _configs, _active_config
    
    # Wenn der Cache leer ist, initialisiere
    if not _configs:
        initialize()
    
    if _active_config and _active_config in _configs:
        return _configs[_active_config]
    return None

def set_active_config(config_id: str) -> bool:
    """Setzt die aktiv verwendete Kamera-Konfiguration
    
    Args:
        config_id: ID der zu verwendenden Konfiguration
    
    Returns:
        bool: True wenn erfolgreich, False sonst
    """
    global _configs, _active_config
    
    # Wenn der Cache leer ist, initialisiere
    if not _configs:
        initialize()
    
    if config_id in _configs:
        _active_config = config_id
        # Speichere die Auswahl in der Datenbank
        return save_active_config_to_db(config_id)
    else:
        manage_logging.error(f"Kamera-Konfiguration mit ID {config_id} existiert nicht", source="manage_camera_config")
        return False

def create_config(config_data: Dict) -> Optional[str]:
    """Erstellt eine neue Kamera-Konfiguration
    
    Args:
        config_data: Konfigurationsdaten
    
    Returns:
        ID der erstellten Konfiguration oder None bei Fehler
    """
    global _configs
    
    try:
        # Validiere die erforderlichen Felder
        if not config_data.get('name'):
            manage_logging.error("Konfigurationsname fehlt", source="manage_camera_config")
            return None
        
        # Erzeuge eine eindeutige ID für die Konfiguration
        base_id = utils.normalize_string(config_data['name'].lower().replace(' ', '_'))
        config_id = base_id
        counter = 1
        
        # Stelle sicher, dass die ID eindeutig ist
        while config_id in _configs:
            config_id = f"{base_id}_{counter}"
            counter += 1
        
        # Speichere die Konfiguration als JSON-Datei
        config_path = os.path.join(CONFIG_DIR, f"{config_id}.json")
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config_data, f, indent=4, ensure_ascii=False)
        
        # Füge die Konfiguration zum Cache hinzu
        _configs[config_id] = config_data
        
        manage_logging.log(f"Neue Kamera-Konfiguration erstellt: {config_data['name']} (ID: {config_id})", 
                         source="manage_camera_config")
        return config_id
    
    except Exception as e:
        manage_logging.error(f"Fehler beim Erstellen der Kamera-Konfiguration: {str(e)}", 
                           exception=e, source="manage_camera_config")
        return None

def update_config(config_id: str, config_data: Dict) -> bool:
    """Aktualisiert eine bestehende Kamera-Konfiguration
    
    Args:
        config_id: ID der zu aktualisierenden Konfiguration
        config_data: Neue Konfigurationsdaten
    
    Returns:
        bool: True wenn erfolgreich, False sonst
    """
    global _configs
    
    if config_id not in _configs:
        manage_logging.error(f"Kamera-Konfiguration mit ID {config_id} existiert nicht", source="manage_camera_config")
        return False
    
    try:
        # Aktualisiere die Konfiguration im Cache
        _configs[config_id] = config_data
        
        # Speichere die aktualisierte Konfiguration als JSON-Datei
        config_path = os.path.join(CONFIG_DIR, f"{config_id}.json")
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config_data, f, indent=4, ensure_ascii=False)
        
        manage_logging.log(f"Kamera-Konfiguration aktualisiert: {config_data.get('name', config_id)}", 
                         source="manage_camera_config")
        return True
    
    except Exception as e:
        manage_logging.error(f"Fehler beim Aktualisieren der Kamera-Konfiguration {config_id}: {str(e)}", 
                           exception=e, source="manage_camera_config")
        return False

def delete_config(config_id: str) -> bool:
    """Löscht eine Kamera-Konfiguration
    
    Args:
        config_id: ID der zu löschenden Konfiguration
    
    Returns:
        bool: True wenn erfolgreich, False sonst
    """
    global _configs, _active_config
    
    if config_id not in _configs:
        manage_logging.error(f"Kamera-Konfiguration mit ID {config_id} existiert nicht", source="manage_camera_config")
        return False
    
    try:
        # Lösche die Konfigurationsdatei
        config_path = os.path.join(CONFIG_DIR, f"{config_id}.json")
        if os.path.exists(config_path):
            os.remove(config_path)
        
        # Entferne die Konfiguration aus dem Cache
        del _configs[config_id]
        
        # Wenn die gelöschte Konfiguration die aktive war, setze die aktive Konfiguration zurück
        if _active_config == config_id:
            if _configs:
                # Verwende die erste verfügbare Konfiguration
                _active_config = next(iter(_configs.keys()))
                save_active_config_to_db(_active_config)
            else:
                _active_config = None
                save_active_config_to_db(None)
        
        manage_logging.log(f"Kamera-Konfiguration gelöscht: {config_id}", source="manage_camera_config")
        return True
    
    except Exception as e:
        manage_logging.error(f"Fehler beim Löschen der Kamera-Konfiguration {config_id}: {str(e)}", 
                           exception=e, source="manage_camera_config")
        return False

def get_active_config_from_db() -> Optional[str]:
    """Lädt die aktive Kamera-Konfiguration aus der Datenbank
    
    Returns:
        ID der aktiven Konfiguration oder None
    """
    try:
        conn = manage_database.get_db_connection()
        cursor = conn.cursor()
        
        # Prüfe, ob die Einstellung existiert
        cursor.execute("SELECT value FROM settings WHERE key = 'camera_config_id'")
        result = cursor.fetchone()
        
        if result:
            config_id = result[0]
            # Prüfe, ob die Konfiguration existiert
            if config_id in _configs:
                return config_id
            else:
                manage_logging.warn(f"Gespeicherte Kamera-Konfiguration {config_id} existiert nicht mehr", 
                                  source="manage_camera_config")
        
        return None
    
    except Exception as e:
        manage_logging.error(f"Fehler beim Laden der aktiven Kamera-Konfiguration aus der DB: {str(e)}", 
                           exception=e, source="manage_camera_config")
        return None

def save_active_config_to_db(config_id: Optional[str]) -> bool:
    """Speichert die aktive Kamera-Konfiguration in der Datenbank
    
    Args:
        config_id: ID der aktiven Konfiguration oder None
    
    Returns:
        bool: True wenn erfolgreich, False sonst
    """
    try:
        conn = manage_database.get_db_connection()
        cursor = conn.cursor()
        
        # Prüfe, ob die Einstellung bereits existiert
        cursor.execute("SELECT 1 FROM settings WHERE key = 'camera_config_id'")
        result = cursor.fetchone()
        
        if result:
            # Aktualisiere den vorhandenen Eintrag
            if config_id is not None:
                cursor.execute("UPDATE settings SET value = ? WHERE key = 'camera_config_id'", (config_id,))
            else:
                cursor.execute("DELETE FROM settings WHERE key = 'camera_config_id'")
        else:
            # Füge einen neuen Eintrag hinzu, aber nur wenn config_id nicht None ist
            if config_id is not None:
                cursor.execute("INSERT INTO settings (key, value) VALUES ('camera_config_id', ?)", (config_id,))
        
        conn.commit()
        return True
    
    except Exception as e:
        manage_logging.error(f"Fehler beim Speichern der aktiven Kamera-Konfiguration in der DB: {str(e)}", 
                           exception=e, source="manage_camera_config")
        return False

# Initialisiere das Modul beim Import
try:
    initialize()
except Exception as e:
    manage_logging.error(f"Fehler bei der Initialisierung des Kamera-Konfigurationsmoduls: {str(e)}", 
                       exception=e, source="manage_camera_config")
