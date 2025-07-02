#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
api_folders.py - API-Endpunkte für Verzeichnisverwaltung

Dieses Modul stellt die REST-API-Endpunkte für die Verzeichnisverwaltung bereit.
Es nutzt das manage_folders-Modul für die eigentliche Implementierung.
"""

import os
import shutil
from typing import Dict, Any
from flask import Blueprint, jsonify, request
import logging
from pathlib import Path

from manage_api import ApiResponse, handle_api_exception
from manage_folders import FolderManager, get_photos_dir, get_photos_gallery_dir
from api_auth import token_required

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für Folder-API erstellen
api_folders = Blueprint('api_folders', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

@api_folders.route('/api/folders/structure', methods=['GET'])
@token_required
def get_folder_structure() -> Dict[str, Any]:
    """
    Gibt die aktuelle Verzeichnisstruktur zurück
    
    Returns:
        JSON-Response mit der Verzeichnisstruktur
    """
    try:
        structure = {
            'photos': {
                'path': get_photos_dir(),
                'gallery': get_photos_gallery_dir(),
                'exists': os.path.exists(get_photos_dir()),
                'is_writable': os.access(get_photos_dir(), os.W_OK) if os.path.exists(get_photos_dir()) else False
            },
            'data': {
                'path': folder_manager.get_path('data'),
                'exists': os.path.exists(folder_manager.get_path('data')),
                'is_writable': os.access(folder_manager.get_path('data'), os.W_OK) if os.path.exists(folder_manager.get_path('data')) else False
            },
            'backup': {
                'path': folder_manager.get_path('backup'),
                'exists': os.path.exists(folder_manager.get_path('backup')),
                'is_writable': os.access(folder_manager.get_path('backup'), os.W_OK) if os.path.exists(folder_manager.get_path('backup')) else False
            },
            'config': {
                'path': folder_manager.get_path('config'),
                'exists': os.path.exists(folder_manager.get_path('config')),
                'is_writable': os.access(folder_manager.get_path('config'), os.W_OK) if os.path.exists(folder_manager.get_path('config')) else False
            },
            'log': {
                'path': folder_manager.get_path('log'),
                'exists': os.path.exists(folder_manager.get_path('log')),
                'is_writable': os.access(folder_manager.get_path('log'), os.W_OK) if os.path.exists(folder_manager.get_path('log')) else False
            }
        }
        
        return ApiResponse.success(data=structure)
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Verzeichnisstruktur: {e}")
        return handle_api_exception(e, endpoint='/api/folders/structure')

@api_folders.route('/api/folders/ensure', methods=['POST'])
@token_required
def ensure_folder_structure() -> Dict[str, Any]:
    """
    Stellt sicher, dass alle benötigten Verzeichnisse existieren
    
    Returns:
        JSON-Response mit Status der Operation
    """
    try:
        folder_manager.ensure_folder_structure()
        return ApiResponse.success(
            message="Verzeichnisstruktur erfolgreich initialisiert"
        )
    except Exception as e:
        logger.error(f"Fehler bei Verzeichnisinitialisierung: {e}")
        return handle_api_exception(e, endpoint='/api/folders/ensure')

@api_folders.route('/api/folders/status', methods=['GET'])
@token_required
def get_folders_status() -> Dict[str, Any]:
    """
    Prüft den Status und die Berechtigungen aller Verzeichnisse
    
    Returns:
        JSON-Response mit detailliertem Verzeichnisstatus
    """
    try:
        # Alle relevanten Verzeichnisse prüfen
        status = {}
        for folder_type in ['photos', 'data', 'backup', 'config', 'log']:
            path = folder_manager.get_path(folder_type)
            folder_status = {
                'exists': os.path.exists(path),
                'is_writable': os.access(path, os.W_OK) if os.path.exists(path) else False,
                'permissions': oct(os.stat(path).st_mode)[-3:] if os.path.exists(path) else None,
                'owner': Path(path).owner() if os.path.exists(path) else None,
                'group': Path(path).group() if os.path.exists(path) else None,
                'size': sum(f.stat().st_size for f in Path(path).glob('**/*') if f.is_file()) if os.path.exists(path) else 0
            }
            status[folder_type] = folder_status
            
        return ApiResponse.success(data=status)
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Verzeichnisstatus: {e}")
        return handle_api_exception(e, endpoint='/api/folders/status')

@api_folders.route('/api/folders/cleanup', methods=['POST'])
@token_required
def cleanup_folders() -> Dict[str, Any]:
    """
    Bereinigt temporäre und nicht mehr benötigte Dateien
    
    Returns:
        JSON-Response mit Cleanup-Statistiken
    """
    try:
        # Statistik-Zähler
        stats = {
            'deleted_files': 0,
            'freed_space': 0,
            'cleaned_folders': []
        }
        
        # Temporäre Dateien in jedem Verzeichnis bereinigen
        for folder_type in ['photos', 'data', 'backup', 'log']:
            path = folder_manager.get_path(folder_type)
            if os.path.exists(path):
                # Temporäre und Backup-Dateien finden und löschen
                for pattern in ['*.tmp', '*.bak', '*.old']:
                    for file in Path(path).glob(f'**/{pattern}'):
                        if file.is_file():
                            size = file.stat().st_size
                            file.unlink()
                            stats['deleted_files'] += 1
                            stats['freed_space'] += size
                            
                stats['cleaned_folders'].append(folder_type)
                
        return ApiResponse.success(
            message=f"{stats['deleted_files']} Dateien bereinigt, {stats['freed_space'] // 1024 // 1024} MB freigegeben",
            data=stats
        )
        
    except Exception as e:
        logger.error(f"Fehler bei Verzeichnisbereinigung: {e}")
        return handle_api_exception(e, endpoint='/api/folders/cleanup')

# Blueprint-Registrierung
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App"""
    app.register_blueprint(api_folders)
    logger.info("API-Endpunkte für Verzeichnisverwaltung registriert")
