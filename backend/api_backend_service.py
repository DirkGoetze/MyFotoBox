#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
api_backend_service.py - API-Endpunkte zur Verwaltung des Backend-Services

Dieses Modul definiert die API-Endpunkte zur Verwaltung des Fotobox-Backend-Services
über die REST-API. Es stellt Funktionen zum Starten, Stoppen, Neustarten und 
Statusabruf des Services bereit.
"""

from flask import Blueprint, request
from typing import Dict, Any
import logging
from datetime import datetime

from manage_api import ApiResponse, handle_api_exception
from api_auth import token_required
import manage_backend_service
from manage_folders import FolderManager

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für Backend-Service-Verwaltung erstellen
api_backend_service = Blueprint('api_backend_service', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

# Backend-Service Instanz
backend_service = manage_backend_service.BackendService()

@api_backend_service.route('/api/service/status', methods=['GET'])
@token_required
def get_service_status() -> Dict[str, Any]:
    """
    Gibt den aktuellen Status des Backend-Services zurück
    
    Returns:
        Dict mit Service-Status
    """
    try:
        status = backend_service.get_status()
        return ApiResponse.success(data={
            'status': status.get('state', 'unknown'),
            'is_active': status.get('is_active', False),
            'uptime': status.get('uptime', None),
            'last_start': status.get('last_start', None),
            'pid': status.get('pid', None),
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Service-Status: {e}")
        return handle_api_exception(e, endpoint='/api/service/status')

@api_backend_service.route('/api/service/details', methods=['GET'])
@token_required
def get_service_details() -> Dict[str, Any]:
    """
    Gibt detaillierte Informationen zum Backend-Service zurück
    
    Returns:
        Dict mit Service-Details
    """
    try:
        details = backend_service.get_details()
        status = backend_service.get_status()
        
        # Prüfe Abhängigkeiten
        dependencies = backend_service.check_dependencies()
        
        return ApiResponse.success(data={
            'status': status,
            'details': details,
            'dependencies': dependencies,
            'config': {
                'service_file': backend_service.service_file,
                'systemd_path': backend_service.systemd_path
            },
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Service-Details: {e}")
        return handle_api_exception(e, endpoint='/api/service/details')

@api_backend_service.route('/api/service/start', methods=['POST'])
@token_required
def start_service() -> Dict[str, Any]:
    """
    Startet den Backend-Service
    
    Returns:
        Dict mit Status der Operation
    """
    try:
        logger.info("Starte Backend-Service...")
        result = backend_service.start()
        
        if not result['success']:
            return ApiResponse.error(
                message="Starten des Backend-Services fehlgeschlagen",
                details=result.get('error'),
                status_code=500
            )
            
        # Hole aktuellen Status
        status = backend_service.get_status()
            
        return ApiResponse.success(
            message="Backend-Service erfolgreich gestartet",
            data={
                'status': status,
                'timestamp': datetime.now().isoformat()
            }
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Starten des Services: {e}")
        return handle_api_exception(e, endpoint='/api/service/start')

@api_backend_service.route('/api/service/stop', methods=['POST'])
@token_required
def stop_service() -> Dict[str, Any]:
    """
    Stoppt den Backend-Service
    
    Returns:
        Dict mit Status der Operation
    """
    try:
        logger.info("Stoppe Backend-Service...")
        result = backend_service.stop()
        
        if not result['success']:
            return ApiResponse.error(
                message="Stoppen des Backend-Services fehlgeschlagen",
                details=result.get('error'),
                status_code=500
            )
            
        # Hole aktuellen Status
        status = backend_service.get_status()
            
        return ApiResponse.success(
            message="Backend-Service erfolgreich gestoppt",
            data={
                'status': status,
                'timestamp': datetime.now().isoformat()
            }
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Stoppen des Services: {e}")
        return handle_api_exception(e, endpoint='/api/service/stop')

@api_backend_service.route('/api/service/restart', methods=['POST'])
@token_required
def restart_service() -> Dict[str, Any]:
    """
    Startet den Backend-Service neu
    
    Returns:
        Dict mit Status der Operation
    """
    try:
        logger.info("Starte Backend-Service neu...")
        result = backend_service.restart()
        
        if not result['success']:
            return ApiResponse.error(
                message="Neustart des Backend-Services fehlgeschlagen",
                details=result.get('error'),
                status_code=500
            )
            
        # Hole aktuellen Status
        status = backend_service.get_status()
            
        return ApiResponse.success(
            message="Backend-Service erfolgreich neugestartet",
            data={
                'status': status,
                'timestamp': datetime.now().isoformat()
            }
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Neustarten des Services: {e}")
        return handle_api_exception(e, endpoint='/api/service/restart')
