"""
manage_api.py - Zentrale API-Verwaltung für Fotobox2 Backend

Dieses Modul bietet eine Abstraktionsschicht für die API-Kommunikation
des Fotobox2-Backend-Systems. Es enthält Hilfsfunktionen für die
einheitliche Formatierung von API-Antworten, die Fehlerbehandlung und
die Validierung der API-Anfragen.
"""

import json
import logging
import os
from typing import Any, Dict, Optional, Union
from datetime import datetime
from flask import jsonify, Response

# Initialisiere Basis-Logging für API-Modul
logger = logging.getLogger(__name__)

# Versuche manage_logging zu importieren, mit Fallback auf Standard-Logging
try:
    import manage_logging
    CUSTOM_LOGGING = True
except ImportError:
    logger.warning("manage_logging nicht verfügbar, verwende Standard-Logging")
    CUSTOM_LOGGING = False

# HTTP-Statuscodes
HTTP_OK = 200
HTTP_BAD_REQUEST = 400
HTTP_UNAUTHORIZED = 401
HTTP_FORBIDDEN = 403
HTTP_NOT_FOUND = 404
HTTP_SERVER_ERROR = 500

def log_api_call(endpoint: str, method: str, status_code: int, 
                error: Optional[str] = None) -> None:
    """
    Protokolliert einen API-Aufruf
    
    Args:
        endpoint: Der aufgerufene API-Endpunkt
        method: Die HTTP-Methode
        status_code: Der HTTP-Statuscode
        error: Optional - Eine Fehlermeldung
    """
    message = f"API-Aufruf: {method} {endpoint} -> {status_code}"
    context = {
        'endpoint': endpoint,
        'method': method,
        'status_code': status_code,
        'timestamp': datetime.now().isoformat()
    }
    
    if error:
        context['error'] = error
    
    if CUSTOM_LOGGING:
        if status_code >= 500:
            manage_logging.error(message, context=context, source='api')
        elif status_code >= 400:
            manage_logging.warn(message, context=context, source='api')
        else:
            manage_logging.log(message, context=context, source='api')
    else:
        if status_code >= 500:
            logger.error(message, extra=context)
        elif status_code >= 400:
            logger.warning(message, extra=context)
        else:
            logger.info(message, extra=context)

class ApiResponse:
    """Klasse zur konsistenten Formatierung von API-Antworten"""
    
    @staticmethod
    def success(data: Any = None, message: Optional[str] = None, 
               status_code: int = HTTP_OK) -> Union[Response, tuple]:
        """
        Erzeugt eine erfolgreiche API-Antwort
        
        Args:
            data: Die Daten, die zurückgegeben werden sollen
            message: Eine optionale Erfolgsmeldung
            status_code: Der HTTP-Statuscode (default: 200)
            
        Returns:
            Ein Flask-Response-Objekt mit den formatierten Daten
        """
        response = {
            'success': True,
            'timestamp': datetime.now().isoformat()
        }
        
        if data is not None:
            response['data'] = data
            
        if message is not None:
            response['message'] = message
        
        return jsonify(response), status_code
    
    @staticmethod
    def error(message: str, error_code: int = HTTP_SERVER_ERROR,
             details: Any = None) -> tuple:
        """
        Erzeugt eine Fehler-API-Antwort
        
        Args:
            message: Die Fehlermeldung
            error_code: Der HTTP-Statuscode für den Fehler
            details: Optionale Details zum Fehler
            
        Returns:
            Ein Flask-Response-Objekt mit der Fehlermeldung
        """
        response = {
            'success': False,
            'error': message,
            'timestamp': datetime.now().isoformat()
        }
        
        if details is not None:
            response['details'] = details
            
        return jsonify(response), error_code

def handle_api_exception(e: Exception, endpoint: Optional[str] = None,
                        context: Optional[Dict] = None) -> tuple:
    """
    Zentrale Fehlerbehandlung für API-Aufrufe
    
    Args:
        e: Die aufgetretene Exception
        endpoint: Der API-Endpunkt, auf dem der Fehler aufgetreten ist
        context: Zusätzlicher Kontext für das Logging
        
    Returns:
        Eine formatierte Fehler-API-Antwort
    """
    error_context = context or {}
    error_context.update({
        'exception_type': type(e).__name__,
        'exception_message': str(e)
    })
    
    if endpoint:
        error_context['endpoint'] = endpoint
    
    if CUSTOM_LOGGING:
        manage_logging.error(
            f"API-Fehler: {str(e)}",
            exception=e,
            context=error_context,
            source="api_handler"
        )
    else:
        logger.error(
            f"API-Fehler: {str(e)}",
            exc_info=True,
            extra=error_context
        )
    
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
