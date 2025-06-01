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
# main
# -------------------------------------------------------------------------------
# Funktion: Hauptablauf für das Update-Skript (Backup, Repo, Backend)
# -------------------------------------------------------------------------------
def main():
    print('Starte Update der Fotobox ...')
    backup_configs()
    update_repo()
    update_backend()
    print('Update abgeschlossen. Siehe Log:', LOGFILE)

if __name__ == '__main__':
    main()
