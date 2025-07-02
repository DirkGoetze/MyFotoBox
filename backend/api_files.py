#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# api_files.py - REST API Schnittstelle für die Dateiverwaltung
#
# Teil der Fotobox2 Anwendung
# Copyright (c) 2023-2025 Dirk Götze
#
# Dieser Endpunkt stellt API-Methoden für die zentrale Dateiverwaltung
# und Operationen auf Dateisystemebene bereit.
#

import os
from flask import Blueprint, request, send_from_directory, Response
import logging
import mimetypes
from typing import Dict, Any, List, Optional
from pathlib import Path
import utils.path_utils as utils  # Sicherheitsutils für Pfadoperationen

# Eigene Module importieren
import manage_files
from manage_api import ApiResponse, handle_api_exception
from api_auth import token_required
from manage_folders import FolderManager

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint definieren
api_files = Blueprint('api_files', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

@api_files.route('/api/files/config', methods=['GET'])
@token_required
def get_config_file_path() -> Dict[str, Any]:
    """
    API-Endpunkt zum Abrufen des Pfads zu einer Konfigurationsdatei.
    
    Erfordert Parameter:
    - category: Die Kategorie der Konfigurationsdatei (nginx, camera, system)
    - name: Der Name der Konfigurationsdatei (ohne Erweiterung)
    
    Returns:
        Dict mit Pfad zur Konfigurationsdatei
    """
    try:
        category = request.args.get('category')
        name = request.args.get('name')
        
        if not category or not name:
            return ApiResponse.error(
                message="Kategorie und Name müssen angegeben werden",
                status_code=400
            )
        
        file_path = manage_files.get_config_file_path(category=category, name=name)
        exists = Path(file_path).exists()
        
        return ApiResponse.success(data={
            'path': file_path,
            'exists': exists,
            'category': category,
            'name': name
        })
    
    except ValueError as e:
        logger.error(f"Ungültige Parameter bei get_config_file_path: {e}")
        return ApiResponse.error(
            message=str(e),
            status_code=400
        )
    except Exception as e:
        logger.error(f"Fehler bei get_config_file_path: {e}")
        return handle_api_exception(e, endpoint='/api/files/config')

@api_files.route('/api/files/system', methods=['GET'])
@token_required
def get_system_file_path() -> Dict[str, Any]:
    """
    API-Endpunkt zum Abrufen des Pfads zu einer Systemdatei.
    
    Erfordert Parameter:
    - file_type: Der Typ der Systemdatei (nginx, systemd, ssl_cert, ssl_key)
    - name: Der Name der Systemdatei (ohne Erweiterung)
    
    Returns:
        Dict mit Pfad zur Systemdatei
    """
    try:
        file_type = request.args.get('file_type')
        name = request.args.get('name')
        
        if not file_type or not name:
            return ApiResponse.error(
                message="Dateityp und Name müssen angegeben werden",
                status_code=400
            )
        
        file_path = manage_files.get_system_file_path(file_type=file_type, name=name)
        exists = Path(file_path).exists()
        
        return ApiResponse.success(data={
            'path': file_path,
            'exists': exists,
            'type': file_type,
            'name': name
        })
    
    except ValueError as e:
        logger.error(f"Ungültige Parameter bei get_system_file_path: {e}")
        return ApiResponse.error(
            message=str(e),
            status_code=400
        )
    except Exception as e:
        logger.error(f"Fehler bei get_system_file_path: {e}")
        return handle_api_exception(e, endpoint='/api/files/system')

@api_files.route('/api/files/download/<path:file_path>', methods=['GET'])
@token_required
def download_file(file_path: str) -> Response:
    """
    API-Endpunkt zum Herunterladen einer Datei.
    
    Args:
        file_path: Relativer Pfad zur Datei
        
    Returns:
        Response mit der angeforderten Datei
    """
    try:
        if not file_path:
            return ApiResponse.error(
                message="Kein Dateipfad angegeben",
                status_code=400
            )
            
        # Sicherheitscheck für Pfad
        abs_path = Path(folder_manager.get_path('data')) / file_path
        if not utils.is_safe_path(str(abs_path)):
            return ApiResponse.error(
                message="Ungültiger Dateipfad",
                status_code=400
            )
            
        if not abs_path.exists():
            return ApiResponse.error(
                message="Datei nicht gefunden",
                status_code=404
            )
            
        return send_from_directory(
            os.path.dirname(abs_path),
            os.path.basename(abs_path),
            as_attachment=True
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Herunterladen der Datei {file_path}: {e}")
        return handle_api_exception(e, endpoint=f'/api/files/download/{file_path}')

@api_files.route('/api/files/info/<path:file_path>', methods=['GET'])
@token_required
def get_file_info(file_path: str) -> Dict[str, Any]:
    """
    API-Endpunkt zum Abrufen von Dateiinformationen.
    
    Args:
        file_path: Relativer Pfad zur Datei
        
    Returns:
        Dict mit Dateiinformationen
    """
    try:
        if not file_path:
            return ApiResponse.error(
                message="Kein Dateipfad angegeben",
                status_code=400
            )
            
        # Sicherheitscheck für Pfad
        abs_path = Path(folder_manager.get_path('data')) / file_path
        if not utils.is_safe_path(str(abs_path)):
            return ApiResponse.error(
                message="Ungültiger Dateipfad",
                status_code=400
            )
            
        if not abs_path.exists():
            return ApiResponse.error(
                message="Datei nicht gefunden",
                status_code=404
            )
            
        file_info = manage_files.get_file_info(str(abs_path))
        return ApiResponse.success(data=file_info)
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Dateiinformationen für {file_path}: {e}")
        return handle_api_exception(e, endpoint=f'/api/files/info/{file_path}')

@api_files.route('/api/files/delete/<path:file_path>', methods=['DELETE'])
@token_required
def delete_file(file_path: str) -> Dict[str, Any]:
    """
    API-Endpunkt zum Löschen einer Datei.
    
    Args:
        file_path: Relativer Pfad zur Datei
        
    Returns:
        Dict mit Status der Operation
    """
    try:
        if not file_path:
            return ApiResponse.error(
                message="Kein Dateipfad angegeben",
                status_code=400
            )
            
        # Sicherheitscheck für Pfad
        abs_path = Path(folder_manager.get_path('data')) / file_path
        if not utils.is_safe_path(str(abs_path)):
            return ApiResponse.error(
                message="Ungültiger Dateipfad",
                status_code=400
            )
            
        if not abs_path.exists():
            return ApiResponse.error(
                message="Datei nicht gefunden",
                status_code=404
            )
            
        manage_files.delete_file(str(abs_path))
        return ApiResponse.success(message="Datei erfolgreich gelöscht")
        
    except Exception as e:
        logger.error(f"Fehler beim Löschen der Datei {file_path}: {e}")
        return handle_api_exception(e, endpoint=f'/api/files/delete/{file_path}')

# Blueprint-Registrierung
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App"""
    app.register_blueprint(api_files)
    logger.info("API-Endpunkte für Dateiverwaltung registriert")
