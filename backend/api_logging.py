"""
api_logging.py - API-Endpunkte für Logging-Operationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Logging-Operationen bereit und
dient als Schnittstelle zwischen dem Frontend und dem manage_logging-Modul.
"""

from flask import Blueprint, request, jsonify, send_file, session
import os
import json
import datetime
import manage_logging
import manage_auth

# Blueprint für die Logging-API erstellen
api_logging = Blueprint('api_logging', __name__)

# -------------------------------------------------------------------------------
# API-Endpunkte für Logging-Operationen
# -------------------------------------------------------------------------------

@api_logging.route('/api/logs', methods=['POST'])
@manage_auth.login_required
def api_get_logs():
    """
    Ruft Logs basierend auf den angegebenen Filtern ab
    """
    data = request.get_json(force=True)
    level = data.get('level')
    limit = data.get('limit', 100)
    offset = data.get('offset', 0)
    start_date = data.get('startDate')
    end_date = data.get('endDate')
    source = data.get('source')
    
    logs = manage_logging.get_logs(
        level=level,
        limit=limit,
        offset=offset,
        start_date=start_date,
        end_date=end_date,
        source=source
    )
    
    return jsonify({'logs': logs})

@api_logging.route('/api/logs/clear', methods=['POST'])
@manage_auth.login_required
def api_clear_logs():
    """
    Löscht Logs basierend auf den angegebenen Filtern
    """
    data = request.get_json(force=True)
    older_than = data.get('older_than')
    
    deleted_count = manage_logging.clear_logs(older_than=older_than)
    
    return jsonify({
        'success': True,
        'deleted_count': deleted_count
    })

@api_logging.route('/api/log', methods=['POST'])
def api_log():
    """
    Speichert einen einzelnen Log-Eintrag vom Client
    """
    data = request.get_json(force=True)
    level = data.get('level', 'INFO')
    message = data.get('message', '')
    context = data.get('context')
    source = data.get('source', 'frontend')
    user_id = session.get('user_id')
    
    # Validierung des Log-Levels
    valid_levels = ['DEBUG', 'INFO', 'WARNING', 'ERROR']
    if level not in valid_levels:
        level = 'INFO'
    
    # Log entsprechend dem Level speichern
    if level == 'DEBUG':
        manage_logging.debug(message, context=context, source=source, user_id=user_id)
    elif level == 'WARNING':
        manage_logging.warn(message, context=context, source=source, user_id=user_id)
    elif level == 'ERROR':
        manage_logging.error(message, context=context, source=source, user_id=user_id)
    else:  # INFO
        manage_logging.log(message, context=context, source=source, user_id=user_id)
    
    return jsonify({'success': True})

@api_logging.route('/api/logs/batch', methods=['POST'])
def api_log_batch():
    """
    Speichert mehrere Log-Einträge vom Client
    """
    data = request.get_json(force=True)
    logs = data.get('logs', [])
    user_id = session.get('user_id')
    
    for log_entry in logs:
        level = log_entry.get('level', 'INFO')
        message = log_entry.get('message', '')
        context = log_entry.get('context')
        source = log_entry.get('source', 'frontend')
        
        # Validierung des Log-Levels
        valid_levels = ['DEBUG', 'INFO', 'WARNING', 'ERROR']
        if level not in valid_levels:
            level = 'INFO'
        
        # Log entsprechend dem Level speichern
        if level == 'DEBUG':
            manage_logging.debug(message, context=context, source=source, user_id=user_id)
        elif level == 'WARNING':
            manage_logging.warn(message, context=context, source=source, user_id=user_id)
        elif level == 'ERROR':
            manage_logging.error(message, context=context, source=source, user_id=user_id)
        else:  # INFO
            manage_logging.log(message, context=context, source=source, user_id=user_id)
    
    return jsonify({'success': True})

@api_logging.route('/api/logs/export', methods=['GET'])
@manage_auth.login_required
def api_export_logs():
    """Exportiert Logs als Datei"""
    try:
        # Filter-Parameter
        level = request.args.get('level')
        source = request.args.get('source')
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        format_type = request.args.get('format', 'json').lower()
        
        # Logs abrufen mit allen verfügbaren Einträgen (kein Limit)
        logs = manage_logging.get_logs(
            level=level,
            source=source,
            start_date=start_date,
            end_date=end_date,
            limit=100000  # Sehr hoher Wert, um praktisch alle Logs zu bekommen
        )
        
        # Temporäre Export-Datei erstellen
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"logs_export_{timestamp}"
        
        if format_type == 'csv':
            # CSV-Format
            filename += ".csv"
            export_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'exports', filename)
            os.makedirs(os.path.dirname(export_path), exist_ok=True)
            
            import csv
            with open(export_path, 'w', newline='', encoding='utf-8') as csvfile:
                fieldnames = ['timestamp', 'level', 'message', 'source', 'user_id', 'context']
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                for log in logs:
                    writer.writerow({
                        'timestamp': log.get('timestamp', ''),
                        'level': log.get('level', ''),
                        'message': log.get('message', ''),
                        'source': log.get('source', ''),
                        'user_id': log.get('user_id', ''),
                        'context': json.dumps(log.get('context', {}))
                    })
        else:
            # JSON-Format (Standard)
            filename += ".json"
            export_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'exports', filename)
            os.makedirs(os.path.dirname(export_path), exist_ok=True)
            
            with open(export_path, 'w', encoding='utf-8') as jsonfile:
                json.dump(logs, jsonfile, ensure_ascii=False, indent=2)
        
        # Log-Eintrag über den Export
        manage_logging.log(f"Logs wurden exportiert: {filename}", source="api_logging")
        
        # Datei zum Download anbieten
        return send_file(export_path, as_attachment=True, download_name=filename)
        
    except Exception as e:
        manage_logging.error(f"Fehler beim Exportieren der Logs: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_logging.route('/api/logs/levels', methods=['GET'])
@manage_auth.login_required
def api_get_log_levels():
    """Gibt verfügbare Log-Level zurück"""
    try:
        levels = manage_logging.get_log_levels()
        return jsonify({'success': True, 'levels': levels})
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Log-Level: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_logging.route('/api/logs/sources', methods=['GET'])
@manage_auth.login_required
def api_get_log_sources():
    """Gibt verfügbare Log-Quellen zurück"""
    try:
        sources = manage_logging.get_log_sources()
        return jsonify({'success': True, 'sources': sources})
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Log-Quellen: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

def init_app(app):
    """Initialisiert die Logging-API mit der Flask-Anwendung"""
    app.register_blueprint(api_logging)
