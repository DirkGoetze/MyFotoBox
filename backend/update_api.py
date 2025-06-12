"""
API-Endpunkte für System-Updates und Abhängigkeitsprüfung in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für System-Updates und 
Abhängigkeitsprüfung bereit. Es fügt die Routen zur Flask-App hinzu und verarbeitet
die API-Anfragen, indem es die Funktionen aus dem manage_update-Modul aufruft.
"""

from flask import request, jsonify, current_app, Blueprint
import os
import logging
import sys
import json
import re

# Import der Update-Funktionen
import manage_update
import manage_auth

# Logger einrichten
logger = logging.getLogger(__name__)

# Blueprint für Update-API-Endpunkte erstellen
update_api = Blueprint('update_api', __name__)

@update_api.route('/api/update', methods=['GET'])
def api_check_updates():
    """API-Endpunkt zum Prüfen auf Updates"""
    try:
        local_version = manage_update.get_local_version() or "0.0.0"
        remote_version = manage_update.get_remote_version() or "0.0.0"
        
        # Status abhängig vom Versionsvergleich
        update_available = local_version != remote_version
        
        return jsonify({
            'success': True,
            'local_version': local_version,
            'remote_version': remote_version,
            'update_available': update_available,
            'last_checked': None  # Könnte aus einer DB geladen werden
        })
    except Exception as e:
        logger.error(f"API-Fehler beim Prüfen auf Updates: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
            'local_version': manage_update.get_local_version() or "unbekannt"
        }), 500

@update_api.route('/api/update/dependencies', methods=['GET'])
def api_check_dependencies():
    """API-Endpunkt zum Prüfen der System- und Python-Abhängigkeiten"""
    # Prüfe, ob der Benutzer eingeloggt ist (Administratorzugriff erforderlich)
    if not manage_auth.is_authenticated():
        return jsonify({'success': False, 'error': 'Authentifizierung erforderlich'}), 401
        
    try:
        # Rufe die Funktion aus dem manage_update-Modul auf
        deps_status = manage_update.get_dependencies_status()
        
        return jsonify({
            'success': True,
            'dependencies': deps_status,
            'timestamp': manage_update.datetime.now().isoformat()
        })
    except Exception as e:
        logger.error(f"API-Fehler beim Prüfen der Abhängigkeiten: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@update_api.route('/api/update', methods=['POST'])
def api_install_update():
    """API-Endpunkt zum Installieren eines Updates"""
    # Prüfe, ob der Benutzer eingeloggt ist (Administratorzugriff erforderlich)
    if not manage_auth.is_authenticated():
        return jsonify({'success': False, 'error': 'Authentifizierung erforderlich'}), 401

    try:
        # Optionen aus dem Request extrahieren
        data = request.get_json() or {}
        fix_deps = data.get('fix_dependencies', True)  # Standardmäßig Abhängigkeiten fixen
        
        # Hier würde man das Update starten
        # Da das Update asynchron läuft, starten wir es im Hintergrund
        # und geben nur eine Bestätigung zurück
        
        # Simulierter Aufruf des Update-Skripts (tatsächlich in der Produktionsumgebung als Hintergrundprozess)
        update_args = []
        if fix_deps:
            update_args.append('--fix-dependencies')
        
        # Hier könnte der Hintergrundprozess gestartet werden
        # subprocess.Popen([sys.executable, os.path.join(os.path.dirname(__file__), 'manage_update.py')] + update_args)
        
        logger.info(f"Update-Installation gestartet mit Optionen: {update_args}")
        
        return jsonify({
            'success': True,
            'message': 'Update-Installation gestartet. Der Server wird sich neu starten, wenn das Update abgeschlossen ist.'
        })
    except Exception as e:
        logger.error(f"API-Fehler beim Installieren des Updates: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@update_api.route('/api/update/status', methods=['GET'])
def api_update_status():
    """API-Endpunkt zum Abrufen des aktuellen Update-Status"""
    # In einer realen Implementierung würde man hier den Status des Update-Prozesses abrufen
    # Für diese Demo geben wir einen festen Status zurück
    return jsonify({
        'success': True,
        'status': 'idle',  # Könnte 'idle', 'downloading', 'installing', 'error' sein
        'progress': 0,     # Fortschritt in Prozent (0-100)
        'message': 'Kein Update aktiv',
        'timestamp': manage_update.datetime.now().isoformat()
    })

def init_app(app):
    """Initialisiert das Update-API-Modul mit der Flask-App
    
    Args:
        app: Die Flask-App-Instanz
    """
    app.register_blueprint(update_api)
