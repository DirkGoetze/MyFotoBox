#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modul zur Verwaltung der Fotobox-Ordnerstruktur.

Dieses Modul stellt Funktionen zum Zugriff auf die Ordnerstruktur der Fotobox bereit.
Es dient als Python-Wrapper für die Shell-Implementierung (manage_folders.sh) und
bietet einen einheitlichen Zugriff auf Verzeichnispfade in der gesamten Anwendung.
"""

import os
import sys
import logging
import subprocess
from typing import Optional, Dict, Any
from pathlib import Path

logger = logging.getLogger(__name__)

class FolderConfigError(Exception):
    """Ausnahme für Fehler bei der Verzeichniskonfiguration"""
    pass

class FolderManager:
    """Verwaltung der Fotobox-Ordnerstruktur"""
    
    def __init__(self):
        self._cache: Dict[str, str] = {}
        self._script_path = self._find_shell_script()
        self._base_dir = self._get_base_dir()
        self._init_base_dirs()
    
    def _find_shell_script(self) -> str:
        """Findet den Pfad zum Shell-Skript"""
        script_name = "manage_folders.sh"
        current_dir = Path(__file__).parent
        script_locations = [
            current_dir / "scripts" / script_name,
            current_dir / ".." / "scripts" / script_name,
            Path("/opt/fotobox/backend/scripts") / script_name
        ]
        
        for location in script_locations:
            if location.is_file():
                logger.debug(f"Shell-Skript gefunden: {location}")
                return str(location)
            else:
                logger.debug(f"Shell-Skript nicht gefunden unter: {location}")
        
        # Wenn wir hier ankommen, wurde kein Skript gefunden
        logger.error(f"Shell-Skript '{script_name}' konnte nicht gefunden werden")
        # Fallback auf Standardpfad
        return "/opt/fotobox/backend/scripts/manage_folders.sh"
    
    def _get_base_dir(self) -> str:
        """Ermittelt das Basis-Installationsverzeichnis"""
        try:
            # Versuche zuerst, das Installationsverzeichnis über das Shell-Skript zu ermitteln
            if os.path.exists(self._script_path):
                result = subprocess.run(
                    [self._script_path, "--get-install-dir"],
                    capture_output=True,
                    text=True,
                    check=True
                )
                if result.returncode == 0 and result.stdout.strip():
                    base_dir = result.stdout.strip()
                    logger.info(f"Basis-Verzeichnis über Shell-Skript ermittelt: {base_dir}")
                    return base_dir
            
            # Wenn das Shell-Skript nicht verfügbar ist oder fehlschlägt,
            # verwende den Standardpfad
            base_dir = "/opt/fotobox"
            logger.warning(f"Verwende Standard-Basis-Verzeichnis: {base_dir}")
            return base_dir
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Fehler beim Ermitteln des Basis-Verzeichnisses: {e}")
            # Fallback zu Standardpfad
            return "/opt/fotobox"
    
    def _init_base_dirs(self) -> None:
        """Initialisiert die Basis-Verzeichnisse"""
        base_dirs = {
            "log": "log",
            "data": "data",
            "config": "conf",
            "frontend": "frontend",
            "backend": "backend",
            "camera_conf": "conf/cameras",
            "photos": "frontend/photos",
            "photos_originals": "frontend/photos/originals",
            "photos_gallery": "frontend/photos/gallery",
            "frontend_css": "frontend/css",
            "frontend_js": "frontend/js",
            "frontend_fonts": "frontend/fonts",
            "frontend_picture": "frontend/picture",
            "script": "backend/scripts",
            "https_conf": "conf/https",
            "https_backup": "backup/https"
        }
        
        for key, path in base_dirs.items():
            full_path = os.path.join(self._base_dir, path)
            try:
                # Versuche zuerst, den Pfad über das Shell-Skript zu erstellen
                if os.path.exists(self._script_path):
                    result = subprocess.run(
                        [self._script_path, f"--create-{key}-dir"],
                        capture_output=True,
                        text=True
                    )
                    if result.returncode == 0:
                        actual_path = result.stdout.strip()
                        if actual_path and os.path.exists(actual_path):
                            self._cache[key] = actual_path
                            logger.debug(f"Verzeichnis über Shell-Skript erstellt: {actual_path}")
                            continue
                
                # Wenn das Shell-Skript nicht verfügbar ist oder fehlschlägt,
                # erstelle das Verzeichnis direkt
                os.makedirs(full_path, exist_ok=True)
                # Setze Berechtigungen (aus lib_core.sh)
                os.chmod(full_path, 0o755)  # Entspricht DEFAULT_MODE_FOLDER
                self._cache[key] = full_path
                logger.debug(f"Verzeichnis direkt erstellt: {full_path}")
                
            except OSError as e:
                logger.error(f"Fehler beim Erstellen des Verzeichnisses {full_path}: {e}")
                raise FolderConfigError(f"Konnte Verzeichnis {key} nicht initialisieren") from e
    
    def _get_path(self, key: str, create: bool = True) -> str:
        """Generische Methode zum Abrufen und Cachen von Verzeichnispfaden"""
        if key not in self._cache:
            try:
                # Versuche zuerst den Pfad über das Shell-Skript zu bekommen
                if os.path.exists(self._script_path):
                    result = subprocess.run(
                        [self._script_path, f"--get-{key}-dir"],
                        capture_output=True,
                        text=True,
                        check=True
                    )
                    if result.returncode == 0 and result.stdout.strip():
                        path = result.stdout.strip()
                        if create:
                            os.makedirs(path, exist_ok=True)
                        self._cache[key] = path
                        return path
                
                # Wenn das Shell-Skript nicht verfügbar ist, verwende die Standard-Struktur
                base_path = os.path.join(self._base_dir, key.replace('_', '/'))
                if create:
                    os.makedirs(base_path, exist_ok=True)
                self._cache[key] = base_path
                
            except (subprocess.CalledProcessError, OSError) as e:
                logger.error(f"Fehler beim Abrufen/Erstellen des Pfads für {key}: {e}")
                raise FolderConfigError(f"Konnte Pfad für {key} nicht ermitteln")
        
        return self._cache[key]

    def get_install_dir(self) -> str:
        """Gibt den Pfad zum Installationsverzeichnis zurück"""
        return self._base_dir

    def get_data_dir(self) -> str:
        """Gibt den Pfad zum Datenverzeichnis zurück"""
        return self._get_path("data")

    def get_backup_dir(self) -> str:
        """Gibt den Pfad zum Backup-Verzeichnis zurück"""
        return self._get_path("backup")

    def get_log_dir(self) -> str:
        """Gibt den Pfad zum Log-Verzeichnis zurück"""
        return self._get_path("log")

    def get_frontend_dir(self) -> str:
        """Gibt den Pfad zum Frontend-Verzeichnis zurück"""
        return self._get_path("frontend")

    def get_config_dir(self) -> str:
        """Gibt den Pfad zum Konfigurationsverzeichnis zurück"""
        return self._get_path("config")

    def get_camera_conf_dir(self) -> str:
        """Gibt den Pfad zum Kamera-Konfigurationsverzeichnis zurück"""
        return self._get_path("camera_conf")

    def get_photos_dir(self) -> str:
        """Gibt den Pfad zum Fotos-Verzeichnis zurück"""
        return self._get_path("photos")

    def get_photos_originals_dir(self, event_name: Optional[str] = None) -> str:
        """
        Gibt den Pfad zum Originalfotos-Verzeichnis zurück

        Args:
            event_name: Optionaler Event-Name für ein Unterverzeichnis

        Returns:
            Pfad zum Originalfotos-Verzeichnis
        """
        key = "photos_originals"
        base_path = self._get_path(key)
        
        if event_name:
            # Bereinige den Event-Namen für die Verzeichnisnutzung
            clean_name = event_name.strip().replace(' ', '_').lower()
            if not clean_name:
                raise ValueError("Event-Name darf nicht leer sein")
                
            event_path = os.path.join(base_path, clean_name)
            os.makedirs(event_path, exist_ok=True)
            return event_path
            
        return base_path

    def get_photos_gallery_dir(self, event_name: Optional[str] = None) -> str:
        """
        Gibt den Pfad zum Galerie-Verzeichnis zurück

        Args:
            event_name: Optionaler Event-Name für ein Unterverzeichnis

        Returns:
            Pfad zum Galerie-Verzeichnis
        """
        key = "photos_gallery"
        base_path = self._get_path(key)
        
        if event_name:
            # Bereinige den Event-Namen für die Verzeichnisnutzung
            clean_name = event_name.strip().replace(' ', '_').lower()
            if not clean_name:
                raise ValueError("Event-Name darf nicht leer sein")
                
            event_path = os.path.join(base_path, clean_name)
            os.makedirs(event_path, exist_ok=True)
            return event_path
            
        return base_path

    def get_frontend_css_dir(self) -> str:
        """Gibt den Pfad zum Frontend-CSS-Verzeichnis zurück"""
        return self._get_path("frontend_css")

    def get_frontend_js_dir(self) -> str:
        """Gibt den Pfad zum Frontend-JavaScript-Verzeichnis zurück"""
        return self._get_path("frontend_js")

    def get_frontend_fonts_dir(self) -> str:
        """Gibt den Pfad zum Frontend-Fonts-Verzeichnis zurück"""
        return self._get_path("frontend_fonts")

    def get_frontend_picture_dir(self) -> str:
        """Gibt den Pfad zum Frontend-Bilder-Verzeichnis zurück"""
        return self._get_path("frontend_picture")

    def get_script_dir(self) -> str:
        """Gibt den Pfad zum Backend-Skript-Verzeichnis zurück"""
        return self._get_path("script")

    def get_https_conf_dir(self) -> str:
        """Gibt den Pfad zum HTTPS-Konfigurations-Verzeichnis zurück"""
        return self._get_path("https_conf")

    def get_https_backup_dir(self) -> str:
        """Gibt den Pfad zum HTTPS-Backup-Verzeichnis zurück"""
        return self._get_path("https_backup")

    def ensure_folder_structure(self) -> bool:
        """
        Stellt sicher, dass die gesamte Ordnerstruktur existiert und
        alle benötigten Verzeichnisse mit korrekten Berechtigungen angelegt sind

        Returns:
            True bei erfolgreicher Erstellung aller Verzeichnisse, False bei einem Fehler

        Notes:
            Verwendet die Shell-Implementierung falls verfügbar,
            mit Python-Fallback wenn die Shell-Skripte nicht erreichbar sind
        """
        if not self._script_path:
            # Manuelles Erstellen der Struktur, wenn das Skript nicht verfügbar ist
            try:
                # Hauptverzeichnisse
                self.ensure_dir(self.get_install_dir())
                self.ensure_dir(self.get_data_dir())
                self.ensure_dir(self.get_backup_dir())
                self.ensure_dir(self.get_log_dir())
                self.ensure_dir(self.get_frontend_dir())
                self.ensure_dir(self.get_config_dir())

                # Photos-Verzeichnisse
                self.ensure_dir(self.get_photos_dir())
                self.ensure_dir(self.get_photos_originals_dir())
                self.ensure_dir(self.get_photos_gallery_dir())

                # Kamera-Verzeichnis
                self.ensure_dir(self.get_camera_conf_dir())
                # Frontend-Unterverzeichnisse
                self.ensure_dir(self.get_frontend_css_dir())
                self.ensure_dir(self.get_frontend_js_dir())
                self.ensure_dir(self.get_frontend_fonts_dir())
                self.ensure_dir(self.get_frontend_picture_dir())
                # Skript-Verzeichnis
                self.ensure_dir(self.get_script_dir())
                # HTTPS-Verzeichnisse
                self.ensure_dir(self.get_https_conf_dir())
                self.ensure_dir(self.get_https_backup_dir())
                return True
            except OSError as e:
                logger.error("Fehler beim Erstellen der Ordnerstruktur: %s", e)
                return False

        try:
            subprocess.run(
                ['bash', self._script_path, 'ensure_structure'],
                check=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE
            )
            return True
        except subprocess.CalledProcessError as e:
            logger.error("Fehler beim Erstellen der Ordnerstruktur: %s", e.stderr.decode())
            return False


if __name__ == "__main__":    # Bei direktem Aufruf des Skripts werden einige Tests durchgeführt
    import sys

    # Einfaches Logging einrichten
    logging.basicConfig(level=logging.INFO)

    if len(sys.argv) > 1:
        # Aufruf mit Parametern
        command = sys.argv[1]
        param = sys.argv[2] if len(sys.argv) > 2 else None

        fm = FolderManager()

        if command == "install_dir":
            print(fm.get_install_dir())
        elif command == "data_dir":
            print(fm.get_data_dir())
        elif command == "backup_dir":
            print(fm.get_backup_dir())
        elif command == "log_dir":
            print(fm.get_log_dir())
        elif command == "frontend_dir":
            print(fm.get_frontend_dir())
        elif command == "config_dir":
            print(fm.get_config_dir())
        elif command == "camera_conf_dir":
            print(fm.get_camera_conf_dir())
        elif command == "photos_dir":
            print(fm.get_photos_dir())
        elif command == "photos_originals_dir":
            print(fm.get_photos_originals_dir(param))
        elif command == "photos_gallery_dir":
            print(fm.get_photos_gallery_dir(param))
        elif command == "ensure_structure":
            if fm.ensure_folder_structure():
                print("Ordnerstruktur erfolgreich erstellt")
            else:
                print("Fehler beim Erstellen der Ordnerstruktur")
                sys.exit(1)
        else:
            print(f"Unbekannter Befehl: {command}")
            sys.exit(1)
    else:
        # Ohne Parameter: Alle Pfade ausgeben
        fm = FolderManager()
        print(f"Install-Verzeichnis:           {fm.get_install_dir()}")
        print(f"Daten-Verzeichnis:             {fm.get_data_dir()}")
        print(f"Backup-Verzeichnis:            {fm.get_backup_dir()}")
        print(f"Log-Verzeichnis:               {fm.get_log_dir()}")
        print(f"Frontend-Verzeichnis:          {fm.get_frontend_dir()}")
        print(f"Config-Verzeichnis:            {fm.get_config_dir()}")
        print(f"Kamera-Config-Verzeichnis:     {fm.get_camera_conf_dir()}")
        print(f"Fotos-Verzeichnis:             {fm.get_photos_dir()}")
        print(f"Fotos-Original-Verzeichnis:    {fm.get_photos_originals_dir()}")
        print(f"Fotos-Galerie-Verzeichnis:     {fm.get_photos_gallery_dir()}")
        print(f"Frontend-CSS-Verzeichnis:      {fm.get_frontend_css_dir()}")
        print(f"Frontend-JS-Verzeichnis:       {fm.get_frontend_js_dir()}")
        print(f"Frontend-Fonts-Verzeichnis:    {fm.get_frontend_fonts_dir()}")
        print(f"Frontend-Bilder-Verzeichnis:   {fm.get_frontend_picture_dir()}")
        print(f"Script-Verzeichnis:            {fm.get_script_dir()}")
        print(f"HTTPS-Konfigurations-Verzeichnis: {fm.get_https_conf_dir()}")
        print(f"HTTPS-Backup-Verzeichnis:      {fm.get_https_backup_dir()}")
