"""
app.py - Hauptmodul der Fotobox2 Backend-Anwendung

Dieses Modul initialisiert die Flask-Anwendung und konfiguriert alle
notwendigen Erweiterungen, Blueprints und Middleware-Komponenten.
"""

from flask import Flask, request, jsonify, session
from flask_cors import CORS
import os
import logging
import sys
from werkzeug.middleware.proxy_fix import ProxyFix

# Importiere Kernmodule
import manage_logging
import manage_folders
import manage_auth
import manage_settings  # TODO: Anpassung für neue Settings-API (hierarchische Schlüssel und DB-Backend)
import manage_database  # TODO: Integration mit manage_database.sh für zentralisierte Datenbankoperationen
import manage_backend_service

# Importiere API-Module
import api_auth
import api_camera
import api_camera_config
import api_database
import api_files
import api_filesystem
import api_folders
import api_logging
import api_settings
import api_update
import api_backend_service

# Logging einrichten (vor Flask-App-Erstellung)
manage_logging.setup_logging()
logger = logging.getLogger(__name__)

def create_app(test_config=None):
    """Factory-Funktion zur Erstellung der Flask-App"""
    
    # Flask-App erstellen
    app = Flask(__name__)
    
    # Konfiguration laden
    if test_config is None:
        # Produktionskonfiguration
        app.config.from_object('config.ProductionConfig')
        # Umgebungsvariablen überschreiben Standardkonfiguration
        if os.environ.get('FOTOBOX_CONFIG'):
            app.config.from_envvar('FOTOBOX_CONFIG')
    else:
        # Testkonfiguration
        app.config.from_mapping(test_config)
    
    # Secret Key setzen
    app.secret_key = os.environ.get('FOTOBOX_SECRET_KEY', os.urandom(24))
    
    # CORS konfigurieren
    CORS(app, resources={
        r"/api/*": {
            "origins": app.config.get('CORS_ORIGINS', "*"),
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"]
        }
    })
    
    # Proxy-Konfiguration (für nginx)
    app.wsgi_app = ProxyFix(
        app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1
    )
    
    # Blueprints registrieren
    api_auth.register_blueprint(app)
    api_camera.register_blueprint(app)
    api_camera_config.register_blueprint(app)
    api_database.register_blueprint(app)
    api_files.register_blueprint(app)
    api_filesystem.register_blueprint(app)
    api_folders.register_blueprint(app)
    api_logging.register_blueprint(app)
    api_settings.register_blueprint(app)
    api_update.register_blueprint(app)
    api_backend_service.register_blueprint(app)
    
    # Fehlerbehandlung
    @app.errorhandler(400)
    def bad_request(error):
        return jsonify({
            'success': False,
            'error': 'Ungültige Anfrage',
            'details': str(error)
        }), 400

    @app.errorhandler(401)
    def unauthorized(error):
        return jsonify({
            'success': False,
            'error': 'Nicht autorisiert'
        }), 401

    @app.errorhandler(403)
    def forbidden(error):
        return jsonify({
            'success': False,
            'error': 'Zugriff verweigert'
        }), 403

    @app.errorhandler(404)
    def not_found(error):
        return jsonify({
            'success': False,
            'error': 'Ressource nicht gefunden'
        }), 404

    @app.errorhandler(500)
    def server_error(error):
        logger.error(f"Interner Serverfehler: {error}")
        return jsonify({
            'success': False,
            'error': 'Interner Serverfehler'
        }), 500

    # Globale Middleware für Logging
    @app.before_request
    def log_request_info():
        logger.debug(f"Request: {request.method} {request.path}")

    @app.after_request
    def log_response_info(response):
        logger.debug(f"Response: {response.status}")
        return response
    
    return app

# Anwendung starten
if __name__ == '__main__':
    app = create_app()
    port = int(os.environ.get('FOTOBOX_PORT', 5000))
    debug = os.environ.get('FOTOBOX_DEBUG', '0').lower() in ('true', '1', 't')
    
    try:
        # Stelle sicher, dass alle notwendigen Verzeichnisse existieren
        manage_folders.init_folders()
        
        # Stelle sicher, dass die Einstellungen initialisiert sind
        manage_settings.load_settings()
        
        # Starte die Anwendung
        logger.info(f"Starte Fotobox2 Backend auf Port {port} (Debug: {debug})")
        app.run(
            host='0.0.0.0',
            port=port,
            debug=debug,
            use_reloader=debug
        )
    except Exception as e:
        logger.error(f"Fehler beim Starten der Anwendung: {e}")
        sys.exit(1)
