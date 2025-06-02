import os
import subprocess
import sys
from datetime import datetime

BACKUP_DIR = os.path.join(os.path.dirname(__file__), '../backup')
LOGFILE = os.path.join(BACKUP_DIR, 'uninstall.log')
DATA_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../data'))
DB_PATH = os.path.join(DATA_DIR, 'fotobox_settings.db')

os.makedirs(BACKUP_DIR, exist_ok=True)

# -------------------------------------------------------------------------------
# log
# -------------------------------------------------------------------------------
# Funktion: Schreibt eine Lognachricht mit Zeitstempel in die Logdatei
# Parameter: msg (str) – Nachricht
# -------------------------------------------------------------------------------
def log(msg):
    with open(LOGFILE, 'a') as f:
        f.write(f"[{datetime.now()}] {msg}\n")

# -------------------------------------------------------------------------------
# run
# -------------------------------------------------------------------------------
# Funktion: Führt einen Shell-Befehl aus, optional mit sudo, loggt und prüft Exitcode
# Parameter: cmd (list), sudo (bool)
# Rückgabe: stdout (str), beendet bei Fehler
# -------------------------------------------------------------------------------
def run(cmd, sudo=False):
    if sudo and os.geteuid() != 0:
        cmd = ['sudo'] + cmd
    log(f"RUN: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        log(f"ERROR: {result.stderr}")
        print(f"Fehler: {result.stderr}")
        sys.exit(1)
    return result.stdout

# -------------------------------------------------------------------------------
# backup_configs
# -------------------------------------------------------------------------------
# Funktion: Sichert wichtige Systemdateien (z.B. NGINX-Konfiguration) ins Backup-Verzeichnis
# -------------------------------------------------------------------------------
def backup_configs():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    ts = datetime.now().strftime('%Y%m%d%H%M%S')
    # Beispiel: NGINX-Konfig sichern
    if os.path.exists('/etc/nginx/sites-available/fotobox'):
        run(['cp', '/etc/nginx/sites-available/fotobox', f'{BACKUP_DIR}/nginx-fotobox.conf.bak.{ts}'], sudo=True)
    # Weitere Backups nach Bedarf ...
    log('Backup abgeschlossen.')

# -------------------------------------------------------------------------------
# remove_systemd
# -------------------------------------------------------------------------------
# Funktion: Stoppt und entfernt den systemd-Service für das Fotobox-Backend
# -------------------------------------------------------------------------------
def remove_systemd():
    run(['systemctl', 'stop', 'fotobox-backend'], sudo=True)
    run(['systemctl', 'disable', 'fotobox-backend'], sudo=True)
    run(['rm', '-f', '/etc/systemd/system/fotobox-backend.service'], sudo=True)
    run(['systemctl', 'daemon-reload'], sudo=True)
    log('systemd-Service entfernt.')

# -------------------------------------------------------------------------------
# remove_nginx
# -------------------------------------------------------------------------------
# Funktion: Entfernt die NGINX-Konfiguration für die Fotobox
# -------------------------------------------------------------------------------
def remove_nginx():
    run(['rm', '-f', '/etc/nginx/sites-available/fotobox'], sudo=True)
    run(['rm', '-f', '/etc/nginx/sites-enabled/fotobox'], sudo=True)
    run(['systemctl', 'restart', 'nginx'], sudo=True)
    log('NGINX-Konfiguration entfernt.')

# -------------------------------------------------------------------------------
# remove_project
# -------------------------------------------------------------------------------
# Funktion: Entfernt das Projektverzeichnis /opt/fotobox
# -------------------------------------------------------------------------------
def remove_project():
    project_dir = '/opt/fotobox'
    if os.path.exists(project_dir):
        run(['rm', '-rf', project_dir], sudo=True)
        log('Projektverzeichnis entfernt.')

# -------------------------------------------------------------------------------
# backup_and_remove_systemd
# -------------------------------------------------------------------------------
# Funktion: Sichert und entfernt die systemd-Unit für das Fotobox-Backend
# -------------------------------------------------------------------------------
def backup_and_remove_systemd():
    import shutil, datetime, os
    dst = '/etc/systemd/system/fotobox-backend.service'
    backup = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backup', f'fotobox-backend.service.bak.{datetime.datetime.now():%Y%m%d%H%M%S}'))
    if os.path.exists(dst):
        shutil.copy(dst, backup)
        log(f"Backup systemd-Unit vor Entfernung: {backup}")
        os.remove(dst)
        run(['systemctl', 'daemon-reload'], sudo=True)
        log('systemd-Unit entfernt.')

# -------------------------------------------------------------------------------
# backup_and_remove_nginx
# -------------------------------------------------------------------------------
# Funktion: Sichert und entfernt die NGINX-Konfiguration für die Fotobox
# -------------------------------------------------------------------------------
def backup_and_remove_nginx():
    import shutil, datetime, os
    dst = '/etc/nginx/sites-available/fotobox'
    backup = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backup', f'nginx-fotobox.conf.bak.{datetime.datetime.now():%Y%m%d%H%M%S}'))
    if os.path.exists(dst):
        shutil.copy(dst, backup)
        log(f"Backup NGINX-Konfiguration vor Entfernung: {backup}")
        os.remove(dst)
        run(['systemctl', 'restart', 'nginx'], sudo=True)
        log('NGINX-Konfiguration entfernt.')

# -------------------------------------------------------------------------------
# cleanup_and_optimize_db
# -------------------------------------------------------------------------------
# Funktion: Bereinigt und optimiert die Datenbank über manage_database.py
# -------------------------------------------------------------------------------
def cleanup_and_optimize_db():
    subprocess.run(['python3', os.path.join(os.path.dirname(__file__), 'manage_database.py'), 'cleanup'])
    subprocess.run(['python3', os.path.join(os.path.dirname(__file__), 'manage_database.py'), 'optimize'])

# -------------------------------------------------------------------------------
# main
# -------------------------------------------------------------------------------
# Funktion: Hauptablauf für das Uninstall-Skript (Backup, systemd, nginx, Projekt)
# -------------------------------------------------------------------------------
def main():
    print('Starte Deinstallation der Fotobox ...')
    backup_configs()
    backup_and_remove_systemd()
    backup_and_remove_nginx()
    remove_systemd()
    remove_nginx()
    remove_project()
    # -------------------------------------------------------------------------------
    # backup_dir_entfernen_mit_rueckfrage
    # -------------------------------------------------------------------------------
    # Funktion: Fragt vor dem Löschen des Backup-Verzeichnisses nach Bestätigung
    # -------------------------------------------------------------------------------
    import shutil
    backup_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backup'))
    if os.path.exists(backup_dir):
        antwort = input('Backup-Verzeichnis und alle Backups unwiderruflich löschen? (j/N): ')
        if antwort.strip().lower() == 'j':
            try:
                shutil.rmtree(backup_dir)
                print('Backup-Verzeichnis wurde entfernt.')
                log('Backup-Verzeichnis entfernt.')
            except Exception as e:
                print(f'Fehler beim Entfernen des Backup-Verzeichnisses: {e}')
                log(f'Fehler beim Entfernen des Backup-Verzeichnisses: {e}')
        else:
            print('Backup-Verzeichnis wurde NICHT entfernt.')
            log('Backup-Verzeichnis wurde auf Nutzerwunsch nicht entfernt.')
    print('Deinstallation abgeschlossen. Siehe Log:', LOGFILE)

if __name__ == '__main__':
    cleanup_and_optimize_db()
    main()
