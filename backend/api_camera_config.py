"""
api_camera_config.py - API-Endpunkte für Kamera-Konfigurationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für die Verwaltung von Kamera-Konfigurationen
bereit. Es dient als Schnittstelle zwischen dem Frontend und dem manage_camera_config-Modul.
"""

from flask import Blueprint, jsonify, request
import os
import json
import logging
from typing import Dict, List, Optional, Any

from manage_folders import FolderManager, get_config_dir
import manage_camera_config
from api_auth import token_required
from manage_api import ApiResponse, handle_api_exception

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für die Kamera-Konfigurations-API erstellen
api_camera_config = Blueprint('api_camera_config', __name__)

@api_camera_config.route('/api/camera-configs', methods=['GET'])
@token_required
def get_camera_configs():
    """API-Endpunkt um alle verfügbaren Kamera-Konfigurationen abzurufen"""
    try:
        configs = manage_camera_config.get_camera_configs()
        return ApiResponse.success(data={
            'configs': configs,
            'count': len(configs)
        })
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Kamera-Konfigurationen: {e}")
        return handle_api_exception(e, endpoint='/api/camera-configs')

@api_camera_config.route('/api/camera-configs/active', methods=['GET'])
@token_required
def get_active_config():
    """API-Endpunkt um die aktuell aktive Kamera-Konfiguration abzurufen"""
    try:
        active_config = manage_camera_config.get_active_config()
        if not active_config:
            return ApiResponse.error(
                "Keine aktive Kamera-Konfiguration gefunden",
                error_code=404
            )
        return ApiResponse.success(data=active_config)
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der aktiven Konfiguration: {e}")
        return handle_api_exception(e, endpoint='/api/camera-configs/active')

@api_camera_config.route('/api/camera-configs/<config_id>', methods=['GET'])
@token_required
def get_camera_config(config_id: str):
    """API-Endpunkt um eine spezifische Kamera-Konfiguration abzurufen"""
    try:
        config = manage_camera_config.get_config(config_id)
        if not config:
            return ApiResponse.error(
                f"Konfiguration {config_id} nicht gefunden",
                error_code=404
            )
        return ApiResponse.success(data=config)
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Konfiguration {config_id}: {e}")
        return handle_api_exception(e, endpoint=f'/api/camera-configs/{config_id}')

@api_camera_config.route('/api/camera-configs', methods=['POST'])
@token_required
def create_camera_config():
    """API-Endpunkt um eine neue Kamera-Konfiguration zu erstellen"""
    try:
        data = request.get_json()
        if not data:
            return ApiResponse.error(
                "Keine Konfigurationsdaten übermittelt",
                error_code=400
            )
            
        config_id = manage_camera_config.create_config(data)
        return ApiResponse.success(
            message=f"Konfiguration {config_id} erstellt",
            data={'config_id': config_id}
        )
    except Exception as e:
        logger.error(f"Fehler beim Erstellen der Konfiguration: {e}")
        return handle_api_exception(e, endpoint='/api/camera-configs')

@api_camera_config.route('/api/camera-configs/<config_id>', methods=['PUT'])
@token_required
def update_camera_config(config_id: str):
    """API-Endpunkt um eine Kamera-Konfiguration zu aktualisieren"""
    try:
        data = request.get_json()
        if not data:
            return ApiResponse.error(
                "Keine Konfigurationsdaten übermittelt",
                error_code=400
            )
            
        if not manage_camera_config.config_exists(config_id):
            return ApiResponse.error(
                f"Konfiguration {config_id} nicht gefunden",
                error_code=404
            )
            
        updated_config = manage_camera_config.update_config(config_id, data)
        return ApiResponse.success(
            message=f"Konfiguration {config_id} aktualisiert",
            data=updated_config
        )
    except Exception as e:
        logger.error(f"Fehler beim Aktualisieren der Konfiguration {config_id}: {e}")
        return handle_api_exception(e, endpoint=f'/api/camera-configs/{config_id}')

@api_camera_config.route('/api/camera-configs/<config_id>', methods=['DELETE'])
@token_required
def delete_camera_config(config_id: str):
    """API-Endpunkt um eine Kamera-Konfiguration zu löschen"""
    try:
        if not manage_camera_config.config_exists(config_id):
            return ApiResponse.error(
                f"Konfiguration {config_id} nicht gefunden",
                error_code=404
            )
            
        if manage_camera_config.is_active_config(config_id):
            return ApiResponse.error(
                "Aktive Konfiguration kann nicht gelöscht werden",
                error_code=400
            )
            
        manage_camera_config.delete_config(config_id)
        return ApiResponse.success(
            message=f"Konfiguration {config_id} gelöscht"
        )
    except Exception as e:
        logger.error(f"Fehler beim Löschen der Konfiguration {config_id}: {e}")
        return handle_api_exception(e, endpoint=f'/api/camera-configs/{config_id}')

@api_camera_config.route('/api/camera-configs/<config_id>/activate', methods=['POST'])
@token_required
def activate_camera_config(config_id: str):
    """API-Endpunkt um eine Kamera-Konfiguration zu aktivieren"""
    try:
        if not manage_camera_config.config_exists(config_id):
            return ApiResponse.error(
                f"Konfiguration {config_id} nicht gefunden",
                error_code=404
            )
            
        manage_camera_config.set_active_config(config_id)
        return ApiResponse.success(
            message=f"Konfiguration {config_id} aktiviert"
        )
    except Exception as e:
        logger.error(f"Fehler beim Aktivieren der Konfiguration {config_id}: {e}")
        return handle_api_exception(e, endpoint=f'/api/camera-configs/{config_id}/activate')

# Blueprint-Registrierung
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App"""
    app.register_blueprint(api_camera_config)
    logger.info("API-Endpunkte für Kamera-Konfigurationen registriert")
