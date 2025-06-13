"""
camera_api.py - Kamera-API-Endpunkte für Fotobox2

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

from flask import Blueprint, request, jsonify, Response, stream_with_context
import time
import json
import os

# Importiere die Kameramodule
import manage_camera
import manage_camera_config  # Neu importiert für Kamera-Konfigurationen
import manage_logging
import manage_api

# Erstellen des Blueprints für die Kamera-API
camera_api = Blueprint('camera_api', __name__)
api_formatter = manage_api.APIResponseFormatter()

@camera_api.route('/api/camera/list', methods=['GET'])
def list_cameras():
    """Gibt eine Liste aller verfügbaren Kameras zurück"""
    try:
        cameras = manage_camera.get_camera_list()
        return api_formatter.success_response(data=cameras)
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Kameraliste: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Abrufen der Kameraliste", str(e))

@camera_api.route('/api/camera/connect', methods=['POST'])
def connect_camera():
    """Verbindet zu einer Kamera"""
    try:
        data = request.json
        if not data or 'camera_id' not in data:
            return api_formatter.error_response("Ungültige Anfrage: camera_id fehlt")
            
        camera_id = data['camera_id']
        result = manage_camera.connect_camera(camera_id)
        
        if result['success']:
            return api_formatter.success_response(data=result['camera'])
        else:
            return api_formatter.error_response("Verbindung konnte nicht hergestellt werden", result.get('error', 'Unbekannter Fehler'))
            
    except Exception as e:
        manage_logging.error(f"Fehler beim Verbinden mit der Kamera: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Verbinden mit der Kamera", str(e))

@camera_api.route('/api/camera/disconnect', methods=['POST'])
def disconnect_camera():
    """Trennt die Verbindung zu einer Kamera"""
    try:
        data = request.json
        camera_id = data.get('camera_id') if data else None
        
        result = manage_camera.disconnect_camera(camera_id)
        
        if result['success']:
            return api_formatter.success_response(message="Kamera erfolgreich getrennt")
        else:
            return api_formatter.error_response("Trennen der Kamera fehlgeschlagen", result.get('error', 'Unbekannter Fehler'))
            
    except Exception as e:
        manage_logging.error(f"Fehler beim Trennen der Kamera: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Trennen der Kamera", str(e))

@camera_api.route('/api/camera/capture', methods=['POST'])
def capture_image():
    """Nimmt ein Bild mit der aktiven Kamera auf"""
    try:
        data = request.json
        options = data if data else {}
        
        result = manage_camera.capture_image(options)
        
        if result['success']:
            return api_formatter.success_response(
                message="Bild erfolgreich aufgenommen",
                data={
                    'filepath': result.get('filepath', ''),
                    'filename': result.get('filename', ''),
                    'thumbnail': result.get('thumbnail', None)
                }
            )
        else:
            return api_formatter.error_response(
                "Bildaufnahme fehlgeschlagen", 
                result.get('error', 'Unbekannter Fehler')
            )
            
    except Exception as e:
        manage_logging.error(f"Fehler bei der Bildaufnahme: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler bei der Bildaufnahme", str(e))

@camera_api.route('/api/camera/settings', methods=['GET', 'POST'])
def camera_settings():
    """Ruft Kameraeinstellungen ab oder aktualisiert sie"""
    try:
        if request.method == 'GET':
            # Einstellungen abrufen
            result = manage_camera.get_camera_settings()
            
            if result['success']:
                return api_formatter.success_response(data=result['settings'])
            else:
                return api_formatter.error_response(
                    "Kameraeinstellungen konnten nicht abgerufen werden", 
                    result.get('error', 'Unbekannter Fehler')
                )
        else:
            # Einstellungen aktualisieren (POST)
            data = request.json
            if not data:
                return api_formatter.error_response("Ungültige Anfrage: Keine Einstellungen angegeben")
                
            result = manage_camera.update_camera_settings(data)
            
            if result['success']:
                return api_formatter.success_response(message="Kameraeinstellungen aktualisiert")
            else:
                return api_formatter.error_response(
                    "Kameraeinstellungen konnten nicht aktualisiert werden", 
                    result.get('error', 'Unbekannter Fehler')
                )
                
    except Exception as e:
        manage_logging.error(f"Fehler bei Kameraeinstellungen: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler bei Kameraeinstellungen", str(e))

@camera_api.route('/api/camera/preview', methods=['GET'])
def get_preview_frame():
    """Gibt ein einzelnes Vorschaubild zurück"""
    try:
        # Einzelbild-Vorschau
        image_data = manage_camera.get_preview_frame()
        
        if image_data:
            return Response(image_data, mimetype='image/jpeg')
        else:
            return api_formatter.error_response(
                "Vorschaubild konnte nicht abgerufen werden", 
                "Keine Kamera verbunden oder Fehler beim Abrufen des Vorschaubildes"
            )
            
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen des Vorschaubildes: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Abrufen des Vorschaubildes", str(e))

@camera_api.route('/api/camera/preview/stream', methods=['GET'])
def get_preview_stream():
    """Gibt einen Stream von Vorschaubildern zurück (MJPEG)"""
    
    def generate_frames():
        """Generiert Frames für den MJPEG-Stream"""
        try:
            while True:
                # Frame vom Kameramodul abrufen
                frame = manage_camera.get_preview_frame()
                
                if frame is None:
                    # Bei Fehler kurz warten und erneut versuchen
                    time.sleep(0.5)
                    continue
                    
                # MJPEG-Format erfordert einen Header für jedes Bild
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
                       
                # Kurze Pause für Framerate-Begrenzung
                time.sleep(0.033)  # Ca. 30 FPS
        except Exception as e:
            manage_logging.error(f"Fehler im Vorschau-Stream: {str(e)}", exception=e, source="camera_api")
            yield b'--frame\r\nContent-Type: text/plain\r\n\r\nFehler im Stream\r\n'
    
    # Stream als Antwort senden
    return Response(
        stream_with_context(generate_frames()),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )

@camera_api.route('/api/camera/status', methods=['GET'])
def get_camera_status():
    """Gibt den Status der aktiven Kamera zurück"""
    try:
        active_camera = manage_camera.get_active_camera()
        
        if active_camera:
            return api_formatter.success_response(
                data={
                    'active_camera': active_camera,
                    'status': 'connected' if active_camera.get('connected', False) else 'disconnected'
                }
            )
        else:
            return api_formatter.success_response(
                data={
                    'active_camera': None,
                    'status': 'not_available'
                }
            )
            
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen des Kamerastatus: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Abrufen des Kamerastatus", str(e))

@camera_api.route('/api/camera/configs', methods=['GET'])
def get_camera_configs():
    """Gibt eine Liste aller verfügbaren Kamera-Konfigurationen zurück"""
    try:
        configs = manage_camera_config.get_camera_configs()
        return api_formatter.success_response(data=configs)
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Kamera-Konfigurationen: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Abrufen der Kamera-Konfigurationen", str(e))

@camera_api.route('/api/camera/config', methods=['GET', 'POST'])
def manage_active_config():
    """Verwaltet die aktive Kamera-Konfiguration"""
    try:
        if request.method == 'GET':
            # Aktive Konfiguration abrufen
            active_config = manage_camera_config.get_active_config()
            
            if active_config:
                return api_formatter.success_response(data={
                    'id': manage_camera_config._active_config,
                    'config': active_config
                })
            else:
                return api_formatter.success_response(data={
                    'id': None,
                    'config': None
                })
        else:
            # Aktive Konfiguration setzen
            data = request.json
            if not data or 'config_id' not in data:
                return api_formatter.error_response("Ungültige Anfrage: config_id fehlt")
                
            config_id = data['config_id']
            success = manage_camera_config.set_active_config(config_id)
            
            if success:
                # Kameramodul neu initialisieren mit der neuen Konfiguration
                manage_camera.initialize()
                return api_formatter.success_response(message=f"Kamera-Konfiguration {config_id} aktiviert")
            else:
                return api_formatter.error_response("Konfiguration konnte nicht aktiviert werden", 
                                               f"Konfiguration mit ID {config_id} existiert nicht")
                
    except Exception as e:
        manage_logging.error(f"Fehler bei Kamera-Konfiguration: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler bei Kamera-Konfiguration", str(e))

@camera_api.route('/api/camera/config/<config_id>', methods=['GET'])
def get_camera_config(config_id):
    """Gibt eine bestimmte Kamera-Konfiguration zurück"""
    try:
        config = manage_camera_config.get_config(config_id)
        
        if config:
            return api_formatter.success_response(data=config)
        else:
            return api_formatter.error_response(f"Konfiguration mit ID {config_id} nicht gefunden")
                
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Kamera-Konfiguration: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Abrufen der Kamera-Konfiguration", str(e))

@camera_api.route('/api/camera/config/create', methods=['POST'])
def create_camera_config():
    """Erstellt eine neue Kamera-Konfiguration"""
    try:
        data = request.json
        if not data or 'name' not in data:
            return api_formatter.error_response("Ungültige Anfrage: name fehlt")
            
        config_id = manage_camera_config.create_config(data)
        
        if config_id:
            return api_formatter.success_response(
                message=f"Kamera-Konfiguration {data['name']} erstellt",
                data={'id': config_id}
            )
        else:
            return api_formatter.error_response("Konfiguration konnte nicht erstellt werden")
                
    except Exception as e:
        manage_logging.error(f"Fehler beim Erstellen der Kamera-Konfiguration: {str(e)}", exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Erstellen der Kamera-Konfiguration", str(e))

@camera_api.route('/api/camera/config/<config_id>', methods=['PUT'])
def update_camera_config(config_id):
    """Aktualisiert eine bestehende Kamera-Konfiguration"""
    try:
        data = request.json
        if not data:
            return api_formatter.error_response("Ungültige Anfrage: Keine Daten")
            
        success = manage_camera_config.update_config(config_id, data)
        
        if success:
            # Wenn die aktive Konfiguration aktualisiert wurde, Kameramodul neu initialisieren
            if manage_camera_config._active_config == config_id:
                manage_camera.initialize()
                
            return api_formatter.success_response(message=f"Kamera-Konfiguration {config_id} aktualisiert")
        else:
            return api_formatter.error_response(f"Konfiguration mit ID {config_id} konnte nicht aktualisiert werden")
                
    except Exception as e:
        manage_logging.error(f"Fehler beim Aktualisieren der Kamera-Konfiguration: {str(e)}", 
                           exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Aktualisieren der Kamera-Konfiguration", str(e))

@camera_api.route('/api/camera/config/<config_id>', methods=['DELETE'])
def delete_camera_config(config_id):
    """Löscht eine Kamera-Konfiguration"""
    try:
        success = manage_camera_config.delete_config(config_id)
        
        if success:
            return api_formatter.success_response(message=f"Kamera-Konfiguration {config_id} gelöscht")
        else:
            return api_formatter.error_response(f"Konfiguration mit ID {config_id} konnte nicht gelöscht werden")
                
    except Exception as e:
        manage_logging.error(f"Fehler beim Löschen der Kamera-Konfiguration: {str(e)}", 
                           exception=e, source="camera_api")
        return api_formatter.error_response("Fehler beim Löschen der Kamera-Konfiguration", str(e))

# Weitere Endpunkte je nach Bedarf...
