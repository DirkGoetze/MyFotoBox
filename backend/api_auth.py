#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
api_auth.py - API-Endpunkte für Authentifizierung und Berechtigungen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Authentifizierung, Passwort-
Management und Berechtigungsüberprüfungen bereit. Es implementiert Token-basierte
Authentifizierung und sichere Passwort-Verwaltung.
"""

from flask import Blueprint, request
from typing import Dict, Any, Optional
import logging
from datetime import datetime

from manage_api import ApiResponse, handle_api_exception, token_required
import manage_auth
from manage_folders import FolderManager

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für Auth-API-Endpunkte erstellen
api_auth = Blueprint('api_auth', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

@api_auth.route('/api/auth/login', methods=['POST'])
def api_login() -> Dict[str, Any]:
    """
    API-Endpunkt für den Login
    
    Returns:
        Dict mit JWT-Token bei erfolgreicher Authentifizierung
    """
    try:
        data = request.get_json()
        if not data or 'password' not in data:
            return ApiResponse.error('Passwort erforderlich', status_code=400)
        
        password = data['password']
        if not manage_auth.check_password(password):
            logger.warning('Login fehlgeschlagen: Falsches Passwort')
            return ApiResponse.error('Falsches Passwort', status_code=401)
            
        # Token generieren
        token = manage_auth.generate_token()
        logger.info('Login erfolgreich')
        
        return ApiResponse.success(data={
            'token': token,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Login: {str(e)}")
        return handle_api_exception(e, endpoint='/api/auth/login')

@api_auth.route('/api/auth/logout', methods=['POST'])
@token_required
def api_logout() -> Dict[str, Any]:
    """
    API-Endpunkt für den Logout
    
    Returns:
        Dict mit Bestätigung
    """
    try:
        token = request.headers.get('X-Auth-Token')
        if token:
            manage_auth.invalidate_token(token)
            logger.info('Benutzer ausgeloggt')
        
        return ApiResponse.success(data={
            'message': 'Erfolgreich ausgeloggt',
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Fehler beim Logout: {str(e)}")
        return handle_api_exception(e, endpoint='/api/auth/logout')

@api_auth.route('/api/auth/verify', methods=['GET'])
def api_verify_token() -> Dict[str, Any]:
    """
    API-Endpunkt zur Token-Überprüfung
    
    Returns:
        Dict mit Token-Status
    """
    try:
        token = request.headers.get('X-Auth-Token')
        if not token:
            return ApiResponse.error('Kein Token gefunden', status_code=401)
            
        is_valid = manage_auth.verify_token(token)
        
        return ApiResponse.success(data={
            'valid': is_valid,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Fehler bei Token-Überprüfung: {str(e)}")
        return handle_api_exception(e, endpoint='/api/auth/verify')

@api_auth.route('/api/auth/password', methods=['POST'])
def api_set_password() -> Dict[str, Any]:
    """
    API-Endpunkt zum Ändern des Passworts
    
    Returns:
        Dict mit Bestätigung
    """
    try:
        data = request.get_json()
        if not data:
            return ApiResponse.error('Keine Daten erhalten', status_code=400)
        
        # Setup-Modus prüfen
        is_setup = manage_auth.check_if_setup_needed()
        
        # Prüfen, ob Benutzer authentifiziert ist (außer beim Setup)
        if not is_setup:
            token = request.headers.get('X-Auth-Token')
            if not token or not manage_auth.verify_token(token):
                logger.warning('Unautorisierter Zugriff: Passwort-Änderungsversuch')
                return ApiResponse.error('Nicht autorisiert', status_code=401)
        
        # Bei Ersteinrichtung
        if is_setup and 'new_password' in data:
            if not manage_auth.set_password(data['new_password']):
                logger.error('Fehler beim Setzen des ersten Passworts')
                return ApiResponse.error('Passwort konnte nicht gesetzt werden', status_code=500)
                
            # Token für initiale Anmeldung generieren
            token = manage_auth.generate_token()
            logger.info('Passwort bei Ersteinrichtung gesetzt')
            
            return ApiResponse.success(data={
                'message': 'Initiales Passwort gesetzt',
                'token': token,
                'timestamp': datetime.now().isoformat()
            })
        
        # Passwort ändern im normalen Betrieb
        elif 'current_password' in data and 'new_password' in data:
            if not manage_auth.check_password(data['current_password']):
                logger.warning('Passwort-Änderung fehlgeschlagen: Aktuelles Passwort falsch')
                return ApiResponse.error('Aktuelles Passwort falsch', status_code=401)
                
            if not manage_auth.set_password(data['new_password']):
                logger.error('Fehler beim Ändern des Passworts')
                return ApiResponse.error('Passwort konnte nicht geändert werden', status_code=500)
            
            # Altes Token invalidieren und neues generieren
            token = request.headers.get('X-Auth-Token')
            if token:
                manage_auth.invalidate_token(token)
            new_token = manage_auth.generate_token()
            
            logger.info('Passwort erfolgreich geändert')
            return ApiResponse.success(data={
                'message': 'Passwort erfolgreich geändert',
                'token': new_token,
                'timestamp': datetime.now().isoformat()
            })
        
        else:
            return ApiResponse.error('Ungültige Daten', status_code=400)
            
    except Exception as e:
        logger.error(f"Fehler bei Passwort-Änderung: {str(e)}")
        return handle_api_exception(e, endpoint='/api/auth/password')
