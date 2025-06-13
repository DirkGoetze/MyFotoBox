"""
API-Endpunkte für Authentifizierung und Berechtigungen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Authentifizierung, Passwort-
Management und Berechtigungsüberprüfungen bereit. Es fügt die Routen zur Flask-App 
hinzu und verarbeitet die API-Anfragen, indem es die Funktionen aus dem manage_auth-Modul aufruft.
"""

from flask import request, jsonify, session, Blueprint
import logging

# Import der Auth-Funktionen
import manage_auth
import manage_logging

# Logger einrichten
logger = logging.getLogger(__name__)

# Blueprint für Auth-API-Endpunkte erstellen
api_auth = Blueprint('api_auth', __name__)

@api_auth.route('/api/login', methods=['POST'])
def api_login():
    """API-Endpunkt für den Login"""
    try:
        data = request.get_json()
        if not data or 'password' not in data:
            return jsonify({'success': False, 'error': 'Passwort erforderlich'}), 400
        
        password = data['password']
        if manage_auth.check_password(password):
            session['authenticated'] = True
            manage_logging.log_info('Login erfolgreich', 'api_auth')
            return jsonify({'success': True})
        else:
            manage_logging.log_warning('Login fehlgeschlagen: Falsches Passwort', 'api_auth')
            return jsonify({'success': False, 'error': 'Falsches Passwort'}), 401
    
    except Exception as e:
        manage_logging.log_error(f'Login-Fehler: {str(e)}', 'api_auth')
        return jsonify({'success': False, 'error': str(e)}), 500

@api_auth.route('/api/logout', methods=['POST'])
def api_logout():
    """API-Endpunkt für den Logout"""
    try:
        session.pop('authenticated', None)
        manage_logging.log_info('Benutzer ausgeloggt', 'api_auth')
        return jsonify({'success': True})
    except Exception as e:
        manage_logging.log_error(f'Logout-Fehler: {str(e)}', 'api_auth')
        return jsonify({'success': False, 'error': str(e)}), 500

@api_auth.route('/api/session-check', methods=['GET'])
def api_session_check():
    """API-Endpunkt zur Überprüfung der Session"""
    try:
        is_authenticated = session.get('authenticated', False)
        return jsonify({'authenticated': is_authenticated})
    except Exception as e:
        manage_logging.log_error(f'Session-Check-Fehler: {str(e)}', 'api_auth')
        return jsonify({'authenticated': False, 'error': str(e)}), 500

@api_auth.route('/api/password', methods=['POST'])
def api_set_password():
    """API-Endpunkt zum Ändern des Passworts"""
    try:
        # Prüfen, ob Benutzer authentifiziert ist (außer beim Setup)
        is_setup = manage_auth.check_if_setup_needed()
        if not is_setup and not session.get('authenticated', False):
            manage_logging.log_warning('Unautorisierter Zugriff: Passwort-Änderungsversuch', 'api_auth')
            return jsonify({'success': False, 'error': 'Nicht autorisiert'}), 401
        
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'Keine Daten erhalten'}), 400
        
        # Bei Ersteinrichtung
        if is_setup and 'new_password' in data:
            success = manage_auth.set_password(data['new_password'])
            if success:
                manage_logging.log_info('Passwort bei Ersteinrichtung gesetzt', 'api_auth')
                session['authenticated'] = True
                return jsonify({'success': True})
            else:
                manage_logging.log_error('Fehler beim Setzen des ersten Passworts', 'api_auth')
                return jsonify({'success': False, 'error': 'Passwort konnte nicht gesetzt werden'}), 500
        
        # Passwort ändern
        elif 'current_password' in data and 'new_password' in data:
            if manage_auth.check_password(data['current_password']):
                success = manage_auth.set_password(data['new_password'])
                if success:
                    manage_logging.log_info('Passwort erfolgreich geändert', 'api_auth')
                    return jsonify({'success': True})
                else:
                    manage_logging.log_error('Fehler beim Ändern des Passworts', 'api_auth')
                    return jsonify({'success': False, 'error': 'Passwort konnte nicht geändert werden'}), 500
            else:
                manage_logging.log_warning('Passwort-Änderung fehlgeschlagen: Aktuelles Passwort falsch', 'api_auth')
                return jsonify({'success': False, 'error': 'Aktuelles Passwort ist falsch'}), 401
        
        else:
            return jsonify({'success': False, 'error': 'Fehlende Passwort-Informationen'}), 400
    
    except Exception as e:
        manage_logging.log_error(f'Passwort-Änderungsfehler: {str(e)}', 'api_auth')
        return jsonify({'success': False, 'error': str(e)}), 500

@api_auth.route('/api/check-setup', methods=['GET'])
def api_check_setup():
    """API-Endpunkt zur Überprüfung, ob die Ersteinrichtung erforderlich ist"""
    try:
        needs_setup = manage_auth.check_if_setup_needed()
        return jsonify({'setup_required': needs_setup})
    except Exception as e:
        manage_logging.log_error(f'Setup-Check-Fehler: {str(e)}', 'api_auth')
        return jsonify({'error': str(e)}), 500

def init_app(app):
    """Initialisiert die Auth-API mit der Flask-Anwendung"""
    app.register_blueprint(api_auth)
