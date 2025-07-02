"""
manage_uninstall.py - Verwaltung der Deinstallation von Fotobox2

Dieses Modul stellt Funktionen für die sichere Deinstallation der Fotobox2-Anwendung
bereit, inklusive Backup von Konfigurationen und Entfernen von Systemdiensten.
"""

import os
import subprocess
import sys
from datetime import datetime
from typing import Dict, Any, Optional, List, Tuple
from pathlib import Path
import shutil

from manage_folders import FolderManager
import logging

# Logger konfigurieren
logger = logging.getLogger(__name__)

# FolderManager Instanz
folder_manager = FolderManager()

class UninstallError(Exception):
    """Basisklasse für Deinstallationsfehler"""
    pass

class SystemdError(UninstallError):
    """Fehler bei systemd-Operationen"""
    pass

class NginxError(UninstallError):
    """Fehler bei NGINX-Operationen"""
    pass

def run_command(cmd: List[str], sudo: bool = False) -> Tuple[bool, str]:
    """
    Führt einen Shell-Befehl aus und behandelt Fehler
    
    Args:
        cmd: Liste der Befehlskomponenten
        sudo: Ob der Befehl mit sudo ausgeführt werden soll
    
    Returns:
        Tuple aus (Erfolg, Ausgabe/Fehlermeldung)
    """
    try:
        if sudo and os.geteuid() != 0:
            cmd = ['sudo'] + cmd
            
        logger.info(f"Führe Befehl aus: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            error_msg = f"Befehl fehlgeschlagen: {result.stderr}"
            logger.error(error_msg)
            return False, error_msg
            
        return True, result.stdout
        
    except Exception as e:
        error_msg = f"Fehler bei Befehlsausführung: {str(e)}"
        logger.error(error_msg)
        return False, error_msg

def backup_configs() -> Dict[str, Any]:
    """
    Sichert wichtige Systemdateien ins Backup-Verzeichnis
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        backup_dir = folder_manager.get_path('backup')
        Path(backup_dir).mkdir(parents=True, exist_ok=True)
        
        ts = datetime.now().strftime('%Y%m%d%H%M%S')
        backup_files = {
            'nginx': '/etc/nginx/sites-available/fotobox',
            'systemd': '/etc/systemd/system/fotobox-backend.service'
        }
        
        results = {}
        for name, path in backup_files.items():
            if Path(path).exists():
                backup_path = Path(backup_dir) / f"{name}_backup_{ts}.conf"
                success, output = run_command(['cp', path, str(backup_path)], sudo=True)
                results[name] = {'success': success, 'path': str(backup_path) if success else None}
                
        logger.info("Backup der Konfigurationen abgeschlossen")
        return {
            'success': True,
            'backups': results,
            'timestamp': ts
        }
        
    except Exception as e:
        error_msg = f"Fehler beim Backup der Konfigurationen: {str(e)}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg
        }

def remove_systemd() -> Dict[str, Any]:
    """
    Stoppt und entfernt den systemd-Service
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        steps = [
            (['systemctl', 'stop', 'fotobox-backend'], "Service stoppen"),
            (['systemctl', 'disable', 'fotobox-backend'], "Service deaktivieren"),
            (['rm', '-f', '/etc/systemd/system/fotobox-backend.service'], "Service-Datei entfernen"),
            (['systemctl', 'daemon-reload'], "systemd neu laden")
        ]
        
        results = []
        for cmd, description in steps:
            success, output = run_command(cmd, sudo=True)
            results.append({
                'step': description,
                'success': success,
                'output': output if not success else None
            })
            if not success:
                raise SystemdError(f"Fehler beim {description}: {output}")
                
        logger.info("systemd-Service erfolgreich entfernt")
        return {
            'success': True,
            'steps': results
        }
        
    except Exception as e:
        error_msg = f"Fehler beim Entfernen des systemd-Service: {str(e)}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg
        }

def remove_nginx() -> Dict[str, Any]:
    """
    Entfernt die NGINX-Konfiguration
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        steps = [
            (['rm', '-f', '/etc/nginx/sites-available/fotobox'], "Konfiguration entfernen"),
            (['rm', '-f', '/etc/nginx/sites-enabled/fotobox'], "Symlink entfernen"),
            (['systemctl', 'restart', 'nginx'], "NGINX neu starten")
        ]
        
        results = []
        for cmd, description in steps:
            success, output = run_command(cmd, sudo=True)
            results.append({
                'step': description,
                'success': success,
                'output': output if not success else None
            })
            if not success:
                raise NginxError(f"Fehler beim {description}: {output}")
                
        logger.info("NGINX-Konfiguration erfolgreich entfernt")
        return {
            'success': True,
            'steps': results
        }
        
    except Exception as e:
        error_msg = f"Fehler beim Entfernen der NGINX-Konfiguration: {str(e)}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg
        }

def remove_project() -> Dict[str, Any]:
    """
    Entfernt das Projektverzeichnis
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        install_dir = folder_manager.get_path('install')
        if not Path(install_dir).exists():
            return {
                'success': True,
                'message': 'Projektverzeichnis existiert nicht'
            }
            
        success, output = run_command(['rm', '-rf', install_dir], sudo=True)
        if not success:
            raise UninstallError(f"Fehler beim Entfernen des Projektverzeichnisses: {output}")
            
        logger.info(f"Projektverzeichnis {install_dir} erfolgreich entfernt")
        return {
            'success': True,
            'path': install_dir
        }
        
    except Exception as e:
        error_msg = f"Fehler beim Entfernen des Projektverzeichnisses: {str(e)}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg
        }

def backup_and_remove_systemd() -> Dict[str, Any]:
    """
    Sichert und entfernt den systemd-Service
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        # Erst Backup durchführen
        backup_result = backup_configs()
        if not backup_result['success']:
            return backup_result
            
        # Dann Service entfernen
        remove_result = remove_systemd()
        
        return {
            'success': remove_result['success'],
            'backup': backup_result.get('backups', {}),
            'remove': remove_result.get('steps', [])
        }
        
    except Exception as e:
        error_msg = f"Fehler beim Backup und Entfernen des systemd-Service: {str(e)}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg
        }

def backup_and_remove_nginx() -> Dict[str, Any]:
    """
    Sichert und entfernt die NGINX-Konfiguration
    
    Returns:
        Dict mit Status und Details der Operation
    """
    try:
        # Erst Backup durchführen
        backup_result = backup_configs()
        if not backup_result['success']:
            return backup_result
            
        # Dann Konfiguration entfernen
        remove_result = remove_nginx()
        
        return {
            'success': remove_result['success'],
            'backup': backup_result.get('backups', {}),
            'remove': remove_result.get('steps', [])
        }
        
    except Exception as e:
        error_msg = f"Fehler beim Backup und Entfernen der NGINX-Konfiguration: {str(e)}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg
        }

def cleanup_and_optimize_db():
    """Bereinigt und optimiert die Datenbank"""
    try:
        logger.info("Starte Datenbankbereinigung und -optimierung...")
        
        db_script = os.path.join(os.path.dirname(__file__), 'manage_database.py')
        
        # Führe Cleanup durch
        cleanup_result = subprocess.run(
            ['python3', db_script, 'cleanup'],
            capture_output=True,
            text=True
        )
        if cleanup_result.returncode != 0:
            logger.error(f"Datenbankbereinigung fehlgeschlagen: {cleanup_result.stderr}")
            return False
            
        # Führe Optimierung durch
        optimize_result = subprocess.run(
            ['python3', db_script, 'optimize'],
            capture_output=True,
            text=True
        )
        if optimize_result.returncode != 0:
            logger.error(f"Datenbankoptimierung fehlgeschlagen: {optimize_result.stderr}")
            return False
            
        logger.info("Datenbankbereinigung und -optimierung erfolgreich abgeschlossen")
        return True
        
    except Exception as e:
        logger.error(f"Fehler bei Datenbankoperationen: {str(e)}")
        return False

def main():
    """Hauptablauf für das Uninstall-Skript"""
    try:
        logger.info("Starte Deinstallation der Fotobox...")
        
        # Führe Datenbankbereinigung durch
        if not cleanup_and_optimize_db():
            logger.warning("Datenbankbereinigung fehlgeschlagen, fahre trotzdem fort")
            
        # Backup und Entfernen der Dienste
        services_result = backup_and_remove_systemd()
        if not services_result['success']:
            logger.error("Fehler beim Entfernen des systemd-Service")
            
        nginx_result = backup_and_remove_nginx()
        if not nginx_result['success']:
            logger.error("Fehler beim Entfernen der NGINX-Konfiguration")
            
        # Entferne Projektverzeichnis
        project_result = remove_project()
        if not project_result['success']:
            logger.error("Fehler beim Entfernen des Projektverzeichnisses")
            
        # Optional: Backup-Verzeichnis aufräumen
        backup_dir = folder_manager.get_path('backup')
        if Path(backup_dir).exists():
            try:
                antwort = input('Backup-Verzeichnis und alle Backups unwiderruflich löschen? (j/N): ')
                if antwort.strip().lower() == 'j':
                    shutil.rmtree(backup_dir)
                    logger.info("Backup-Verzeichnis wurde entfernt")
                    print('Backup-Verzeichnis wurde entfernt.')
                else:
                    logger.info("Backup-Verzeichnis wurde auf Nutzerwunsch nicht entfernt")
                    print('Backup-Verzeichnis wurde NICHT entfernt.')
            except Exception as e:
                error_msg = f"Fehler beim Entfernen des Backup-Verzeichnisses: {str(e)}"
                logger.error(error_msg)
                print(error_msg)
                
        logger.info("Deinstallation abgeschlossen")
        print('Deinstallation abgeschlossen. Details im Log unter:', folder_manager.get_path('log'))
        
    except Exception as e:
        error_msg = f"Fehler bei der Deinstallation: {str(e)}"
        logger.error(error_msg)
        print(error_msg)
        sys.exit(1)

if __name__ == '__main__':
    main()
