"""
Manage Filesystem Modul für die Fotobox2 Backend-Anwendung

Dieses Modul bietet Funktionen für Dateisystem-Operationen wie das Auflisten,
Speichern und Löschen von Bildern sowie Funktionen zur Verwaltung von Verzeichnissen
und zur Überwachung des Speicherplatzes.
"""

import os
import shutil
import glob
import json
import logging
import time
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple, Union
import mimetypes
import psutil
from PIL import Image
from werkzeug.utils import secure_filename

# Logger einrichten
logger = logging.getLogger(__name__)

# Pfadkonfiguration über das zentrale Verzeichnismanagement
try:
    from manage_folders import get_data_dir, get_photos_dir, get_photos_gallery_dir
    DATA_DIR = get_data_dir()
    PHOTOS_DIR = get_photos_dir()
    DEFAULT_GALLERY_DIR = get_photos_gallery_dir()
except ImportError:
    # Fallback falls manage_folders nicht verfügbar ist
    DATA_DIR = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data'))
    PHOTOS_DIR = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(__file__)), 'frontend', 'photos'))
    DEFAULT_GALLERY_DIR = os.path.join(PHOTOS_DIR, 'gallery')

# Standard-Bildgrößen für Thumbnail-Generierung
THUMBNAIL_SIZE = (200, 200)

def ensure_directories_exist() -> None:
    """Stellt sicher, dass alle notwendigen Verzeichnisse existieren

    Erstellt die Verzeichnisse für Daten, Fotos und Galerie, falls sie noch nicht vorhanden sind.
    """
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(PHOTOS_DIR, exist_ok=True)
    os.makedirs(DEFAULT_GALLERY_DIR, exist_ok=True)
    
    # Thumbnail-Verzeichnis
    os.makedirs(os.path.join(PHOTOS_DIR, 'thumbnails'), exist_ok=True)
    
    logger.debug(f"Verzeichnisstruktur überprüft: {DATA_DIR}, {PHOTOS_DIR}, {DEFAULT_GALLERY_DIR}")

def get_image_list(directory: str = 'gallery') -> Dict[str, Any]:
    """Ruft eine Liste aller Bilder in einem Verzeichnis ab
    
    Args:
        directory (str, optional): Das zu durchsuchende Verzeichnis. Defaults to 'gallery'.
    
    Returns:
        Dict[str, Any]: Dictionary mit Erfolgs-Flag und Bilderliste
    """
    logger.debug(f"Bilderliste aus {directory} wird abgerufen")
    
    try:
        # Sicherstellen, dass das Verzeichnis im erlaubten Bereich ist
        target_dir = os.path.join(PHOTOS_DIR, secure_directory(directory))
        os.makedirs(target_dir, exist_ok=True)
        
        # Bilder im Verzeichnis suchen (unterstützte Formate)
        image_extensions = ['*.jpg', '*.jpeg', '*.png', '*.gif', '*.bmp', '*.webp']
        photos = []
        
        for ext in image_extensions:
            photos.extend(glob.glob(os.path.join(target_dir, ext)))
        
        # Nur Dateinamen zurückgeben, nicht die vollständigen Pfade
        photos = [os.path.basename(photo) for photo in sorted(photos, key=os.path.getmtime, reverse=True)]
        
        logger.info(f"{len(photos)} Bilder im Verzeichnis '{directory}' gefunden")
        return {
            'success': True,
            'photos': photos
        }
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Bilderliste: {str(e)}")
        return {
            'success': False,
            'photos': [],
            'error': str(e)
        }

def save_image(image_data: bytes, filename: str, directory: str = 'gallery', 
               create_thumbnail: bool = True) -> Dict[str, Any]:
    """Speichert ein Bild im angegebenen Verzeichnis
    
    Args:
        image_data (bytes): Die zu speichernden Bilddaten
        filename (str): Name der zu speichernden Datei
        directory (str, optional): Zielverzeichnis. Defaults to 'gallery'.
        create_thumbnail (bool, optional): Ob ein Thumbnail erstellt werden soll. Defaults to True.
    
    Returns:
        Dict[str, Any]: Dictionary mit Erfolgs-Flag und Pfad der gespeicherten Datei
    """
    logger.debug(f"Bild {filename} im Verzeichnis '{directory}' wird gespeichert")
    
    try:
        # Sicherstellen, dass der Dateiname sicher ist
        safe_filename = secure_filename(filename)
        
        # Sicherstellen, dass das Verzeichnis im erlaubten Bereich ist
        target_dir = os.path.join(PHOTOS_DIR, secure_directory(directory))
        os.makedirs(target_dir, exist_ok=True)
        
        # Vollständiger Pfad für die Bilddatei
        file_path = os.path.join(target_dir, safe_filename)
        
        # Speichern der Bilddaten
        with open(file_path, 'wb') as f:
            f.write(image_data)
        
        # Optionales Thumbnail erstellen
        thumbnail_path = None
        if create_thumbnail:
            thumbnail_dir = os.path.join(PHOTOS_DIR, 'thumbnails', directory)
            os.makedirs(thumbnail_dir, exist_ok=True)
            thumbnail_path = os.path.join(thumbnail_dir, safe_filename)
            
            try:
                create_image_thumbnail(file_path, thumbnail_path)
                logger.debug(f"Thumbnail für {filename} erstellt: {thumbnail_path}")
            except Exception as thumb_error:
                logger.error(f"Fehler beim Erstellen des Thumbnails: {str(thumb_error)}")
        
        logger.info(f"Bild {filename} erfolgreich gespeichert: {file_path}")
        return {
            'success': True,
            'path': os.path.join(directory, safe_filename),
            'thumbnail': os.path.join('thumbnails', directory, safe_filename) if thumbnail_path else None
        }
    except Exception as e:
        logger.error(f"Fehler beim Speichern des Bildes {filename}: {str(e)}")
        return {
            'success': False,
            'error': str(e)
        }

def delete_image(filename: str, directory: str = 'gallery') -> Dict[str, Any]:
    """Löscht ein Bild aus dem angegebenen Verzeichnis
    
    Args:
        filename (str): Name der zu löschenden Datei
        directory (str, optional): Verzeichnis der Datei. Defaults to 'gallery'.
    
    Returns:
        Dict[str, Any]: Dictionary mit Erfolgs-Flag
    """
    logger.debug(f"Bild {filename} aus {directory} wird gelöscht")
    
    try:
        # Sicherstellen, dass der Dateiname sicher ist
        safe_filename = secure_filename(filename)
        
        # Sicherstellen, dass das Verzeichnis im erlaubten Bereich ist
        target_dir = os.path.join(PHOTOS_DIR, secure_directory(directory))
        
        # Vollständiger Pfad für die Bilddatei
        file_path = os.path.join(target_dir, safe_filename)
        
        # Prüfen, ob die Datei existiert
        if not os.path.exists(file_path):
            logger.warning(f"Datei {file_path} existiert nicht, kann nicht gelöscht werden")
            return {
                'success': False,
                'error': 'Datei existiert nicht'
            }
        
        # Datei löschen
        os.remove(file_path)
        
        # Wenn vorhanden, auch das Thumbnail löschen
        thumbnail_path = os.path.join(PHOTOS_DIR, 'thumbnails', directory, safe_filename)
        if os.path.exists(thumbnail_path):
            os.remove(thumbnail_path)
            logger.debug(f"Thumbnail {thumbnail_path} wurde ebenfalls gelöscht")
        
        logger.info(f"Bild {filename} wurde erfolgreich gelöscht")
        return {
            'success': True
        }
    except Exception as e:
        logger.error(f"Fehler beim Löschen des Bildes {filename}: {str(e)}")
        return {
            'success': False,
            'error': str(e)
        }

def get_file_info(filename: str, directory: str = 'gallery') -> Dict[str, Any]:
    """Ruft Metadaten einer Datei ab
    
    Args:
        filename (str): Name der Datei
        directory (str, optional): Verzeichnis der Datei. Defaults to 'gallery'.
    
    Returns:
        Dict[str, Any]: Dictionary mit Dateimetadaten oder Fehlerinformationen
    """
    logger.debug(f"Dateimetadaten für {filename} in {directory} werden abgerufen")
    
    try:
        # Sicherstellen, dass der Dateiname sicher ist
        safe_filename = secure_filename(filename)
        
        # Sicherstellen, dass das Verzeichnis im erlaubten Bereich ist
        target_dir = os.path.join(PHOTOS_DIR, secure_directory(directory))
        
        # Vollständiger Pfad für die Datei
        file_path = os.path.join(target_dir, safe_filename)
        
        # Prüfen, ob die Datei existiert
        if not os.path.exists(file_path):
            logger.warning(f"Datei {file_path} existiert nicht")
            return {
                'success': False,
                'error': 'Datei existiert nicht'
            }
        
        # Basisdaten der Datei abrufen
        stats = os.stat(file_path)
        
        # MIME-Typ erraten
        mime_type, _ = mimetypes.guess_type(file_path)
        
        # Für Bildateien weitere Informationen abrufen
        width, height = None, None
        if mime_type and mime_type.startswith('image/'):
            try:
                with Image.open(file_path) as img:
                    width, height = img.size
            except Exception as img_error:
                logger.warning(f"Fehler beim Lesen der Bildinformationen: {str(img_error)}")
        
        # Metadata zusammenstellen
        file_info = {
            'name': safe_filename,
            'path': os.path.join(directory, safe_filename),
            'size': stats.st_size,
            'type': mime_type or 'application/octet-stream',
            'created': datetime.fromtimestamp(stats.st_ctime).isoformat(),
            'modified': datetime.fromtimestamp(stats.st_mtime).isoformat(),
            'accessed': datetime.fromtimestamp(stats.st_atime).isoformat()
        }
        
        # Bildinformationen hinzufügen, falls vorhanden
        if width is not None and height is not None:
            file_info.update({
                'width': width,
                'height': height
            })
        
        logger.info(f"Dateimetadaten für {filename} erfolgreich abgerufen")
        return {
            'success': True,
            'data': file_info
        }
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Dateimetadaten für {filename}: {str(e)}")
        return {
            'success': False,
            'error': str(e)
        }

def create_directory(path: str) -> Dict[str, Any]:
    """Erstellt ein Verzeichnis
    
    Args:
        path (str): Zu erstellendes Verzeichnis
    
    Returns:
        Dict[str, Any]: Dictionary mit Erfolgs-Flag
    """
    logger.debug(f"Verzeichnis {path} wird erstellt")
    
    try:
        # Sicherstellen, dass das Verzeichnis im erlaubten Bereich ist
        safe_path = secure_directory(path)
        target_dir = os.path.join(PHOTOS_DIR, safe_path)
        
        # Verzeichnis erstellen
        os.makedirs(target_dir, exist_ok=True)
        
        logger.info(f"Verzeichnis {path} erfolgreich erstellt")
        return {
            'success': True,
            'path': safe_path
        }
    except Exception as e:
        logger.error(f"Fehler beim Erstellen des Verzeichnisses {path}: {str(e)}")
        return {
            'success': False,
            'error': str(e)
        }

def check_disk_space() -> Dict[str, Any]:
    """Prüft den verfügbaren Speicherplatz
    
    Returns:
        Dict[str, Any]: Dictionary mit Speicherplatzinformationen
    """
    logger.debug("Verfügbarer Speicherplatz wird geprüft")
    
    try:
        # Pfad zum Fotobox-Verzeichnis verwenden
        root_path = os.path.dirname(os.path.dirname(__file__))
        
        # Speicherplatzinformationen abrufen
        disk_usage = psutil.disk_usage(root_path)
        
        space_info = {
            'success': True,
            'total': disk_usage.total,
            'free': disk_usage.free,
            'used': disk_usage.used,
            'percent_used': disk_usage.percent
        }
        
        logger.info(f"Speicherplatzinformationen abgerufen: {disk_usage.free / (1024*1024*1024):.2f} GB frei von "
                    f"{disk_usage.total / (1024*1024*1024):.2f} GB ({disk_usage.percent}% genutzt)")
        return space_info
    except Exception as e:
        logger.error(f"Fehler beim Prüfen des Speicherplatzes: {str(e)}")
        return {
            'success': False,
            'error': str(e)
        }

def create_image_thumbnail(source_path: str, target_path: str, size: Tuple[int, int] = THUMBNAIL_SIZE) -> None:
    """Erstellt ein Thumbnail eines Bildes
    
    Args:
        source_path (str): Pfad zum Quellbild
        target_path (str): Pfad zum Ziel-Thumbnail
        size (Tuple[int, int], optional): Größe des Thumbnails. Defaults to THUMBNAIL_SIZE.
    
    Raises:
        Exception: Wenn das Bild nicht gelesen oder verarbeitet werden kann
    """
    with Image.open(source_path) as img:
        img.thumbnail(size)
        # Format aus dem Zieldateipfad ableiten
        format_name = os.path.splitext(target_path)[1].strip('.').upper()
        # Wenn das Format nicht unterstützt wird, JPEG verwenden
        if format_name not in ('JPEG', 'PNG', 'GIF', 'BMP', 'WEBP'):
            format_name = 'JPEG'
        img.save(target_path, format_name)

def secure_directory(directory: str) -> str:
    """Stellt sicher, dass ein Verzeichnispfad sicher ist
    
    Verhindert den Zugriff auf Verzeichnisse außerhalb des erlaubten Bereichs
    durch Entfernen von potenziell gefährlichen Pfadkomponenten.
    
    Args:
        directory (str): Der zu sichernde Verzeichnispfad
    
    Returns:
        str: Der bereinigte Verzeichnispfad
    """
    # Entferne führende Schrägstriche und eventuell vorhandene Laufwerksbuchstaben
    safe_path = directory.lstrip('/\\').lstrip('ABCDEFGHIJKLMNOPQRSTUVWXYZ:')
    
    # Entferne alle ".." und versteckten Verzeichnisse
    components = []
    for part in safe_path.split(os.sep):
        if part and part != '..' and not part.startswith('.'):
            components.append(secure_filename(part))
    
    # Wenn keine gültigen Komponenten übrig bleiben, Standardverzeichnis verwenden
    if not components:
        return 'gallery'
    
    return os.path.join(*components)

# Initialisierung
ensure_directories_exist()
