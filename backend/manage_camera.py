"""
manage_camera.py - Kamerasteuerungsmodul für Fotobox2 Backend

Dieses Modul bietet Funktionen zur Erkennung, Initialisierung und Steuerung
von Kameras (Webcams und DSLR-Kameras) für die Fotobox2-Anwendung.

Hauptfunktionalität:
- Kamera-Erkennung und -Initialisierung
- Bildaufnahme (Einzelbilder, Serien)
- Kamera-Einstellungen verwalten
- Grundlegende Bildverarbeitung
"""

import os
import sys
import time
import json
import logging
import threading
from typing import Dict, List, Optional, Tuple, Union

# Abhängige Module importieren
import manage_logging
import manage_settings
import manage_filesystem as manage_files
import manage_camera_config  # Neu importiert für Kamera-Konfigurationssets
import utils

# Versuche, OpenCV zu importieren
try:
    import cv2
    OPENCV_AVAILABLE = True
    manage_logging.log("OpenCV erfolgreich geladen", source="manage_camera")
except ImportError:
    OPENCV_AVAILABLE = False
    manage_logging.error("OpenCV konnte nicht geladen werden. Kamerafunktionen eingeschränkt.", source="manage_camera")

# Versuche, gPhoto2 zu importieren (für DSLR-Kameras)
try:
    import gphoto2 as gp
    GPHOTO2_AVAILABLE = True
    manage_logging.log("gPhoto2 erfolgreich geladen", source="manage_camera")
except ImportError:
    GPHOTO2_AVAILABLE = False
    manage_logging.log("gPhoto2 konnte nicht geladen werden. DSLR-Unterstützung deaktiviert.", source="manage_camera")

# Versuche, Intel RealSense zu importieren (für Tiefensensor-Kameras)
try:
    import pyrealsense2 as rs
    import numpy as np
    REALSENSE_AVAILABLE = True
    manage_logging.log("Intel RealSense-Bibliothek erfolgreich geladen", source="manage_camera")
except ImportError:
    REALSENSE_AVAILABLE = False
    manage_logging.log("Intel RealSense-Bibliothek konnte nicht geladen werden. Tiefensensor-Unterstützung deaktiviert.", source="manage_camera")

# Versuche, das RealSense-Modul zu importieren (für Tiefensensor-Kameras)
try:
    import pyrealsense2 as rs
    REALSENSE_AVAILABLE = True
    manage_logging.log("RealSense-Bibliothek erfolgreich geladen", source="manage_camera")
except ImportError:
    REALSENSE_AVAILABLE = False
    manage_logging.log("RealSense-Bibliothek konnte nicht geladen werden. Tiefensensor-Unterstützung deaktiviert.", 
                    source="manage_camera")

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Globale Variablen
_cameras = {}  # Speichert initialisierte Kameraobjekte
_active_camera = None  # Aktuell aktive Kamera
_preview_thread = None  # Thread für Vorschau-Stream
_preview_running = False  # Flag für laufende Vorschau

class Camera:
    """Basisklasse für alle Kameratypen"""
    
    def __init__(self, camera_id, name, camera_type):
        """Initialisiert eine Kamerainstanz
        
        Args:
            camera_id: Eindeutige ID der Kamera
            name: Benutzerfreundlicher Name der Kamera
            camera_type: Typ der Kamera (webcam, dslr, etc.)
        """
        self.id = camera_id
        self.name = name
        self.type = camera_type
        self.connected = False
        self.settings = {}
        self.last_error = None
        
    def connect(self) -> bool:
        """Stellt eine Verbindung zur Kamera her
        
        Returns:
            bool: True wenn erfolgreich, False sonst
        """
        raise NotImplementedError("Muss in Unterklasse implementiert werden")
        
    def disconnect(self) -> bool:
        """Trennt die Verbindung zur Kamera
        
        Returns:
            bool: True wenn erfolgreich, False sonst
        """
        raise NotImplementedError("Muss in Unterklasse implementiert werden")
        
    def capture(self, options=None) -> Dict:
        """Nimmt ein Bild auf
        
        Args:
            options: Optionen für die Aufnahme (z.B. Auflösung, Qualität, etc.)
            
        Returns:
            Dict mit Status und ggf. Pfad zum aufgenommenen Bild
        """
        raise NotImplementedError("Muss in Unterklasse implementiert werden")
        
    def get_preview_frame(self) -> Optional[bytes]:
        """Gibt ein einzelnes Vorschaubild zurück
        
        Returns:
            bytes: Bilddaten als JPEG oder None bei Fehler
        """
        raise NotImplementedError("Muss in Unterklasse implementiert werden")
        
    def get_settings(self) -> Dict:
        """Gibt die aktuellen Kameraeinstellungen zurück
        
        Returns:
            Dict mit Kameraeinstellungen
        """
        return self.settings
        
    def update_settings(self, settings: Dict) -> bool:
        """Aktualisiert die Kameraeinstellungen
        
        Args:
            settings: Dict mit zu aktualisierenden Einstellungen
            
        Returns:
            bool: True wenn erfolgreich, False sonst
        """
        raise NotImplementedError("Muss in Unterklasse implementiert werden")

    def to_dict(self) -> Dict:
        """Konvertiert die Kamerainformationen in ein Dict
        
        Returns:
            Dict mit Kamerainfos
        """
        return {
            'id': self.id,
            'name': self.name,
            'type': self.type,
            'connected': self.connected,
            'settings': self.settings
        }

class WebcamCamera(Camera):
    """Implementierung für Webcams mit OpenCV"""
    
    def __init__(self, camera_id, name=None):
        """Initialisiert eine Webcam-Kamera
        
        Args:
            camera_id: ID der Kamera (normalerweise eine Zahl)
            name: Name der Kamera (optional)
        """
        super().__init__(camera_id, name or f"Webcam {camera_id}", "webcam")
        self.device = None
        self.settings = {
            'resolution': {'width': 1280, 'height': 720},
            'fps': 30,
            'focus': 'auto',
            'exposure': 'auto',
            'white_balance': 'auto'
        }
        
    def connect(self) -> bool:
        """Verbindung zur Webcam herstellen"""
        try:
            if not OPENCV_AVAILABLE:
                self.last_error = "OpenCV nicht verfügbar"
                return False
                
            # Versuche, die Kamera zu öffnen
            self.device = cv2.VideoCapture(self.id)
            
            if not self.device.isOpened():
                self.last_error = f"Konnte Kamera {self.id} nicht öffnen"
                return False
                
            # Kameraeinstellungen anwenden
            self.device.set(cv2.CAP_PROP_FRAME_WIDTH, self.settings['resolution']['width'])
            self.device.set(cv2.CAP_PROP_FRAME_HEIGHT, self.settings['resolution']['height'])
            self.device.set(cv2.CAP_PROP_FPS, self.settings['fps'])
            
            # Status aktualisieren
            self.connected = True
            manage_logging.log(f"Verbindung zu {self.name} (ID: {self.id}) hergestellt", source="manage_camera")
            return True
            
        except Exception as e:
            self.last_error = str(e)
            manage_logging.error(f"Fehler beim Verbinden mit {self.name}: {str(e)}", exception=e, source="manage_camera")
            return False
            
    def disconnect(self) -> bool:
        """Trennt die Verbindung zur Webcam"""
        try:
            if self.device and self.connected:
                self.device.release()
                self.connected = False
                manage_logging.log(f"Verbindung zu {self.name} getrennt", source="manage_camera")
                return True
            return False
        except Exception as e:
            self.last_error = str(e)
            manage_logging.error(f"Fehler beim Trennen der Verbindung zu {self.name}: {str(e)}", 
                               exception=e, source="manage_camera")
            return False
            
    def capture(self, options=None) -> Dict:
        """Nimmt ein Bild mit der Webcam auf"""
        if not self.connected or not self.device:
            return {'success': False, 'error': 'Keine Verbindung zur Kamera'}
            
        try:
            if options is None:
                options = {}
                
            # Lese ein Frame von der Kamera
            ret, frame = self.device.read()
            
            if not ret:
                self.last_error = "Konnte kein Bild aufnehmen"
                return {'success': False, 'error': self.last_error}
                
            # Bestimme Dateiname und Pfad
            directory = options.get('directory', 'photos')
            timestamp = int(time.time())
            filename = options.get('filename', f"webcam_{timestamp}.jpg")
            quality = options.get('quality', 95)  # JPEG-Qualität (0-100)
            
            # Speicherpfad erstellen
            file_path = manage_files.get_file_path(filename, directory)
            
            # Bild speichern
            success = cv2.imwrite(file_path, frame, [cv2.IMWRITE_JPEG_QUALITY, quality])
            
            if not success:
                self.last_error = "Fehler beim Speichern des Bildes"
                return {'success': False, 'error': self.last_error}
                
            # Optional: Thumbnail erstellen
            if options.get('create_thumbnail', True):
                thumb_path = manage_files.create_thumbnail(file_path)
            else:
                thumb_path = None
                
            manage_logging.log(f"Bild aufgenommen und gespeichert: {filename}", source="manage_camera")
            
            return {
                'success': True,
                'filepath': file_path,
                'filename': filename,
                'thumbnail': thumb_path
            }
            
        except Exception as e:
            self.last_error = str(e)
            manage_logging.error(f"Fehler bei Bildaufnahme: {str(e)}", exception=e, source="manage_camera")
            return {'success': False, 'error': str(e)}
            
    def get_preview_frame(self) -> Optional[bytes]:
        """Liefert ein einzelnes Vorschaubild als JPEG-Bytes"""
        if not self.connected or not self.device:
            return None
            
        try:
            # Lese ein Frame von der Kamera
            ret, frame = self.device.read()
            
            if not ret:
                return None
                
            # Konvertiere das Bild zu JPEG
            ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            
            if not ret:
                return None
                
            return buffer.tobytes()
            
        except Exception as e:
            self.last_error = str(e)
            manage_logging.error(f"Fehler bei Vorschau: {str(e)}", exception=e, source="manage_camera")
            return None
            
    def update_settings(self, settings: Dict) -> bool:
        """Aktualisiert die Einstellungen der Webcam"""
        if not self.connected or not self.device:
            return False
            
        try:
            # Aktualisiere die Auflösung
            if 'resolution' in settings:
                res = settings['resolution']
                width = res.get('width', self.settings['resolution']['width'])
                height = res.get('height', self.settings['resolution']['height'])
                
                self.device.set(cv2.CAP_PROP_FRAME_WIDTH, width)
                self.device.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
                
                # Aktualisiere gespeicherte Einstellungen
                self.settings['resolution']['width'] = width
                self.settings['resolution']['height'] = height
                
            # Aktualisiere die FPS
            if 'fps' in settings:
                self.device.set(cv2.CAP_PROP_FPS, settings['fps'])
                self.settings['fps'] = settings['fps']
                
            # Weitere Einstellungen: Fokus, Belichtung, etc.
            # Diese hängen stark von der verwendeten Kamera ab und müssen ggf. angepasst werden
            
            return True
            
        except Exception as e:
            self.last_error = str(e)
            manage_logging.error(f"Fehler beim Aktualisieren der Kameraeinstellungen: {str(e)}",
                               exception=e, source="manage_camera")
            return False

class DSLRCamera:
    """Klasse für die Interaktion mit DSLR/DSLM-Kameras über gPhoto2."""
    
    def __init__(self, name: str, addr: str, config=None):
        """Initialisiert eine DSLR-Kamera
        
        Args:
            name: Name der Kamera
            addr: gPhoto2-Adresse der Kamera (z.B. "usb:001,004")
            config: Optionale Kamera-Konfiguration (Dict)
        """
        self.name = name
        self.address = addr
        self.connected = False
        self.camera = None
        self.context = gp.Context()
        
        # Standardeinstellungen
        self.settings = {
            'resolution': 'max',
            'aperture': 'auto',
            'iso': 'auto',
            'shutter_speed': 'auto',
            'focus': 'auto',
            'white_balance': 'auto',
            'compression': 'high'
        }
        
        # Konfiguration anwenden, falls vorhanden
        if config and 'settings' in config:
            self.settings.update(config['settings'])
        
        # Fortgeschrittene Einstellungen (falls vorhanden)
        self.advanced_settings = {}
        if config and 'advanced' in config and 'camera_config' in config['advanced']:
            self.advanced_settings = config['advanced']['camera_config']
        
        # Konfiguration für das USB-Interface
        self.usb_settings = {}
        if config and 'advanced' in config and 'usb_settings' in config['advanced']:
            self.usb_settings = config['advanced']['usb_settings']
        
        # Kamera-Typ (dslr oder dslm)
        self.type = config.get('type', 'dslr') if config else 'dslr'
        
        # Interface (gphoto2)
        self.interface = config.get('interface', 'gphoto2') if config else 'gphoto2'
        
        # Kamera-Config-ID speichern
        self.config_id = None
        if config and '_id' in config:
            self.config_id = config['_id']
    
    def connect(self) -> bool:
        """Verbindet zur Kamera
        
        Returns:
            bool: True wenn erfolgreich, False sonst
        """
        if self.connected:
            return True  # Bereits verbunden
            
        try:
            # Initialisiere die Kamera
            self.camera = gp.Camera()
            
            # Setze die Port-Info basierend auf der Adresse
            port_info_list = gp.PortInfoList()
            port_info_list.load()
            idx = port_info_list.lookup_path(self.address)
            self.camera.set_port_info(port_info_list[idx])
            
            # Initialisiere die Kamera
            self.camera.init(self.context)
            
            # Anwenden der fortgeschrittenen Einstellungen
            self._apply_advanced_settings()
            
            self.connected = True
            manage_logging.log(f"DSLR-Kamera verbunden: {self.name} ({self.address})", source="manage_camera")
            return True
            
        except Exception as e:
            manage_logging.error(f"Fehler beim Verbinden zur DSLR-Kamera {self.name}: {str(e)}", 
                               exception=e, source="manage_camera")
            self.connected = False
            return False
    
    def disconnect(self) -> bool:
        """Trennt die Verbindung zur Kamera
        
        Returns:
            bool: True wenn erfolgreich, False sonst
        """
        if not self.connected or not self.camera:
            return True  # Bereits getrennt
            
        try:
            self.camera.exit()
            self.connected = False
            self.camera = None
            manage_logging.log(f"DSLR-Kamera getrennt: {self.name}", source="manage_camera")
            return True
            
        except Exception as e:
            manage_logging.error(f"Fehler beim Trennen der DSLR-Kamera {self.name}: {str(e)}", 
                               exception=e, source="manage_camera")
            return False
    
    def capture(self, options: Dict = None) -> Dict:
        """Nimmt ein Bild auf
        
        Args:
            options: Optionale Parameter für die Aufnahme
            
        Returns:
            Dict mit Ergebnisinformationen (success, filepath, etc.)
        """
        if not self.connected or not self.camera:
            success = self.connect()
            if not success:
                return {'success': False, 'error': "Kamera nicht verbunden"}
        
        try:
            # Optionen auswerten
            options = options or {}
            save_dir = options.get('save_directory', 'photos/dslr')
            create_thumbnail = options.get('create_thumbnail', True)
            
            # Sicherstellen, dass der Speicherordner existiert
            os.makedirs(save_dir, exist_ok=True)
            
            # Kameraeinstellungen vor der Aufnahme anwenden
            self._apply_capture_settings(options)
            
            # Definiere den Dateipfad für die Aufnahme
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            filename = f"photo_{timestamp}.jpg"
            filepath = os.path.join(save_dir, filename)
            
            # Bild aufnehmen
            file_path = self.camera.capture(gp.GP_CAPTURE_IMAGE, self.context)
            camera_file = self.camera.file_get(
                file_path.folder,
                file_path.name,
                gp.GP_FILE_TYPE_NORMAL,
                self.context
            )
            
            # Speichere die Datei
            camera_file.save(filepath)
            
            # Erstelle Thumbnail, wenn gewünscht
            thumbnail_path = None
            if create_thumbnail:
                thumbnail_dir = os.path.join(save_dir, 'thumbnails')
                os.makedirs(thumbnail_dir, exist_ok=True)
                thumbnail_file = f"thumb_{timestamp}.jpg"
                thumbnail_path = os.path.join(thumbnail_dir, thumbnail_file)
                
                # Thumbnail mit OpenCV erstellen
                if OPENCV_AVAILABLE:
                    img = cv2.imread(filepath)
                    if img is not None:
                        # Thumbnail erstellen (max. 320x240)
                        thumbnail_size = (320, 240)
                        thumbnail = self._resize_image_keep_aspect_ratio(img, thumbnail_size)
                        cv2.imwrite(thumbnail_path, thumbnail)
            
            return {
                'success': True,
                'filepath': filepath,
                'filename': filename,
                'thumbnail': thumbnail_path
            }
            
        except Exception as e:
            manage_logging.error(f"Fehler bei Bildaufnahme mit DSLR {self.name}: {str(e)}", 
                               exception=e, source="manage_camera")
            return {'success': False, 'error': str(e)}
    
    def _resize_image_keep_aspect_ratio(self, img, target_size):
        """Skaliert ein Bild unter Beibehaltung des Seitenverhältnisses
        
        Args:
            img: Das zu skalierende Bild (OpenCV-Format)
            target_size: Zielgröße (Breite, Höhe)
            
        Returns:
            Skaliertes Bild
        """
        height, width = img.shape[:2]
        target_width, target_height = target_size
        
        # Berechne Skalierungsfaktoren für Breite und Höhe
        scale_width = target_width / width
        scale_height = target_height / height
        
        # Verwende den kleineren Faktor, um das Seitenverhältnis beizubehalten
        scale = min(scale_width, scale_height)
        
        # Berechne neue Größe
        new_width = int(width * scale)
        new_height = int(height * scale)
        
        # Skaliere das Bild
        resized = cv2.resize(img, (new_width, new_height))
        
        return resized
    
    def _apply_capture_settings(self, options: Dict = None):
        """Wendet Einstellungen vor der Aufnahme an
        
        Args:
            options: Optionen für die Aufnahme
        """
        try:
            # Mische Optionen mit den bestehenden Einstellungen
            capture_settings = self.settings.copy()
            if options:
                for key, value in options.items():
                    if key in capture_settings:
                        capture_settings[key] = value
            
            # Hier könnten spezifische gPhoto2-Einstellungen angewendet werden
            # z.B. Belichtungszeit, Blende, ISO, etc.
            if self.camera and self.connected:
                config = self.camera.get_config(self.context)
                
                # Anwenden der Einstellungen je nach Verfügbarkeit
                self._try_set_config_value(config, 'aperture', capture_settings.get('aperture'))
                self._try_set_config_value(config, 'iso', capture_settings.get('iso'))
                self._try_set_config_value(config, 'shutterspeed', capture_settings.get('shutter_speed'))
                self._try_set_config_value(config, 'whitebalance', capture_settings.get('white_balance'))
                
                # Konfiguration zurück zur Kamera senden
                self.camera.set_config(config, self.context)
        
        except Exception as e:
            manage_logging.error(f"Fehler beim Anwenden der Kameraeinstellungen: {str(e)}", 
                             exception=e, source="manage_camera")
    
    def _apply_advanced_settings(self):
        """Wendet fortgeschrittene Kameraeinstellungen an"""
        if not self.camera or not self.connected or not self.advanced_settings:
            return
            
        try:
            config = self.camera.get_config(self.context)
            
            for key, value in self.advanced_settings.items():
                self._try_set_config_value(config, key, value)
                
            # Konfiguration zurück zur Kamera senden
            self.camera.set_config(config, self.context)
            
            manage_logging.debug(f"Fortgeschrittene Einstellungen auf DSLR angewendet: {self.name}", 
                           source="manage_camera")
                
        except Exception as e:
            manage_logging.error(f"Fehler beim Anwenden fortgeschrittener Kameraeinstellungen: {str(e)}", 
                             exception=e, source="manage_camera")
    
    def _try_set_config_value(self, config, setting_name, value):
        """Versucht, einen Konfigurationswert zu setzen, ohne bei Fehlern abzubrechen
        
        Args:
            config: gPhoto2-Konfigurationsobjekt
            setting_name: Name der Einstellung
            value: Zu setzender Wert
        """
        if value is None:
            return
            
        try:
            # Finde den Konfigurationsknoten
            setting_node = self._find_config_node(config, setting_name)
            
            if setting_node:
                # Wert setzen
                setting_node.set_value(str(value))
                manage_logging.debug(f"Kameraeinstellung gesetzt: {setting_name}={value}", source="manage_camera")
            else:
                manage_logging.debug(f"Kameraeinstellung nicht gefunden: {setting_name}", source="manage_camera")
                
        except Exception as e:
            manage_logging.debug(f"Einstellung {setting_name} konnte nicht gesetzt werden: {str(e)}", 
                             source="manage_camera")
    
    def _find_config_node(self, config, setting_name):
        """Sucht nach einem Konfigurationsknoten in der Kamerakonfiguration
        
        Berücksichtigt verschiedene Bezeichnungen für die gleiche Einstellung bei verschiedenen Kameraherstellern
        
        Args:
            config: gPhoto2-Konfigurationsobjekt
            setting_name: Gesuchter Einstellungsname
            
        Returns:
            Konfigurationsknoten oder None
        """
        # Mapping von vereinheitlichten Namen zu herstellerspezifischen Namen
        # Die Liste kann erweitert werden, wenn weitere Kameramodelle unterstützt werden
        setting_mapping = {
            'aperture': ['aperture', 'f-number', 'fnumber', 'f-number-value', 'shutteraperture'],
            'iso': ['iso', 'iso-speed', 'iso-speed-value', 'isospeed'],
            'shutter_speed': ['shutterspeed', 'shutter-speed', 'shutter-speed-value', 'shutterspeedvalue'],
            'white_balance': ['whitebalance', 'white-balance', 'wb', 'whitebalanceadjust'],
            'focus': ['focusmode', 'focus-mode', 'focus', 'autofocus'],
            'image_stabilization': ['stabilization', 'imagestabilization', 'is-mode', 'opticalstabilizer'],
            'picture_style': ['picturestyle', 'picture-style', 'picture-mode', 'photomode', 'pictureeffect'],
            'capture_format': ['imageformat', 'image-format', 'capturetarget', 'captureformat']
        }
        
        # Versuche zuerst den exakten Namen
        try:
            return config.get_child_by_name(setting_name)
        except:
            pass
        
        # Wenn nicht gefunden, versuche mögliche Varianten
        if setting_name in setting_mapping:
            for variant in setting_mapping[setting_name]:
                try:
                    return config.get_child_by_name(variant)
                except:
                    continue
        
        # Durchsuche rekursiv alle Knoten (kann bei großen Konfigurationen langsam sein)
        try:
            for child in config.get_children():
                if child.get_name().lower() == setting_name.lower():
                    return child
                
                # Rekursiv in Unterknoten suchen, wenn es sich um einen Container handelt
                if child.get_type() == gp.GP_WIDGET_SECTION or child.get_type() == gp.GP_WIDGET_WINDOW:
                    result = self._find_config_node(child, setting_name)
                    if result:
                        return result
        except:
            pass
            
        return None
    
    def get_preview(self) -> Dict:
        """Ruft ein Vorschaubild von der Kamera ab
        
        Returns:
            Dict mit Ergebnisinformationen (success, image_data, etc.)
        """
        if not self.connected or not self.camera:
            success = self.connect()
            if not success:
                return {'success': False, 'error': "Kamera nicht verbunden"}
        
        try:
            # Aktiviere den Sucher
            self._try_enable_viewfinder()
            
            # Hole ein Vorschaubild
            camera_file = self.camera.capture_preview(self.context)
            
            # Hole die Bilddaten als Bytes
            file_data = camera_file.get_data_and_size()
            
            # Dekodieren des JPEG-Bildes mit OpenCV
            if OPENCV_AVAILABLE:
                import numpy as np
                img_array = np.frombuffer(file_data, np.uint8)
                img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                
                # Größe anpassen, falls nötig
                preview_width = self.settings.get('preview', {}).get('width', 640)
                preview_height = self.settings.get('preview', {}).get('height', 480)
                
                if img is not None and (img.shape[1] > preview_width or img.shape[0] > preview_height):
                    img = self._resize_image_keep_aspect_ratio(img, (preview_width, preview_height))
                
                # Konvertiere zurück zu JPEG-Bytes
                _, buffer = cv2.imencode('.jpg', img)
                
                return {
                    'success': True,
                    'image_data': buffer.tobytes(),
                    'content_type': 'image/jpeg'
                }
            else:
                # Wenn OpenCV nicht verfügbar ist, gib die Original-Daten zurück
                return {
                    'success': True,
                    'image_data': file_data,
                    'content_type': 'image/jpeg'
                }
                
        except Exception as e:
            manage_logging.error(f"Fehler beim Abrufen des Vorschaubildes: {str(e)}", 
                               exception=e, source="manage_camera")
            return {'success': False, 'error': str(e)}
    
    def _try_enable_viewfinder(self):
        """Versucht, den Sucher zu aktivieren (für Live-Vorschau)"""
        try:
            config = self.camera.get_config(self.context)
            
            # Verschiedene Bezeichnungen für den Sucher/Vorschaumodus
            viewfinder_names = ['viewfinder', 'capture', 'output', 'recordingmedia', 'capturetarget']
            
            for name in viewfinder_names:
                try:
                    widget = self._find_config_node(config, name)
                    if widget:
                        # Versuchen, den Wert auf Live-View zu setzen
                        # Mögliche Werte: On, 1, PC, Host, ViewFinder
                        for value in ['1', 'On', 'PC', 'Host', 'ViewFinder']:
                            try:
                                widget.set_value(value)
                                self.camera.set_config(config, self.context)
                                return
                            except:
                                continue
                except:
                    continue
                    
            manage_logging.debug("Konnte den Sucher nicht automatisch aktivieren", source="manage_camera")
            
        except Exception as e:
            manage_logging.debug(f"Fehler beim Aktivieren des Suchers: {str(e)}", source="manage_camera")
    
    def to_dict(self) -> Dict:
        """Konvertiert die Kamera in ein Dictionary
        
        Returns:
            Dict mit Kamerainformationen
        """
        return {
            'id': f"dslr_{self.address.replace(':', '_').replace(',', '_')}",
            'name': self.name,
            'address': self.address,
            'type': self.type,
            'interface': self.interface,
            'connected': self.connected,
            'settings': self.settings,
            'config_id': self.config_id
        }

class DepthSensorCamera:
    """Klasse für die Interaktion mit Tiefensensor-Kameras wie Intel RealSense."""
    
    def __init__(self, name: str, serial_number: str, config=None):
        """Initialisiert eine Tiefensensor-Kamera
        
        Args:
            name: Name der Kamera
            serial_number: Seriennummer der Kamera
            config: Optionale Kamera-Konfiguration (Dict)
        """
        self.name = name
        self.serial_number = serial_number
        self.connected = False
        self.pipeline = None
        self.config = None
        
        # Standardeinstellungen
        self.settings = {
            'resolution': {
                'width': 1280,
                'height': 720
            },
            'fps': 30,
            'depth_mode': False,
            'exposure': 'auto',
            'white_balance': 'auto',
            'compression': 90
        }
        
        # Konfiguration anwenden, falls vorhanden
        if config and 'settings' in config:
            self.settings.update(config['settings'])
        
        # Fortgeschrittene Einstellungen (falls vorhanden)
        self.advanced_settings = {}
        if config and 'advanced' in config and 'camera_controls' in config['advanced']:
            self.advanced_settings = config['advanced']['camera_controls']
        
        # Kamera-Typ
        self.type = 'depth_sensor'
        
        # Interface (librealsense)
        self.interface = config.get('interface', 'librealsense') if config else 'librealsense'
        
        # Kamera-Config-ID speichern
        self.config_id = None
        if config and '_id' in config:
            self.config_id = config['_id']
    
    def connect(self) -> bool:
        """Verbindet zur Kamera
        
        Returns:
            bool: True wenn erfolgreich, False sonst
        """
        if not REALSENSE_AVAILABLE:
            manage_logging.error("RealSense-Bibliothek nicht verfügbar", source="manage_camera")
            return False
            
        if self.connected:
            return True  # Bereits verbunden
            
        try:
            # Initialisiere die Pipeline und Konfiguration
            self.pipeline = rs.pipeline()
            self.config = rs.config()
            
            # Verwende die Seriennummer, um eine bestimmte Kamera auszuwählen
            if self.serial_number:
                self.config.enable_device(self.serial_number)
            
            # Konfiguriere die Streams
            width = self.settings['resolution']['width']
            height = self.settings['resolution']['height']
            fps = self.settings['fps']
            
            # Aktiviere RGB-Stream
            self.config.enable_stream(rs.stream.color, width, height, rs.format.bgr8, fps)
            
            # Aktiviere Tiefensensor nur wenn gewünscht
            if self.settings.get('depth_mode', False):
                self.config.enable_stream(rs.stream.depth, width, height, rs.format.z16, fps)
            
            # Starte die Pipeline
            self.pipeline.start(self.config)
            
            # Anwenden der fortgeschrittenen Einstellungen
            self._apply_advanced_settings()
            
            self.connected = True
            manage_logging.log(f"Tiefensensor-Kamera verbunden: {self.name}", source="manage_camera")
            return True
            
        except Exception as e:
            manage_logging.error(f"Fehler beim Verbinden zur Tiefensensor-Kamera {self.name}: {str(e)}", 
                               exception=e, source="manage_camera")
            self.connected = False
            return False
    
    def disconnect(self) -> bool:
        """Trennt die Verbindung zur Kamera
        
        Returns:
            bool: True wenn erfolgreich, False sonst
        """
        if not self.connected or not self.pipeline:
            return True  # Bereits getrennt
            
        try:
            self.pipeline.stop()
            self.connected = False
            self.pipeline = None
            manage_logging.log(f"Tiefensensor-Kamera getrennt: {self.name}", source="manage_camera")
            return True
            
        except Exception as e:
            manage_logging.error(f"Fehler beim Trennen der Tiefensensor-Kamera {self.name}: {str(e)}", 
                               exception=e, source="manage_camera")
            return False
    
    def capture(self, options: Dict = None) -> Dict:
        """Nimmt ein Bild auf
        
        Args:
            options: Optionale Parameter für die Aufnahme
            
        Returns:
            Dict mit Ergebnisinformationen (success, filepath, etc.)
        """
        if not REALSENSE_AVAILABLE:
            return {'success': False, 'error': "RealSense-Bibliothek nicht verfügbar"}
            
        if not self.connected or not self.pipeline:
            success = self.connect()
            if not success:
                return {'success': False, 'error': "Kamera nicht verbunden"}
        
        try:
            # Optionen auswerten
            options = options or {}
            save_dir = options.get('save_directory', 'photos/realsense')
            create_thumbnail = options.get('create_thumbnail', True)
            
            # Sicherstellen, dass der Speicherordner existiert
            os.makedirs(save_dir, exist_ok=True)
            
            # Definiere den Dateipfad für die Aufnahme
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            filename = f"realsense_{timestamp}.jpg"
            filepath = os.path.join(save_dir, filename)
            
            # Warte auf einen Frame (mehrere Versuche)
            frames = None
            for attempt in range(5):
                try:
                    frames = self.pipeline.wait_for_frames(timeout_ms=5000)
                    if frames:
                        break
                except:
                    time.sleep(0.5)
            
            if not frames:
                return {'success': False, 'error': "Konnte keinen Frame abrufen"}
            
            # Hole den Farbframe
            color_frame = frames.get_color_frame()
            if not color_frame:
                return {'success': False, 'error': "Kein Farbframe verfügbar"}
            
            # Konvertiere zu Numpy-Array für OpenCV
            if OPENCV_AVAILABLE:
                import numpy as np
                color_image = np.asanyarray(color_frame.get_data())
                
                # Speichere das Bild
                cv2.imwrite(filepath, color_image)
                
                # Erstelle Thumbnail, wenn gewünscht
                thumbnail_path = None
                if create_thumbnail:
                    thumbnail_dir = os.path.join(save_dir, 'thumbnails')
                    os.makedirs(thumbnail_dir, exist_ok=True)
                    thumbnail_file = f"thumb_{timestamp}.jpg"
                    thumbnail_path = os.path.join(thumbnail_dir, thumbnail_file)
                    
                    # Thumbnail erstellen (max. 320x240)
                    thumbnail_size = (320, 240)
                    height, width = color_image.shape[:2]
                    
                    # Berechne Skalierungsfaktoren
                    scale_width = thumbnail_size[0] / width
                    scale_height = thumbnail_size[1] / height
                    scale = min(scale_width, scale_height)
                    
                    # Berechne neue Größe
                    new_width = int(width * scale)
                    new_height = int(height * scale)
                    
                    # Skaliere das Bild
                    thumbnail = cv2.resize(color_image, (new_width, new_height))
                    cv2.imwrite(thumbnail_path, thumbnail)
                
                return {
                    'success': True,
                    'filepath': filepath,
                    'filename': filename,
                    'thumbnail': thumbnail_path
                }
            else:
                return {'success': False, 'error': "OpenCV wird benötigt, um das Bild zu speichern"}
            
        except Exception as e:
            manage_logging.error(f"Fehler bei Bildaufnahme mit Tiefensensor {self.name}: {str(e)}", 
                               exception=e, source="manage_camera")
            return {'success': False, 'error': str(e)}
    
    def get_preview(self) -> Dict:
        """Ruft ein Vorschaubild von der Kamera ab
        
        Returns:
            Dict mit Ergebnisinformationen (success, image_data, etc.)
        """
        if not REALSENSE_AVAILABLE:
            return {'success': False, 'error': "RealSense-Bibliothek nicht verfügbar"}
            
        if not self.connected or not self.pipeline:
            success = self.connect()
            if not success:
                return {'success': False, 'error': "Kamera nicht verbunden"}
        
        try:
            # Warte auf einen Frame
            frames = self.pipeline.wait_for_frames(timeout_ms=5000)
            
            # Hole den Farbframe
            color_frame = frames.get_color_frame()
            if not color_frame:
                return {'success': False, 'error': "Kein Farbframe verfügbar"}
            
            # Konvertiere zu Numpy-Array für OpenCV
            if OPENCV_AVAILABLE:
                import numpy as np
                color_image = np.asanyarray(color_frame.get_data())
                
                # Größe anpassen, falls nötig
                preview_width = self.settings.get('preview', {}).get('width', 640)
                preview_height = self.settings.get('preview', {}).get('height', 360)
                
                height, width = color_image.shape[:2]
                if width > preview_width or height > preview_height:
                    # Berechne Skalierungsfaktoren
                    scale_width = preview_width / width
                    scale_height = preview_height / height
                    scale = min(scale_width, scale_height)
                    
                    # Berechne neue Größe
                    new_width = int(width * scale)
                    new_height = int(height * scale)
                    
                    # Skaliere das Bild
                    color_image = cv2.resize(color_image, (new_width, new_height))
                
                # Konvertiere zu JPEG
                _, buffer = cv2.imencode('.jpg', color_image)
                
                return {
                    'success': True,
                    'image_data': buffer.tobytes(),
                    'content_type': 'image/jpeg'
                }
            else:
                return {'success': False, 'error': "OpenCV wird benötigt, um das Bild zu verarbeiten"}
                
        except Exception as e:
            manage_logging.error(f"Fehler beim Abrufen des Vorschaubildes: {str(e)}", 
                               exception=e, source="manage_camera")
            return {'success': False, 'error': str(e)}
    
    def _apply_advanced_settings(self):
        """Wendet fortgeschrittene Kameraeinstellungen an"""
        if not self.connected or not self.pipeline or not self.advanced_settings:
            return
            
        try:
            # Hole das erste Gerät
            device = self.pipeline.get_active_profile().get_device()
            
            # Durchlaufe alle verfügbaren Sensoren
            depth_sensor = None
            for sensor in device.query_sensors():
                if sensor.get_info(rs.camera_info.name) == 'Stereo Module' or 'Depth' in sensor.get_info(rs.camera_info.name):
                    depth_sensor = sensor
                    break
            
            if not depth_sensor:
                return
                
            # Wende die Einstellungen an
            if 'laser_power' in self.advanced_settings:
                laser_power = self.advanced_settings['laser_power']
                if isinstance(laser_power, (int, float)) and 0 <= laser_power <= 100:
                    option = depth_sensor.get_option(rs.option.laser_power)
                    option_range = option.get_range()
                    value = option_range.min + (option_range.max - option_range.min) * (laser_power / 100.0)
                    depth_sensor.set_option(rs.option.laser_power, value)
            
            if 'emitter_enabled' in self.advanced_settings:
                emitter_enabled = self.advanced_settings['emitter_enabled']
                depth_sensor.set_option(rs.option.emitter_enabled, 1 if emitter_enabled else 0)
            
            if 'depth_units' in self.advanced_settings:
                depth_units = self.advanced_settings['depth_units']
                if isinstance(depth_units, (int, float)):
                    depth_sensor.set_option(rs.option.depth_units, depth_units)
                    
            manage_logging.debug(f"Fortgeschrittene Einstellungen auf Tiefensensor angewendet: {self.name}", 
                           source="manage_camera")
                
        except Exception as e:
            manage_logging.error(f"Fehler beim Anwenden fortgeschrittener Tiefensensor-Einstellungen: {str(e)}", 
                             exception=e, source="manage_camera")
    
    def to_dict(self) -> Dict:
        """Konvertiert die Kamera in ein Dictionary
        
        Returns:
            Dict mit Kamerainformationen
        """
        return {
            'id': f"realsense_{self.serial_number}",
            'name': self.name,
            'serial_number': self.serial_number,
            'type': self.type,
            'interface': self.interface,
            'connected': self.connected,
            'settings': self.settings,
            'config_id': self.config_id
        }

# Haupt-API-Funktionen für die Kameraverwaltung
def initialize() -> bool:
    """Initialisiert das Kameramodul
    
    Returns:
        bool: True wenn erfolgreich, False sonst
    """
    global _cameras, _active_camera
    
    manage_logging.log("Initialisiere Kameramodul", source="manage_camera")
    
    # Setze globale Variablen zurück
    _cameras = {}
    _active_camera = None
    
    # Protokolliere die Verfügbarkeit von Kamera-Bibliotheken
    supported_types = []
    if OPENCV_AVAILABLE:
        supported_types.append("Webcams")
    if GPHOTO2_AVAILABLE:
        supported_types.append("DSLR/DSLM-Kameras")
    if REALSENSE_AVAILABLE:
        supported_types.append("Intel RealSense Tiefensensoren")
    
    if supported_types:
        manage_logging.log(f"Unterstützte Kameratypen: {', '.join(supported_types)}", source="manage_camera")
    
    # Prüfe, ob OpenCV verfügbar ist, wird für die meisten Kameras benötigt
    if not OPENCV_AVAILABLE:
        manage_logging.error("Kameramodul kann nicht initialisiert werden: OpenCV fehlt", source="manage_camera")
        return False
    
    # Stelle sicher, dass das Konfigurationsmodul initialisiert ist
    if not manage_camera_config.initialize():
        manage_logging.warn("Kamera-Konfigurationen konnten nicht vollständig geladen werden", source="manage_camera")
    
    # Versuche, verfügbare Kameras zu erkennen
    try:
        detect_cameras()
        
        # Prüfe, ob eine aktive Konfiguration vorhanden ist und versuche, die entsprechende Kamera zu verwenden
        active_config = manage_camera_config.get_active_config()
        if active_config:
            manage_logging.log(f"Verwende Kamera-Konfiguration: {active_config.get('name')}", source="manage_camera")
            # Hier könnte zusätzliche Logik zur Kamera-Initialisierung basierend auf der Konfiguration hinzugefügt werden
        
        return True
    except Exception as e:
        manage_logging.error(f"Fehler bei Kameramodul-Initialisierung: {str(e)}", exception=e, source="manage_camera")
        return False

def detect_cameras() -> List[Dict]:
    """Erkennt verfügbare Kameras basierend auf den Kamera-Konfigurationen
    
    Returns:
        Liste mit erkannten Kameras als Dicts
    """
    global _cameras
    
    manage_logging.log("Suche nach verfügbaren Kameras", source="manage_camera")
    
    # Leere aktuelle Kameraliste
    _cameras = {}
    found_cameras = []
    
    # Lade verfügbare Kamera-Konfigurationen
    configs = manage_camera_config.get_camera_configs()
    active_config = manage_camera_config.get_active_config()
      # Webcams mit OpenCV erkennen
    if OPENCV_AVAILABLE:
        # Auf Windows/macOS: Überprüfe die ersten 10 möglichen Kameraindizes
        # Auf Linux könnten dies /dev/video0, /dev/video1, etc. sein
        max_cameras = 10
        
        webcam_configs = [cfg for cfg in configs if cfg.get('type') in ['webcam', 'depth_sensor']]
        
        for i in range(max_cameras):
            try:
                cap = cv2.VideoCapture(i)
                if cap.isOpened():
                    # Kamera existiert - hole weitere Informationen
                    vendor = ""
                    model = ""
                    product = ""
                    
                    # Versuche, Herstellerinformationen zu lesen
                    # Dies funktioniert möglicherweise nicht auf allen Systemen
                    try:
                        vendor = cap.get(cv2.CAP_PROP_BACKEND_NAME) or ""
                    except:
                        pass
                        
                    # Auf Linux können wir versuchen, mehr Informationen aus udev zu lesen
                    if sys.platform.startswith('linux'):
                        try:
                            import subprocess
                            result = subprocess.run(['v4l2-ctl', '--device', f'/dev/video{i}', '--info'], 
                                                  stdout=subprocess.PIPE, text=True)
                            info = result.stdout
                            
                            # Parse die Ausgabe für Kameradetails
                            import re
                            vendor_match = re.search(r'Card Type:\s+(.+)', info)
                            if vendor_match:
                                vendor = vendor_match.group(1).strip()
                                
                            model_match = re.search(r'driver name\s+:\s+(.+)', info)
                            if model_match:
                                model = model_match.group(1).strip()
                                
                        except Exception as e:
                            manage_logging.debug(f"Konnte keine erweiterten Kamera-Informationen abrufen: {str(e)}", 
                                              source="manage_camera")
                    
                    # Sofort freigeben
                    cap.release()
                    
                    # Erstelle eine Webcam-Instanz
                    cam_id = f"webcam_{i}"
                    
                    # Kamera-Informationen für Konfigurationsabgleich vorbereiten
                    camera_info = {
                        'index': i,
                        'vendor': vendor,
                        'model': model,
                        'product': model,  # Verwende Modell auch als Produkt-Bezeichnung
                        'type': 'webcam'
                    }
                      # Versuche, eine passende Konfiguration zu finden
                    config_id = detect_camera_model(camera_info)
                    camera_config = None
                    camera_name = f"Webcam {i}"
                    
                    # Wenn eine passende Konfiguration gefunden wurde
                    if config_id:
                        camera_config = manage_camera_config.get_config(config_id)
                        if camera_config and 'name' in camera_config:
                            camera_name = camera_config['name']
                    
                    # Falls keine spezifische Konfiguration gefunden wurde, prüfe auf aktive Konfiguration
                    if not camera_config and active_config and active_config.get('type') in ['webcam', 'depth_sensor']:
                        camera_config = active_config
                    
                    # Erstelle eine Webcam-Instanz mit der Konfiguration
                    camera = WebcamCamera(i, camera_name)
                    
                    # Wenn eine Konfiguration vorhanden ist, wende sie an
                    if camera_config:
                        # Setze die konfigurierten Einstellungen
                        if 'settings' in camera_config:
                            camera.settings.update(camera_config['settings'])
                            manage_logging.debug(f"Kamera-Konfiguration angewendet: {camera_config.get('name')}", 
                                               source="manage_camera")
                    
                    # Füge zur Kameraliste hinzu
                    _cameras[cam_id] = camera
                    found_cameras.append(camera.to_dict())
                    
                    manage_logging.log(f"Webcam gefunden: {camera_name} (Index {i})", source="manage_camera")
            except Exception as e:
                manage_logging.error(f"Fehler bei Kameraerkennung für Index {i}: {str(e)}", 
                                   exception=e, source="manage_camera")
      # DSLR-Kameras mit gPhoto2 erkennen
    if GPHOTO2_AVAILABLE:
        try:
            context = gp.Context()
            camera_list = gp.Camera.autodetect(context)
            
            # Suche nach DSLR/DSLM-Konfigurationen
            dslr_configs = [cfg for cfg in configs if cfg.get('type') in ['dslr', 'dslm']]
            
            for i, (name, addr) in enumerate(camera_list):
                cam_id = f"dslr_{i}"
                  # Kamera-Informationen für Konfigurationsabgleich vorbereiten
                # Parse den Namen der Kamera, um Hersteller und Modell zu extrahieren
                # Format ist typischerweise "Hersteller Modell"
                parts = name.split(' ', 1)
                vendor = parts[0] if parts else ""
                model = parts[1] if len(parts) > 1 else ""
                
                camera_info = {
                    'vendor': vendor,
                    'model': model,
                    'product': name,
                    'type': 'dslr',
                    'address': addr
                }
                
                # Versuche, eine passende Konfiguration zu finden
                config_id = detect_camera_model(camera_info)
                camera_config = None
                camera_name = name
                
                # Wenn eine passende Konfiguration gefunden wurde
                if config_id:
                    camera_config = manage_camera_config.get_config(config_id)
                    if camera_config and 'name' in camera_config:
                        camera_name = camera_config['name']
                
                # Falls keine spezifische Konfiguration gefunden wurde, prüfe auf aktive Konfiguration
                if not camera_config and active_config and active_config.get('type') in ['dslr', 'dslm']:
                    camera_config = active_config
                
                # Erstelle und konfiguriere die DSLR-Kamera mit unserer neuen Klasse
                camera = DSLRCamera(camera_name, addr, camera_config)
                
                # DSLR-Kamera zur Liste hinzufügen
                _cameras[cam_id] = camera
                
                manage_logging.log(f"DSLR-Kamera gefunden: {camera_name} (Adresse: {addr})", source="manage_camera")
                
                if camera_config:
                    manage_logging.log(f"Konfiguration für DSLR angewendet: {camera_config.get('name')}", 
                                     source="manage_camera")
                
                # Füge die Kamera als Dict zur Liste der gefundenen Kameras hinzu
                found_cameras.append(camera.to_dict())
        except Exception as e:
            manage_logging.error(f"Fehler bei DSLR-Kameraerkennung: {str(e)}", exception=e, source="manage_camera")
    
    # RealSense-Kameras erkennen, wenn die Bibliothek verfügbar ist
    if REALSENSE_AVAILABLE:
        try:
            # Erstelle einen Kontext für RealSense
            context = rs.context()
            
            # Erhalte eine Liste aller verfügbaren RealSense-Geräte
            realsense_devices = context.query_devices()
            
            # Suche nach Tiefensensor-Konfigurationen
            depth_configs = [cfg for cfg in configs if cfg.get('type') == 'depth_sensor']
            
            for i in range(realsense_devices.size()):
                # Hole gerätespezifische Informationen
                device = realsense_devices.get_device(i)
                name = device.get_info(rs.camera_info.name) or "Intel RealSense"
                serial = device.get_info(rs.camera_info.serial_number) or f"rs{i}"
                model = device.get_info(rs.camera_info.product_id) or ""
                
                # Erstelle einen eindeutigen Bezeichner für diese Kamera
                cam_id = f"realsense_{serial}"
                
                # Kamera-Informationen für Konfigurationsabgleich vorbereiten
                camera_info = {
                    'vendor': 'Intel',
                    'model': model,
                    'product': name,
                    'type': 'depth_sensor',
                    'serial_number': serial
                }
                
                # Versuche, eine passende Konfiguration zu finden
                config_id = detect_camera_model(camera_info)
                camera_config = None
                camera_name = f"{name} ({serial})"
                
                # Wenn eine passende Konfiguration gefunden wurde
                if config_id:
                    camera_config = manage_camera_config.get_config(config_id)
                    if camera_config and 'name' in camera_config:
                        camera_name = camera_config['name']
                
                # Falls keine spezifische Konfiguration gefunden wurde, prüfe auf aktive Konfiguration
                if not camera_config and active_config and active_config.get('type') == 'depth_sensor':
                    camera_config = active_config
                
                # Erstelle und konfiguriere die RealSense-Kamera
                camera = DepthSensorCamera(camera_name, serial, camera_config)
                
                # Füge zur Kameraliste hinzu
                _cameras[cam_id] = camera
                found_cameras.append(camera.to_dict())
                
                manage_logging.log(f"Intel RealSense Tiefensensor gefunden: {camera_name} (Seriennr: {serial})", 
                                 source="manage_camera")
                
        except Exception as e:
            manage_logging.error(f"Fehler bei RealSense-Kameraerkennung: {str(e)}", 
                               exception=e, source="manage_camera")
    
    if not found_cameras:
        manage_logging.warn("Keine Kameras erkannt", source="manage_camera")
    
    return found_cameras

def get_camera_list() -> List[Dict]:
    """Gibt eine Liste aller verfügbaren Kameras zurück
    
    Returns:
        Liste mit Kamera-Dicts
    """
    global _cameras
    
    # Wenn noch keine Kameras erkannt wurden, führe eine Erkennung durch
    if not _cameras:
        detect_cameras()
        
    return [cam.to_dict() for cam in _cameras.values()]

def connect_camera(camera_id: str) -> Dict:
    """Verbindet eine Kamera
    
    Args:
        camera_id: ID der zu verbindenden Kamera
        
    Returns:
        Dict mit Status und Kamerainformationen
    """
    global _cameras, _active_camera
    
    if camera_id not in _cameras:
        return {'success': False, 'error': f"Kamera mit ID {camera_id} nicht gefunden"}
        
    camera = _cameras[camera_id]
    success = camera.connect()
    
    if success:
        _active_camera = camera
        return {'success': True, 'camera': camera.to_dict()}
    else:
        return {'success': False, 'error': camera.last_error or "Unbekannter Fehler"}

def disconnect_camera(camera_id: str = None) -> Dict:
    """Trennt die Verbindung zu einer Kamera
    
    Args:
        camera_id: ID der zu trennenden Kamera oder None für die aktive Kamera
        
    Returns:
        Dict mit Status
    """
    global _cameras, _active_camera, _preview_running
    
    # Wenn ein Vorschau-Stream läuft, stoppe ihn
    if _preview_running:
        stop_preview()
    
    # Wenn keine ID angegeben wurde, verwende die aktive Kamera
    if camera_id is None:
        if _active_camera is None:
            return {'success': False, 'error': "Keine aktive Kamera"}
        camera = _active_camera
    elif camera_id in _cameras:
        camera = _cameras[camera_id]
    else:
        return {'success': False, 'error': f"Kamera mit ID {camera_id} nicht gefunden"}
    
    success = camera.disconnect()
    
    if success:
        if camera == _active_camera:
            _active_camera = None
        return {'success': True}
    else:
        return {'success': False, 'error': camera.last_error or "Unbekannter Fehler"}

def capture_image(options: Dict = None) -> Dict:
    """Nimmt ein Bild mit der aktiven Kamera auf
    
    Args:
        options: Optionen für die Aufnahme
        
    Returns:
        Dict mit Status und ggf. Dateipfad
    """
    global _active_camera
    
    if _active_camera is None:
        return {'success': False, 'error': "Keine aktive Kamera"}
        
    if not _active_camera.connected:
        return {'success': False, 'error': "Kamera nicht verbunden"}
    
    # Standardwerte für Optionen
    if options is None:
        options = {}
        
    return _active_camera.capture(options)

def get_camera_settings() -> Dict:
    """Gibt die Einstellungen der aktiven Kamera zurück
    
    Returns:
        Dict mit Kameraeinstellungen oder Fehlerstatus
    """
    global _active_camera
    
    if _active_camera is None:
        return {'success': False, 'error': "Keine aktive Kamera"}
        
    if not _active_camera.connected:
        return {'success': False, 'error': "Kamera nicht verbunden"}
        
    return {
        'success': True, 
        'settings': _active_camera.get_settings()
    }

def update_camera_settings(settings: Dict) -> Dict:
    """Aktualisiert die Einstellungen der aktiven Kamera
    
    Args:
        settings: Zu aktualisierende Einstellungen
        
    Returns:
        Dict mit Status
    """
    global _active_camera
    
    if _active_camera is None:
        return {'success': False, 'error': "Keine aktive Kamera"}
        
    if not _active_camera.connected:
        return {'success': False, 'error': "Kamera nicht verbunden"}
        
    success = _active_camera.update_settings(settings)
    
    if success:
        return {'success': True}
    else:
        return {'success': False, 'error': _active_camera.last_error or "Unbekannter Fehler"}

def get_active_camera() -> Optional[Dict]:
    """Gibt Informationen über die aktive Kamera zurück
    
    Returns:
        Dict mit Kamerainformationen oder None
    """
    global _active_camera
    
    if _active_camera is None:
        return None
        
    return _active_camera.to_dict()

def get_preview_frame() -> Optional[bytes]:
    """Gibt ein einzelnes Vorschaubild der aktiven Kamera zurück
    
    Returns:
        bytes: JPEG-Bilddaten oder None bei Fehler
    """
    global _active_camera
    
    if _active_camera is None or not _active_camera.connected:
        return None
        
    return _active_camera.get_preview_frame()

def stop_preview() -> bool:
    """Stoppt den Vorschau-Stream
    
    Returns:
        bool: True wenn erfolgreich, False sonst
    """
    global _preview_thread, _preview_running
    
    try:
        if _preview_thread and _preview_running:
            _preview_running = False
            _preview_thread.join(timeout=1.0)
            _preview_thread = None
            manage_logging.log("Kamera-Vorschau gestoppt", source="manage_camera")
        return True
    except Exception as e:
        manage_logging.error(f"Fehler beim Stoppen der Kamera-Vorschau: {str(e)}", 
                           exception=e, source="manage_camera")
        return False

def detect_camera_model(camera_info: Dict) -> Optional[str]:
    """
    Erkennt das Kameramodell und gibt die passende Konfiguration zurück.
    
    Args:
        camera_info: Informationen über die Kamera (Hersteller, Modell, etc.)
    
    Returns:
        config_id: ID der passenden Kamera-Konfiguration oder None, wenn keine übereinstimmt
    """
    # Kamera-Konfigurationen abrufen
    configs = manage_camera_config.get_camera_configs()
    
    manage_logging.debug(f"Prüfe Kamera-Konfigurationen für: {camera_info}", source="manage_camera")
    
    # Extrahiere relevante Informationen aus camera_info
    camera_vendor = camera_info.get('vendor', '').lower()
    camera_model = camera_info.get('model', '').lower()
    camera_product = camera_info.get('product', '').lower()
    camera_type = camera_info.get('type', 'unknown').lower()
    
    # Durchlaufe alle Konfigurationen und prüfe auf Übereinstimmung
    for config in configs:
        config_id = config.get('id')
        if not config_id:
            continue
        
        # Lade die vollständige Konfiguration
        config_data = manage_camera_config.get_config(config_id)
        if not config_data:
            continue
              # Extrahiere die Erkennungsmethode und Parameter
        detection = config_data.get('detection', {})
        method = detection.get('method', '')
        config_type = config_data.get('type', 'unknown')
        
        # Überprüfe, ob der Kameratyp unterstützt wird (notwendige Bibliotheken verfügbar)
        if not camera_type_supported(config_type):
            continue
        
        # Prüfe nach unterschiedlichen Erkennungsmethoden
        match = False
        
        if method == 'vendor_product':
            # Überprüfe Hersteller und Produkt
            vendor_match = detection.get('vendor', '').lower() in camera_vendor
            product_match = detection.get('product', '').lower() in camera_product
            
            if vendor_match and product_match:
                match = True
                
        elif method == 'brand_model':
            # Überprüfe Marke und Modell
            brand = detection.get('brand', '').lower()
            model = detection.get('model', '').lower()
            
            # Unterstütze Wildcards in der Modellbezeichnung
            if '*' in model:
                model_prefix = model.replace('*', '').lower()
                if brand in camera_vendor and model_prefix in camera_model:
                    match = True
            elif brand in camera_vendor and model in camera_model:
                match = True
                
        elif method == 'auto':
            # Einfache Erkennung basierend auf dem Kameraindex
            # Bei auto-Methode immer übereinstimmen, aber mit niedriger Priorität
            match = True
        
        # Wenn eine Übereinstimmung gefunden wurde, gib die Konfigurations-ID zurück
        if match:
            manage_logging.log(f"Kamera-Konfiguration gefunden: {config_id}", source="manage_camera")
            return config_id
    
    # Keine übereinstimmende Konfiguration gefunden
    manage_logging.log("Keine passende Kamera-Konfiguration gefunden", source="manage_camera")
    return None

def camera_type_supported(camera_type: str) -> bool:
    """Überprüft, ob die notwendigen Bibliotheken für den angegebenen Kameratyp verfügbar sind
    
    Args:
        camera_type: Typ der Kamera ('webcam', 'dslr', 'depth_sensor', etc.)
        
    Returns:
        bool: True wenn unterstützt, False sonst
    """
    if camera_type == 'webcam':
        return OPENCV_AVAILABLE
    elif camera_type in ['dslr', 'dslm']:
        return GPHOTO2_AVAILABLE
    elif camera_type == 'depth_sensor':
        return REALSENSE_AVAILABLE
    else:
        # Unbekannter Kameratyp
        return False

# API-Endpunkte werden in einer separaten Blueprint-Datei implementiert
# Diese würde manage_camera importieren und die entsprechenden Funktionen aufrufen

# Aufräumfunktion
def cleanup():
    """Räumt die Kameraressourcen auf"""
    global _cameras, _active_camera, _preview_running
    
    # Stoppe Preview, falls aktiv
    if _preview_running:
        stop_preview()
    
    # Trenne alle verbundenen Kameras
    for camera_id, camera in _cameras.items():
        if camera.connected:
            camera.disconnect()
    
    _cameras = {}
    _active_camera = None
    
    manage_logging.log("Kameramodul aufgeräumt", source="manage_camera")

# Initialisiere das Modul beim Import
try:
    initialize()
except Exception as e:
    manage_logging.error(f"Fehler bei Kameramodul-Initialisierung: {str(e)}", exception=e, source="manage_camera")
