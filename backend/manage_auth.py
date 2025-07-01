#!/usr/bin/env python3
"""
manage_auth.py - Authentifizierungsmodul für Fotobox2

Dieses Modul stellt zentrale Funktionen für die Authentifizierung und
Autorisierung in der Fotobox2-Anwendung bereit.
"""

import os
import logging
import bcrypt
import jwt
import datetime
from typing import Optional, Dict, Any, Tuple
from functools import wraps
from flask import session, request, jsonify

# Modul-Logger konfigurieren
logger = logging.getLogger(__name__)

# Importiere FolderManager und DatabaseManager
from manage_folders import FolderManager, get_data_dir
from manage_database import DatabaseManager, get_setting, set_setting

class AuthError(Exception):
    """Basisklasse für Authentifizierungs-bezogene Fehler"""
    pass

class TokenError(AuthError):
    """Fehler bei der Token-Verarbeitung"""
    pass

class AuthManager:
    """Zentrale Verwaltungsklasse für Authentifizierung"""
    
    def __init__(self):
        self.folder_manager = FolderManager()
        self.data_dir = get_data_dir()
        self._secret_key = os.environ.get('FOTOBOX_SECRET_KEY', os.urandom(32))
        self._token_expiry = datetime.timedelta(hours=24)
        
    def _hash_password(self, password: str) -> bytes:
        """Erstellt einen sicheren Hash des Passworts"""
        return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        
    def _verify_password(self, password: str, hashed: str) -> bool:
        """Verifiziert ein Passwort gegen einen Hash"""
        try:
            return bcrypt.checkpw(
                password.encode('utf-8'),
                hashed.encode('utf-8')
            )
        except Exception as e:
            logger.error(f"Fehler bei Passwort-Verifizierung: {e}")
            return False
            
    def is_password_set(self) -> bool:
        """Prüft ob ein Passwort gesetzt ist"""
        return bool(get_setting('admin_password_hash'))
        
    def set_password(self, password: str) -> bool:
        """Setzt ein neues Passwort"""
        try:
            password_hash = self._hash_password(password)
            return set_setting('admin_password_hash', password_hash.decode('utf-8'))
        except Exception as e:
            logger.error(f"Fehler beim Setzen des Passworts: {e}")
            return False
            
    def verify_password(self, password: str) -> bool:
        """Verifiziert das eingegebene Passwort"""
        stored_hash = get_setting('admin_password_hash')
        if not stored_hash:
            return False
        return self._verify_password(password, stored_hash)
        
    def generate_token(self, user_id: str = 'admin') -> str:
        """Generiert ein JWT-Token"""
        try:
            payload = {
                'user_id': user_id,
                'exp': datetime.datetime.utcnow() + self._token_expiry
            }
            return jwt.encode(payload, self._secret_key, algorithm='HS256')
        except Exception as e:
            logger.error(f"Fehler bei Token-Generierung: {e}")
            raise TokenError(f"Token-Generierung fehlgeschlagen: {e}")
            
    def verify_token(self, token: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Verifiziert ein JWT-Token"""
        try:
            payload = jwt.decode(token, self._secret_key, algorithms=['HS256'])
            return True, payload
        except jwt.ExpiredSignatureError:
            return False, {'error': 'Token abgelaufen'}
        except jwt.InvalidTokenError as e:
            return False, {'error': f'Ungültiges Token: {str(e)}'}
        except Exception as e:
            logger.error(f"Fehler bei Token-Verifizierung: {e}")
            return False, {'error': str(e)}

# Globale Instanz
_auth_manager = AuthManager()

# Decorator für geschützte Routen
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return jsonify({'error': 'Kein Authentifizierungs-Token'}), 401
            
        try:
            token = auth_header.split(' ')[1]
            valid, payload = _auth_manager.verify_token(token)
            
            if not valid:
                return jsonify(payload), 401
                
            return f(*args, **kwargs)
            
        except Exception as e:
            logger.error(f"Authentifizierungsfehler: {e}")
            return jsonify({'error': 'Authentifizierung fehlgeschlagen'}), 401
            
    return decorated_function

# Convenience-Funktionen
def is_password_set() -> bool:
    return _auth_manager.is_password_set()

def set_password(password: str) -> bool:
    return _auth_manager.set_password(password)

def verify_password(password: str) -> bool:
    return _auth_manager.verify_password(password)

def generate_token(user_id: str = 'admin') -> str:
    return _auth_manager.generate_token(user_id)

def verify_token(token: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
    return _auth_manager.verify_token(token)
