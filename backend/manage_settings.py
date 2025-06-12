"""
Manage Settings-Modul für die Fotobox2 Backend-Anwendung

Dieses Modul bietet Funktionen zum Laden, Validieren und Speichern von Einstellungen.
Es fungiert als zentrale Schnittstelle für alle einstellungsbezogenen Operationen.
"""

import os
import json
import logging
from datetime import datetime
from typing import Dict, Any, List, Union, Optional, Tuple

# Logger einrichten
logger = logging.getLogger(__name__)

# Standard-Einstellungen (als Fallback)
DEFAULT_SETTINGS = {
    "event_name": "Fotobox Event",
    "event_date": datetime.now().strftime("%Y-%m-%d"),
    "color_mode": "system",
    "screensaver_timeout": 120,
    "gallery_timeout": 60,
    "countdown_duration": 3,
    "camera_id": "auto",
    "flash_mode": "auto"
}

# Validierungsregeln
VALIDATION_RULES = {
    "event_name": {
        "required": True,
        "max_length": 50
    },
    "screensaver_timeout": {
        "required": True,
        "type": "number",
        "min": 30,
        "max": 600
    },
    "gallery_timeout": {
        "required": True,
        "type": "number",
        "min": 30,
        "max": 300
    },
    "countdown_duration": {
        "required": True,
        "type": "number",
        "min": 1,
        "max": 10
    }
}

# Pfad zur Einstellungsdatei (relativ zum Skriptverzeichnis)
SETTINGS_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "settings.json")

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
