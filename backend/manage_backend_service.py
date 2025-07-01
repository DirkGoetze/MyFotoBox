#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
manage_backend_service.py - Verwaltung des Fotobox Backend-Services

Dieses Modul stellt Funktionen zur Verwaltung des systemd-Services für das Fotobox-Backend
bereit. Es erlaubt das Installieren, Aktivieren, Starten, Stoppen, Neustarten und 
Deinstallieren des Services.
"""

import os
import sys
import datetime
import subprocess
import logging
from pathlib import Path

# Logger einrichten
logger = logging.getLogger(__name__)

# Importiere manage_folders für zentrale Pfadverwaltung
try:
    from manage_folders import get_config_dir, get_backup_dir, get_log_dir
    CONFIG_DIR = get_config_dir()
    BACKUP_DIR = get_backup_dir()
    LOG_DIR = get_log_dir()
except ImportError as e:
    logger.error(f"Fehler beim Import von manage_folders: {e}")
    # Fallback zu Standardpfaden
    CONFIG_DIR = "/opt/fotobox/conf"
    BACKUP_DIR = "/opt/fotobox/backup"
    LOG_DIR = "/opt/fotobox/log"

# Service-Konfiguration
SYSTEMD_SERVICE = os.path.join(CONFIG_DIR, 'fotobox-backend.service')
SYSTEMD_DST = '/etc/systemd/system/fotobox-backend.service'
SERVICE_NAME = 'fotobox-backend'

def check_service_dependencies() -> bool:
    """
    Prüft, ob alle notwendigen Verzeichnisse und Abhängigkeiten für den Service existieren
    
    Returns:
        bool: True wenn alle Abhängigkeiten erfüllt sind, False sonst
    """
    required_dirs = [
        ('/opt/fotobox/backend', 'Backend-Verzeichnis'),
        ('/opt/fotobox/backend/venv', 'Python Virtual Environment'),
        (LOG_DIR, 'Log-Verzeichnis'),
        (os.path.join(CONFIG_DIR, 'cameras'), 'Kamera-Konfiguration')
    ]
    
    all_ok = True
    for dir_path, description in required_dirs:
        if not os.path.exists(dir_path):
            logger.error(f"Fehlendes {description}: {dir_path}")
            all_ok = False
            
    return all_ok

def verify_service_file() -> bool:
    """
    Überprüft die Service-Datei auf notwendige Einträge
    
    Returns:
        bool: True wenn die Service-Datei valide ist, False sonst
    """
    try:
        if not os.path.exists(SYSTEMD_SERVICE):
            logger.error(f"Service-Datei nicht gefunden: {SYSTEMD_SERVICE}")
            return False
            
        with open(SYSTEMD_SERVICE, 'r') as f:
            content = f.read()
            
        required_entries = [
            'Description=Fotobox Backend',
            'User=fotobox',
            'Group=fotobox',
            'WorkingDirectory=/opt/fotobox/backend',
            'Environment=PYTHONPATH=/opt/fotobox/backend'
        ]
        
        for entry in required_entries:
            if entry not in content:
                logger.error(f"Fehlender Eintrag in Service-Datei: {entry}")
                return False
                
        return True
    except Exception as e:
        logger.error(f"Fehler beim Überprüfen der Service-Datei: {e}")
        return False

def install_backend_service() -> bool:
    """
    Installiert den Backend-Service
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    logger.info("Installiere Backend-Service...")
    
    # Prüfe Abhängigkeiten
    if not check_service_dependencies():
        logger.error("Service-Abhängigkeiten nicht erfüllt")
        return False
        
    # Prüfe Service-Datei
    if not verify_service_file():
        logger.error("Service-Datei ungültig")
        return False
    
    # Erstelle Backup falls Service bereits existiert
    if os.path.exists(SYSTEMD_DST):
        backup = os.path.join(
            BACKUP_DIR, 
            f'fotobox-backend.service.bak.{datetime.datetime.now():%Y%m%d%H%M%S}'
        )
        try:
            subprocess.run(['sudo', 'cp', SYSTEMD_DST, backup], check=True)
            logger.info(f"Backup erstellt: {backup}")
        except subprocess.CalledProcessError as e:
            logger.error(f"Backup fehlgeschlagen: {e}")
            return False
    
    # Kopiere Service-Datei
    try:
        subprocess.run(['sudo', 'cp', SYSTEMD_SERVICE, SYSTEMD_DST], check=True)
        subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
        logger.info("Service-Datei installiert und systemd aktualisiert")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Installation fehlgeschlagen: {e}")
        return False

def enable_backend_service() -> bool:
    """
    Aktiviert den Backend-Service (startet automatisch beim Systemstart)
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    logger.info("Aktiviere Backend-Service...")
    try:
        subprocess.run(['sudo', 'systemctl', 'enable', SERVICE_NAME], check=True)
        logger.info("Backend-Service aktiviert")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Aktivierung fehlgeschlagen: {e}")
        return False

def disable_backend_service() -> bool:
    """
    Deaktiviert den Backend-Service
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    logger.info("Deaktiviere Backend-Service...")
    try:
        subprocess.run(['sudo', 'systemctl', 'disable', SERVICE_NAME], check=True)
        logger.info("Backend-Service deaktiviert")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Deaktivierung fehlgeschlagen: {e}")
        return False

def start_backend_service() -> bool:
    """
    Startet den Backend-Service
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    logger.info("Starte Backend-Service...")
    try:
        subprocess.run(['sudo', 'systemctl', 'start', SERVICE_NAME], check=True)
        logger.info("Backend-Service gestartet")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Start fehlgeschlagen: {e}")
        return False

def stop_backend_service() -> bool:
    """
    Stoppt den Backend-Service
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    logger.info("Stoppe Backend-Service...")
    try:
        subprocess.run(['sudo', 'systemctl', 'stop', SERVICE_NAME], check=True)
        logger.info("Backend-Service gestoppt")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Stop fehlgeschlagen: {e}")
        return False

def restart_backend_service() -> bool:
    """
    Startet den Backend-Service neu
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    logger.info("Starte Backend-Service neu...")
    try:
        subprocess.run(['sudo', 'systemctl', 'restart', SERVICE_NAME], check=True)
        logger.info("Backend-Service neugestartet")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Neustart fehlgeschlagen: {e}")
        return False

def get_service_status() -> dict:
    """
    Ruft den Status des Backend-Services ab
    
    Returns:
        Dict mit Status-Informationen:
        - active (bool): True wenn Service aktiv
        - enabled (bool): True wenn Service beim Boot aktiviert
        - status (str): Detaillierter Status-Text
        - error (str, optional): Fehlermeldung falls vorhanden
    """
    try:
        # Prüfe ob Service aktiv ist
        active_result = subprocess.run(
            ['systemctl', 'is-active', SERVICE_NAME],
            capture_output=True,
            text=True
        )
        is_active = active_result.returncode == 0
        
        # Prüfe ob Service enabled ist
        enabled_result = subprocess.run(
            ['systemctl', 'is-enabled', SERVICE_NAME],
            capture_output=True,
            text=True
        )
        is_enabled = enabled_result.returncode == 0
        
        # Hole detaillierten Status
        status_result = subprocess.run(
            ['systemctl', 'status', SERVICE_NAME],
            capture_output=True,
            text=True
        )
        
        return {
            'active': is_active,
            'enabled': is_enabled,
            'status': status_result.stdout,
            'error': status_result.stderr if status_result.returncode != 0 else None
        }
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Service-Status: {e}")
        return {
            'active': False,
            'enabled': False,
            'status': 'Unbekannt',
            'error': str(e)
        }

def uninstall_backend_service() -> bool:
    """
    Deinstalliert den Backend-Service vollständig
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    logger.info("Deinstalliere Backend-Service...")
    
    # Stoppe und deaktiviere den Service
    try:
        subprocess.run(['sudo', 'systemctl', 'stop', SERVICE_NAME], 
                      check=False)  # Ignoriere Fehler
        subprocess.run(['sudo', 'systemctl', 'disable', SERVICE_NAME], 
                      check=False)  # Ignoriere Fehler
    except Exception as e:
        logger.warning(f"Fehler beim Stoppen/Deaktivieren: {e}")
    
    # Erstelle Backup der Service-Datei
    if os.path.exists(SYSTEMD_DST):
        backup = os.path.join(
            BACKUP_DIR,
            f'fotobox-backend.service.uninstall.{datetime.datetime.now():%Y%m%d%H%M%S}'
        )
        try:
            subprocess.run(['sudo', 'cp', SYSTEMD_DST, backup], check=True)
            logger.info(f"Backup erstellt: {backup}")
        except subprocess.CalledProcessError as e:
            logger.error(f"Backup fehlgeschlagen: {e}")
    
    # Entferne Service-Datei
    try:
        if os.path.exists(SYSTEMD_DST):
            subprocess.run(['sudo', 'rm', '-f', SYSTEMD_DST], check=True)
        
        # Lade systemd neu
        subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
        logger.info("Backend-Service erfolgreich deinstalliert")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Deinstallation fehlgeschlagen: {e}")
        return False

def setup_backend_service():
    """
    Führt die komplette Installation des Backend-Services durch
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    # Installiere den Service
    if not install_backend_service():
        return False
    
    # Aktiviere den Service
    if not enable_backend_service():
        return False
    
    # Starte den Service
    if not start_backend_service():
        return False
    
    return True

# Wenn dieses Skript direkt ausgeführt wird
if __name__ == "__main__":
    print("Dieses Modul sollte nicht direkt ausgeführt werden.")
    print("Bitte verwenden Sie die entsprechenden API-Funktionen oder CLI-Tools.")
    sys.exit(1)
