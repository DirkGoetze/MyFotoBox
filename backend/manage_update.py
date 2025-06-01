import os
import subprocess
import sys
from datetime import datetime

BACKUP_DIR = os.path.join(os.path.dirname(__file__), '../backup')
LOGFILE = os.path.join(BACKUP_DIR, 'update.log')

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
# update_repo
# -------------------------------------------------------------------------------
# Funktion: Aktualisiert das Projekt-Repository per git pull
# -------------------------------------------------------------------------------
def update_repo():
    repo_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    run(['git', '-C', repo_dir, 'pull'])
    log('Repository aktualisiert.')

# -------------------------------------------------------------------------------
# update_backend
# -------------------------------------------------------------------------------
# Funktion: Aktualisiert Python-Abhängigkeiten im Backend (pip, requirements.txt)
# -------------------------------------------------------------------------------
def update_backend():
    backend_dir = os.path.dirname(__file__)
    run([os.path.join(backend_dir, 'venv/bin/pip'), 'install', '--upgrade', 'pip'])
    run([os.path.join(backend_dir, 'venv/bin/pip'), 'install', '-r', 'requirements.txt'])
    log('Backend-Abhängigkeiten aktualisiert.')

# -------------------------------------------------------------------------------
# backup_and_install_systemd
# -------------------------------------------------------------------------------
# Funktion: Sichert die aktuelle systemd-Unit und installiert die neue
# -------------------------------------------------------------------------------
def backup_and_install_systemd():
    import shutil, datetime, os
    src = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'conf', 'fotobox-backend.service'))
    dst = '/etc/systemd/system/fotobox-backend.service'
    backup = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backup', f'fotobox-backend.service.bak.{datetime.datetime.now():%Y%m%d%H%M%S}'))
    if os.path.exists(dst):
        shutil.copy(dst, backup)
        log(f"Backup systemd-Unit: {backup}")
    shutil.copy(src, dst)
    run(['systemctl', 'daemon-reload'], sudo=True)
    run(['systemctl', 'enable', 'fotobox-backend'], sudo=True)
    run(['systemctl', 'restart', 'fotobox-backend'], sudo=True)
    log('Neue systemd-Unit installiert.')

# -------------------------------------------------------------------------------
# backup_and_install_nginx
# -------------------------------------------------------------------------------
# Funktion: Sichert die aktuelle NGINX-Konfiguration und installiert die neue
# -------------------------------------------------------------------------------
def backup_and_install_nginx():
    import shutil, datetime, os
    src = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'conf', 'nginx-fotobox.conf'))
    dst = '/etc/nginx/sites-available/fotobox'
    backup = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backup', f'nginx-fotobox.conf.bak.{datetime.datetime.now():%Y%m%d%H%M%S}'))
    if os.path.exists(dst):
        shutil.copy(dst, backup)
        log(f"Backup NGINX-Konfiguration: {backup}")
    shutil.copy(src, dst)
    run(['systemctl', 'restart', 'nginx'], sudo=True)
    log('Neue NGINX-Konfiguration installiert.')

# -------------------------------------------------------------------------------
# main
# -------------------------------------------------------------------------------
# Funktion: Hauptablauf für das Update-Skript (Backup, Repo, Backend)
# -------------------------------------------------------------------------------
def main():
    print('Starte Update der Fotobox ...')
    backup_configs()
    backup_and_install_systemd()
    backup_and_install_nginx()
    update_repo()
    update_backend()
    print('Update abgeschlossen. Siehe Log:', LOGFILE)

if __name__ == '__main__':
    import sys
    if '--backup-only' in sys.argv:
        backup_configs()
        print('Backup abgeschlossen.')
        sys.exit(0)
    main()
