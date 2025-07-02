"""
api_filesystem.py - API-Endpunkte für Dateisystemoperationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Dateisystemoperationen bereit und
dient als Schnittstelle zwischen dem Frontend und dem manage_files-Modul.
"""

from flask import Blueprint, request, jsonify, send_from_directory, Response
import os
import logging
import mimetypes
from typing import Dict, Any, List, Optional
from werkzeug.utils import secure_filename
from pathlib import Path

from manage_folders import FolderManager, get_photos_dir
import manage_files
from api_auth import token_required
from manage_api import ApiResponse, handle_api_exception

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für Filesystem-API-Endpunkte erstellen
api_filesystem = Blueprint('api_filesystem', __name__)

@api_filesystem.route('/api/filesystem/images', methods=['GET'])
@token_required
def get_images():
    """API-Endpunkt zum Abrufen einer Liste von Bildern"""
    try:
        directory = request.args.get('directory', 'gallery')
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 50, type=int)
        sort_by = request.args.get('sort', 'date')
        order = request.args.get('order', 'desc')
        
        result = manage_files.get_image_list(
            directory=directory,
            page=page,
            limit=limit,
            sort_by=sort_by,
            order=order
        )
        
        return ApiResponse.success(data={
            'images': result['images'],
            'total': result['total'],
            'page': page,
            'pages': (result['total'] + limit - 1) // limit
        })
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Bilderliste: {e}")
        return handle_api_exception(e, endpoint='/api/filesystem/images')

@api_filesystem.route('/api/filesystem/image/<path:filename>', methods=['GET'])
@token_required
def get_image(filename: str):
    """API-Endpunkt zum Abrufen eines einzelnen Bildes"""
    try:
        photos_dir = get_photos_dir()
        file_path = os.path.join(photos_dir, secure_filename(filename))
        
        if not os.path.exists(file_path):
            return ApiResponse.error(
                "Bild nicht gefunden",
                error_code=404
            )
            
        # Prüfe MIME-Type
        mime_type, _ = mimetypes.guess_type(file_path)
        if not mime_type or not mime_type.startswith('image/'):
            return ApiResponse.error(
                "Ungültiger Dateityp",
                error_code=400
            )
            
        return send_from_directory(
            photos_dir,
            secure_filename(filename),
            mimetype=mime_type
        )
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Bildes {filename}: {e}")
        return handle_api_exception(e, endpoint=f'/api/filesystem/image/{filename}')

@api_filesystem.route('/api/filesystem/upload', methods=['POST'])
@token_required
def upload_file():
    """API-Endpunkt zum Hochladen von Dateien"""
    try:
        if 'file' not in request.files:
            return ApiResponse.error(
                "Keine Datei übermittelt",
                error_code=400
            )
            
        file = request.files['file']
        if not file.filename:
            return ApiResponse.error(
                "Kein Dateiname angegeben",
                error_code=400
            )
            
        filename = secure_filename(file.filename)
        directory = request.form.get('directory', 'gallery')
        
        # Prüfe MIME-Type
        mime_type = file.content_type
        if not mime_type or not mime_type.startswith('image/'):
            return ApiResponse.error(
                "Nur Bilddateien sind erlaubt",
                error_code=400
            )
            
        # Speichere Datei
        file_path = manage_files.save_uploaded_file(file, filename, directory)
        
        # Erstelle Thumbnail
        thumb_path = manage_files.create_thumbnail(file_path)
        
        return ApiResponse.success(
            message="Datei erfolgreich hochgeladen",
            data={
                'filename': filename,
                'path': file_path,
                'thumbnail': thumb_path,
                'mime_type': mime_type
            }
        )
    except Exception as e:
        logger.error(f"Fehler beim Hochladen der Datei: {e}")
        return handle_api_exception(e, endpoint='/api/filesystem/upload')

@api_filesystem.route('/api/filesystem/delete/<path:filename>', methods=['DELETE'])
@token_required
def delete_file(filename: str):
    """API-Endpunkt zum Löschen von Dateien"""
    try:
        directory = request.args.get('directory', 'gallery')
        file_path = os.path.join(get_photos_dir(), directory, secure_filename(filename))
        
        if not os.path.exists(file_path):
            return ApiResponse.error(
                "Datei nicht gefunden",
                error_code=404
            )
            
        # Lösche Datei und zugehöriges Thumbnail
        manage_files.delete_file(file_path)
        
        return ApiResponse.success(
            message="Datei erfolgreich gelöscht"
        )
    except Exception as e:
        logger.error(f"Fehler beim Löschen der Datei {filename}: {e}")
        return handle_api_exception(e, endpoint=f'/api/filesystem/delete/{filename}')

@api_filesystem.route('/api/filesystem/thumbnail/<path:filename>', methods=['GET'])
@token_required
def get_thumbnail(filename: str):
    """API-Endpunkt zum Abrufen eines Thumbnails"""
    try:
        directory = request.args.get('directory', 'gallery')
        thumb_path = manage_files.get_thumbnail_path(filename, directory)
        
        if not os.path.exists(thumb_path):
            # Erstelle Thumbnail falls nicht vorhanden
            original_path = os.path.join(get_photos_dir(), directory, secure_filename(filename))
            if os.path.exists(original_path):
                thumb_path = manage_files.create_thumbnail(original_path)
            else:
                return ApiResponse.error(
                    "Originalbild nicht gefunden",
                    error_code=404
                )
                
        return send_from_directory(
            os.path.dirname(thumb_path),
            os.path.basename(thumb_path),
            mimetype='image/jpeg'
        )
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Thumbnails {filename}: {e}")
        return handle_api_exception(e, endpoint=f'/api/filesystem/thumbnail/{filename}')

# Blueprint-Registrierung
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App"""
    app.register_blueprint(api_filesystem)
    logger.info("API-Endpunkte für Dateisystem registriert")
