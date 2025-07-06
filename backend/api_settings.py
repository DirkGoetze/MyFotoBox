"""
api_settings.py - API-Endpunkte für Einstellungsverwaltung in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für die Verwaltung von Einstellungen
bereit und dient als Schnittstelle zwischen dem Frontend und dem manage_settings-Modul.
"""

# TODO: Integration mit dem neuen manage_settings.sh-Modul
# - API-Endpunkte für die neuen Settings-Funktionen bereitstellen (hierarchische Schlüssel, Transaktionen)
# - Unterstützung für Transaktionen und Gruppen-IDs
# - Validierung für hierarchische Schlüssel implementieren
# - Fehlerbehandlung und sauberes Error-Reporting
# - Siehe detaillierte Anforderungen in 2025-07-02 Konfigurationswerte_neu.todo

from flask import Blueprint, request, jsonify
import logging
from typing import Dict, Any, Optional

from manage_folders import FolderManager, get_config_dir
import manage_settings
from api_auth import token_required
from manage_api import ApiResponse, handle_api_exception

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für die Settings-API erstellen
api_settings = Blueprint('api_settings', __name__)

# FolderManager für Pfadverwaltung
folder_manager = FolderManager()

@api_settings.route('/api/settings', methods=['GET'])
@token_required
def get_settings():
    """API-Endpunkt zum Abrufen aller Einstellungen"""
    try:
        settings = manage_settings.load_settings()
        return ApiResponse.success(data={
            'settings': settings,
            'timestamp': manage_settings.get_last_modified()
        })
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Einstellungen: {e}")
        return handle_api_exception(e, endpoint='/api/settings')

@api_settings.route('/api/settings/<key>', methods=['GET'])
@token_required
def get_setting(key: str):
    """API-Endpunkt zum Abrufen einer einzelnen Einstellung"""
    try:
        value = manage_settings.load_single_setting(key)
        if value is None:
            return jsonify({
                'success': False,
                'error': f'Einstellung {key} nicht gefunden'
            }), 404
        
        return jsonify({
            'success': True,
            'key': key,
            'value': value
        })
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Einstellung {key}: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_settings.route('/api/settings', methods=['PUT'])
@token_required
def update_settings():
    """API-Endpunkt zum Aktualisieren mehrerer Einstellungen"""
    try:
        settings = request.get_json()
        if not settings:
            return jsonify({
                'success': False,
                'error': 'Keine Einstellungen übermittelt'
            }), 400
            
        # Validierung durchführen
        validation_result, validation_errors = manage_settings.validate_settings(settings)
        if not validation_result:
            return jsonify({
                'success': False,
                'error': 'Validierungsfehler',
                'details': validation_errors
            }), 400
            
        # Backup erstellen
        if not manage_settings.ensure_settings_backup():
            logger.warning("Backup konnte nicht erstellt werden")
            
        # Einstellungen aktualisieren
        if manage_settings.update_settings(settings):
            return jsonify({
                'success': True,
                'message': 'Einstellungen erfolgreich aktualisiert'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Fehler beim Aktualisieren der Einstellungen'
            }), 500
            
    except Exception as e:
        logger.error(f"Fehler beim Aktualisieren der Einstellungen: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_settings.route('/api/settings/<key>', methods=['PUT'])
@token_required
def update_setting(key: str):
    """API-Endpunkt zum Aktualisieren einer einzelnen Einstellung"""
    try:
        data = request.get_json()
        if not data or 'value' not in data:
            return jsonify({
                'success': False,
                'error': 'Kein Wert übermittelt'
            }), 400
            
        value = data['value']
        
        # Validierung durchführen
        validation_result, validation_errors = manage_settings.validate_settings({key: value}, [key])
        if not validation_result:
            return jsonify({
                'success': False,
                'error': 'Validierungsfehler',
                'details': validation_errors
            }), 400
            
        # Backup erstellen
        if not manage_settings.ensure_settings_backup():
            logger.warning("Backup konnte nicht erstellt werden")
            
        # Einstellung aktualisieren
        if manage_settings.update_single_setting(key, value):
            return jsonify({
                'success': True,
                'message': f'Einstellung {key} erfolgreich aktualisiert'
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Fehler beim Aktualisieren der Einstellung {key}'
            }), 500
            
    except Exception as e:
        logger.error(f"Fehler beim Aktualisieren der Einstellung {key}: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_settings.route('/api/settings/reset', methods=['POST'])
@token_required
def reset_settings():
    """API-Endpunkt zum Zurücksetzen von Einstellungen"""
    try:
        data = request.get_json()
        keys = data.get('keys') if data else None
        
        # Backup erstellen
        if not manage_settings.ensure_settings_backup():
            logger.warning("Backup konnte nicht erstellt werden")
            
        if manage_settings.reset_to_defaults(keys):
            return jsonify({
                'success': True,
                'message': 'Einstellungen erfolgreich zurückgesetzt'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Fehler beim Zurücksetzen der Einstellungen'
            }), 500
            
    except Exception as e:
        logger.error(f"Fehler beim Zurücksetzen der Einstellungen: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Blueprint-Registrierung
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App"""
    app.register_blueprint(api_settings)
    logger.info("API-Endpunkte für Einstellungen registriert")
