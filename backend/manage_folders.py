#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# manage_folders.py
# ------------------------------------------------------------------------------
# Funktion: Python-Wrapper für die zentrale Ordnerverwaltung (manage_folders.sh)
# Erlaubt Python-Modulen den einheitlichen Zugriff auf die Ordnerstruktur.
# ------------------------------------------------------------------------------
"""
Modul zur Verwaltung der Fotobox-Ordnerstruktur.

Dieses Modul stellt Funktionen zum Zugriff auf die Ordnerstruktur der Fotobox bereit.
Es dient als Python-Wrapper für die Shell-Implementierung (manage_folders.sh) und
bietet einen einheitlichen Zugriff auf Verzeichnispfade in der gesamten Anwendung.
"""

import os
import subprocess
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Globale Instanz des FolderManagers für die Zugangsfunktionen
_FOLDER_MANAGER = None

def _get_folder_manager():
    """Liefert eine singleton Instanz des FolderManagers"""
    # pylint: disable=global-statement
    global _FOLDER_MANAGER
    if _FOLDER_MANAGER is None:
        _FOLDER_MANAGER = FolderManager()
    return _FOLDER_MANAGER

# Globale Funktionen für den einfachen Import in anderen Modulen
def get_install_dir() -> str:
    """Gibt den Pfad zum Installationsverzeichnis zurück"""
    return _get_folder_manager().get_install_dir()

def get_data_dir() -> str:
    """Gibt den Pfad zum Datenverzeichnis zurück"""
    return _get_folder_manager().get_data_dir()

def get_backup_dir() -> str:
    """Gibt den Pfad zum Backup-Verzeichnis zurück"""
    return _get_folder_manager().get_backup_dir()

def get_log_dir() -> str:
    """Gibt den Pfad zum Log-Verzeichnis zurück"""
    return _get_folder_manager().get_log_dir()

def get_frontend_dir() -> str:
    """Gibt den Pfad zum Frontend-Verzeichnis zurück"""
    return _get_folder_manager().get_frontend_dir()

def get_config_dir() -> str:
    """Gibt den Pfad zum Konfigurationsverzeichnis zurück"""
    return _get_folder_manager().get_config_dir()

def get_camera_conf_dir() -> str:
    """Gibt den Pfad zum Kamera-Konfigurationsverzeichnis zurück"""
    return _get_folder_manager().get_camera_conf_dir()

def get_photos_dir() -> str:
    """Gibt den Pfad zum Fotos-Verzeichnis zurück"""
    return _get_folder_manager().get_photos_dir()

def get_photos_originals_dir(event_name: Optional[str] = None) -> str:
    """Gibt den Pfad zum Originalfotos-Verzeichnis zurück"""
    return _get_folder_manager().get_photos_originals_dir(event_name)

def get_photos_gallery_dir(event_name: Optional[str] = None) -> str:
    """Gibt den Pfad zum Galerie-Verzeichnis zurück"""
    return _get_folder_manager().get_photos_gallery_dir(event_name)

def get_frontend_css_dir() -> str:
    """Gibt den Pfad zum Frontend-CSS-Verzeichnis zurück"""
    return _get_folder_manager().get_frontend_css_dir()

def get_frontend_js_dir() -> str:
    """Gibt den Pfad zum Frontend-JavaScript-Verzeichnis zurück"""
    return _get_folder_manager().get_frontend_js_dir()

def get_frontend_fonts_dir() -> str:
    """Gibt den Pfad zum Frontend-Fonts-Verzeichnis zurück"""
    return _get_folder_manager().get_frontend_fonts_dir()

def get_frontend_picture_dir() -> str:
    """Gibt den Pfad zum Frontend-Bilder-Verzeichnis zurück"""
    return _get_folder_manager().get_frontend_picture_dir()

def get_script_dir() -> str:
    """Gibt den Pfad zum Backend-Skript-Verzeichnis zurück"""
    return _get_folder_manager().get_script_dir()

def get_https_conf_dir() -> str:
    """Gibt den Pfad zum HTTPS-Konfigurations-Verzeichnis zurück"""
    return _get_folder_manager().get_https_conf_dir()

def get_https_backup_dir() -> str:
    """Gibt den Pfad zum HTTPS-Backup-Verzeichnis zurück"""
    return _get_folder_manager().get_https_backup_dir()

def ensure_folder_structure() -> bool:
    """
    Stellt sicher, dass die gesamte Ordnerstruktur existiert und
    alle benötigten Verzeichnisse mit korrekten Berechtigungen angelegt sind

    Returns:
        True bei erfolgreicher Erstellung aller Verzeichnisse, False bei einem Fehler

    Notes:
        Verwendet die Shell-Implementierung falls verfügbar,
        mit Python-Fallback wenn die Shell-Skripte nicht erreichbar sind
    """
    return _get_folder_manager().ensure_folder_structure()

class FolderManager:
    """
    Verwaltet die Ordnerstruktur für die Fotobox durch Zugriff auf manage_folders.sh
    """

    def __init__(self):
        """Initialisiert den FolderManager"""
        self._script_path = os.path.join(
            os.path.dirname(__file__), 'scripts', 'manage_folders.sh'
        )

        # Prüfen, ob das Skript existiert und ausführbar ist
        if not os.path.isfile(self._script_path):
            logger.warning("manage_folders.sh nicht gefunden unter %s", self._script_path)
            # Fallback zur alten Struktur (für Abwärtskompatibilität)
            self._script_path = None
        elif not os.access(self._script_path, os.X_OK):
            try:
                os.chmod(self._script_path, 0o755)
            except OSError as e:
                logger.warning("Konnte manage_folders.sh nicht ausführbar machen: %s", e)
                # Skript nicht auf None setzen, damit wir es mit bash aufrufen können

    def _run_command(self, cmd_name: str, cmd_param: Optional[str] = None) -> str:
        """
        Führt einen Befehl in manage_folders.sh aus und gibt die Ausgabe zurück        Args:
            cmd_name: Der auszuführende Befehl
            cmd_param: Optionaler Parameter für den Befehl

        Returns:
            Die Ausgabe des Befehls oder einen Fallback-Pfad bei Fehler
        """
        if not self._script_path:
            # Fallback zur alten Struktur, wenn das Skript nicht verfügbar ist
            return self._get_fallback_path(cmd_name)

        try:
            cmd = ['bash', self._script_path, cmd_name]
            if cmd_param:
                cmd.append(cmd_param)

            result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, universal_newlines=True)
            return result.strip()
        except subprocess.CalledProcessError as e:
            logger.error("Fehler beim Ausführen von %s: %s", cmd_name, e)
            return self._get_fallback_path(cmd_name)
        except OSError as e:
            logger.error("Unerwarteter Fehler: %s", e)
            return self._get_fallback_path(cmd_name)

    def _get_fallback_path(self, cmd_name: str) -> str:
        """
        Liefert einen Fallback-Pfad basierend auf dem angeforderten Befehl

        Args:
            cmd_name: Der angeforderte Befehl

        Returns:
            Ein Fallback-Pfad für den angeforderten Befehl
        """
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        # Mapping von Befehlen zu Fallback-Pfaden
        fallbacks = {
            'install_dir': base_dir,
            'data_dir': os.path.join(base_dir, 'data'),
            'backup_dir': os.path.join(base_dir, 'backup'),
            'log_dir': os.path.join(base_dir, 'log'),
            'frontend_dir': os.path.join(base_dir, 'frontend'),
            'config_dir': os.path.join(base_dir, 'conf'),
            'photos_dir': os.path.join(base_dir, 'frontend', 'photos'),
            'photos_originals_dir': os.path.join(base_dir, 'frontend', 'photos', 'originals'),
            'photos_gallery_dir': os.path.join(base_dir, 'frontend', 'photos', 'gallery'),
            'frontend_css_dir': os.path.join(base_dir, 'frontend', 'css'),
            'frontend_js_dir': os.path.join(base_dir, 'frontend', 'js'),
            'frontend_fonts_dir': os.path.join(base_dir, 'frontend', 'fonts'),
            'frontend_picture_dir': os.path.join(base_dir, 'frontend', 'picture'),
            'script_dir': os.path.join(base_dir, 'backend', 'scripts'),
            'https_conf_dir': os.path.join(base_dir, 'conf', 'https'),
            'https_backup_dir': os.path.join(base_dir, 'backup', 'https'),
        }

        return fallbacks.get(cmd_name, base_dir)

    def ensure_dir(self, path: str) -> bool:
        """
        Stellt sicher, dass ein Verzeichnis existiert

        Args:
            path: Der zu prüfende und ggf. zu erstellende Pfad

        Returns:
            True, wenn das Verzeichnis existiert oder erstellt wurde, sonst False
        """
        try:
            if not os.path.exists(path):
                os.makedirs(path, exist_ok=True)
            return os.path.isdir(path)
        except OSError as e:
            logger.error("Fehler beim Erstellen des Verzeichnisses %s: %s", path, e)
            return False

    def get_install_dir(self) -> str:
        """Gibt den Pfad zum Installationsverzeichnis zurück"""
        path = self._run_command('install_dir')
        self.ensure_dir(path)
        return path

    def get_data_dir(self) -> str:
        """Gibt den Pfad zum Datenverzeichnis zurück"""
        path = self._run_command('data_dir')
        self.ensure_dir(path)
        return path

    def get_backup_dir(self) -> str:
        """Gibt den Pfad zum Backup-Verzeichnis zurück"""
        path = self._run_command('backup_dir')
        self.ensure_dir(path)
        return path

    def get_log_dir(self) -> str:
        """Gibt den Pfad zum Log-Verzeichnis zurück"""
        path = self._run_command('log_dir')
        self.ensure_dir(path)
        return path

    def get_frontend_dir(self) -> str:
        """Gibt den Pfad zum Frontend-Verzeichnis zurück"""
        path = self._run_command('frontend_dir')
        self.ensure_dir(path)
        return path

    def get_config_dir(self) -> str:
        """Gibt den Pfad zum Konfigurationsverzeichnis zurück"""
        path = self._run_command('config_dir')
        self.ensure_dir(path)
        return path

    def get_camera_conf_dir(self) -> str:
        """Gibt den Pfad zum Kamera-Konfigurationsverzeichnis zurück"""
        path = self._run_command('camera_conf_dir')
        self.ensure_dir(path)
        return path

    def get_photos_dir(self) -> str:
        """Gibt den Pfad zum Fotos-Verzeichnis zurück"""
        path = self._run_command('photos_dir')
        self.ensure_dir(path)
        return path

    def get_photos_originals_dir(self, event_name: Optional[str] = None) -> str:
        """
        Gibt den Pfad zum Originalfotos-Verzeichnis zurück

        Args:
            event_name: Optionaler Event-Name für ein Unterverzeichnis

        Returns:
            Pfad zum Originalfotos-Verzeichnis
        """
        if event_name:
            path = self._run_command('photos_originals_dir', event_name)
        else:
            path = self._run_command('photos_originals_dir')
        self.ensure_dir(path)
        return path

    def get_photos_gallery_dir(self, event_name: Optional[str] = None) -> str:
        """
        Gibt den Pfad zum Galerie-Verzeichnis zurück

        Args:
            event_name: Optionaler Event-Name für ein Unterverzeichnis

        Returns:
            Pfad zum Galerie-Verzeichnis
        """
        if event_name:
            path = self._run_command('photos_gallery_dir', event_name)
        else:
            path = self._run_command('photos_gallery_dir')
        self.ensure_dir(path)
        return path

    def get_frontend_css_dir(self) -> str:
        """Gibt den Pfad zum Frontend-CSS-Verzeichnis zurück"""
        path = self._run_command('frontend_css_dir')
        self.ensure_dir(path)
        return path

    def get_frontend_js_dir(self) -> str:
        """Gibt den Pfad zum Frontend-JavaScript-Verzeichnis zurück"""
        path = self._run_command('frontend_js_dir')
        self.ensure_dir(path)
        return path

    def get_frontend_fonts_dir(self) -> str:
        """Gibt den Pfad zum Frontend-Fonts-Verzeichnis zurück"""
        path = self._run_command('frontend_fonts_dir')
        self.ensure_dir(path)
        return path

    def get_frontend_picture_dir(self) -> str:
        """Gibt den Pfad zum Frontend-Bilder-Verzeichnis zurück"""
        path = self._run_command('frontend_picture_dir')
        self.ensure_dir(path)
        return path

    def get_script_dir(self) -> str:
        """Gibt den Pfad zum Backend-Skript-Verzeichnis zurück"""
        path = self._run_command('script_dir')
        self.ensure_dir(path)
        return path

    def get_https_conf_dir(self) -> str:
        """Gibt den Pfad zum HTTPS-Konfigurations-Verzeichnis zurück"""
        path = self._run_command('https_conf_dir')
        self.ensure_dir(path)
        return path

    def get_https_backup_dir(self) -> str:
        """Gibt den Pfad zum HTTPS-Backup-Verzeichnis zurück"""
        path = self._run_command('https_backup_dir')
        self.ensure_dir(path)
        return path

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
