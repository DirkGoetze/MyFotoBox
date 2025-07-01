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

from manage_api import ApiResponse, handle_api_exception
from manage_folders import FolderManager, get_photos_dir, get_photos_gallery_dir

# Logger einrichten
logger = logging.getLogger(__name__)

# Blueprint für Folder-API erstellen
folders_api = Blueprint('folders_api', __name__)

# Folder Manager Instanz
folder_manager = FolderManager()

@folders_api.route('/api/folders/structure', methods=['GET'])
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
                'exists': os.path.exists(get_photos_dir())
            },
            'data': {
                'path': folder_manager.get_data_dir(),
                'exists': os.path.exists(folder_manager.get_data_dir())
            },
            'backup': {
                'path': folder_manager.get_backup_dir(),
                'exists': os.path.exists(folder_manager.get_backup_dir())
            }
        }
        
        return ApiResponse.success(data=structure)
        
    except Exception as e:
        return handle_api_exception(e, endpoint='/api/folders/structure')

@folders_api.route('/api/folders/ensure', methods=['POST'])
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
        return handle_api_exception(e, endpoint='/api/folders/ensure')

@folders_api.route('/api/folders/gallery/list', methods=['GET'])
def list_gallery_folders() -> Dict[str, Any]:
    """
    Listet alle Galerie-Verzeichnisse auf
    
    Returns:
        JSON-Response mit Liste der Galerie-Verzeichnisse
    """
    try:
        gallery_dir = get_photos_gallery_dir()
        if not os.path.exists(gallery_dir):
            return ApiResponse.error(
                "Galerie-Verzeichnis existiert nicht",
                error_code=404
            )
            
        # Liste alle Unterverzeichnisse auf
        folders = []
        for item in os.listdir(gallery_dir):
            path = os.path.join(gallery_dir, item)
            if os.path.isdir(path):
                folders.append({
                    'name': item,
                    'path': path,
                    'file_count': len(os.listdir(path))
                })
                
        return ApiResponse.success(data={'folders': folders})
        
    except Exception as e:
        return handle_api_exception(e, endpoint='/api/folders/gallery/list')

@folders_api.route('/api/folders/gallery/create', methods=['POST'])
def create_gallery_folder() -> Dict[str, Any]:
    """
    Erstellt ein neues Galerie-Verzeichnis
    
    Returns:
        JSON-Response mit Status der Operation
    """
    try:
        data = request.get_json()
        if not data or 'name' not in data:
            return ApiResponse.error(
                "Verzeichnisname fehlt",
                error_code=400
            )
            
        folder_name = data['name']
        gallery_dir = get_photos_gallery_dir()
        new_folder = os.path.join(gallery_dir, folder_name)
        
        if os.path.exists(new_folder):
            return ApiResponse.error(
                "Verzeichnis existiert bereits",
                error_code=409
            )
            
        os.makedirs(new_folder, mode=0o755)
        shutil.chown(new_folder, user='fotobox', group='fotobox')
        
        return ApiResponse.success(
            message=f"Galerie-Verzeichnis '{folder_name}' erstellt",
            data={'path': new_folder}
        )
        
    except Exception as e:
        return handle_api_exception(e, endpoint='/api/folders/gallery/create')

@folders_api.route('/api/folders/gallery/delete/<path:folder_name>', methods=['DELETE'])
def delete_gallery_folder(folder_name: str) -> Dict[str, Any]:
    """
    Löscht ein Galerie-Verzeichnis
    
    Args:
        folder_name: Name des zu löschenden Verzeichnisses
        
    Returns:
        JSON-Response mit Status der Operation
    """
    try:
        gallery_dir = get_photos_gallery_dir()
        folder_path = os.path.join(gallery_dir, folder_name)
        
        if not os.path.exists(folder_path):
            return ApiResponse.error(
                "Verzeichnis existiert nicht",
                error_code=404
            )
            
        if not os.path.isdir(folder_path):
            return ApiResponse.error(
                "Pfad ist kein Verzeichnis",
                error_code=400
            )
            
        # Prüfe ob Verzeichnis leer ist
        if os.listdir(folder_path):
            return ApiResponse.error(
                "Verzeichnis ist nicht leer",
                error_code=409
            )
            
        os.rmdir(folder_path)
        return ApiResponse.success(
            message=f"Galerie-Verzeichnis '{folder_name}' gelöscht"
        )
        
    except Exception as e:
        return handle_api_exception(e, endpoint=f'/api/folders/gallery/delete/{folder_name}')
