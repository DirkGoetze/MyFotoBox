"""
API-Endpunkte für Dateisystem-Operationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für die Dateisystem-Operationen bereit.
Es fügt die Routen zur Flask-App hinzu und verarbeitet die API-Anfragen,
indem es die Funktionen aus dem manage_files-Modul aufruft.
"""

from flask import request, jsonify, current_app, Blueprint, send_from_directory
import os
import logging
from werkzeug.utils import secure_filename

# Import der Dateisystem-Funktionen
import manage_files
import manage_auth
import manage_logging

# Logger einrichten
logger = logging.getLogger(__name__)

# Blueprint für Filesystem-API-Endpunkte erstellen
filesystem_api = Blueprint('filesystem_api', __name__)

@filesystem_api.route('/api/filesystem/images', methods=['GET'])
def api_get_images():
    """API-Endpunkt zum Abrufen einer Liste von Bildern"""
    try:
        directory = request.args.get('directory', 'gallery')
        result = manage_files.get_image_list(directory)
        return jsonify(result)
    except Exception as e:
        logger.error(f"API-Fehler beim Abrufen der Bilderliste: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@filesystem_api.route('/api/filesystem/save', methods=['POST'])
def api_save_image():
    """API-Endpunkt zum Speichern eines Bildes"""
    try:
        # Prüfen, ob eine Datei hochgeladen wurde
        if 'image' not in request.files:
            return jsonify({'success': False, 'error': 'Keine Bilddatei gefunden'}), 400
        
        image_file = request.files['image']
        
        # Prüfen, ob ein Dateiname vorhanden ist
        if image_file.filename == '':
            return jsonify({'success': False, 'error': 'Kein Dateiname angegeben'}), 400
        
        # Formular-Parameter abrufen
        directory = request.form.get('directory', 'gallery')
        create_thumbnail = request.form.get('create_thumbnail', 'true').lower() == 'true'
        
        # Sicherer Dateiname
        filename = secure_filename(image_file.filename)
        if not filename:
            filename = f"photo_{int(time.time())}.jpg"
        
        # Bild speichern
        result = manage_files.save_image(
            image_data=image_file.read(),
            filename=filename,
            directory=directory,
            create_thumbnail=create_thumbnail
        )
        
        if result.get('success', False):
            manage_logging.log(f"Bild {filename} erfolgreich in {directory} gespeichert")
        else:
            manage_logging.error(f"Fehler beim Speichern von {filename}: {result.get('error')}")
            
        return jsonify(result)
    except Exception as e:
        logger.error(f"API-Fehler beim Speichern des Bildes: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@filesystem_api.route('/api/filesystem/delete', methods=['POST'])
@manage_auth.require_auth
def api_delete_image():
    """API-Endpunkt zum Löschen eines Bildes (erfordert Authentifizierung)"""
    try:
        data = request.get_json()
        filename = data.get('filename')
        directory = data.get('directory', 'gallery')
        
        if not filename:
            return jsonify({'success': False, 'error': 'Kein Dateiname angegeben'}), 400
        
        result = manage_files.delete_image(filename, directory)
        
        if result.get('success', False):
            manage_logging.log(f"Bild {filename} aus {directory} gelöscht")
        else:
            manage_logging.error(f"Fehler beim Löschen von {filename}: {result.get('error')}")
            
        return jsonify(result)
    except Exception as e:
        logger.error(f"API-Fehler beim Löschen des Bildes: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@filesystem_api.route('/api/filesystem/info', methods=['GET'])
def api_get_file_info():
    """API-Endpunkt zum Abrufen von Dateimetadaten"""
    try:
        filename = request.args.get('filename')
        directory = request.args.get('directory', 'gallery')
        
        if not filename:
            return jsonify({'success': False, 'error': 'Kein Dateiname angegeben'}), 400
        
        result = manage_files.get_file_info(filename, directory)
        return jsonify(result)
    except Exception as e:
        logger.error(f"API-Fehler beim Abrufen der Dateimetadaten: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@filesystem_api.route('/api/filesystem/mkdir', methods=['POST'])
@manage_auth.require_auth
def api_create_directory():
    """API-Endpunkt zum Erstellen eines Verzeichnisses (erfordert Authentifizierung)"""
    try:
        data = request.get_json()
        path = data.get('path')
        
        if not path:
            return jsonify({'success': False, 'error': 'Kein Verzeichnispfad angegeben'}), 400
        
        result = manage_files.create_directory(path)
        
        if result.get('success', False):
            manage_logging.log(f"Verzeichnis {path} erstellt")
        else:
            manage_logging.error(f"Fehler beim Erstellen des Verzeichnisses {path}: {result.get('error')}")
            
        return jsonify(result)
    except Exception as e:
        logger.error(f"API-Fehler beim Erstellen des Verzeichnisses: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@filesystem_api.route('/api/filesystem/space', methods=['GET'])
def api_check_disk_space():
    """API-Endpunkt zum Prüfen des verfügbaren Speicherplatzes"""
    try:
        result = manage_files.check_disk_space()
        return jsonify(result)
    except Exception as e:
        logger.error(f"API-Fehler beim Prüfen des Speicherplatzes: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@filesystem_api.route('/api/gallery', methods=['GET'])
def api_gallery():
    """Abwärtskompatibilität: Leitet zum neuen Endpunkt für Bilder weiter"""
    try:
        result = manage_files.get_image_list('gallery')
        return jsonify(result)
    except Exception as e:
        logger.error(f"API-Fehler beim Abrufen der Galerie: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

def init_app(app):
    """Initialisiert das Filesystem-API-Modul mit der Flask-App
    
    Args:
        app: Die Flask-App-Instanz
    """
    app.register_blueprint(filesystem_api)
