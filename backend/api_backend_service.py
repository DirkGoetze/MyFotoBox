#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
api_backend_service.py - API-Endpunkte zur Verwaltung des Backend-Services

Dieses Modul definiert die API-Endpunkte zur Verwaltung des Fotobox-Backend-Services
über die REST-API. Es stellt Funktionen zum Starten, Stoppen, Neustarten und 
Statusabruf des Services bereit.
"""

from flask import Blueprint, jsonify, request
from functools import wraps
import datetime

# Import der Backend-Service-Verwaltungsfunktionen
import backend.manage_backend_service as mbs
from backend.manage_auth import requires_admin_auth, requires_auth
from backend.utils import log_info, log_error

# Blueprint für Backend-Service-Verwaltung erstellen
api_backend_service = Blueprint('api_backend_service', __name__)

# Hilfsfunktion zum Wrapper von API-Antworten
def service_api_response(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            result = func(*args, **kwargs)
            if isinstance(result, dict):
                return jsonify(result), 200
            elif isinstance(result, tuple) and len(result) == 2:
                return jsonify(result[0]), result[1]
            else:
                return jsonify({"success": True, "result": result}), 200
        except Exception as e:
            log_error(f"Fehler in Backend-Service-API: {str(e)}")
            return jsonify({
                "success": False, 
                "error": str(e),
                "timestamp": datetime.datetime.now().isoformat()
            }), 500
    return wrapper

@api_backend_service.route('/status', methods=['GET'])
@requires_auth
@service_api_response
def get_service_status():
    """
    Gibt den aktuellen Status des Backend-Services zurück
    """
    status = mbs.get_backend_service_status()
    is_active = status == "active"
    
    return {
        "success": True, 
        "status": status,
        "is_active": is_active,
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/details', methods=['GET'])
@requires_auth
@service_api_response
def get_service_details():
    """
    Gibt detaillierte Informationen zum Backend-Service zurück
    """
    details = mbs.get_backend_service_details()
    status = mbs.get_backend_service_status()
    is_active = status == "active"
    
    return {
        "success": True, 
        "details": details,
        "status": status,
        "is_active": is_active,
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/start', methods=['POST'])
@requires_admin_auth
@service_api_response
def start_service():
    """
    Startet den Backend-Service
    """
    log_info("API: Starte Backend-Service...")
    result = mbs.start_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich gestartet" if result else "Starten des Backend-Services fehlgeschlagen",
        "status": mbs.get_backend_service_status(),
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/stop', methods=['POST'])
@requires_admin_auth
@service_api_response
def stop_service():
    """
    Stoppt den Backend-Service
    """
    log_info("API: Stoppe Backend-Service...")
    result = mbs.stop_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich gestoppt" if result else "Stoppen des Backend-Services fehlgeschlagen",
        "status": mbs.get_backend_service_status(),
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/restart', methods=['POST'])
@requires_admin_auth
@service_api_response
def restart_service():
    """
    Startet den Backend-Service neu
    """
    log_info("API: Starte Backend-Service neu...")
    result = mbs.restart_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich neugestartet" if result else "Neustart des Backend-Services fehlgeschlagen",
        "status": mbs.get_backend_service_status(),
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/enable', methods=['POST'])
@requires_admin_auth
@service_api_response
def enable_service():
    """
    Aktiviert den Backend-Service (automatischer Start beim Systemstart)
    """
    log_info("API: Aktiviere Backend-Service...")
    result = mbs.enable_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich aktiviert" if result else "Aktivieren des Backend-Services fehlgeschlagen",
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/disable', methods=['POST'])
@requires_admin_auth
@service_api_response
def disable_service():
    """
    Deaktiviert den Backend-Service (kein automatischer Start beim Systemstart)
    """
    log_info("API: Deaktiviere Backend-Service...")
    result = mbs.disable_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich deaktiviert" if result else "Deaktivieren des Backend-Services fehlgeschlagen",
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/install', methods=['POST'])
@requires_admin_auth
@service_api_response
def install_service():
    """
    Installiert den Backend-Service (kopiert die Service-Datei)
    """
    log_info("API: Installiere Backend-Service...")
    result = mbs.install_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich installiert" if result else "Installation des Backend-Services fehlgeschlagen",
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/uninstall', methods=['DELETE'])
@requires_admin_auth
@service_api_response
def uninstall_service():
    """
    Deinstalliert den Backend-Service vollständig
    """
    log_info("API: Deinstalliere Backend-Service...")
    result = mbs.uninstall_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich deinstalliert" if result else "Deinstallation des Backend-Services fehlgeschlagen",
        "timestamp": datetime.datetime.now().isoformat()
    }

@api_backend_service.route('/setup', methods=['POST'])
@requires_admin_auth
@service_api_response
def setup_service():
    """
    Führt die vollständige Einrichtung des Backend-Services durch
    (Installation, Aktivierung und Start)
    """
    log_info("API: Richte Backend-Service vollständig ein...")
    result = mbs.setup_backend_service()
    
    return {
        "success": result,
        "message": "Backend-Service erfolgreich eingerichtet" if result else "Einrichtung des Backend-Services fehlgeschlagen",
        "status": mbs.get_backend_service_status(),
        "timestamp": datetime.datetime.now().isoformat()
    }
