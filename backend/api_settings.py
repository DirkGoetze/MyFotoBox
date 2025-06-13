"""
api_settings.py - API-Endpunkte für Einstellungsverwaltung in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für die Verwaltung von Einstellungen
bereit und dient als Schnittstelle zwischen dem Frontend und dem manage_settings-Modul.
"""

from flask import Blueprint, request, jsonify, session
import sqlite3
import os
import json

import manage_settings
import manage_logging
import manage_auth
import manage_api

# Blueprint für die Settings-API erstellen
api_settings = Blueprint('api_settings', __name__)

# DB-Pfad
DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')

# -------------------------------------------------------------------------------
# API-Endpunkte für Einstellungsverwaltung
# -------------------------------------------------------------------------------

@api_settings.route('/api/settings', methods=['GET', 'POST'])
def api_settings_handler():
    """API-Endpunkt zur Verwaltung von Einstellungen (Abrufen und Speichern)"""
    try:
        db = sqlite3.connect(DB_PATH)
        cur = db.cursor()
        cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        
        # API-Anfrage protokollieren
        manage_api.log_api_request('/api/settings', request.method, 
                                  request_data=request.get_json(force=True) if request.method == 'POST' else None, 
                                  user_id=session.get('user_id'))
        
        if request.method == 'POST':
            data = request.get_json(force=True)
            # Alle Einstellungen aus dem Frontend verarbeiten
            allowed_keys = [
                'camera_mode', 'resolution_width', 'resolution_height', 
                'storage_path', 'event_name', 'event_date', 'show_splash', 'photo_timer',
                'color_mode', 'screensaver_timeout', 'gallery_timeout',
                'camera_id', 'flash_mode', 'countdown_duration'
            ]
            
            # Log der Einstellungsänderung
            manage_logging.log(f"Einstellungen werden aktualisiert. Geänderte Schlüssel: {', '.join([k for k in data if k in allowed_keys])}")
            
            for key in data:
                if key in allowed_keys:
                    # Alle Werte als String speichern
                    cur.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (key, str(data[key])))
                    
            # Admin-Passwort setzen/ändern - Unterstütze sowohl new_password (settings.html) als auch admin_password (install.html)
            password_key = None
            if 'new_password' in data and data['new_password'] and len(data['new_password']) >= 4:
                password_key = 'new_password'
                manage_logging.log("Administratorpasswort wird geändert")
            elif 'admin_password' in data and data['admin_password'] and len(data['admin_password']) >= 4:
                password_key = 'admin_password'
                manage_logging.log("Neues Administratorpasswort wird gesetzt")
                
            if password_key:
                # Nutze manage_auth zum Setzen des Passworts
                manage_auth.set_password(data[password_key])
            
            db.commit()
            db.close()
            manage_logging.log("Einstellungen erfolgreich gespeichert")
            return manage_api.ApiResponse.success(message="Einstellungen erfolgreich gespeichert")
            
        # GET
        manage_logging.log("Aktuelle Einstellungen werden abgerufen")
        cur.execute("SELECT key, value FROM settings")
        result = {k: v for k, v in cur.fetchall()}
        # show_splash als bool zurückgeben (Default: '1')
        if 'show_splash' not in result:
            result['show_splash'] = '1'
        if 'photo_timer' not in result:
            result['photo_timer'] = '5'
        db.close()
        
        # Formatierte Antwort zurückgeben
        return manage_api.ApiResponse.success(data=result)
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint='/api/settings')

@api_settings.route('/api/settings/<key>', methods=['GET', 'PUT'])
def api_settings_item(key):
    """API-Endpunkt zum Verwalten einzelner Einstellungen"""
    try:
        # API-Anfrage protokollieren
        manage_api.log_api_request(f'/api/settings/{key}', request.method, 
                                 request_data=request.get_json(force=True) if request.method == 'PUT' else None, 
                                 user_id=session.get('user_id'))
        
        db = sqlite3.connect(DB_PATH)
        cur = db.cursor()
        
        if request.method == 'PUT':
            # Einzelne Einstellung aktualisieren
            data = request.get_json(force=True)
            value = data.get('value')
            
            if value is None:
                db.close()
                return jsonify({'success': False, 'error': 'Wert fehlt'}), 400
            
            cur.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (key, str(value)))
            db.commit()
            db.close()
            
            manage_logging.log(f"Einstellung '{key}' wurde auf '{value}' gesetzt")
            return manage_api.ApiResponse.success(message=f"Einstellung {key} erfolgreich aktualisiert")
        
        # GET: Einzelne Einstellung abrufen
        cur.execute("SELECT value FROM settings WHERE key = ?", (key,))
        result = cur.fetchone()
        db.close()
        
        if result:
            return manage_api.ApiResponse.success(data={key: result[0]})
        else:
            return jsonify({'success': False, 'error': f'Einstellung {key} nicht gefunden'}), 404
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint=f'/api/settings/{key}')

@api_settings.route('/api/settings/reset', methods=['POST'])
@manage_auth.require_auth
def api_reset_settings():
    """API-Endpunkt zum Zurücksetzen aller Einstellungen"""
    try:
        # API-Anfrage protokollieren
        manage_api.log_api_request('/api/settings/reset', request.method, 
                                 user_id=session.get('user_id'))
        
        # Prüfe, ob bestimmte Einstellungen ausgenommen werden sollen
        data = request.get_json(force=True)
        exclude = data.get('exclude', []) if data else []
        
        db = sqlite3.connect(DB_PATH)
        cur = db.cursor()
        
        # Entweder alle Einstellungen löschen oder nur bestimmte
        if exclude:
            # Konvertiere Liste zu SQL-Platzhaltern
            placeholders = ','.join(['?' for _ in exclude])
            cur.execute(f"DELETE FROM settings WHERE key NOT IN ({placeholders})", exclude)
        else:
            cur.execute("DELETE FROM settings")
        
        db.commit()
        db.close()
        
        manage_logging.log(f"Einstellungen wurden zurückgesetzt (Ausnahmen: {', '.join(exclude)})")
        return manage_api.ApiResponse.success(message="Einstellungen wurden zurückgesetzt")
    except Exception as e:
        return manage_api.handle_api_exception(e, endpoint='/api/settings/reset')

def init_app(app):
    """Initialisiert die Settings-API mit der Flask-Anwendung"""
    app.register_blueprint(api_settings)
