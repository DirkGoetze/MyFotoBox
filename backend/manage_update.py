import os
import subprocess
import sys
from datetime import datetime
import shutil

BACKUP_DIR = os.path.join(os.path.dirname(__file__), '../backup')
LOGFILE = os.path.join(BACKUP_DIR, 'update.log')
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
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    venv_dir = os.path.join(backend_dir, 'venv')
    # Plattformunabhängige Bildung des pip-Pfads
    if os.name == 'nt':
        venv_pip = os.path.join(venv_dir, 'Scripts', 'pip.exe')
        venv_python = os.path.join(venv_dir, 'Scripts', 'python.exe')
    else:
        venv_pip = os.path.join(venv_dir, 'bin', 'pip')
        venv_python = os.path.join(venv_dir, 'bin', 'python')
    # -------------------------------------------------------------------------------
    # venv_pruefen_und_ggf_anlegen
    # -------------------------------------------------------------------------------
    # Funktion: Prüft, ob das venv-Verzeichnis und pip existieren, legt ggf. venv an
    # -------------------------------------------------------------------------------
    if not os.path.exists(venv_pip):
        print("Python-virtualenv (venv) nicht gefunden. Versuche, venv automatisch anzulegen ...")
        log("venv/bin/pip nicht gefunden. Versuche automatisches Anlegen von venv.")
        try:
            import venv as venv_mod
            venv_mod.create(venv_dir, with_pip=True)
        except Exception as e:
            print(f"Fehler beim automatischen Anlegen des venv: {e}\nBitte manuell mit 'python3 -m venv venv' im backend-Verzeichnis anlegen.")
            log(f"Fehler beim automatischen Anlegen des venv: {e}")
            sys.exit(1)
        if not os.path.exists(venv_pip):
            print("venv wurde angelegt, aber pip nicht gefunden. Abbruch.")
            log("venv wurde angelegt, aber pip nicht gefunden. Update abgebrochen.")
            sys.exit(1)
        print("venv wurde automatisch angelegt.")
        log("venv wurde automatisch angelegt.")
    # -------------------------------------------------------------------------------
    # pip_pruefen_und_installieren
    # -------------------------------------------------------------------------------
    # Funktion: Prüft, ob pip im venv vorhanden ist, installiert ggf. pip neu
    # -------------------------------------------------------------------------------
    if not os.path.isfile(venv_pip):
        print("pip im venv nicht gefunden. Versuche, pip zu installieren ...")
        log("pip im venv nicht gefunden. Versuche Installation.")
        try:
            import subprocess
            subprocess.check_call([venv_python, '-m', 'ensurepip'])
        except Exception as e:
            print(f"Fehler bei der Installation von pip im venv: {e}\nBitte manuell mit 'python3 -m ensurepip' im venv nachinstallieren.")
            log(f"Fehler bei der Installation von pip im venv: {e}")
            sys.exit(1)
        if not os.path.isfile(venv_pip):
            print("pip konnte nicht installiert werden. Abbruch.")
            log("pip konnte nicht installiert werden. Update abgebrochen.")
            sys.exit(1)
        print("pip wurde automatisch im venv installiert.")
        log("pip wurde automatisch im venv installiert.")
    run([venv_pip, 'install', '--upgrade', 'pip'])
    run([venv_pip, 'install', '-r', os.path.join(backend_dir, 'requirements.txt')])
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
# migrate_db_to_data_dir
# -------------------------------------------------------------------------------
# Funktion: Verschiebt die alte Datenbankdatei ins neue data-Verzeichnis, falls nötig
# -------------------------------------------------------------------------------
def migrate_db_to_data_dir():
    old_db = os.path.abspath(os.path.join(os.path.dirname(__file__), 'fotobox_settings.db'))
    new_db = DB_PATH
    if os.path.exists(old_db) and not os.path.exists(new_db):
        os.makedirs(DATA_DIR, exist_ok=True)
        shutil.move(old_db, new_db)
        print(f"Datenbank wurde nach {new_db} verschoben.")
        log(f"Datenbank migriert: {old_db} -> {new_db}")

# -------------------------------------------------------------------------------
# migrate_and_init_db
# -------------------------------------------------------------------------------
# Funktion: Migriert und initialisiert die Datenbank über manage_database.py
# -------------------------------------------------------------------------------
def migrate_and_init_db():
    subprocess.run(['python3', os.path.join(os.path.dirname(__file__), 'manage_database.py'), 'migrate'])
    subprocess.run(['python3', os.path.join(os.path.dirname(__file__), 'manage_database.py'), 'init'])

# -------------------------------------------------------------------------------
# main
# -------------------------------------------------------------------------------
# Funktion: Hauptablauf für das Update-Skript (Backup, Repo, Backend)
# -------------------------------------------------------------------------------
def main():
    print('Starte Update der Fotobox ...')
    # -------------------------------------------------------------------------------
    # backup_dir_erzeugen
    # -------------------------------------------------------------------------------
    # Funktion: Legt das Backup-Verzeichnis an, falls nicht vorhanden
    # -------------------------------------------------------------------------------
    backup_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backup'))
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)
        with open(os.path.join(backup_dir, 'readme.md'), 'w') as f:
            f.write('# backup\nDieses Verzeichnis wird automatisch durch die Installations- und Update-Skripte erzeugt und enthält Backups von Konfigurationsdateien und Logs. Es ist nicht Teil des Repositorys.')
    backup_configs()
    backup_and_install_systemd()
    backup_and_install_nginx()
    update_repo()
    update_backend()
    print('Update abgeschlossen. Siehe Log:', LOGFILE)

if __name__ == "__main__":
    migrate_and_init_db()
    import sys
    if '--backup-only' in sys.argv:
        backup_configs()
        print('Backup abgeschlossen.')
        sys.exit(0)
    main()
