import sqlite3
from flask import Flask, request, jsonify, session, redirect, url_for, render_template_string, send_from_directory
import os
import subprocess
import bcrypt
import re
import json

# Importiere die Module
import manage_auth
import manage_logging
import manage_database

# -------------------------------------------------------------------------------
# DB_PATH und Datenverzeichnis sicherstellen
# -------------------------------------------------------------------------------
DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')
os.makedirs(DB_DIR, exist_ok=True)

app = Flask(__name__)
app.secret_key = os.environ.get('FOTOBOX_SECRET_KEY', 'fotobox_default_secret')

# Cache-Kontrolle für die Testphase
@app.after_request
def add_no_cache_headers(response):
    """
    Fügt No-Cache-Header zu allen Antworten für die Testphase hinzu
    """
    # Prüfe, ob wir uns im Testmodus befinden
    test_mode = os.environ.get('FOTOBOX_TEST_MODE', 'true').lower() == 'true'
    
    if test_mode:
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        
        # Debug-Header hinzufügen, um zu zeigen, dass die Cache-Deaktivierung aktiv ist
        response.headers['X-Fotobox-Test-Mode'] = 'active'
    
    return response

# Datenbank initialisieren (bei jedem Start sicherstellen)
subprocess.run(['python3', os.path.join(os.path.dirname(__file__), 'manage_database.py'), 'init'])

# -------------------------------------------------------------------------------
# check_first_run
# -------------------------------------------------------------------------------
# Funktion: Prüft, ob die Fotobox das erste Mal aufgerufen wird (keine Konfiguration vorhanden)
# Rückgabe: True = erste Inbetriebnahme, False = Konfiguration vorhanden
# -------------------------------------------------------------------------------
def check_first_run():
    return not manage_auth.is_password_set()

# -------------------------------------------------------------------------------
# / (Root-Route)
# -------------------------------------------------------------------------------
@app.route('/')
def root():
    if check_first_run():
        manage_logging.log("Erste Inbetriebnahme erkannt - Weiterleitung zur Setup-Seite")
        return redirect('/setup.html')
    manage_logging.debug("Startseite wird angezeigt")
    return send_from_directory('../frontend', 'index.html')

# -------------------------------------------------------------------------------
# /login (GET, POST)
# -------------------------------------------------------------------------------
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        pw = request.form.get('password', '')
        if manage_auth.login(pw):
            manage_logging.log(f"Erfolgreicher Web-Login von IP {request.remote_addr}")
            return redirect(url_for('config'))
        else:
            manage_logging.warn(f"Fehlgeschlagener Web-Login-Versuch von IP {request.remote_addr}")
            return render_template_string('<h3>Falsches Passwort!</h3><a href="/login">Zurück</a>')
    return render_template_string('<form method="post">\n        <h3>Fotobox Konfiguration Login</h3>\n        Passwort: <input type="password" name="password" autofocus>\n        <input type="submit" value="Login">\n    </form>')

# -------------------------------------------------------------------------------
# /logout
# -------------------------------------------------------------------------------
@app.route('/logout')
def logout():
    manage_logging.log("Benutzer-Logout durchgeführt")
    manage_auth.logout()
    return redirect(url_for('login'))

# -------------------------------------------------------------------------------
# /config (GET)
# -------------------------------------------------------------------------------
@app.route('/config')
@manage_auth.login_required
def config():
    if check_first_run():
        manage_logging.log("Zugriff auf /config während Ersteinrichtung - Weiterleitung zur Setup-Seite")
        return redirect('/setup.html')
    manage_logging.debug("Konfigurationsseite wird angezeigt")
    return render_template_string('<h2>Fotobox Konfiguration</h2>\n    <a href="/logout">Logout</a>')

# -------------------------------------------------------------------------------
# /api/login (POST)
# -------------------------------------------------------------------------------
@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.get_json(force=True)
    pw = data.get('password', '')
    if manage_auth.login(pw):
        manage_logging.log(f"Erfolgreicher Login von IP {request.remote_addr}")
        return jsonify({'success': True})
    else:
        manage_logging.warn(f"Fehlgeschlagener Login-Versuch von IP {request.remote_addr}")
        return jsonify({'success': False}), 401

# -------------------------------------------------------------------------------
# /api/settings (GET, POST)
# -------------------------------------------------------------------------------
@app.route('/api/settings', methods=['GET', 'POST'])
def api_settings():
    db = sqlite3.connect(DB_PATH)
    cur = db.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    
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
        return jsonify({'status': 'ok'})
        
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
    return jsonify(result)

# -------------------------------------------------------------------------------
# /api/check_password_set (GET)
# -------------------------------------------------------------------------------
# Funktion: Prüft, ob ein Admin-Passwort gesetzt ist (für Erstinstallation)
# -------------------------------------------------------------------------------
@app.route('/api/check_password_set', methods=['GET'])
def api_check_password_set():
    is_password_set = manage_auth.is_password_set()
    manage_logging.debug(f"Passwort-Status-Check: Passwort ist {'gesetzt' if is_password_set else 'nicht gesetzt'}")
    return jsonify({'password_set': is_password_set})

# -------------------------------------------------------------------------------
# /api/session-check (GET)
# -------------------------------------------------------------------------------
@app.route('/api/session-check', methods=['GET'])
def api_session_check():
    """
    Endpunkt zur Überprüfung des Authentifizierungsstatus
    """
    status = manage_auth.get_login_status()
    if status.get('authenticated', False):
        manage_logging.debug(f"Session-Check: Benutzer ist authentifiziert")
    else:
        manage_logging.debug(f"Session-Check: Keine aktive Authentifizierung")
    return jsonify(status)

# -------------------------------------------------------------------------------
# /api/logs (GET)
# -------------------------------------------------------------------------------
@app.route('/api/logs', methods=['POST'])
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

# -------------------------------------------------------------------------------
# /api/logs/clear (POST)
# -------------------------------------------------------------------------------
@app.route('/api/logs/clear', methods=['POST'])
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

# -------------------------------------------------------------------------------
# /api/log (POST) - Einzelner Log vom Client
# -------------------------------------------------------------------------------
@app.route('/api/log', methods=['POST'])
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

# -------------------------------------------------------------------------------
# /api/logs/batch (POST) - Batch-Logging vom Client
# -------------------------------------------------------------------------------
@app.route('/api/logs/batch', methods=['POST'])
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

# -------------------------------------------------------------------------------
# Error-Handler mit Logging
# -------------------------------------------------------------------------------
@app.errorhandler(404)
def page_not_found(e):
    """404-Handler mit Logging"""
    path = request.path
    ip = request.remote_addr
    manage_logging.warn(f"404 Nicht gefunden: {path}", context={'ip': ip}, source="error_handler")
    return jsonify({'error': 'not_found', 'message': 'Die angeforderte Resource wurde nicht gefunden'}), 404

@app.errorhandler(500)
def server_error(e):
    """500-Handler mit Logging"""
    path = request.path
    ip = request.remote_addr
    manage_logging.error(f"500 Server-Fehler: {path}", exception=e, context={'ip': ip}, source="error_handler")
    return jsonify({'error': 'server_error', 'message': 'Ein interner Serverfehler ist aufgetreten'}), 500

@app.errorhandler(403)
def forbidden(e):
    """403-Handler mit Logging"""
    path = request.path
    ip = request.remote_addr
    manage_logging.warn(f"403 Verboten: {path}", context={'ip': ip}, source="error_handler")
    return jsonify({'error': 'forbidden', 'message': 'Zugriff verweigert'}), 403

@app.errorhandler(401)
def unauthorized(e):
    """401-Handler mit Logging"""
    path = request.path
    ip = request.remote_addr
    manage_logging.warn(f"401 Nicht autorisiert: {path}", context={'ip': ip}, source="error_handler")
    return jsonify({'error': 'unauthorized', 'message': 'Authentifizierung erforderlich'}), 401

# -------------------------------------------------------------------------------
# API-Endpunkte für Datenbankoperationen
# -------------------------------------------------------------------------------

@app.route('/api/database/query', methods=['POST'])
@manage_auth.require_auth
def db_query():
    """API-Endpunkt für Datenbankabfragen"""
    try:
        data = request.get_json()
        sql = data.get('sql')
        params = data.get('params')
        
        if not sql:
            return jsonify({'success': False, 'error': 'SQL-Statement fehlt'}), 400
            
        # SQL-Injection-Prüfung
        if not manage_auth.is_admin():
            # Einfache Sicherheitsprüfung für Nicht-Admins
            forbidden_patterns = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'CREATE', 'TRUNCATE']
            if any(pattern in sql.upper() for pattern in forbidden_patterns):
                manage_logging.warn(f"Versuchter SQL-Injection-Angriff: {sql}", 
                                  context={'user_id': session.get('user_id')})
                return jsonify({'success': False, 'error': 'Operation nicht erlaubt'}), 403
        
        # Führe die Abfrage durch
        result = manage_database.query(sql, params)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler bei DB-Abfrage: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/database/insert', methods=['POST'])
@manage_auth.require_auth
def db_insert():
    """API-Endpunkt zum Einfügen von Daten"""
    try:
        data = request.get_json()
        table = data.get('table')
        insert_data = data.get('data')
        
        if not table or not insert_data:
            return jsonify({'success': False, 'error': 'Tabelle oder Daten fehlen'}), 400
            
        # Führe den Insert durch
        result = manage_database.insert(table, insert_data)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim DB-Insert: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/database/update', methods=['POST'])
@manage_auth.require_auth
def db_update():
    """API-Endpunkt zum Aktualisieren von Daten"""
    try:
        data = request.get_json()
        table = data.get('table')
        update_data = data.get('data')
        condition = data.get('condition')
        params = data.get('params')
        
        if not table or not update_data or not condition:
            return jsonify({'success': False, 'error': 'Tabelle, Daten oder Bedingung fehlen'}), 400
            
        # Führe das Update durch
        result = manage_database.update(table, update_data, condition, params)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim DB-Update: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/database/delete', methods=['POST'])
@manage_auth.require_auth
def db_delete():
    """API-Endpunkt zum Löschen von Daten"""
    try:
        data = request.get_json()
        table = data.get('table')
        condition = data.get('condition')
        params = data.get('params')
        
        if not table or not condition:
            return jsonify({'success': False, 'error': 'Tabelle oder Bedingung fehlen'}), 400
            
        # Führe das Delete durch
        result = manage_database.delete(table, condition, params)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim DB-Delete: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/database/settings/<key>', methods=['GET'])
@manage_auth.require_auth
def get_db_setting(key):
    """API-Endpunkt zum Abrufen einer Einstellung"""
    try:
        value = manage_database.get_setting(key)
        if value is None:
            return jsonify({'success': False, 'error': 'Einstellung nicht gefunden'}), 404
        return jsonify({'success': True, 'data': value})
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Einstellung {key}: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/database/settings', methods=['POST'])
@manage_auth.require_auth
def set_db_setting():
    """API-Endpunkt zum Speichern einer Einstellung"""
    try:
        data = request.get_json()
        key = data.get('key')
        value = data.get('value')
        
        if not key:
            return jsonify({'success': False, 'error': 'Schlüssel fehlt'}), 400
            
        result = manage_database.set_setting(key, value)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim Speichern der Einstellung: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/database/check-integrity', methods=['GET'])
@manage_auth.require_auth
def check_db_integrity():
    """API-Endpunkt zur Überprüfung der Datenbankintegrität"""
    try:
        result = manage_database.check_integrity()
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler bei der Datenbankintegritätsprüfung: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/database/stats', methods=['GET'])
@manage_auth.require_auth
def get_db_stats():
    """API-Endpunkt zum Abrufen von Datenbankstatistiken"""
    try:
        # Hier müssen wir die Statistiken manuell sammeln, da diese nicht direkt in manage_database implementiert sind
        conn = manage_database.connect_db()
        cursor = conn.cursor()
        
        # Tabellen auflisten
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row['name'] for row in cursor.fetchall()]
        
        # Statistiken pro Tabelle sammeln
        stats = {}
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) as count FROM {table}")
            count_result = cursor.fetchone()
            count = count_result['count'] if count_result else 0
            stats[table] = {'rows': count}
        
        # Datenbankgröße ermitteln
        db_size = os.path.getsize(manage_database.DB_PATH) if os.path.exists(manage_database.DB_PATH) else 0
        
        conn.close()
        
        return jsonify({
            'success': True,
            'data': {
                'tables': tables,
                'stats': stats,
                'size_bytes': db_size,
                'size_mb': round(db_size / (1024 * 1024), 2)
            }
        })
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Datenbankstatistiken: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

# -------------------------------------------------------------------------------
# Flask-Anwendung starten, wenn Skript direkt aufgerufen wird
# -------------------------------------------------------------------------------
if __name__ == '__main__':
    # Initialisiere die Anwendung
    manage_logging.log("Fotobox Backend wurde gestartet", source="app_startup")
    app.run(debug=True, host='0.0.0.0')
