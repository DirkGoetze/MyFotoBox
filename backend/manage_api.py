"""
manage_api.py - Zentrale API-Verwaltung für Fotobox2 Backend

Dieses Modul bietet eine Abstraktionsschicht für die API-Kommunikation
des Fotobox2-Backend-Systems. Es enthält Hilfsfunktionen für die
einheitliche Formatierung von API-Antworten, die Fehlerbehandlung und
die Validierung der API-Anfragen.
"""

import json
import logging
from flask import jsonify, Response
import manage_logging

# Logger einrichten
logger = logging.getLogger(__name__)

# HTTP-Statuscodes
HTTP_OK = 200
HTTP_BAD_REQUEST = 400
HTTP_UNAUTHORIZED = 401
HTTP_FORBIDDEN = 403
HTTP_NOT_FOUND = 404
HTTP_SERVER_ERROR = 500

class ApiResponse:
    """Klasse zur konsistenten Formatierung von API-Antworten"""
    
    @staticmethod
    def success(data=None, message=None):
        """Erzeugt eine erfolgreiche API-Antwort
        
        Args:
            data: Die Daten, die zurückgegeben werden sollen
            message: Eine optionale Erfolgsmeldung
            
        Returns:
            Ein Flask-Response-Objekt mit den formatierten Daten
        """
        response = {
            'success': True
        }
        
        if data is not None:
            response['data'] = data
            
        if message is not None:
            response['message'] = message
            
        return jsonify(response)
    
    @staticmethod
    def error(message, error_code=HTTP_SERVER_ERROR, details=None):
        """Erzeugt eine Fehler-API-Antwort
        
        Args:
            message: Die Fehlermeldung
            error_code: Der HTTP-Statuscode für den Fehler
            details: Optionale Details zum Fehler
            
        Returns:
            Ein Flask-Response-Objekt mit der Fehlermeldung
        """
        response = {
            'success': False,
            'error': message
        }
        
        if details is not None:
            response['details'] = details
            
        return jsonify(response), error_code

def handle_api_exception(e, endpoint=None, context=None):
    """Zentrale Fehlerbehandlung für API-Aufrufe
    
    Args:
        e: Die aufgetretene Exception
        endpoint: Der API-Endpunkt, auf dem der Fehler aufgetreten ist
        context: Zusätzlicher Kontext für das Logging
        
    Returns:
        Eine formatierte Fehler-API-Antwort
    """
    # Logge den Fehler mit manage_logging
    endpoint_info = f" bei {endpoint}" if endpoint else ""
    manage_logging.error(f"API-Fehler{endpoint_info}: {str(e)}", 
                       exception=e, 
                       context=context,
                       source="api_handler")
    
    # Gib eine standardisierte API-Fehlerantwort zurück
    return ApiResponse.error(str(e))

def validate_request_data(data, required_fields=None, field_types=None):
    """Validiert die Daten einer API-Anfrage
    
    Args:
        data: Die zu validierenden Daten (typischerweise der JSON-Body einer Anfrage)
        required_fields: Eine Liste mit Pflichtfeldern
        field_types: Ein dict mit Feldnamen und erwarteten Typen
        
    Returns:
        (bool, str): Ein Tupel aus dem Validierungsergebnis und einer Fehlermeldung (oder None)
    """
    # Prüfe auf Pflichtfelder
    if required_fields:
        for field in required_fields:
            if field not in data:
                return False, f"Pflichtfeld '{field}' fehlt"
    
    # Prüfe auf korrekte Typen
    if field_types:
        for field, expected_type in field_types.items():
            if field in data and not isinstance(data[field], expected_type):
                return False, f"Feld '{field}' hat falschen Typ. Erwartet: {expected_type.__name__}, " \
                             f"Erhalten: {type(data[field]).__name__}"
    
    return True, None

def format_response_data(data):
    """Formatiert Daten für API-Antworten
    
    Diese Funktion stellt sicher, dass alle Daten korrekt formatiert sind,
    z.B. durch die Konvertierung von Python-Objekten in JSON-serialisierbare Formate.
    
    Args:
        data: Die zu formatierenden Daten
        
    Returns:
        Die formatierten Daten
    """
    # Hier können wir spezifische Formatierungslogik hinzufügen
    # z.B. Konvertierung von Datumsobjekten in Strings usw.
    return data

def log_api_request(endpoint, method, request_data=None, user_id=None):
    """Protokolliert eine API-Anfrage
    
    Args:
        endpoint: Der aufgerufene API-Endpunkt
        method: Die verwendete HTTP-Methode
        request_data: Die übermittelten Daten (falls vorhanden)
        user_id: Die ID des Benutzers (falls bekannt)
    """
    context = {
        'endpoint': endpoint,
        'method': method
    }
    
    if user_id:
        context['user_id'] = user_id
        
    # Sensible Daten vor dem Logging filtern
    filtered_data = None
    if request_data:
        # Tiefe Kopie erstellen, um das Original nicht zu verändern
        try:
            filtered_data = json.loads(json.dumps(request_data))
            # Lösche sensible Felder
            for sensitive_field in ['password', 'admin_password', 'new_password']:
                if sensitive_field in filtered_data:
                    filtered_data[sensitive_field] = '***'
            context['request_data'] = filtered_data
        except Exception:
            # Bei Problemen mit der JSON-Serialisierung einfach keine Daten loggen
            pass
    
    manage_logging.debug(
        f"API-Aufruf: {method} {endpoint}",
        context=context,
        source="api_request"
    )
