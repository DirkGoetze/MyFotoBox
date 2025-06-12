import os
import subprocess
import sys
from datetime import datetime
import shutil
import glob
import re
from pkg_resources import parse_version

BACKUP_DIR = os.path.join(os.path.dirname(__file__), '../backup')
LOG_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../backup/logs'))
os.makedirs(LOG_DIR, exist_ok=True)

# Pfad zur requirements_system.inf im conf-Verzeichnis
SYSTEM_REQUIREMENTS_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '../conf/requirements_system.inf'))

# Pfad zur requirements_python.inf im conf-Verzeichnis
PYTHON_REQUIREMENTS_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '../conf/requirements_python.inf'))

# -------------------------------------------------------------------------------
# Neue Funktionen für Abhängigkeiten
# -------------------------------------------------------------------------------

def detect_package_manager():
    """Erkennt den verwendeten Paketmanager"""
    
    if os.path.exists('/usr/bin/apt'):
        return 'apt'
    elif os.path.exists('/usr/bin/yum'):
        return 'yum'
    elif os.path.exists('/usr/bin/dnf'):
        return 'dnf'
    elif os.path.exists('/usr/bin/pacman'):
        return 'pacman'
    else:
        return None

def version_satisfies(installed, required):
    """Prüft, ob die installierte Version die Mindestanforderung erfüllt"""
    try:
        return parse_version(installed) >= parse_version(required)
    except Exception:
        # Im Zweifelsfall davon ausgehen, dass ein Update nötig ist
        return False

def check_package_installed(package, min_version=None):
    """Überprüft, ob ein Paket installiert ist und die Mindestversion erfüllt"""
    package_manager = detect_package_manager()
    
    if not package_manager:
        log(f"Kein unterstützter Paketmanager gefunden. Überspringe Prüfung für {package}.", "WARNING")
        return True  # Bei Windows oder nicht erkannten Systemen überspringen
    
    try:
        if package_manager == 'apt':
            result = subprocess.run(['dpkg-query', '-W', '-f=${Status} ${Version}', package], 
                                   capture_output=True, text=True)
            
            if 'install ok installed' not in result.stdout:
                return False
                
            if min_version:
                # Extrahieren der Version mit Regex
                version_match = re.search(r'install ok installed ([\d\.]+)', result.stdout)
                if not version_match:
                    return False
                    
                installed_version = version_match.group(1)
                if not version_satisfies(installed_version, min_version):
                    return False
        
        elif package_manager == 'yum' or package_manager == 'dnf':
            result = subprocess.run([package_manager, 'list', 'installed', package], 
                                   capture_output=True, text=True)
            if package not in result.stdout:
                return False
                
            if min_version:
                version_match = re.search(fr'{package}\..*\s+([\d\.]+)', result.stdout)
                if not version_match:
                    return False
                    
                installed_version = version_match.group(1)
                if not version_satisfies(installed_version, min_version):
                    return False
                    
        elif package_manager == 'pacman':
            result = subprocess.run(['pacman', '-Q', package], 
                                   capture_output=True, text=True)
            if package not in result.stdout:
                return False
                
            if min_version:
                version_match = re.search(fr'{package} ([\d\.]+)', result.stdout)
                if not version_match:
                    return False
                    
                installed_version = version_match.group(1)
                if not version_satisfies(installed_version, min_version):
                    return False
        
        return True
    except Exception as e:
        log(f"Fehler beim Prüfen des Pakets {package}: {str(e)}", "ERROR")
        return False

def check_system_requirements():
    """Überprüft (ohne Installation) fehlende Systempakete basierend auf system_requirements.txt"""
    missing_packages = []
    outdated_packages = []
      if not os.path.exists(SYSTEM_REQUIREMENTS_PATH):
        log(f"requirements_system.inf nicht gefunden: {SYSTEM_REQUIREMENTS_PATH}", "WARNING")
        return [], []

    try:
        with open(SYSTEM_REQUIREMENTS_PATH, 'r') as f:
            requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
        for req in requirements:
            # Paketname und Version trennen
            match = re.match(r'^([a-zA-Z0-9\-_\.]+)(?:>=|==|>)?([\d\.]+)?$', req)
            if not match:
                log(f"Ungültiges Format für Paket: {req}", "WARNING")
                continue
            
            package, min_version = match.groups()
            
            if not check_package_installed(package, None):  # Prüfe nur, ob es installiert ist
                missing_packages.append(package)
            elif min_version and not check_package_installed(package, min_version):  # Prüfe Version
                outdated_packages.append(package)
        
        return missing_packages, outdated_packages
        
    except Exception as e:
        log(f"Fehler beim Überprüfen von Systempaketen: {str(e)}", "ERROR")
        return [], []

def check_python_requirements():
    """Überprüft fehlende Python-Pakete basierend auf requirements.txt"""
    import pkg_resources
    
    missing_packages = []
    outdated_packages = []
      if not os.path.exists(PYTHON_REQUIREMENTS_PATH):
        log(f"requirements_python.inf nicht gefunden: {PYTHON_REQUIREMENTS_PATH}", "WARNING")
        return [], []
        
    try:
        with open(PYTHON_REQUIREMENTS_PATH, 'r') as f:
            requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]
            
        # Installierte Pakete prüfen
        installed = {pkg.key: pkg.version for pkg in pkg_resources.working_set}
        
        for req in requirements:
            # Paketname und Version trennen
            match = re.match(r'^([a-zA-Z0-9\-_\.]+)(?:>=|==|>)?([\d\.]+)?$', req)
            if not match:
                log(f"Ungültiges Format für Python-Paket: {req}", "WARNING")
                continue
                
            package, min_version = match.groups()
            package = package.lower()  # pip-Paketnamen sind case-insensitive
            
            if package not in installed:
                missing_packages.append(package)
            elif min_version and not version_satisfies(installed[package], min_version):
                outdated_packages.append(package)
                
        return missing_packages, outdated_packages
        
    except Exception as e:
        log(f"Fehler beim Überprüfen von Python-Paketen: {str(e)}", "ERROR")
        return [], []

def install_system_requirements():
    """Installiert fehlende Systempakete basierend auf system_requirements.txt"""
    if os.name == 'nt':  # Windows
        log("Installation von Systempaketen unter Windows nicht unterstützt", "WARNING")
        return False, "Installation von Systempaketen unter Windows nicht unterstützt"

    package_manager = detect_package_manager()
    if not package_manager:
        return False, "Kein unterstützter Paketmanager gefunden"

    missing_packages, outdated_packages = check_system_requirements()
    packages_to_install = missing_packages + outdated_packages

    if not packages_to_install:
        return True, "Alle Systempakete sind bereits installiert"

    try:
        log(f"Installiere {len(packages_to_install)} fehlende/veraltete Systempakete", "INFO")
        
        # Paketliste aktualisieren
        if package_manager == 'apt':
            subprocess.run(['apt-get', 'update'], check=True)
        
        # Pakete installieren
        if package_manager == 'apt':
            cmd = ['apt-get', 'install', '-y'] + packages_to_install
            subprocess.run(cmd, check=True)
        elif package_manager == 'yum' or package_manager == 'dnf':
            cmd = [package_manager, 'install', '-y'] + packages_to_install
            subprocess.run(cmd, check=True)
        elif package_manager == 'pacman':
            cmd = ['pacman', '-S', '--noconfirm'] + packages_to_install
            subprocess.run(cmd, check=True)
        
        return True, f"{len(packages_to_install)} Systempakete installiert"
    except Exception as e:
        log(f"Fehler beim Installieren von Systempaketen: {str(e)}", "ERROR")
        return False, str(e)

def get_dependencies_status():
    """Gibt einen Status der Abhängigkeiten zurück (für die API)"""
    system_missing, system_outdated = check_system_requirements()
    python_missing, python_outdated = check_python_requirements()
    
    return {
        "system": {
            "missing": system_missing,
            "outdated": system_outdated,
            "ok": len(system_missing) == 0 and len(system_outdated) == 0
        },
        "python": {
            "missing": python_missing,
            "outdated": python_outdated,
            "ok": len(python_missing) == 0 and len(python_outdated) == 0
        },
        "all_ok": (len(system_missing) == 0 and len(system_outdated) == 0 and 
                  len(python_missing) == 0 and len(python_outdated) == 0)
    }

# -------------------------------------------------------------------------------
# get_log_file
# -------------------------------------------------------------------------------
# Funktion: Gibt den Pfad zur aktuellen Logdatei zurück
# Rückgabe: str – Pfad zur Logdatei
# -------------------------------------------------------------------------------
def get_log_file():
    try:
        log_file = subprocess.check_output(['bash', os.path.join(os.path.dirname(__file__), 'scripts', 'log_helper.sh'), 'get_log_file'])
        return log_file.decode().strip()
    except Exception as e:
        # Fallback: Schreibe ins Backup-Verzeichnis
        backup_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../backup/logs'))
        os.makedirs(backup_dir, exist_ok=True)
        return os.path.join(backup_dir, f"{datetime.now():%Y-%m-%d}_fotobox.log")

LOGFILE = get_log_file()

MAX_LOGFILES = 5

def rotate_logs():
    logs = sorted(glob.glob(os.path.join(LOG_DIR, '*_update.log')))
    while len(logs) > MAX_LOGFILES:
        os.remove(logs[0])
        logs = sorted(glob.glob(os.path.join(LOG_DIR, '*_update.log')))
rotate_logs()

DATA_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../data'))
DB_PATH = os.path.join(DATA_DIR, 'fotobox_settings.db')

os.makedirs(BACKUP_DIR, exist_ok=True)

# -------------------------------------------------------------------------------
# log
# -------------------------------------------------------------------------------
# Funktion: Schreibt eine Lognachricht mit Zeitstempel in die Logdatei
# Parameter: msg (str) – Nachricht
# -------------------------------------------------------------------------------
def log(msg, level="INFO", func=None, file=None):
    # Vor jedem Log-Eintrag: Logrotation und Komprimierung wie in chk_log_file
    try:
        subprocess.run(['bash', os.path.join(os.path.dirname(__file__), 'scripts', 'log_helper.sh'), 'chk_log_file'])
    except Exception:
        pass
    # Log-Eintrag über log_helper.sh schreiben (Formatierung, Loglevel, Funktionsname, Datei)
    try:
        args = ['bash', os.path.join(os.path.dirname(__file__), 'scripts', 'log_helper.sh'), 'log', f"{level}: {msg}"]
        if func:
            args.append(func)
        if file:
            args.append(file)
        subprocess.run(args)
    except Exception:
        # Fallback: Direkt in die Logdatei schreiben
        log_file = get_log_file() if 'get_log_file' in globals() else f"backup/logs/{datetime.now():%Y-%m-%d}_fotobox.log"
        with open(log_file, 'a') as f:
            f.write(f"[{datetime.now():%Y-%m-%d %H:%M:%S}] [{level}] {msg}\n")

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
#          und prüft/installiert Systemabhängigkeiten
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
    
    # Systemabhängigkeiten prüfen und installieren
    if os.name != 'nt' and os.geteuid() == 0:  # Nur auf Linux/Unix mit Root-Rechten
        try:
            sys_success, sys_msg = install_system_requirements()
            if sys_success:
                print(f"Systemabhängigkeiten: {sys_msg}")
                log(f"Systemabhängigkeiten: {sys_msg}")
            else:
                print(f"Warnung: Probleme mit Systemabhängigkeiten: {sys_msg}")
                log(f"Warnung: Probleme mit Systemabhängigkeiten: {sys_msg}", "WARNING")
        except Exception as e:
            print(f"Fehler bei Systemabhängigkeiten: {str(e)}")
            log(f"Fehler bei Systemabhängigkeiten: {str(e)}", "ERROR")
    
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
            sys.exit(1)        if not os.path.isfile(venv_pip):
            print("pip konnte nicht installiert werden. Abbruch.")
            log("pip konnte nicht installiert werden. Update abgebrochen.")
            sys.exit(1)
        print("pip wurde automatisch im venv installiert.")
        log("pip wurde automatisch im venv installiert.")
    
    # PIP aktualisieren
    run([venv_pip, 'install', '--upgrade', 'pip'])
    
    # Python-Abhängigkeiten aus der neuen requirements_python.inf installieren
    run([venv_pip, 'install', '-r', PYTHON_REQUIREMENTS_PATH])
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

def get_local_version():
    version_file = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'conf', 'version.inf'))
    try:
        with open(version_file, 'r') as f:
            return f.read().strip()
    except Exception:
        return None

def get_remote_version():
    import urllib.request
    url = 'https://raw.githubusercontent.com/DirkGoetze/MyFotoBox/main/conf/version.inf'
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            return response.read().decode('utf-8').strip()
    except Exception:
        return None

# -------------------------------------------------------------------------------
# main
# -------------------------------------------------------------------------------
# Funktion: Hauptablauf für das Update-Skript (Backup, Repo, Backend)
# -------------------------------------------------------------------------------
def main():
    print('Starte Update der Fotobox ...')
    local_version = get_local_version()
    remote_version = get_remote_version()
    if local_version and remote_version:
        if local_version == remote_version:
            print(f'Fotobox ist bereits auf dem neuesten Stand (Version {local_version}).')
            log(f'Keine Aktualisierung nötig. Lokale Version: {local_version}, Remote-Version: {remote_version}')
            
            # Überprüfe dennoch die Abhängigkeiten
            deps_status = get_dependencies_status()
            if not deps_status['all_ok']:
                print("Es wurden Probleme mit Abhängigkeiten festgestellt:")
                
                if deps_status['system']['missing']:
                    print(f"Fehlende Systempakete: {', '.join(deps_status['system']['missing'])}")
                if deps_status['system']['outdated']:
                    print(f"Veraltete Systempakete: {', '.join(deps_status['system']['outdated'])}")
                if deps_status['python']['missing']:
                    print(f"Fehlende Python-Module: {', '.join(deps_status['python']['missing'])}")
                if deps_status['python']['outdated']:
                    print(f"Veraltete Python-Module: {', '.join(deps_status['python']['outdated'])}")
                
                print("Diese Probleme können mit '--fix-dependencies' behoben werden.")
                log("Es wurden Probleme mit Abhängigkeiten festgestellt, Update erforderlich.", "WARNING")
                
                # Wenn --fix-dependencies als Parameter übergeben wurde, installiere fehlende Abhängigkeiten
                if '--fix-dependencies' in sys.argv:
                    print("Installiere fehlende und aktualisiere veraltete Abhängigkeiten...")
                    update_backend()
                    print('Abhängigkeiten aktualisiert. Siehe Log:', LOGFILE)
                
            return
        else:
            print(f'Update verfügbar: Lokal {local_version}, Remote {remote_version}. Update wird durchgeführt ...')
            log(f'Update: Lokal {local_version}, Remote {remote_version}')
    elif local_version:
        print(f'Lokale Version: {local_version}. Remote-Version konnte nicht ermittelt werden.')
    elif remote_version:
        print(f'Remote-Version: {remote_version}. Lokale Version konnte nicht ermittelt werden.')
    else:
        print('Versionsvergleich nicht möglich. Update wird trotzdem durchgeführt.')
    
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
    
    # Führe Backups und Updates durch
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
    elif '--install-system-deps' in sys.argv:
        # Nur Systemabhängigkeiten installieren, ohne andere Updates
        if os.name != 'nt' and os.geteuid() == 0:  # Nur auf Linux/Unix mit Root-Rechten
            try:
                sys_success, sys_msg = install_system_requirements()
                if sys_success:
                    print(f"Systemabhängigkeiten: {sys_msg}")
                    log(f"Systemabhängigkeiten: {sys_msg}")
                else:
                    print(f"Warnung: Probleme mit Systemabhängigkeiten: {sys_msg}")
                    log(f"Warnung: Probleme mit Systemabhängigkeiten: {sys_msg}", "WARNING")
                sys.exit(0)
            except Exception as e:
                print(f"Fehler bei Systemabhängigkeiten: {str(e)}")
                log(f"Fehler bei Systemabhängigkeiten: {str(e)}", "ERROR")
                sys.exit(1)
        else:
            print("Fehler: Die Installation von Systemabhängigkeiten erfordert Root-Rechte unter Linux/Unix.")
            log("Fehler: Die Installation von Systemabhängigkeiten erfordert Root-Rechte", "ERROR")
            sys.exit(1)
    main()
