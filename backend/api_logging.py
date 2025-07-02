"""
api_logging.py - API-Endpunkte für Logging-Operationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Logging-Operationen bereit und
dient als Schnittstelle zwischen dem Frontend und dem manage_logging-Modul.
"""

from flask import Blueprint, request, jsonify, send_file
import os
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional, List
from pathlib import Path

from manage_folders import FolderManager, get_log_dir
import manage_logging
from api_auth import token_required
from manage_api import ApiResponse, handle_api_exception

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für die Logging-API erstellen
api_logging = Blueprint('api_logging', __name__)

# FolderManager für Pfadverwaltung
folder_manager = FolderManager()

@api_logging.route('/api/logs', methods=['GET'])
@token_required
def get_logs():
    """API-Endpunkt zum Abrufen von Logs mit Filtern"""
    try:
        # Parameter aus Query extrahieren
        level = request.args.get('level')
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        source = request.args.get('source')
        
        # Parameter validieren
        if limit > 1000:
            return ApiResponse.error(
                "Limit darf maximal 1000 sein",
                error_code=400
            )
            
        if start_date:
            try:
                start_date = datetime.strptime(start_date, '%Y-%m-%d')
            except ValueError:
                return ApiResponse.error(
                    "Ungültiges Startdatum (Format: YYYY-MM-DD)",
                    error_code=400
                )
                
        if end_date:
            try:
                end_date = datetime.strptime(end_date, '%Y-%m-%d')
            except ValueError:
                return ApiResponse.error(
                    "Ungültiges Enddatum (Format: YYYY-MM-DD)",
                    error_code=400
                )
        
        # Logs abrufen
        logs = manage_logging.get_logs(
            level=level,
            limit=limit,
            offset=offset,
            start_date=start_date,
            end_date=end_date,
            source=source
        )
        
        # Metadaten berechnen
        total_count = manage_logging.get_log_count(
            level=level,
            start_date=start_date,
            end_date=end_date,
            source=source
        )
        
        return ApiResponse.success(data={
            'logs': logs,
            'total': total_count,
            'offset': offset,
            'limit': limit,
            'has_more': (offset + limit) < total_count
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Logs: {e}")
        return handle_api_exception(e, endpoint='/api/logs')

@api_logging.route('/api/logs/sources', methods=['GET'])
@token_required
def get_log_sources():
    """API-Endpunkt zum Abrufen verfügbarer Log-Quellen"""
    try:
        sources = manage_logging.get_log_sources()
        return ApiResponse.success(data={
            'sources': sources
        })
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Log-Quellen: {e}")
        return handle_api_exception(e, endpoint='/api/logs/sources')

@api_logging.route('/api/logs/download', methods=['GET'])
@token_required
def download_logs():
    """API-Endpunkt zum Herunterladen von Logs"""
    try:
        # Parameter aus Query extrahieren
        source = request.args.get('source')
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        format_type = request.args.get('format', 'json')
        
        # Parameter validieren
        if format_type not in ['json', 'csv', 'txt']:
            return ApiResponse.error(
                "Ungültiges Format (erlaubt: json, csv, txt)",
                error_code=400
            )
        
        # Logs exportieren
        export_path = manage_logging.export_logs(
            source=source,
            start_date=start_date,
            end_date=end_date,
            format_type=format_type
        )
        
        # Datei zum Download bereitstellen
        filename = f"logs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{format_type}"
        return send_file(
            export_path,
            as_attachment=True,
            download_name=filename,
            mimetype='application/json' if format_type == 'json' else 'text/plain'
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Download der Logs: {e}")
        return handle_api_exception(e, endpoint='/api/logs/download')

@api_logging.route('/api/logs', methods=['DELETE'])
@token_required
def clear_logs():
    """API-Endpunkt zum Löschen von Logs"""
    try:
        # Parameter aus Query extrahieren
        source = request.args.get('source')
        older_than = request.args.get('older_than')  # Format: YYYY-MM-DD
        
        if older_than:
            try:
                older_than = datetime.strptime(older_than, '%Y-%m-%d')
            except ValueError:
                return ApiResponse.error(
                    "Ungültiges Datum (Format: YYYY-MM-DD)",
                    error_code=400
                )
        
        # Backup vor dem Löschen
        backup_path = manage_logging.backup_logs(source)
        
        # Logs löschen
        deleted_count = manage_logging.clear_logs(
            source=source,
            older_than=older_than
        )
        
        return ApiResponse.success(
            message=f"{deleted_count} Logs gelöscht",
            data={
                'deleted_count': deleted_count,
                'backup_path': backup_path
            }
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Löschen der Logs: {e}")
        return handle_api_exception(e, endpoint='/api/logs')

@api_logging.route('/api/logs/level', methods=['PUT'])
@token_required
def set_log_level():
    """API-Endpunkt zum Ändern des Log-Levels"""
    try:
        data = request.get_json()
        if not data or 'level' not in data:
            return ApiResponse.error(
                "Log-Level muss angegeben werden",
                error_code=400
            )
            
        level = data['level'].upper()
        if level not in ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']:
            return ApiResponse.error(
                "Ungültiger Log-Level",
                error_code=400
            )
            
        manage_logging.set_log_level(level)
        return ApiResponse.success(
            message=f"Log-Level auf {level} gesetzt"
        )
        
    except Exception as e:
        logger.error(f"Fehler beim Setzen des Log-Levels: {e}")
        return handle_api_exception(e, endpoint='/api/logs/level')

# Blueprint-Registrierung
def register_blueprint(app):
    """Registriert den Blueprint bei der Flask-App"""
    app.register_blueprint(api_logging)
    logger.info("API-Endpunkte für Logging registriert")
