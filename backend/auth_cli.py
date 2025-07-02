#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
auth_cli.py - CLI-Tool für Fotobox2 Authentifizierung

Dieses Modul stellt ein Kommandozeilen-Interface für die Verwaltung der
Fotobox2-Authentifizierung bereit. Es ermöglicht das Überprüfen und
Setzen von Passwörtern sowie die Token-Verwaltung.
"""

import sys
import logging
import argparse
from typing import List, Optional
from datetime import datetime

from manage_auth import AuthManager
from manage_api import ApiResponse
from utils import Result

# Logger konfigurieren
logger = logging.getLogger(__name__)

def parse_args(args: List[str]) -> argparse.Namespace:
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Fotobox2 Authentifizierungs-Management"
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Verfügbare Befehle')
    
    # Status-Befehl
    status_parser = subparsers.add_parser('status', help='Zeigt den Passwort-Status')
    
    # Set-Password-Befehl
    set_parser = subparsers.add_parser('set-password', help='Setzt ein neues Passwort')
    set_parser.add_argument('password', help='Das neue Passwort')
    
    # Check-Token-Befehl
    token_parser = subparsers.add_parser('check-token', help='Überprüft einen Token')
    token_parser.add_argument('token', help='Der zu überprüfende Token')
    
    return parser.parse_args(args)

def show_status(auth_manager: AuthManager) -> Result:
    """Zeigt den aktuellen Status der Authentifizierung"""
    try:
        status = auth_manager.get_password_status()
        
        print("\n=== Fotobox2 Authentifizierungs-Status ===")
        print(f"Passwort gesetzt: {'✅' if status['is_set'] else '❌'}")
        print(f"Zeitstempel: {status['timestamp']}")
        print(f"Anzahl Einstellungen: {status['settings_count']}")
        print("=========================================\n")
        
        return Result.ok(status)
        
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Status: {str(e)}")
        return Result.fail(str(e))

def set_password(auth_manager: AuthManager, password: str) -> Result:
    """Setzt ein neues Passwort"""
    try:
        if auth_manager.set_password(password):
            print("✅ Passwort erfolgreich gesetzt")
            return Result.ok(True)
        else:
            print("❌ Fehler beim Setzen des Passworts")
            return Result.fail("Passwort konnte nicht gesetzt werden")
            
    except Exception as e:
        logger.error(f"Fehler beim Setzen des Passworts: {str(e)}")
        return Result.fail(str(e))

def check_token(auth_manager: AuthManager, token: str) -> Result:
    """Überprüft einen Authentication-Token"""
    try:
        is_valid = auth_manager.verify_token(token)
        
        print(f"\nToken Status: {'✅ Gültig' if is_valid else '❌ Ungültig'}")
        print("================================\n")
        
        return Result.ok({'valid': is_valid})
        
    except Exception as e:
        logger.error(f"Fehler bei Token-Überprüfung: {str(e)}")
        return Result.fail(str(e))

def main(args: Optional[List[str]] = None) -> int:
    """Hauptfunktion des CLI-Tools"""
    if args is None:
        args = sys.argv[1:]
        
    try:
        parsed_args = parse_args(args)
        auth_manager = AuthManager()
        
        if parsed_args.command == 'status':
            result = show_status(auth_manager)
        elif parsed_args.command == 'set-password':
            result = set_password(auth_manager, parsed_args.password)
        elif parsed_args.command == 'check-token':
            result = check_token(auth_manager, parsed_args.token)
        else:
            print("Bitte geben Sie einen gültigen Befehl an")
            return 1
            
        return 0 if result.success else 1
        
    except Exception as e:
        logger.error(f"Unerwarteter Fehler: {str(e)}")
        print(f"Fehler: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
