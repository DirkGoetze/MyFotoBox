"""
Manage Filesystem Modul für die Fotobox2 Backend-Anwendung

Dieses Modul bietet Funktionen für Dateisystem-Operationen wie das Auflisten,
Speichern und Löschen von Bildern sowie Funktionen zur Verwaltung von Verzeichnissen
und zur Überwachung des Speicherplatzes.

Zusätzlich enthält es zentrale Funktionen zur Verwaltung von Dateipfaden für alle
Komponenten des Systems, einschließlich Konfigurationsdateien, Log-Dateien und Systemdateien.
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

# -----------------------------------------------
# ZENTRALE DATEIPFAD-FUNKTIONEN
# -----------------------------------------------

def get_config_file_path(category: str, name: str) -> str:
    """Gibt den Pfad zu einer Konfigurationsdatei zurück.
    
    Args:
        category: Die Kategorie der Datei (nginx, camera, system, ...)
        name: Der Name der Datei ohne Erweiterung
        
    Returns:
        str: Der vollständige Pfad zur Konfigurationsdatei
        
    Raises:
        ValueError: Wenn eine ungültige Kategorie angegeben wird
    """
    logger.debug(f"Konfigurationsdateipfad angefordert: Kategorie={category}, Name={name}")
    
    if not category:
        raise ValueError("Kategorie nicht angegeben")
    if not name:
        raise ValueError("Name nicht angegeben")
    
    # Sicherstellen, dass keine Verzeichnistraversierungen möglich sind
    safe_name = secure_filename(name)
    
    if category == "nginx":
        from manage_folders import get_nginx_conf_dir
        folder_path = get_nginx_conf_dir()
        return os.path.join(folder_path, f"{safe_name}.conf")
    elif category == "camera":
        from manage_folders import get_camera_conf_dir
        folder_path = get_camera_conf_dir()
        return os.path.join(folder_path, f"{safe_name}.json")
    elif category == "system":
        from manage_folders import get_conf_dir
        folder_path = get_conf_dir()
        return os.path.join(folder_path, f"{safe_name}.inf")
    else:
        raise ValueError(f"Unbekannte Dateikategorie: {category}")

def get_system_file_path(file_type: str, name: str) -> str:
    """Gibt den Pfad zu einer System-Konfigurationsdatei zurück (mit Fallback).
    
    Args:
        file_type: Der Typ der Systemdatei (nginx, systemd, ssl_cert, ssl_key)
        name: Der Name der Systemdatei ohne Erweiterung
        
    Returns:
        str: Der vollständige Pfad zur Systemdatei
        
    Raises:
        ValueError: Wenn ein ungültiger Dateityp angegeben wird
    """
    logger.debug(f"Systemdateipfad angefordert: Typ={file_type}, Name={name}")
    
    if not file_type:
        raise ValueError("Dateityp nicht angegeben")
    if not name:
        raise ValueError("Name nicht angegeben")
    
    # Sicherstellen, dass keine Verzeichnistraversierungen möglich sind
    safe_name = secure_filename(name)
    
    # Konfiguration für Systemdateitypen
    file_conf = {
        "nginx": {
            "primary": "/etc/nginx/sites-available",
            "extension": ".conf",
            "fallback_getter": "get_nginx_conf_dir" 
        },
        "systemd": {
            "primary": "/etc/systemd/system",
            "extension": ".service",
            "fallback_getter": "get_conf_dir"
        },
        "ssl_cert": {
            "primary": "/etc/ssl/certs",
            "extension": ".crt",
            "fallback_getter": "get_ssl_dir"
        },
        "ssl_key": {
            "primary": "/etc/ssl/private",
            "extension": ".key",
            "fallback_getter": "get_ssl_dir"
        }
    }
    
    if file_type not in file_conf:
        raise ValueError(f"Unbekannter Dateityp: {file_type}")
    
    config = file_conf[file_type]
    primary_path = os.path.join(config["primary"], f"{safe_name}{config['extension']}")
    
    # Prüfen, ob die Datei am primären Ort existiert
    if os.path.isfile(primary_path):
        logger.debug(f"Datei {safe_name} am primären Ort gefunden: {primary_path}")
        return primary_path
    
    # Fallback-Ort verwenden
    try:
        # Dynamisch den Fallback-Ort aus manage_folders abrufen
        import manage_folders
        fallback_dir = getattr(manage_folders, config["fallback_getter"])()
        fallback_path = os.path.join(fallback_dir, f"{safe_name}{config['extension']}")
        
        logger.debug(f"Fallback-Pfad für {safe_name}: {fallback_path}")
        return fallback_path
    except (ImportError, AttributeError) as e:
        logger.error(f"Fehler beim Abrufen des Fallback-Pfads: {str(e)}")
        # Wenn manage_folders nicht verfügbar ist, verwenden wir feste Pfade
        if file_type == "nginx":
            return os.path.join("../conf/nginx", f"{safe_name}.conf")
        else:
            return os.path.join("../conf", f"{safe_name}{config['extension']}")

def get_log_file_path(component: str) -> str:
    """Gibt den Pfad zu einer Log-Datei zurück.
    
    Args:
        component: Die Komponente, für die die Log-Datei bestimmt ist
        
    Returns:
        str: Der vollständige Pfad zur Log-Datei
    """
    if not component:
        raise ValueError("Komponente nicht angegeben")
    
    # Sicherstellen, dass keine Verzeichnistraversierungen möglich sind
    safe_component = secure_filename(component)
    
    date_suffix = datetime.now().strftime("%Y-%m-%d")
    
    try:
        # Verwende get_log_dir aus manage_folders
        from manage_folders import get_log_dir
        log_dir = get_log_dir()
    except ImportError:
        # Fallback, falls manage_folders nicht verfügbar ist
        log_dir = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(__file__)), 'log'))
        os.makedirs(log_dir, exist_ok=True)
    
    return os.path.join(log_dir, f"{safe_component}_{date_suffix}.log")

def get_template_file_path(category: str, name: str) -> str:
    """Gibt den Pfad zu einer Template-Datei zurück.
    
    Args:
        category: Die Kategorie des Templates (nginx, backup, ...)
        name: Der Name des Templates
        
    Returns:
        str: Der vollständige Pfad zur Template-Datei
        
    Raises:
        ValueError: Wenn eine ungültige Kategorie angegeben wird
    """
    if not category:
        raise ValueError("Kategorie nicht angegeben")
    if not name:
        raise ValueError("Name nicht angegeben")
    
    # Sicherstellen, dass keine Verzeichnistraversierungen möglich sind
    safe_name = secure_filename(name)
    
    try:
        if category == "nginx":
            from manage_folders import get_nginx_conf_dir
            folder_path = get_nginx_conf_dir()
        elif category == "backup":
            # Gemeinsamer Speicherort mit nginx Templates
            from manage_folders import get_nginx_conf_dir
            folder_path = get_nginx_conf_dir()
        else:
            raise ValueError(f"Unbekannte Template-Kategorie: {category}")
    except ImportError:
        # Fallback, falls manage_folders nicht verfügbar ist
        folder_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(__file__)), 'conf', 'nginx'))
        os.makedirs(folder_path, exist_ok=True)
    
    return os.path.join(folder_path, f"template_{safe_name}")

def file_exists(file_path: str) -> bool:
    """Prüft, ob eine Datei existiert.
    
    Args:
        file_path: Der vollständige Pfad zur Datei
        
    Returns:
        bool: True wenn die Datei existiert, False wenn nicht
    """
    if not file_path:
        raise ValueError("Dateipfad nicht angegeben")
    
    return os.path.isfile(file_path)

# Funktion zum Lesen des Inhalts einer Textdatei
def read_file_content(file_path: str, encoding: str = 'utf-8') -> str:
    """Liest den Inhalt einer Textdatei.
    
    Args:
        file_path: Der vollständige Pfad zur Datei
        encoding: Die zu verwendende Kodierung (Standard: utf-8)
        
    Returns:
        str: Der Inhalt der Datei
        
    Raises:
        FileNotFoundError: Wenn die Datei nicht existiert
        UnicodeDecodeError: Wenn die Datei nicht mit der angegebenen Kodierung gelesen werden kann
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Datei nicht gefunden: {file_path}")
    
    try:
        with open(file_path, 'r', encoding=encoding) as file:
            return file.read()
    except UnicodeDecodeError:
        # Wenn UTF-8 fehlschlägt, versuchen wir es mit Latin-1 als Fallback
        with open(file_path, 'r', encoding='latin-1') as file:
            return file.read()

# Funktion zum Schreiben in eine Textdatei
def write_file_content(file_path: str, content: str, encoding: str = 'utf-8') -> bool:
    """Schreibt Inhalt in eine Textdatei.
    
    Args:
        file_path: Der vollständige Pfad zur Datei
        content: Der zu schreibende Inhalt
        encoding: Die zu verwendende Kodierung (Standard: utf-8)
        
    Returns:
        bool: True wenn erfolgreich, False wenn ein Fehler aufgetreten ist
    """
    try:
        # Sicherstellen, dass das Verzeichnis existiert
        directory = os.path.dirname(file_path)
        if directory:
            os.makedirs(directory, exist_ok=True)
        
        with open(file_path, 'w', encoding=encoding) as file:
            file.write(content)
        
        logger.info(f"Inhalt in Datei geschrieben: {file_path}")
        return True
    except Exception as e:
        logger.error(f"Fehler beim Schreiben in Datei {file_path}: {str(e)}")
        return False

# Initialisierung
ensure_directories_exist()
