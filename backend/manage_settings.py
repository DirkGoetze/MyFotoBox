"""
Manage Settings-Modul für die Fotobox2 Backend-Anwendung

Dieses Modul bietet Funktionen zum Laden, Validieren und Speichern von Einstellungen.
Es fungiert als zentrale Schnittstelle für alle einstellungsbezogenen Operationen.
"""

# TODO: Integration mit manage_settings.sh
# - Wrapper-Funktionen für die wichtigsten Bash-Funktionen implementieren (get_config_value, set_config_value, etc.)
# - Kompatibilitätsschicht zwischen alter und neuer API
# - Unterstützung für hierarchische Schlüssel und Gruppen-IDs
# - Fehlerbehandlung und Status-Mapping zwischen Bash und Python
# - Siehe detaillierte Anforderungen in 2025-07-02 Konfigurationswerte_neu.todo

import os
import json
import logging
import shutil
from datetime import datetime
from typing import Dict, Any, List, Union, Optional, Tuple

# Logger einrichten
logger = logging.getLogger(__name__)

# Importiere manage_folders für zentrale Pfadverwaltung
try:
    from manage_folders import (
        get_data_dir, get_config_dir, get_backup_dir,
        get_log_dir, get_photos_dir
    )
    
    DATA_DIR = get_data_dir()
    CONFIG_DIR = get_config_dir()
    BACKUP_DIR = get_backup_dir()
    LOG_DIR = get_log_dir()
    PHOTOS_DIR = get_photos_dir()
    
except ImportError as e:
    logger.error(f"Fehler beim Import von manage_folders: {e}")
    # Fallback auf Standardpfade, aber mit Warnung
    DATA_DIR = "/opt/fotobox/data"
    CONFIG_DIR = "/opt/fotobox/conf"
    BACKUP_DIR = "/opt/fotobox/backup"
    LOG_DIR = "/opt/fotobox/log"
    PHOTOS_DIR = "/opt/fotobox/frontend/photos"
    logger.warning(f"Verwende Standardpfade: DATA_DIR={DATA_DIR}")

# Stelle sicher, dass die Verzeichnisse existieren
for directory in [DATA_DIR, CONFIG_DIR, BACKUP_DIR, LOG_DIR, PHOTOS_DIR]:
    os.makedirs(directory, mode=0o755, exist_ok=True)
    # Setze Benutzer/Gruppe auf fotobox
    try:
        shutil.chown(directory, user='fotobox', group='fotobox')
    except Exception as e:
        logger.warning(f"Konnte Berechtigungen für {directory} nicht setzen: {e}")

# Pfad zur Einstellungsdatei
SETTINGS_FILE = os.path.join(DATA_DIR, "settings.json")

# Standard-Einstellungen (als Fallback)
DEFAULT_SETTINGS = {
    "system": {
        "event_name": "Fotobox Event",
        "event_date": datetime.now().strftime("%Y-%m-%d"),
        "color_mode": "system",
        "language": "de_DE",
        "debug_mode": False
    },
    "interface": {
        "screensaver_timeout": 120,
        "gallery_timeout": 60,
        "countdown_duration": 3
    },
    "camera": {
        "camera_id": "auto",
        "flash_mode": "auto",
        "image_format": "jpeg",
        "image_quality": 95
    },
    "storage": {
        "backup_enabled": True,
        "auto_cleanup": True,
        "min_free_space": 1000  # MB
    }
}

# Validierungsregeln
VALIDATION_RULES = {
    "system.event_name": {
        "required": True,
        "max_length": 50
    },
    "interface.screensaver_timeout": {
        "required": True,
        "type": "number",
        "min": 30,
        "max": 600
    },
    "interface.gallery_timeout": {
        "required": True,
        "type": "number",
        "min": 30,
        "max": 300
    },
    "interface.countdown_duration": {
        "required": True,
        "type": "number",
        "min": 1,
        "max": 10
    },
    "camera.image_quality": {
        "required": True,
        "type": "number",
        "min": 1,
        "max": 100
    }
}

def ensure_settings_backup() -> bool:
    """
    Erstellt ein Backup der Einstellungsdatei falls nötig
    
    Returns:
        bool: True wenn Backup erstellt oder nicht nötig, False bei Fehler
    """
    if not os.path.exists(SETTINGS_FILE):
        return True
        
    try:
        # Erstelle Backup mit Zeitstempel
        backup_file = os.path.join(
            BACKUP_DIR,
            f"settings_{datetime.now():%Y%m%d_%H%M%S}.json"
        )
        shutil.copy2(SETTINGS_FILE, backup_file)
        logger.info(f"Einstellungs-Backup erstellt: {backup_file}")
        return True
    except Exception as e:
        logger.error(f"Fehler beim Erstellen des Einstellungs-Backups: {e}")
        return False

def load_settings() -> Dict[str, Any]:
    """Lädt alle Einstellungen aus der Datenbank oder Datei
    
    Returns:
        Dict[str, Any]: Ein Dictionary mit allen Einstellungen
    """
    logger.debug("Lade alle Einstellungen")
    
    try:
        # Versuche, die Einstellungen aus der Datei zu laden
        if os.path.exists(SETTINGS_FILE):
            with open(SETTINGS_FILE, 'r', encoding='utf-8') as file:
                settings = json.load(file)
                logger.info("Einstellungen erfolgreich geladen")
                return settings
    except Exception as e:
        logger.error(f"Fehler beim Laden der Einstellungen: {str(e)}")
    
    # Wenn nicht erfolgreich, gebe Standardeinstellungen zurück
    logger.warning("Keine Einstellungen gefunden, verwende Standardeinstellungen")
    return DEFAULT_SETTINGS.copy()

def load_single_setting(key: str, default_value: Any = None) -> Any:
    """Lädt eine einzelne Einstellung
    
    Args:
        key (str): Schlüssel der Einstellung
        default_value (Any, optional): Standardwert, falls nicht gefunden. Defaults to None.
    
    Returns:
        Any: Der Wert der Einstellung oder der Standardwert
    """
    logger.debug(f"Lade Einstellung: {key}")
    
    try:
        # Lade alle Einstellungen
        settings = load_settings()
        
        # Gebe den spezifischen Wert zurück, falls vorhanden
        if key in settings:
            return settings[key]
        
        # Prüfe auf Standardwert in DEFAULT_SETTINGS
        if key in DEFAULT_SETTINGS:
            logger.debug(f"Verwende Standardwert für {key}")
            return DEFAULT_SETTINGS[key]
            
        # Fallback auf den übergebenen Standardwert
        logger.debug(f"Kein Wert für {key} gefunden, verwende übergebenen Standardwert")
        return default_value
    except Exception as e:
        logger.error(f"Fehler beim Laden der Einstellung {key}: {str(e)}")
        
        # Verwende Standardwerte als Fallback
        if key in DEFAULT_SETTINGS:
            return DEFAULT_SETTINGS[key]
        
        return default_value

def update_settings(settings: Dict[str, Any]) -> bool:
    """Aktualisiert mehrere Einstellungen auf einmal
    
    Args:
        settings (Dict[str, Any]): Dictionary mit zu aktualisierenden Einstellungen
    
    Returns:
        bool: True wenn erfolgreich, sonst False
    """
    logger.debug(f"Aktualisiere Einstellungen: {settings}")
    
    # Validiere alle übergebenen Einstellungen
    validation_result, validation_errors = validate_settings(settings)
    if not validation_result:
        logger.error(f"Validierung fehlgeschlagen: {validation_errors}")
        return False
    
    try:
        # Lade aktuelle Einstellungen
        current_settings = load_settings()
        
        # Aktualisiere nur die übergebenen Einstellungen
        for key, value in settings.items():
            current_settings[key] = value
        
        # Stelle sicher, dass das Verzeichnis existiert
        os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
        
        # Speichere die aktualisierten Einstellungen
        with open(SETTINGS_FILE, 'w', encoding='utf-8') as file:
            json.dump(current_settings, file, indent=2, ensure_ascii=False)
        
        logger.info("Einstellungen erfolgreich aktualisiert")
        return True
    except Exception as e:
        logger.error(f"Fehler beim Aktualisieren der Einstellungen: {str(e)}")
        return False

def update_single_setting(key: str, value: Any) -> bool:
    """Aktualisiert eine einzelne Einstellung
    
    Args:
        key (str): Schlüssel der Einstellung
        value (Any): Neuer Wert
    
    Returns:
        bool: True wenn erfolgreich, sonst False
    """
    logger.debug(f"Aktualisiere Einstellung {key}: {value}")
    
    # Erstelle ein Dictionary mit der einzelnen Einstellung
    setting_dict = {key: value}
    
    # Validiere nur diese eine Einstellung
    validation_result, validation_errors = validate_settings(setting_dict, [key])
    if not validation_result:
        logger.error(f"Validierung für {key} fehlgeschlagen: {validation_errors}")
        return False
    
    # Verwende die allgemeine update_settings Funktion
    return update_settings(setting_dict)

def validate_settings(settings: Dict[str, Any], keys: Optional[List[str]] = None) -> Tuple[bool, Dict[str, str]]:
    """Validiert Einstellungen basierend auf definierten Regeln
    
    Args:
        settings (Dict[str, Any]): Zu validierende Einstellungen
        keys (Optional[List[str]], optional): Optionale Liste von Schlüsseln, die validiert werden sollen

    Returns:
        Tuple[bool, Dict[str, str]]: (Erfolg, Fehlermeldungen)
    """
    errors = {}
    keys_to_validate = keys if keys is not None else list(settings.keys())
    
    for key in keys_to_validate:
        if key not in settings:
            continue
            
        value = settings[key]
        
        # Prüfe, ob es Validierungsregeln für diesen Schlüssel gibt
        if key not in VALIDATION_RULES:
            continue
            
        rules = VALIDATION_RULES[key]
        
        # Pflichtfeld-Prüfung
        if rules.get("required", False) and (value is None or value == ""):
            errors[key] = f"{key} ist ein Pflichtfeld"
            continue
            
        # Zahlen-Validierung
        if rules.get("type") == "number" and value is not None:
            try:
                num_value = float(value)
                
                # Minimalwert-Prüfung
                if "min" in rules and num_value < rules["min"]:
                    errors[key] = f"{key} muss mindestens {rules['min']} sein"
                    continue
                    
                # Maximalwert-Prüfung
                if "max" in rules and num_value > rules["max"]:
                    errors[key] = f"{key} darf höchstens {rules['max']} sein"
                    continue
            except (ValueError, TypeError):
                errors[key] = f"{key} muss eine Zahl sein"
                continue
                
        # Textlängen-Validierung
        if isinstance(value, str) and "max_length" in rules and len(value) > rules["max_length"]:
            errors[key] = f"{key} darf höchstens {rules['max_length']} Zeichen enthalten"
            continue
    
    return len(errors) == 0, errors

def reset_to_defaults(keys: Optional[List[str]] = None) -> bool:
    """Setzt Einstellungen auf Standardwerte zurück
    
    Args:
        keys (Optional[List[str]], optional): Optionale Liste von Schlüsseln, die zurückgesetzt werden sollen
    
    Returns:
        bool: True wenn erfolgreich, sonst False
    """
    logger.debug("Setze Einstellungen auf Standardwerte zurück")
    
    try:
        # Lade aktuelle Einstellungen
        current_settings = load_settings()
        
        # Definiere, welche Schlüssel zurückgesetzt werden sollen
        keys_to_reset = keys if keys is not None else list(DEFAULT_SETTINGS.keys())
        
        # Setze die ausgewählten Schlüssel auf die Standardwerte zurück
        for key in keys_to_reset:
            if key in DEFAULT_SETTINGS:
                current_settings[key] = DEFAULT_SETTINGS[key]
        
        # Speichere die aktualisierten Einstellungen
        with open(SETTINGS_FILE, 'w', encoding='utf-8') as file:
            json.dump(current_settings, file, indent=2, ensure_ascii=False)
        
        logger.info("Einstellungen erfolgreich auf Standardwerte zurückgesetzt")
        return True
    except Exception as e:
        logger.error(f"Fehler beim Zurücksetzen der Einstellungen: {str(e)}")
        return False

# Initialisierungscode
logger.debug("Einstellungs-Modul initialisiert")
