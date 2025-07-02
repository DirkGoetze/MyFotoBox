"""
api_update.py - API-Endpunkte für Update-Operationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Update-Operationen bereit und
dient als Schnittstelle zwischen dem Frontend und dem manage_update-Modul.
"""

from flask import Blueprint, request, current_app, jsonify
import os
import logging
import sys
from datetime import datetime
from typing import Dict, Any, Optional

# Import der Update-Funktionen
import manage_update
from api_auth import token_required
from manage_api import ApiResponse, handle_api_exception
from manage_folders import FolderManager

# Logger einrichten
logger = logging.getLogger(__name__)

# Blueprint für Update-API-Endpunkte erstellen
api_update = Blueprint('api_update', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

@api_update.route('/api/update/check', methods=['GET'])
@token_required
def check_updates() -> Dict[str, Any]:
    """
    API-Endpunkt zum Prüfen auf Updates
    
    Returns:
        Dict mit Versions- und Update-Informationen
    """
    try:
        local_version = manage_update.get_local_version()
        remote_version = manage_update.get_remote_version()
        
        if not local_version or not remote_version:
            raise ValueError('Version konnte nicht ermittelt werden')
        
        update_available = manage_update.is_update_available()
        last_check = manage_update.get_last_update_check()
        
        return ApiResponse.success(data={
            'local_version': local_version,
            'remote_version': remote_version,
            'update_available': update_available,
            'last_checked': last_check,
            'changelog': manage_update.get_changelog()
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Prüfen auf Updates: {e}")
        return handle_api_exception(e, endpoint='/api/update/check')

@api_update.route('/api/update/start', methods=['POST'])
@token_required
def start_update() -> Dict[str, Any]:
    """
    API-Endpunkt zum Starten des Update-Prozesses
    
    Returns:
        Dict mit Status und Job-ID des Update-Prozesses
    """
    try:
        # Prüfe Systemvoraussetzungen
        system_check = manage_update.check_system_requirements()
        if not system_check['success']:
            return ApiResponse.error(
                message='Systemvoraussetzungen nicht erfüllt',
                details=system_check['errors'],
                status_code=400
            )
        
        # Backup-Verzeichnis sicherstellen
        backup_dir = folder_manager.get_path('backup')
        if not os.path.exists(backup_dir):
            folder_manager.ensure_folder_structure()
        
        # Backup vor Update
        if not manage_update.create_backup():
            raise RuntimeError('Backup konnte nicht erstellt werden')
        
        # Starte Update-Prozess
        update_result = manage_update.start_update()
        if not update_result['success']:
            raise RuntimeError(update_result.get('error', 'Unbekannter Fehler beim Update-Start'))
            
        return ApiResponse.success(
            message='Update erfolgreich gestartet',
            data={'job_id': update_result['job_id']}
        )
            
    except Exception as e:
        logger.error(f"Fehler beim Starten des Updates: {e}")
        return handle_api_exception(e, endpoint='/api/update/start')

@api_update.route('/api/update/status/<job_id>', methods=['GET'])
@token_required
def get_update_status(job_id: str) -> Dict[str, Any]:
    """
    API-Endpunkt zum Abfragen des Update-Status
    
    Args:
        job_id: ID des Update-Jobs
        
    Returns:
        Dict mit aktuellem Status des Updates
    """
    try:
        if not job_id:
            return ApiResponse.error(
                message='Keine Job-ID angegeben',
                status_code=400
            )
            
        status = manage_update.get_update_status(job_id)
        if not status:
            return ApiResponse.error(
                message=f'Kein Update-Job mit ID {job_id} gefunden',
                status_code=404
            )
            
        return ApiResponse.success(data={
            'status': status['status'],
            'progress': status.get('progress', 0),
            'message': status.get('message', ''),
            'error': status.get('error', None),
            'timestamp': status.get('timestamp', datetime.now().isoformat())
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Update-Status: {e}")
        return handle_api_exception(e, endpoint=f'/api/update/status/{job_id}')

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
