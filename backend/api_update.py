"""
api_update.py - API-Endpunkte für Update-Operationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Update-Operationen bereit und
dient als Schnittstelle zwischen dem Frontend und dem manage_update-Modul.
"""

from flask import Blueprint, request, jsonify, current_app
import os
import logging
import sys
import json
from datetime import datetime
from typing import Dict, Any, Optional

# Import der Update-Funktionen
import manage_update
from api_auth import token_required

# Logger einrichten
logger = logging.getLogger(__name__)

# Blueprint für Update-API-Endpunkte erstellen
api_update = Blueprint('api_update', __name__)

@api_update.route('/api/update/check', methods=['GET'])
@token_required
def check_updates():
    """API-Endpunkt zum Prüfen auf Updates"""
    try:
        local_version = manage_update.get_local_version()
        remote_version = manage_update.get_remote_version()
        
        if not local_version or not remote_version:
            return jsonify({
                'success': False,
                'error': 'Version konnte nicht ermittelt werden'
            }), 500
        
        update_available = manage_update.is_update_available()
        last_check = manage_update.get_last_update_check()
        
        return jsonify({
            'success': True,
            'local_version': local_version,
            'remote_version': remote_version,
            'update_available': update_available,
            'last_checked': last_check,
            'changelog': manage_update.get_changelog()
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Prüfen auf Updates: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_update.route('/api/update/start', methods=['POST'])
@token_required
def start_update():
    """API-Endpunkt zum Starten des Update-Prozesses"""
    try:
        # Prüfe Systemvoraussetzungen
        system_check = manage_update.check_system_requirements()
        if not system_check['success']:
            return jsonify({
                'success': False,
                'error': 'Systemvoraussetzungen nicht erfüllt',
                'details': system_check['errors']
            }), 400
        
        # Backup vor Update
        if not manage_update.create_backup():
            return jsonify({
                'success': False,
                'error': 'Backup konnte nicht erstellt werden'
            }), 500
        
        # Starte Update-Prozess
        update_result = manage_update.start_update()
        if update_result['success']:
            return jsonify({
                'success': True,
                'message': 'Update erfolgreich gestartet',
                'job_id': update_result['job_id']
            })
        else:
            return jsonify({
                'success': False,
                'error': update_result['error']
            }), 500
            
    except Exception as e:
        logger.error(f"Fehler beim Starten des Updates: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_update.route('/api/update/status/<job_id>', methods=['GET'])
@token_required
def get_update_status(job_id: str):
    """API-Endpunkt zum Abrufen des Update-Status"""
    try:
        status = manage_update.get_update_status(job_id)
        return jsonify({
            'success': True,
            'status': status['status'],
            'progress': status['progress'],
            'message': status['message'],
            'error': status.get('error')
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Update-Status: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_update.route('/api/update/cancel/<job_id>', methods=['POST'])
@token_required
def cancel_update(job_id: str):
    """API-Endpunkt zum Abbrechen eines laufenden Updates"""
    try:
        if manage_update.cancel_update(job_id):
            return jsonify({
                'success': True,
                'message': 'Update erfolgreich abgebrochen'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Update konnte nicht abgebrochen werden'
            }), 500
            
    except Exception as e:
        logger.error(f"Fehler beim Abbrechen des Updates: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Blueprint-Registrierung
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App"""
    app.register_blueprint(api_update)
    logger.info("API-Endpunkte für Updates registriert")
