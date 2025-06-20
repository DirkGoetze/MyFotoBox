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
import flask
from flask import Blueprint, request, jsonify
import logging
import mimetypes
from typing import Dict, Any, List, Optional

# Eigene Module importieren
import manage_files
import manage_folders
import utils
import manage_auth
from api_auth import token_required

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint definieren
api_files_bp = Blueprint('api_files', __name__)

@api_files_bp.route('/files/config', methods=['GET'])
@token_required
def get_config_file_path():
    """API-Endpunkt zum Abrufen des Pfads zu einer Konfigurationsdatei.
    
    Erfordert Parameter:
    - category: Die Kategorie der Konfigurationsdatei (nginx, camera, system)
    - name: Der Name der Konfigurationsdatei (ohne Erweiterung)
    
    Returns:
        flask.Response: JSON-Response mit Erfolgs-Flag und Pfad zur Konfigurationsdatei
    """
    try:
        category = request.args.get('category')
        name = request.args.get('name')
        
        if not category or not name:
            return jsonify({
                'success': False,
                'error': 'Kategorie und Name müssen angegeben werden'
            }), 400
        
        file_path = manage_files.get_config_file_path(category=category, name=name)
        
        return jsonify({
            'success': True,
            'path': file_path,
            'exists': os.path.exists(file_path)
        })
    
    except ValueError as e:
        logger.error(f"Fehler bei get_config_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei get_config_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': "Interner Serverfehler"
        }), 500

@api_files_bp.route('/files/system', methods=['GET'])
@token_required
def get_system_file_path():
    """API-Endpunkt zum Abrufen des Pfads zu einer Systemdatei (mit Fallback).
    
    Erfordert Parameter:
    - file_type: Der Typ der Systemdatei (nginx, systemd, ssl_cert, ssl_key)
    - name: Der Name der Systemdatei (ohne Erweiterung)
    
    Returns:
        flask.Response: JSON-Response mit Erfolgs-Flag und Pfad zur Systemdatei
    """
    try:
        file_type = request.args.get('file_type')
        name = request.args.get('name')
        
        if not file_type or not name:
            return jsonify({
                'success': False,
                'error': 'Dateityp und Name müssen angegeben werden'
            }), 400
        
        file_path = manage_files.get_system_file_path(file_type=file_type, name=name)
        
        return jsonify({
            'success': True,
            'path': file_path,
            'exists': os.path.exists(file_path),
            'is_primary': file_path.startswith('/etc/') or file_path.startswith('/var/')
        })
    
    except ValueError as e:
        logger.error(f"Fehler bei get_system_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei get_system_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': "Interner Serverfehler"
        }), 500

@api_files_bp.route('/files/log', methods=['GET'])
@token_required
def get_log_file_path():
    """API-Endpunkt zum Abrufen des Pfads zu einer Log-Datei.
    
    Erfordert Parameter:
    - component: Die Komponente, für die die Log-Datei bestimmt ist
    
    Returns:
        flask.Response: JSON-Response mit Erfolgs-Flag und Pfad zur Log-Datei
    """
    try:
        component = request.args.get('component')
        
        if not component:
            return jsonify({
                'success': False,
                'error': 'Komponente muss angegeben werden'
            }), 400
        
        file_path = manage_files.get_log_file_path(component=component)
        
        return jsonify({
            'success': True,
            'path': file_path,
            'exists': os.path.exists(file_path)
        })
    
    except ValueError as e:
        logger.error(f"Fehler bei get_log_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei get_log_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': "Interner Serverfehler"
        }), 500

@api_files_bp.route('/files/template', methods=['GET'])
@token_required
def get_template_file_path():
    """API-Endpunkt zum Abrufen des Pfads zu einer Template-Datei.
    
    Erfordert Parameter:
    - category: Die Kategorie des Templates (nginx, backup)
    - name: Der Name des Templates
    
    Returns:
        flask.Response: JSON-Response mit Erfolgs-Flag und Pfad zur Template-Datei
    """
    try:
        category = request.args.get('category')
        name = request.args.get('name')
        
        if not category or not name:
            return jsonify({
                'success': False,
                'error': 'Kategorie und Name müssen angegeben werden'
            }), 400
        
        file_path = manage_files.get_template_file_path(category=category, name=name)
        
        return jsonify({
            'success': True,
            'path': file_path,
            'exists': os.path.exists(file_path)
        })
    
    except ValueError as e:
        logger.error(f"Fehler bei get_template_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei get_template_file_path: {str(e)}")
        return jsonify({
            'success': False,
            'error': "Interner Serverfehler"
        }), 500

@api_files_bp.route('/files/exists', methods=['GET'])
@token_required
def check_file_exists():
    """API-Endpunkt zum Überprüfen, ob eine Datei existiert.
    
    Erfordert Parameter:
    - path: Der vollständige Pfad zur Datei
    
    Returns:
        flask.Response: JSON-Response mit Erfolgs-Flag und Existenz-Status der Datei
    """
    try:
        file_path = request.args.get('path')
        
        if not file_path:
            return jsonify({
                'success': False,
                'error': 'Dateipfad muss angegeben werden'
            }), 400
        
        # Sicherheitscheck durchführen
        if not utils.is_safe_path(file_path):
            return jsonify({
                'success': False,
                'error': 'Dateipfad ist nicht sicher'
            }), 403
        
        exists = manage_files.file_exists(file_path)
        
        return jsonify({
            'success': True,
            'exists': exists
        })
    
    except ValueError as e:
        logger.error(f"Fehler bei check_file_exists: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei check_file_exists: {str(e)}")
        return jsonify({
            'success': False,
            'error': "Interner Serverfehler"
        }), 500

@api_files_bp.route('/files/content', methods=['GET'])
@token_required
def get_file_content():
    """API-Endpunkt zum Abrufen des Inhalts einer Datei.
    
    Erfordert Parameter:
    - path: Der vollständige Pfad zur Datei
    
    Returns:
        flask.Response: JSON-Response mit Erfolgs-Flag und Inhalt der Datei
    """
    try:
        file_path = request.args.get('path')
        
        if not file_path:
            return jsonify({
                'success': False,
                'error': 'Dateipfad muss angegeben werden'
            }), 400
        
        # Sicherheitscheck durchführen
        if not utils.is_safe_path(file_path):
            return jsonify({
                'success': False,
                'error': 'Dateipfad ist nicht sicher'
            }), 403
        
        if not os.path.exists(file_path):
            return jsonify({
                'success': False,
                'error': 'Datei existiert nicht'
            }), 404
            
        # Dateityp überprüfen (binäre Dateien vermeiden)
        mime_type, encoding = mimetypes.guess_type(file_path)
        if mime_type and not mime_type.startswith('text/'):
            return jsonify({
                'success': False,
                'error': 'Nur Text-Dateien können angezeigt werden'
            }), 400
        
        # Inhalt der Datei lesen
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
        except UnicodeDecodeError:
            # Fallback für nicht-UTF-8-Dateien
            with open(file_path, 'r', encoding='latin-1') as file:
                content = file.read()
        
        return jsonify({
            'success': True,
            'content': content,
            'mime_type': mime_type or 'text/plain'
        })
    
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei get_file_content: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@api_files_bp.route('/files/write', methods=['POST'])
@token_required
def write_file_content():
    """API-Endpunkt zum Schreiben von Inhalt in eine Datei.
    
    Erfordert einen JSON-Body mit:
    - path: Der vollständige Pfad zur Datei
    - content: Der zu schreibende Inhalt
    - create_dirs (optional): Flag, ob Verzeichnisse erstellt werden sollen (default: True)
    
    Returns:
        flask.Response: JSON-Response mit Erfolgs-Flag
    """
    try:
        data = request.get_json()
        
        if not data or 'path' not in data or 'content' not in data:
            return jsonify({
                'success': False,
                'error': 'Pfad und Inhalt müssen angegeben werden'
            }), 400
        
        file_path = data['path']
        content = data['content']
        create_dirs = data.get('create_dirs', True)
        
        # Sicherheitscheck durchführen
        if not utils.is_safe_path(file_path):
            return jsonify({
                'success': False,
                'error': 'Dateipfad ist nicht sicher'
            }), 403
        
        # Sicherstellen, dass das Verzeichnis existiert
        if create_dirs:
            directory = os.path.dirname(file_path)
            if directory and not os.path.exists(directory):
                os.makedirs(directory, exist_ok=True)
        
        # Inhalt in die Datei schreiben
        with open(file_path, 'w', encoding='utf-8') as file:
            file.write(content)
        
        return jsonify({
            'success': True,
            'path': file_path
        })
    
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei write_file_content: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Flask-App-Konfiguration: Blueprint wird in app.py registriert
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App
    
    Args:
        app (Flask): Die Flask-App-Instanz
    """
    app.register_blueprint(api_files_bp, url_prefix='/api')
    logger.info("API-Endpunkte für Dateiverwaltung registriert")
