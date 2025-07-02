#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
manage_backend_service.py - Verwaltung des Fotobox Backend-Services

Dieses Modul stellt Funktionen zur Verwaltung des systemd-Services für das Fotobox-Backend
bereit. Es erlaubt das Installieren, Aktivieren, Starten, Stoppen, Neustarten und 
Deinstallieren des Services.
"""

import os
import sys
import datetime
import subprocess
import logging
import json
from typing import Dict, Any, Optional, Tuple
from pathlib import Path

# Logger einrichten
logger = logging.getLogger(__name__)

# Importiere manage_folders für zentrale Pfadverwaltung
from manage_folders import FolderManager, get_config_dir

class ServiceError(Exception):
    """Basisklasse für Service-bezogene Fehler"""
    pass

class ServiceConfigError(ServiceError):
    """Fehler in der Service-Konfiguration"""
    pass

class ServiceOperationError(ServiceError):
    """Fehler bei Service-Operationen"""
    pass

class BackendService:
    """Verwaltung des Fotobox Backend-Services"""
    
    def __init__(self):
        self.folder_manager = FolderManager()
        self.config_dir = get_config_dir()
        self.service_file = os.path.join(self.config_dir, 'fotobox-backend.service')
        self.systemd_path = '/etc/systemd/system/fotobox-backend.service'
        self.service_name = 'fotobox-backend'
        
    def _execute_systemctl(self, command: str, check: bool = True) -> Tuple[int, str, str]:
        """Führt systemctl Befehle aus"""
        try:
            cmd = ['systemctl', command, self.service_name]
            result = subprocess.run(cmd, capture_output=True, text=True, check=check)
            return 0, result.stdout, result.stderr
        except subprocess.CalledProcessError as e:
            return e.returncode, e.stdout, e.stderr
            
    def check_dependencies(self) -> Dict[str, bool]:
        """Prüft alle Service-Abhängigkeiten"""
        dependencies = {
            'python_venv': os.path.exists('/opt/fotobox/backend/venv'),
            'config_dir': os.path.exists(self.config_dir),
            'service_file': os.path.exists(self.service_file),
            'systemd': os.path.exists('/run/systemd/system')
        }
        logger.debug(f"Service-Abhängigkeiten: {json.dumps(dependencies, indent=2)}")
        return dependencies
        
    def validate_service_file(self) -> Tuple[bool, Optional[str]]:
        """Validiert die Service-Datei"""
        try:
            # Prüfe ob Datei existiert
            if not os.path.exists(self.service_file):
                return False, "Service-Datei nicht gefunden"
                
            # Lese und validiere Service-Datei
            with open(self.service_file, 'r') as f:
                content = f.read()
                
            required_fields = [
                'Description=',
                'ExecStart=',
                'User=',
                'Group=',
                'WorkingDirectory='
            ]
            
            for field in required_fields:
                if field not in content:
                    return False, f"Pflichtfeld '{field}' fehlt in Service-Datei"
                    
            return True, None
            
        except Exception as e:
            return False, f"Fehler bei Service-Datei-Validierung: {e}"
            
    def install(self) -> bool:
        """Installiert den Service"""
        try:
            # Validiere Service-Datei
            valid, error = self.validate_service_file()
            if not valid:
                raise ServiceConfigError(error)
                
            # Kopiere Service-Datei
            subprocess.run(['sudo', 'cp', self.service_file, self.systemd_path], check=True)
            subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
            
            logger.info("Backend-Service erfolgreich installiert")
            return True
            
        except Exception as e:
            logger.error(f"Fehler bei Service-Installation: {e}")
            raise ServiceOperationError(f"Installation fehlgeschlagen: {e}")
            
    def start(self) -> bool:
        """Startet den Service"""
        try:
            code, out, err = self._execute_systemctl('start')
            if code != 0:
                raise ServiceOperationError(f"Start fehlgeschlagen: {err}")
            logger.info("Backend-Service erfolgreich gestartet")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Starten des Services: {e}")
            raise
            
    def stop(self) -> bool:
        """Stoppt den Service"""
        try:
            code, out, err = self._execute_systemctl('stop')
            if code != 0:
                raise ServiceOperationError(f"Stop fehlgeschlagen: {err}")
            logger.info("Backend-Service erfolgreich gestoppt")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Stoppen des Services: {e}")
            raise
            
    def restart(self) -> bool:
        """Startet den Service neu"""
        try:
            code, out, err = self._execute_systemctl('restart')
            if code != 0:
                raise ServiceOperationError(f"Neustart fehlgeschlagen: {err}")
            logger.info("Backend-Service erfolgreich neugestartet")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Neustarten des Services: {e}")
            raise
            
    def status(self) -> Dict[str, Any]:
        """Gibt den Service-Status zurück"""
        try:
            cmd = ['systemctl', 'show', self.service_name, 
                  '--property=ActiveState,SubState,LoadState,UnitFileState']
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            status = {}
            for line in result.stdout.split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    status[key] = value
                    
            return {
                'active': status.get('ActiveState') == 'active',
                'running': status.get('SubState') == 'running',
                'enabled': status.get('UnitFileState') == 'enabled',
                'state': status.get('ActiveState', 'unknown'),
                'substate': status.get('SubState', 'unknown')
            }
            
        except Exception as e:
            logger.error(f"Fehler beim Abrufen des Service-Status: {e}")
            raise ServiceOperationError(f"Status-Abfrage fehlgeschlagen: {e}")
    
    def get_status_with_comparison(self, comparison_status: str = None) -> Tuple[bool, str]:
        """
        Bash-kompatible Statusabfrage mit optionalem Vergleich
        
        Args:
            comparison_status: Optional. Wenn angegeben, wird der aktuelle Status mit diesem verglichen.
                Gültige Werte: active, inactive, failed, unknown, enabled, disabled
        
        Returns:
            Tuple aus (bool, str):
            - bool: True wenn Status übereinstimmt oder (ohne Vergleich) Service aktiv und enabled ist
            - str: Kombinierter Status "state enabled/disabled" (z.B. "active enabled")
        
        Raises:
            ServiceOperationError: Wenn der Status nicht abgerufen werden kann
        """
        valid_statuses = ["active", "inactive", "failed", "unknown", "enabled", "disabled"]
        
        try:
            status_info = self.status()
            current_status = status_info['state']
            autostart_status = "enabled" if status_info['enabled'] else "disabled"
            
            # Kombinierter Status für Bash-Kompatibilität
            combined_status = f"{current_status} {autostart_status}"
            
            # Wenn ein Vergleichsstatus angegeben wurde
            if comparison_status:
                # Prüfen ob der Vergleichsstatus gültig ist
                if comparison_status not in valid_statuses:
                    logger.error(f"Ungültiger Vergleichsstatus: {comparison_status}")
                    return False, combined_status
                
                # Prüfen ob der angegebene Status im kombinierten Status enthalten ist
                return comparison_status in combined_status, combined_status
            else:
                # Ohne Parameter: True wenn Service läuft und Autostart aktiviert
                return current_status == "active" and autostart_status == "enabled", combined_status
                
        except Exception as e:
            logger.error(f"Fehler beim Statusvergleich: {e}")
            raise ServiceOperationError(f"Statusvergleich fehlgeschlagen: {e}")
            
    def enable(self) -> bool:
        """Aktiviert den Service für Autostart"""
        try:
            code, out, err = self._execute_systemctl('enable')
            if code != 0:
                raise ServiceOperationError(f"Aktivierung fehlgeschlagen: {err}")
            logger.info("Backend-Service erfolgreich für Autostart aktiviert")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Aktivieren des Services: {e}")
            raise
            
    def disable(self) -> bool:
        """Deaktiviert den Service-Autostart"""
        try:
            code, out, err = self._execute_systemctl('disable')
            if code != 0:
                raise ServiceOperationError(f"Deaktivierung fehlgeschlagen: {err}")
            logger.info("Backend-Service-Autostart erfolgreich deaktiviert")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Deaktivieren des Services: {e}")
            raise
            
    def uninstall(self) -> bool:
        """Deinstalliert den Service"""
        try:
            # Stoppe und deaktiviere den Service
            self.stop()
            self.disable()
            
            # Entferne Service-Datei
            if os.path.exists(self.systemd_path):
                subprocess.run(['sudo', 'rm', self.systemd_path], check=True)
                subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
                
            logger.info("Backend-Service erfolgreich deinstalliert")
            return True
            
        except Exception as e:
            logger.error(f"Fehler bei Service-Deinstallation: {e}")
            raise ServiceOperationError(f"Deinstallation fehlgeschlagen: {e}")

# Globale Instanz
_service = BackendService()

# Convenience-Funktionen
def install_service() -> bool:
    return _service.install()
    
def start_service() -> bool:
    return _service.start()
    
def stop_service() -> bool:
    return _service.stop()
    
def restart_service() -> bool:
    return _service.restart()
    
def get_service_status() -> Dict[str, Any]:
    return _service.status()

def get_service_status_with_comparison(comparison_status: str = None) -> Tuple[bool, str]:
    """
    Bash-kompatible Funktion für die Statusabfrage
    
    Args:
        comparison_status: Optional. Status mit dem verglichen werden soll.
    
    Returns:
        Tuple aus (bool, str): Success-Flag und kombinierter Status
    """
    return _service.get_status_with_comparison(comparison_status)
    
def enable_service() -> bool:
    return _service.enable()
    
def disable_service() -> bool:
    return _service.disable()
    
def uninstall_service() -> bool:
    return _service.uninstall()
