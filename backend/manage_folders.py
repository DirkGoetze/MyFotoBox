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
import json
from typing import Optional, Dict, Any, List, Tuple
from pathlib import Path

logger = logging.getLogger(__name__)

class FolderConfigError(Exception):
    """Ausnahme für Fehler bei der Verzeichniskonfiguration"""
    pass

class ShellScriptError(Exception):
    """Ausnahme für Fehler bei der Shell-Skript-Ausführung"""
    pass

class FolderManager:
    """Verwaltung der Fotobox-Ordnerstruktur"""
    
    def __init__(self):
        self._cache: Dict[str, str] = {}
        self._script_path = self._find_shell_script()
        self._lib_core_path = self._find_lib_core()
        self._initialized = False
        self._init_shell_environment()
        
    def _find_shell_script(self) -> str:
        """Findet den Pfad zum manage_folders.sh Skript"""
        script_name = "manage_folders.sh"
        current_dir = Path(__file__).parent
        script_locations = [
            current_dir / "scripts" / script_name,
            current_dir.parent / "scripts" / script_name,
            Path("/opt/fotobox/backend/scripts") / script_name
        ]
        
        for location in script_locations:
            if location.is_file():
                logger.debug(f"Shell-Skript gefunden: {location}")
                return str(location)
                
        raise FolderConfigError("manage_folders.sh nicht gefunden")
        
    def _find_lib_core(self) -> str:
        """Findet den Pfad zur lib_core.sh"""
        lib_name = "lib_core.sh"
        script_dir = Path(self._script_path).parent
        lib_path = script_dir / lib_name
        
        if not lib_path.is_file():
            raise FolderConfigError("lib_core.sh nicht gefunden")
            
        return str(lib_path)
        
    def _init_shell_environment(self) -> None:
        """Initialisiert die Shell-Umgebung"""
        try:
            # Source lib_core.sh und prüfe Rückgabewert
            result = subprocess.run(
                ['/bin/bash', '-c', f'source "{self._lib_core_path}" && echo $?'],
                capture_output=True,
                text=True,
                check=True
            )
            
            if result.stdout.strip() != "0":
                raise ShellScriptError("Fehler beim Laden von lib_core.sh")
                
            # Initialisiere Ordnerstruktur via Shell-Skript
            result = subprocess.run(
                ['/bin/bash', self._script_path, '--init'],
                capture_output=True,
                text=True,
                check=True
            )
            
            if "ERROR" in result.stderr:
                raise ShellScriptError(f"Fehler bei Ordnerinitialisierung: {result.stderr}")
                
            self._initialized = True
            logger.info("Shell-Umgebung erfolgreich initialisiert")
            
        except subprocess.CalledProcessError as e:
            raise ShellScriptError(f"Shell-Skript-Fehler: {e.stderr}")
        except Exception as e:
            raise FolderConfigError(f"Initialisierungsfehler: {e}")
            
    def _execute_shell_command(self, command: str, *args: str) -> str:
        """Führt ein Shell-Kommando aus und gibt das Ergebnis zurück"""
        if not self._initialized:
            raise FolderConfigError("Shell-Umgebung nicht initialisiert")
            
        try:
            cmd = ['/bin/bash', '-c', 
                  f'source "{self._lib_core_path}" && source "{self._script_path}" && {command} {" ".join(args)}']
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            raise ShellScriptError(f"Fehler bei '{command}': {e.stderr}")
            
    def get_path(self, path_type: str) -> str:
        """Holt einen Pfad über das Shell-Skript"""
        if path_type in self._cache:
            return self._cache[path_type]
            
        try:
            path = self._execute_shell_command(f"get_{path_type}_dir")
            self._cache[path_type] = path
            return path
        except Exception as e:
            logger.error(f"Fehler beim Abrufen von {path_type}_dir: {e}")
            raise
            
    def ensure_folder_structure(self) -> None:
        """Stellt sicher, dass alle benötigten Verzeichnisse existieren"""
        try:
            self._execute_shell_command("init_folders")
        except Exception as e:
            logger.error(f"Fehler bei Verzeichnisinitialisierung: {e}")
            raise

# Globale Instanz und Convenience-Funktionen
_folder_manager = FolderManager()

def get_data_dir() -> str:
    return _folder_manager.get_path("data")
    
def get_config_dir() -> str:
    return _folder_manager.get_path("config")
    
def get_backup_dir() -> str:
    return _folder_manager.get_path("backup")
    
def get_log_dir() -> str:
    return _folder_manager.get_path("log")
    
def get_photos_dir() -> str:
    return _folder_manager.get_path("photos")
    
def get_photos_gallery_dir() -> str:
    return _folder_manager.get_path("gallery")
    
def ensure_folder_structure() -> None:
    _folder_manager.ensure_folder_structure()
