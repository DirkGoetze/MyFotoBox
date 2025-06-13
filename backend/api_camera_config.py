"""
api_camera_config.py - API-Endpunkte für Kamera-Konfigurationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für die Verwaltung von Kamera-Konfigurationen
bereit. Es dient als Schnittstelle zwischen dem Frontend und dem manage_camera_config-Modul.
"""

from flask import Blueprint, jsonify, request
import os
import json
from typing import Dict, List, Optional

import manage_auth
import manage_logging
import manage_camera_config
import manage_api

# Blueprint für die Kamera-Konfigurations-API erstellen
api_camera_config = Blueprint('api_camera_config', __name__)

# -------------------------------------------------------------------------------
# API-Endpunkte für Kamera-Konfigurationsoperationen
# -------------------------------------------------------------------------------

@api_camera_config.route('/api/camera-configs', methods=['GET'])
def api_get_camera_configs():
    """API-Endpunkt um alle verfügbaren Kamera-Konfigurationen abzurufen"""
    try:
        manage_api.log_api_request('/api/camera-configs', request.method,
                                  user_id=request.cookies.get('user_id'))
        
        configs = manage_camera_config.get_camera_configs()
        return manage_api.ApiResponse.success(data=configs)
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint='/api/camera-configs')

@api_camera_config.route('/api/camera-configs/active', methods=['GET'])
def api_get_active_config():
    """API-Endpunkt um die aktuell aktive Kamera-Konfiguration abzurufen"""
    try:
        manage_api.log_api_request('/api/camera-configs/active', request.method,
                                  user_id=request.cookies.get('user_id'))
        
        active_config = manage_camera_config.get_active_config()
        if active_config:
            return manage_api.ApiResponse.success(data=active_config)
        else:
            return jsonify({'success': False, 'error': 'Keine aktive Kamera-Konfiguration gefunden'}), 404
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint='/api/camera-configs/active')

@api_camera_config.route('/api/camera-configs/active', methods=['PUT'])
@manage_auth.require_auth
def api_set_active_config():
    """API-Endpunkt um die aktiv verwendete Kamera-Konfiguration zu setzen"""
    try:
        data = request.get_json(force=True)
        config_id = data.get('config_id')
        
        manage_api.log_api_request('/api/camera-configs/active', request.method,
                                  request_data=data,
                                  user_id=request.cookies.get('user_id'))
        
        if not config_id:
            return jsonify({'success': False, 'error': 'Konfiguration-ID fehlt'}), 400
        
        success = manage_camera_config.set_active_config(config_id)
        if success:
            manage_logging.log(f"Aktive Kamera-Konfiguration wurde auf {config_id} gesetzt")
            return manage_api.ApiResponse.success(message=f"Aktive Kamera-Konfiguration wurde gesetzt")
        else:
            return jsonify({'success': False, 'error': f'Konfiguration mit ID {config_id} existiert nicht'}), 404
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint='/api/camera-configs/active')

@api_camera_config.route('/api/camera-configs/<config_id>', methods=['GET'])
def api_get_config(config_id):
    """API-Endpunkt um eine bestimmte Kamera-Konfiguration abzurufen"""
    try:
        manage_api.log_api_request(f'/api/camera-configs/{config_id}', request.method,
                                  user_id=request.cookies.get('user_id'))
        
        config = manage_camera_config.get_config(config_id)
        if config:
            return manage_api.ApiResponse.success(data=config)
        else:
            return jsonify({'success': False, 'error': f'Konfiguration mit ID {config_id} nicht gefunden'}), 404
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint=f'/api/camera-configs/{config_id}')

@api_camera_config.route('/api/camera-configs', methods=['POST'])
@manage_auth.require_auth
def api_create_config():
    """API-Endpunkt zum Erstellen einer neuen Kamera-Konfiguration"""
    try:
        data = request.get_json(force=True)
        
        manage_api.log_api_request('/api/camera-configs', request.method,
                                  request_data=data,
                                  user_id=request.cookies.get('user_id'))
        
        if not data:
            return jsonify({'success': False, 'error': 'Keine Konfigurationsdaten übermittelt'}), 400
        
        if not data.get('name'):
            return jsonify({'success': False, 'error': 'Konfigurationsname fehlt'}), 400
        
        config_id = manage_camera_config.create_config(data)
        if config_id:
            manage_logging.log(f"Neue Kamera-Konfiguration erstellt: {data['name']} (ID: {config_id})")
            return manage_api.ApiResponse.success(data={'id': config_id, 'name': data['name']}, 
                                               message="Kamera-Konfiguration erfolgreich erstellt", 
                                               code=201)
        else:
            return jsonify({'success': False, 'error': 'Fehler beim Erstellen der Konfiguration'}), 500
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint='/api/camera-configs')

@api_camera_config.route('/api/camera-configs/<config_id>', methods=['PUT'])
@manage_auth.require_auth
def api_update_config(config_id):
    """API-Endpunkt zum Aktualisieren einer bestehenden Kamera-Konfiguration"""
    try:
        data = request.get_json(force=True)
        
        manage_api.log_api_request(f'/api/camera-configs/{config_id}', request.method,
                                  request_data=data,
                                  user_id=request.cookies.get('user_id'))
        
        if not data:
            return jsonify({'success': False, 'error': 'Keine Konfigurationsdaten übermittelt'}), 400
        
        success = manage_camera_config.update_config(config_id, data)
        if success:
            manage_logging.log(f"Kamera-Konfiguration aktualisiert: {data.get('name', config_id)}")
            return manage_api.ApiResponse.success(message="Kamera-Konfiguration erfolgreich aktualisiert")
        else:
            return jsonify({'success': False, 'error': f'Konfiguration mit ID {config_id} existiert nicht'}), 404
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint=f'/api/camera-configs/{config_id}')

@api_camera_config.route('/api/camera-configs/<config_id>', methods=['DELETE'])
@manage_auth.require_auth
def api_delete_config(config_id):
    """API-Endpunkt zum Löschen einer Kamera-Konfiguration"""
    try:
        manage_api.log_api_request(f'/api/camera-configs/{config_id}', request.method,
                                  user_id=request.cookies.get('user_id'))
        
        success = manage_camera_config.delete_config(config_id)
        if success:
            manage_logging.log(f"Kamera-Konfiguration gelöscht: {config_id}")
            return manage_api.ApiResponse.success(message="Kamera-Konfiguration erfolgreich gelöscht")
        else:
            return jsonify({'success': False, 'error': f'Konfiguration mit ID {config_id} existiert nicht'}), 404
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint=f'/api/camera-configs/{config_id}')

def init_app(app):
    """Initialisiert die Kamera-Konfigurations-API mit der Flask-Anwendung"""
    app.register_blueprint(api_camera_config)
