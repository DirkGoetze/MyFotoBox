"""
api_uninstall.py - API-Endpunkte für Deinstallationsoperationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Deinstallationsoperationen bereit
und dient als Schnittstelle zwischen dem Frontend und dem manage_uninstall-Modul.
"""

from flask import Blueprint, request
from typing import Dict, Any
import logging

from manage_api import ApiResponse, handle_api_exception
from api_auth import token_required
import manage_uninstall
from manage_folders import FolderManager

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für die Deinstallation-API erstellen
api_uninstall = Blueprint('api_uninstall', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

@api_uninstall.route('/api/uninstall/backup-configs', methods=['POST'])
@token_required
def backup_configs() -> Dict[str, Any]:
    """
    API-Endpunkt für das Sichern von Konfigurationsdateien
    
    Returns:
        Dict mit Status und Details der Backup-Operation
    """
    try:
        result = manage_uninstall.backup_configs()
        if not result['success']:
            return ApiResponse.error(
                message='Fehler beim Backup der Konfigurationen',
                details=result.get('error'),
                status_code=500
            )
            
        return ApiResponse.success(
            message='Konfigurationen wurden erfolgreich gesichert',
            data=result
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Sichern der Konfigurationen: {e}")
        return handle_api_exception(e, endpoint='/api/uninstall/backup-configs')

@api_uninstall.route('/api/uninstall/systemd', methods=['POST'])
@token_required
def remove_systemd() -> Dict[str, Any]:
    """
    API-Endpunkt zum Entfernen des systemd-Services
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        result = manage_uninstall.remove_systemd()
        if not result['success']:
            return ApiResponse.error(
                message='Fehler beim Entfernen des systemd-Service',
                details=result.get('error'),
                status_code=500
            )
            
        return ApiResponse.success(
            message='systemd-Service wurde erfolgreich entfernt',
            data=result
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Entfernen des systemd-Service: {e}")
        return handle_api_exception(e, endpoint='/api/uninstall/systemd')

@api_uninstall.route('/api/uninstall/nginx', methods=['POST'])
@token_required
def remove_nginx() -> Dict[str, Any]:
    """
    API-Endpunkt zum Entfernen der NGINX-Konfiguration
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        result = manage_uninstall.remove_nginx()
        if not result['success']:
            return ApiResponse.error(
                message='Fehler beim Entfernen der NGINX-Konfiguration',
                details=result.get('error'),
                status_code=500
            )
            
        return ApiResponse.success(
            message='NGINX-Konfiguration wurde erfolgreich entfernt',
            data=result
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Entfernen der NGINX-Konfiguration: {e}")
        return handle_api_exception(e, endpoint='/api/uninstall/nginx')

@api_uninstall.route('/api/uninstall/project', methods=['POST'])
@token_required
def remove_project() -> Dict[str, Any]:
    """
    API-Endpunkt zum Entfernen des Projektverzeichnisses
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        result = manage_uninstall.remove_project()
        if not result['success']:
            return ApiResponse.error(
                message='Fehler beim Entfernen des Projektverzeichnisses',
                details=result.get('error'),
                status_code=500
            )
            
        return ApiResponse.success(
            message='Projektverzeichnis wurde erfolgreich entfernt',
            data=result
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Entfernen des Projektverzeichnisses: {e}")
        return handle_api_exception(e, endpoint='/api/uninstall/project')

@api_uninstall.route('/api/uninstall/complete', methods=['POST'])
@token_required
def complete_uninstall() -> Dict[str, Any]:
    """
    API-Endpunkt für die vollständige Deinstallation
    
    Führt alle Deinstallationsschritte nacheinander aus:
    1. Backup der Konfigurationen
    2. Entfernen des systemd-Service
    3. Entfernen der NGINX-Konfiguration
    4. Entfernen des Projektverzeichnisses
    
    Returns:
        Dict mit Status und Details aller Operationen
    """
    try:
        results = {
            'backup': manage_uninstall.backup_configs(),
            'systemd': manage_uninstall.remove_systemd(),
            'nginx': manage_uninstall.remove_nginx(),
            'project': manage_uninstall.remove_project()
        }
        
        # Prüfe auf Fehler
        errors = {k: v.get('error') for k, v in results.items() 
                 if not v['success'] and 'error' in v}
                 
        if errors:
            return ApiResponse.error(
                message='Fehler bei der vollständigen Deinstallation',
                details=errors,
                status_code=500
            )
            
        return ApiResponse.success(
            message='Fotobox2 wurde erfolgreich deinstalliert',
            data=results
        )
        
    except Exception as e:
        logger.error(f"Fehler bei der vollständigen Deinstallation: {e}")
        return handle_api_exception(e, endpoint='/api/uninstall/complete')
