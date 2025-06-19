#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
manage_backend_service.py - Verwaltung des Fotobox Backend-Services

Dieses Modul stellt Funktionen zur Verwaltung des systemd-Services für das Fotobox-Backend
bereit. Es erlaubt das Installieren, Aktivieren, Starten, Stoppen, Neustarten und 
Deinstallieren des Services.

Das Modul nutzt die shell.py-Hilfsfunktionen für Shell-Aufrufe mit sudo-Rechten.
"""

import os
import sys
import datetime
import subprocess
from pathlib import Path

# Fügt den übergeordneten Ordner zum Suchpfad hinzu, um Modul-Importe zu ermöglichen
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.utils import get_project_root, get_config_dir, get_backup_dir
from backend.utils import run, log_info, log_error, log_success, log_warning

# Konstanten
CONFIG_DIR = get_config_dir()
BACKUP_DIR = get_backup_dir()
SYSTEMD_SERVICE = os.path.join(CONFIG_DIR, 'fotobox-backend.service')
SYSTEMD_DST = '/etc/systemd/system/fotobox-backend.service'
SERVICE_NAME = 'fotobox-backend'

def install_backend_service():
    """
    Installiert den Backend-Service (kopiert die Service-Datei und lädt systemd neu)
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    log_info("Installiere Backend-Service...")
    
    # Erstelle Backup falls Service bereits existiert
    if os.path.exists(SYSTEMD_DST):
        backup = os.path.join(BACKUP_DIR, 
                              f'fotobox-backend.service.bak.{datetime.datetime.now():%Y%m%d%H%M%S}')
        try:
            run(['cp', SYSTEMD_DST, backup], sudo=True)
            log_success(f"Backup der bestehenden systemd-Unit nach {backup} erstellt.")
        except subprocess.CalledProcessError:
            log_error("Erstellen des Backups fehlgeschlagen.")
            return False
    
    # Kopiere Service-Datei
    try:
        run(['cp', SYSTEMD_SERVICE, SYSTEMD_DST], sudo=True)
        log_success("Service-Datei erfolgreich kopiert.")
    except subprocess.CalledProcessError:
        log_error("Kopieren der Service-Datei fehlgeschlagen.")
        return False
    
    # Aktualisiere systemd
    try:
        run(['systemctl', 'daemon-reload'], sudo=True)
        log_success("Systemd-Daemon neu geladen.")
    except subprocess.CalledProcessError:
        log_warning("Aktualisieren des systemd-Daemons fehlgeschlagen.")
        # Keine Rückgabe von False, da dies nicht unbedingt einen Fehler darstellt
    
    return True

def enable_backend_service():
    """
    Aktiviert den Backend-Service (startet automatisch beim Systemstart)
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    log_info("Aktiviere Backend-Service...")
    try:
        run(['systemctl', 'enable', SERVICE_NAME], sudo=True)
        log_success("Backend-Service aktiviert.")
        return True
    except subprocess.CalledProcessError:
        log_error("Aktivieren des Backend-Services fehlgeschlagen.")
        return False

def disable_backend_service():
    """
    Deaktiviert den Backend-Service (startet nicht mehr automatisch beim Systemstart)
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    log_info("Deaktiviere Backend-Service...")
    try:
        run(['systemctl', 'disable', SERVICE_NAME], sudo=True)
        log_success("Backend-Service deaktiviert.")
        return True
    except subprocess.CalledProcessError:
        log_error("Deaktivieren des Backend-Services fehlgeschlagen.")
        return False

def start_backend_service():
    """
    Startet den Backend-Service
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    log_info("Starte Backend-Service...")
    try:
        run(['systemctl', 'start', SERVICE_NAME], sudo=True)
    except subprocess.CalledProcessError:
        log_error("Starten des Backend-Services fehlgeschlagen.")
        return False
    
    # Überprüfe, ob der Service läuft
    if is_backend_service_active():
        log_success("Backend-Service erfolgreich gestartet.")
        return True
    else:
        log_warning("Backend-Service konnte nicht gestartet werden oder läuft nicht.")
        log_info("Der Status kann mit 'systemctl status fotobox-backend' überprüft werden.")
        return False

def stop_backend_service():
    """
    Stoppt den Backend-Service
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    log_info("Stoppe Backend-Service...")
    try:
        run(['systemctl', 'stop', SERVICE_NAME], sudo=True)
        log_success("Backend-Service gestoppt.")
        return True
    except subprocess.CalledProcessError:
        log_error("Stoppen des Backend-Services fehlgeschlagen.")
        return False

def restart_backend_service():
    """
    Startet den Backend-Service neu
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    log_info("Starte Backend-Service neu...")
    try:
        run(['systemctl', 'restart', SERVICE_NAME], sudo=True)
    except subprocess.CalledProcessError:
        log_error("Neustart des Backend-Services fehlgeschlagen.")
        return False
    
    # Überprüfe, ob der Service läuft
    if is_backend_service_active():
        log_success("Backend-Service erfolgreich neugestartet.")
        return True
    else:
        log_warning("Backend-Service konnte nicht neugestartet werden oder läuft nicht.")
        log_info("Der Status kann mit 'systemctl status fotobox-backend' überprüft werden.")
        return False

def is_backend_service_active():
    """
    Überprüft, ob der Backend-Service aktiv und am Laufen ist
    
    Returns:
        bool: True wenn aktiv, False wenn inaktiv
    """
    try:
        result = run(['systemctl', 'is-active', SERVICE_NAME], 
                     sudo=True, check=False, capture_output=True)
        return result.stdout.strip() == b'active'
    except Exception:
        return False

def get_backend_service_status():
    """
    Gibt den aktuellen Status des Backend-Services zurück
    
    Returns:
        str: Status des Backend-Services (z.B. "active", "inactive", "failed")
    """
    try:
        result = run(['systemctl', 'is-active', SERVICE_NAME], 
                     sudo=True, check=False, capture_output=True)
        return result.stdout.strip().decode('utf-8')
    except Exception:
        return "unknown"

def get_backend_service_details():
    """
    Gibt detaillierte Informationen zum Backend-Service zurück
    
    Returns:
        str: Detaillierte Statusinformationen
    """
    try:
        result = run(['systemctl', 'status', SERVICE_NAME], 
                     sudo=True, check=False, capture_output=True)
        return result.stdout.decode('utf-8')
    except Exception:
        return "Fehler beim Abrufen des Service-Status."

def uninstall_backend_service():
    """
    Deinstalliert den Backend-Service (stoppt, deaktiviert und entfernt)
    
    Returns:
        bool: True bei Erfolg, False bei Fehler
    """
    # Stoppe den Service zuerst
    log_info("Stoppe Backend-Service vor der Deinstallation...")
    try:
        run(['systemctl', 'stop', SERVICE_NAME], sudo=True, check=False)
    except subprocess.CalledProcessError:
        log_warning("Stoppen des Services fehlgeschlagen. Fahre trotzdem fort.")
    
    # Deaktiviere den Service
    log_info("Deaktiviere Backend-Service...")
    try:
        run(['systemctl', 'disable', SERVICE_NAME], sudo=True, check=False)
    except subprocess.CalledProcessError:
        log_warning("Deaktivieren des Services fehlgeschlagen. Fahre trotzdem fort.")
    
    # Erstelle Backup vor dem Löschen
    if os.path.exists(SYSTEMD_DST):
        backup = os.path.join(BACKUP_DIR, 
                              f'fotobox-backend.service.bak.{datetime.datetime.now():%Y%m%d%H%M%S}')
        try:
            run(['cp', SYSTEMD_DST, backup], sudo=True)
            log_success(f"Backup der systemd-Unit nach {backup} erstellt.")
        except subprocess.CalledProcessError:
            log_warning("Erstellen des Backups fehlgeschlagen. Fahre trotzdem fort.")
        
        # Entferne Service-Datei
        try:
            run(['rm', '-f', SYSTEMD_DST], sudo=True)
            log_success("Service-Datei erfolgreich entfernt.")
        except subprocess.CalledProcessError:
            log_error("Entfernen der Service-Datei fehlgeschlagen.")
            return False
    else:
        log_info("Keine Service-Datei zum Entfernen gefunden.")
    
    # Lade systemd neu
    try:
        run(['systemctl', 'daemon-reload'], sudo=True)
        log_success("Systemd-Daemon neu geladen.")
    except subprocess.CalledProcessError:
        log_warning("Aktualisieren des systemd-Daemons fehlgeschlagen.")
    
    log_success("Backend-Service erfolgreich deinstalliert.")
    return True

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
