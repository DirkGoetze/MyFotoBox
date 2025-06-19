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
import manage_files
import manage_api
import manage_camera  # Neu importiert für Kamerafunktionalität
import manage_backend_service  # Neu importiert für Backend-Service-Verwaltung

# Importiere die API-Module
import api_auth
import api_camera
import api_camera_config
import api_database
import api_filesystem
import api_logging
import api_settings
import api_uninstall
import api_update
import api_backend_service  # Neu importiert für Backend-Service API

# -------------------------------------------------------------------------------
# DB_PATH und Datenverzeichnis sicherstellen
# -------------------------------------------------------------------------------
DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')
os.makedirs(DB_DIR, exist_ok=True)

app = Flask(__name__)
app.secret_key = os.environ.get('FOTOBOX_SECRET_KEY', 'fotobox_default_secret')

# Registriere Blueprints für API-Module
app.register_blueprint(api_auth.api_auth)
app.register_blueprint(api_camera.api_camera)
app.register_blueprint(api_camera_config.api_camera_config)
app.register_blueprint(api_database.api_database)
app.register_blueprint(api_filesystem.api_filesystem)
app.register_blueprint(api_logging.api_logging)
app.register_blueprint(api_settings.api_settings)
app.register_blueprint(api_uninstall.api_uninstall)
app.register_blueprint(api_update.api_update)
app.register_blueprint(api_backend_service.api_backend_service, url_prefix='/api/backend_service')

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
# API-Routen wurden in die entsprechenden API-Module ausgelagert
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Diese Route wurde in das settings_api.py Modul ausgelagert
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Diese Routen wurden in das auth_api.py Modul ausgelagert
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Diese Routen wurden in das logging_api.py Modul ausgelagert
# -------------------------------------------------------------------------------

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
# Diese Routen wurden in das database_api.py Modul ausgelagert
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Flask-Anwendung starten, wenn Skript direkt aufgerufen wird
# -------------------------------------------------------------------------------
# Register API Blueprints
# -------------------------------------------------------------------------------
# Initialisiere alle API-Module
api_auth.init_app(app)
api_camera.init_app(app)
api_camera_config.init_app(app)
api_database.init_app(app)
api_filesystem.init_app(app)
api_logging.init_app(app)
api_settings.init_app(app)
api_uninstall.init_app(app)
api_update.init_app(app)

# -------------------------------------------------------------------------------
if __name__ == '__main__':
    # Initialisiere die Anwendung
    manage_logging.log("Fotobox Backend wurde gestartet", source="app_startup")
    app.run(debug=True, host='0.0.0.0')
