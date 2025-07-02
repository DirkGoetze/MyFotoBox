"""
api_camera.py - Kamera-API-Endpunkte für Fotobox2

Dieses Modul stellt die Flask-Endpunkte für die Kamerasteuerung bereit.
Es dient als Schnittstelle zwischen dem Frontend und dem manage_camera-Modul.

API-Endpunkte:
- /api/camera/list (GET): Liste aller verfügbaren Kameras
- /api/camera/connect (POST): Verbindung zu einer Kamera herstellen
- /api/camera/disconnect (POST): Verbindung zu einer Kamera trennen
- /api/camera/capture (POST): Bild aufnehmen
- /api/camera/settings (GET/POST): Kameraeinstellungen abrufen/ändern
- /api/camera/preview (GET): Live-Vorschau erhalten
- /api/camera/status (GET): Status der Kamera abrufen
- /api/camera/configs (GET): Liste aller verfügbaren Kamera-Konfigurationen
- /api/camera/config (GET/POST): Aktive Kamera-Konfiguration abrufen/ändern
"""

from flask import Blueprint, request, Response, stream_with_context
from typing import Dict, Any, List, Optional, Generator
import logging
import time
import json

# Importiere die Kameramodule
import manage_camera
import manage_camera_config
from manage_api import ApiResponse, handle_api_exception
from api_auth import token_required
from manage_folders import FolderManager

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für die Kamera-API erstellen
api_camera = Blueprint('api_camera', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

@api_camera.route('/api/camera/list', methods=['GET'])
@token_required
def list_cameras() -> Dict[str, Any]:
    """
    Gibt eine Liste aller verfügbaren Kameras zurück
    
    Returns:
        Dict mit Liste der verfügbaren Kameras
    """
    try:
        cameras = manage_camera.get_camera_list()
        return ApiResponse.success(data=cameras)
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Kameraliste: {e}")
        return handle_api_exception(e, endpoint='/api/camera/list')

@api_camera.route('/api/camera/connect', methods=['POST'])
@token_required
def connect_camera() -> Dict[str, Any]:
    """
    Verbindet zu einer Kamera
    
    Returns:
        Dict mit Details zur verbundenen Kamera
    """
    try:
        data = request.get_json()
        if not data or 'camera_id' not in data:
            return ApiResponse.error(
                message="Ungültige Anfrage: camera_id fehlt",
                status_code=400
            )
            
        camera_id = data['camera_id']
        result = manage_camera.connect_camera(camera_id)
        
        if not result['success']:
            return ApiResponse.error(
                message="Verbindung konnte nicht hergestellt werden",
                details=result.get('error', 'Unbekannter Fehler'),
                status_code=400
            )
            
        return ApiResponse.success(
            message="Kamera erfolgreich verbunden",
            data=result['camera']
        )
            
    except Exception as e:
        logger.error(f"Fehler beim Verbinden mit der Kamera: {e}")
        return handle_api_exception(e, endpoint='/api/camera/connect')

@api_camera.route('/api/camera/disconnect', methods=['POST'])
@token_required
def disconnect_camera() -> Dict[str, Any]:
    """
    Trennt die Verbindung zu einer Kamera
    
    Returns:
        Dict mit Status der Operation
    """
    try:
        data = request.get_json()
        camera_id = data.get('camera_id') if data else None
        
        result = manage_camera.disconnect_camera(camera_id)
        
        if not result['success']:
            return ApiResponse.error(
                message="Trennen der Kamera fehlgeschlagen",
                details=result.get('error', 'Unbekannter Fehler'),
                status_code=400
            )
            
        return ApiResponse.success(message="Kamera erfolgreich getrennt")
            
    except Exception as e:
        logger.error(f"Fehler beim Trennen der Kamera: {e}")
        return handle_api_exception(e, endpoint='/api/camera/disconnect')

@api_camera.route('/api/camera/capture', methods=['POST'])
@token_required
def capture_image() -> Dict[str, Any]:
    """
    Nimmt ein Bild mit der aktiven Kamera auf
    
    Returns:
        Dict mit Pfad zum aufgenommenen Bild
    """
    try:
        data = request.get_json()
        options = data if data else {}
        
        result = manage_camera.capture_image(options)
        
        if not result['success']:
            return ApiResponse.error(
                message="Bildaufnahme fehlgeschlagen",
                details=result.get('error', 'Unbekannter Fehler'),
                status_code=400
            )
            
        return ApiResponse.success(
            message="Bild erfolgreich aufgenommen",
            data={
                'filepath': result.get('filepath', ''),
                'thumbnail': result.get('thumbnail', ''),
                'metadata': result.get('metadata', {})
            }
        )
        
    except Exception as e:
        logger.error(f"Fehler bei der Bildaufnahme: {e}")
        return handle_api_exception(e, endpoint='/api/camera/capture')

@api_camera.route('/api/camera/preview', methods=['GET'])
@token_required
def get_preview() -> Response:
    """
    Liefert einen Live-Vorschau-Stream der Kamera
    
    Returns:
        Response: Streamende Response mit MJPEG-Daten
    """
    try:
        def generate_preview() -> Generator[bytes, None, None]:
            while True:
                try:
                    frame = manage_camera.get_preview_frame()
                    if frame is None:
                        time.sleep(0.5)
                        continue
                        
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
                    time.sleep(0.033)  # Ca. 30 FPS
                    
                except Exception as e:
                    logger.error(f"Fehler beim Generieren des Preview-Frames: {e}")
                    time.sleep(1)
                    
        return Response(
            stream_with_context(generate_preview()),
            mimetype='multipart/x-mixed-replace; boundary=frame'
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Starten des Preview-Streams: {e}")
        return handle_api_exception(e, endpoint='/api/camera/preview')

@api_camera.route('/api/camera/settings', methods=['GET', 'POST'])
@token_required
def camera_settings() -> Dict[str, Any]:
    """
    Abrufen oder Ändern von Kameraeinstellungen
    
    Returns:
        Dict mit aktuellen Kameraeinstellungen
    """
    try:
        if request.method == 'POST':
            settings = request.get_json()
            if not settings:
                return ApiResponse.error(
                    message="Keine Einstellungen übermittelt",
                    status_code=400
                )
                
            result = manage_camera.update_settings(settings)
            if not result['success']:
                return ApiResponse.error(
                    message="Aktualisierung der Einstellungen fehlgeschlagen",
                    details=result.get('error'),
                    status_code=400
                )
                
            return ApiResponse.success(
                message="Einstellungen erfolgreich aktualisiert",
                data=result.get('settings', {})
            )
            
        else:  # GET
            settings = manage_camera.get_settings()
            return ApiResponse.success(data=settings)
            
    except Exception as e:
        logger.error(f"Fehler bei Kameraeinstellungen: {e}")
        return handle_api_exception(e, endpoint='/api/camera/settings')

@api_camera.route('/api/camera/status', methods=['GET'])
@token_required
def get_status() -> Dict[str, Any]:
    """
    Liefert den aktuellen Status der Kamera
    
    Returns:
        Dict mit Kamerastatus
    """
    try:
        status = manage_camera.get_status()
        return ApiResponse.success(data=status)
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Kamerastatus: {e}")
        return handle_api_exception(e, endpoint='/api/camera/status')

@api_camera.route('/api/camera/configs', methods=['GET'])
@token_required
def get_configs() -> Dict[str, Any]:
    """
    Liefert eine Liste aller verfügbaren Kamera-Konfigurationen
    
    Returns:
        Dict mit Konfigurationsliste
    """
    try:
        configs = manage_camera_config.get_configs()
        return ApiResponse.success(data=configs)
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Kamera-Konfigurationen: {e}")
        return handle_api_exception(e, endpoint='/api/camera/configs')

@api_camera.route('/api/camera/config', methods=['GET', 'POST'])
@token_required
def camera_config() -> Dict[str, Any]:
    """
    Abrufen oder Ändern der aktiven Kamera-Konfiguration
    
    Returns:
        Dict mit aktiver Konfiguration
    """
    try:
        if request.method == 'POST':
            data = request.get_json()
            if not data or 'config_name' not in data:
                return ApiResponse.error(
                    message="Kein Konfigurationsname übermittelt",
                    status_code=400
                )
                
            result = manage_camera_config.set_active_config(data['config_name'])
            if not result['success']:
                return ApiResponse.error(
                    message="Aktivierung der Konfiguration fehlgeschlagen",
                    details=result.get('error'),
                    status_code=400
                )
                
            return ApiResponse.success(
                message="Konfiguration erfolgreich aktiviert",
                data=result.get('config', {})
            )
            
        else:  # GET
            config = manage_camera_config.get_active_config()
            return ApiResponse.success(data=config)
            
    except Exception as e:
        logger.error(f"Fehler bei Kamera-Konfiguration: {e}")
        return handle_api_exception(e, endpoint='/api/camera/config')
