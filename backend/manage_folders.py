#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# manage_folders.py
# ------------------------------------------------------------------------------
# Funktion: Python-Wrapper für die zentrale Ordnerverwaltung (manage_folders.sh)
# Erlaubt Python-Modulen den einheitlichen Zugriff auf die Ordnerstruktur.
# ------------------------------------------------------------------------------

import os
import subprocess
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Globale Instanz des FolderManagers für die Zugangsfunktionen
_folder_manager = None

def _get_folder_manager():
    """Liefert eine singleton Instanz des FolderManagers"""
    global _folder_manager
    if _folder_manager is None:
        _folder_manager = FolderManager()
    return _folder_manager

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

def get_photos_dir() -> str:
    """Gibt den Pfad zum Fotos-Verzeichnis zurück"""
    return _get_folder_manager().get_photos_dir()

def get_photos_originals_dir(event_name: Optional[str] = None) -> str:
    """Gibt den Pfad zum Originalfotos-Verzeichnis zurück"""
    return _get_folder_manager().get_photos_originals_dir(event_name)

def get_photos_gallery_dir(event_name: Optional[str] = None) -> str:
    """Gibt den Pfad zum Galerie-Verzeichnis zurück"""
    return _get_folder_manager().get_photos_gallery_dir(event_name)

def ensure_folder_structure() -> bool:
    """Stellt sicher, dass die gesamte Ordnerstruktur existiert"""
    return _get_folder_manager().ensure_folder_structure()

class FolderManager:
    """
    Verwaltet die Ordnerstruktur für die Fotobox durch Zugriff auf manage_folders.sh
    """
    
    def __init__(self):
        """Initialisiert den FolderManager"""
        self._script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'manage_folders.sh')
        
        # Prüfen, ob das Skript existiert und ausführbar ist
        if not os.path.isfile(self._script_path):
            logger.warning(f"manage_folders.sh nicht gefunden unter {self._script_path}")
            # Fallback zur alten Struktur (für Abwärtskompatibilität)
            self._script_path = None
        elif not os.access(self._script_path, os.X_OK):
            try:
                os.chmod(self._script_path, 0o755)
            except Exception as e:
                logger.warning(f"Konnte manage_folders.sh nicht ausführbar machen: {e}")
                # Wir setzen das Skript nicht auf None, damit wir es trotzdem mit bash aufrufen können

    def _run_command(self, command: str, param: Optional[str] = None) -> str:
        """
        Führt einen Befehl in manage_folders.sh aus und gibt die Ausgabe zurück
        
        Args:
            command: Der auszuführende Befehl
            param: Optionaler Parameter für den Befehl
            
        Returns:
            Die Ausgabe des Befehls oder einen Fallback-Pfad bei Fehler
        """
        if not self._script_path:
            # Fallback zur alten Struktur, wenn das Skript nicht verfügbar ist
            return self._get_fallback_path(command)
            
        try:
            cmd = ['bash', self._script_path, command]
            if param:
                cmd.append(param)
                
            result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, universal_newlines=True)
            return result.strip()
        except subprocess.CalledProcessError as e:
            logger.error(f"Fehler beim Ausführen von {command}: {e}")
            return self._get_fallback_path(command)
        except Exception as e:
            logger.error(f"Unerwarteter Fehler: {e}")
            return self._get_fallback_path(command)

    def _get_fallback_path(self, command: str) -> str:
        """
        Liefert einen Fallback-Pfad basierend auf dem angeforderten Befehl
        
        Args:
            command: Der angeforderte Befehl
            
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
        }
        
        return fallbacks.get(command, base_dir)
    
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
        except Exception as e:
            logger.error(f"Fehler beim Erstellen des Verzeichnisses {path}: {e}")
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
            self.ensure_dir(path)
            return path
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
            self.ensure_dir(path)
            return path
        else:
            path = self._run_command('photos_gallery_dir')
            self.ensure_dir(path)
            return path
    
    def ensure_folder_structure(self) -> bool:
        """
        Stellt sicher, dass die gesamte Ordnerstruktur existiert
        
        Returns:
            True bei Erfolg, False bei Fehler
        """
        if not self._script_path:
            # Manuelles Erstellen der Struktur, wenn das Skript nicht verfügbar ist
            try:
                self.ensure_dir(self.get_install_dir())
                self.ensure_dir(self.get_data_dir())
                self.ensure_dir(self.get_backup_dir())
                self.ensure_dir(self.get_log_dir())
                self.ensure_dir(self.get_frontend_dir())
                self.ensure_dir(self.get_config_dir())
                self.ensure_dir(self.get_photos_dir())
                self.ensure_dir(self.get_photos_originals_dir())
                self.ensure_dir(self.get_photos_gallery_dir())
                return True
            except Exception as e:
                logger.error(f"Fehler beim Erstellen der Ordnerstruktur: {e}")
                return False
        
        try:
            result = subprocess.run(['bash', self._script_path, 'ensure_structure'], 
                                    check=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Fehler beim Erstellen der Ordnerstruktur: {e.stderr.decode()}")
            return False


# Die Funktionen im Modul wurden bereits am Anfang der Datei definiert
# Sie rufen direkt _get_folder_manager() auf, was die FolderManager-Instanz als Singleton zurückgibt
# Die doppelte Definition hier ist unnötig und würde zu Fehlern führen, da folder_manager nicht definiert ist


if __name__ == "__main__":
    """
    Bei direktem Aufruf des Skripts werden einige Tests durchgeführt
    """
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
        print(f"Fotos-Verzeichnis:             {fm.get_photos_dir()}")
        print(f"Fotos-Original-Verzeichnis:    {fm.get_photos_originals_dir()}")
        print(f"Fotos-Galerie-Verzeichnis:     {fm.get_photos_gallery_dir()}")
