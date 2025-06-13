"""
api_uninstall.py - API-Endpunkte für Deinstallationsoperationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Deinstallationsoperationen bereit
und dient als Schnittstelle zwischen dem Frontend und dem manage_uninstall-Modul.
"""

from flask import Blueprint, jsonify, request
import os
import subprocess
import sys
from datetime import datetime
import manage_auth
import manage_logging
import manage_uninstall
import manage_api

# Blueprint für die Deinstallation-API erstellen
api_uninstall = Blueprint('api_uninstall', __name__)

# -------------------------------------------------------------------------------
# API-Endpunkte für Deinstallationsoperationen
# -------------------------------------------------------------------------------

@api_uninstall.route('/api/uninstall/backup-configs', methods=['POST'])
@manage_auth.require_auth
def api_backup_configs():
    """API-Endpunkt für das Sichern von Konfigurationsdateien"""
    try:
        manage_api.log_api_request('/api/uninstall/backup-configs', request.method, 
                                   request_data=request.get_json(force=True) if request.method == 'POST' else None,
                                   user_id=request.cookies.get('user_id'))
        
        if not manage_auth.is_admin():
            manage_logging.warn(f"Nicht autorisierter Zugriff auf Deinstallation-Backup von {request.remote_addr}")
            return jsonify({'success': False, 'error': 'Nicht autorisiert'}), 403
        
        manage_uninstall.backup_configs()
        return jsonify({
            'success': True,
            'message': 'Konfigurationen wurden erfolgreich gesichert'
        })
    except Exception as e:
        manage_logging.error(f"Fehler beim Sichern der Konfigurationen: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_uninstall.route('/api/uninstall/systemd', methods=['POST'])
@manage_auth.require_auth
def api_remove_systemd():
    """API-Endpunkt zum Entfernen des systemd-Services"""
    try:
        manage_api.log_api_request('/api/uninstall/systemd', request.method, 
                                  request_data=request.get_json(force=True) if request.method == 'POST' else None,
                                  user_id=request.cookies.get('user_id'))
        
        if not manage_auth.is_admin():
            manage_logging.warn(f"Nicht autorisierter Zugriff auf Deinstallation-systemd von {request.remote_addr}")
            return jsonify({'success': False, 'error': 'Nicht autorisiert'}), 403
        
        manage_uninstall.backup_and_remove_systemd()
        return jsonify({
            'success': True,
            'message': 'systemd-Service wurde gesichert und entfernt'
        })
    except Exception as e:
        manage_logging.error(f"Fehler beim Entfernen des systemd-Service: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_uninstall.route('/api/uninstall/nginx', methods=['POST'])
@manage_auth.require_auth
def api_remove_nginx():
    """API-Endpunkt zum Entfernen der NGINX-Konfiguration"""
    try:
        manage_api.log_api_request('/api/uninstall/nginx', request.method, 
                                  request_data=request.get_json(force=True) if request.method == 'POST' else None,
                                  user_id=request.cookies.get('user_id'))
        
        if not manage_auth.is_admin():
            manage_logging.warn(f"Nicht autorisierter Zugriff auf Deinstallation-nginx von {request.remote_addr}")
            return jsonify({'success': False, 'error': 'Nicht autorisiert'}), 403
        
        manage_uninstall.backup_and_remove_nginx()
        return jsonify({
            'success': True,
            'message': 'NGINX-Konfiguration wurde gesichert und entfernt'
        })
    except Exception as e:
        manage_logging.error(f"Fehler beim Entfernen der NGINX-Konfiguration: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_uninstall.route('/api/uninstall/project', methods=['POST'])
@manage_auth.require_auth
def api_remove_project():
    """API-Endpunkt zum Entfernen des Projektverzeichnisses"""
    try:
        manage_api.log_api_request('/api/uninstall/project', request.method, 
                                  request_data=request.get_json(force=True) if request.method == 'POST' else None,
                                  user_id=request.cookies.get('user_id'))
        
        if not manage_auth.is_admin():
            manage_logging.warn(f"Nicht autorisierter Zugriff auf Deinstallation-project von {request.remote_addr}")
            return jsonify({'success': False, 'error': 'Nicht autorisiert'}), 403
        
        manage_uninstall.remove_project()
        return jsonify({
            'success': True,
            'message': 'Projektverzeichnis wurde entfernt'
        })
    except Exception as e:
        manage_logging.error(f"Fehler beim Entfernen des Projektverzeichnisses: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_uninstall.route('/api/uninstall/db-cleanup', methods=['POST'])
@manage_auth.require_auth
def api_cleanup_optimize_db():
    """API-Endpunkt zur Bereinigung und Optimierung der Datenbank"""
    try:
        manage_api.log_api_request('/api/uninstall/db-cleanup', request.method, 
                                  request_data=request.get_json(force=True) if request.method == 'POST' else None,
                                  user_id=request.cookies.get('user_id'))
        
        if not manage_auth.is_admin():
            manage_logging.warn(f"Nicht autorisierter Zugriff auf DB-Cleanup von {request.remote_addr}")
            return jsonify({'success': False, 'error': 'Nicht autorisiert'}), 403
        
        manage_uninstall.cleanup_and_optimize_db()
        return jsonify({
            'success': True,
            'message': 'Datenbank wurde bereinigt und optimiert'
        })
    except Exception as e:
        manage_logging.error(f"Fehler bei der Datenbankbereinigung: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_uninstall.route('/api/uninstall/complete', methods=['POST'])
@manage_auth.require_auth
def api_complete_uninstall():
    """API-Endpunkt für den kompletten Deinstallationsprozess"""
    try:
        manage_api.log_api_request('/api/uninstall/complete', request.method, 
                                  request_data=request.get_json(force=True) if request.method == 'POST' else None,
                                  user_id=request.cookies.get('user_id'))
        
        if not manage_auth.is_admin():
            manage_logging.warn(f"Nicht autorisierter Zugriff auf vollständige Deinstallation von {request.remote_addr}")
            return jsonify({'success': False, 'error': 'Nicht autorisiert'}), 403
        
        data = request.get_json(force=True)
        remove_backups = data.get('remove_backups', False)
        
        # Führe die vollständige Deinstallation durch
        manage_uninstall.backup_configs()
        manage_uninstall.backup_and_remove_systemd()
        manage_uninstall.backup_and_remove_nginx()
        manage_uninstall.remove_systemd()
        manage_uninstall.remove_nginx()
        manage_uninstall.remove_project()
        
        # Backup-Verzeichnis entfernen, wenn angefordert
        message = 'Deinstallation abgeschlossen. Backup-Verzeichnis wurde beibehalten.'
        if remove_backups:
            backup_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backup'))
            if os.path.exists(backup_dir):
                import shutil
                try:
                    shutil.rmtree(backup_dir)
                    message = 'Deinstallation abgeschlossen. Backup-Verzeichnis wurde entfernt.'
                except Exception as e:
                    manage_logging.error(f"Fehler beim Entfernen des Backup-Verzeichnisses: {str(e)}", exception=e)
                    return jsonify({
                        'success': True,
                        'message': 'Deinstallation abgeschlossen, aber Backup-Verzeichnis konnte nicht entfernt werden.',
                        'error': str(e)
                    })
        
        return jsonify({
            'success': True,
            'message': message
        })
    except Exception as e:
        manage_logging.error(f"Fehler bei der vollständigen Deinstallation: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

def init_app(app):
    """Initialisiert die Uninstall-API mit der Flask-Anwendung"""
    app.register_blueprint(api_uninstall)
