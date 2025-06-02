import sqlite3
from flask import Flask, request, jsonify, session, redirect, url_for, render_template_string, send_from_directory
import os
import subprocess

# -------------------------------------------------------------------------------
# DB_PATH und Datenverzeichnis sicherstellen
# -------------------------------------------------------------------------------
DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')
os.makedirs(DB_DIR, exist_ok=True)

app = Flask(__name__)
app.secret_key = os.environ.get('FOTOBOX_SECRET_KEY', 'fotobox_default_secret')

# Datenbank initialisieren (bei jedem Start sicherstellen)
subprocess.run(['python3', os.path.join(os.path.dirname(__file__), 'manage_database.py'), 'init'])

# -------------------------------------------------------------------------------
# check_password
# -------------------------------------------------------------------------------
# Funktion: Prüft das eingegebene Passwort gegen den gespeicherten SHA256-Hash
# Rückgabe: True/False
# -------------------------------------------------------------------------------
def check_password(pw):
    import sqlite3, hashlib
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    cur.execute("SELECT value FROM settings WHERE key='config_password'")
    row = cur.fetchone()
    con.close()
    if not row:
        return False
    hashval = row[0]
    return hashlib.sha256(pw.encode()).hexdigest() == hashval

# -------------------------------------------------------------------------------
# login_required
# -------------------------------------------------------------------------------
# Funktion: Decorator für passwortgeschützte Routen
# -------------------------------------------------------------------------------
def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

# -------------------------------------------------------------------------------
# check_first_run
# -------------------------------------------------------------------------------
# Funktion: Prüft, ob die Fotobox das erste Mal aufgerufen wird (keine Konfiguration vorhanden)
# Rückgabe: True = erste Inbetriebnahme, False = Konfiguration vorhanden
# -------------------------------------------------------------------------------
def check_first_run():
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    cur.execute("SELECT COUNT(*) FROM settings WHERE key='config_password'")
    count = cur.fetchone()[0]
    # Standardwert für photo_timer bei Erstinstallation setzen
    cur.execute("SELECT COUNT(*) FROM settings WHERE key='photo_timer'")
    timer_count = cur.fetchone()[0]
    if timer_count == 0:
        cur.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ("photo_timer", "5"))
        con.commit()
    con.close()
    return count == 0

# -------------------------------------------------------------------------------
# / (Root-Route)
# -------------------------------------------------------------------------------
@app.route('/')
def root():
    if check_first_run():
        return redirect(url_for('config'))
    return send_from_directory('../frontend', 'index.html')

# -------------------------------------------------------------------------------
# /login (GET, POST)
# -------------------------------------------------------------------------------
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        pw = request.form.get('password', '')
        if check_password(pw):
            session['logged_in'] = True
            return redirect(url_for('config'))
        else:
            return render_template_string('<h3>Falsches Passwort!</h3><a href="/login">Zurück</a>')
    return render_template_string('<form method="post">\n        <h3>Fotobox Konfiguration Login</h3>\n        Passwort: <input type="password" name="password" autofocus>\n        <input type="submit" value="Login">\n    </form>')

# -------------------------------------------------------------------------------
# /logout
# -------------------------------------------------------------------------------
@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# -------------------------------------------------------------------------------
# /config (GET)
# -------------------------------------------------------------------------------
@app.route('/config')
@login_required
def config():
    return render_template_string('<h2>Fotobox Konfiguration</h2>\n    <a href="/logout">Logout</a>')

# -------------------------------------------------------------------------------
# /api/settings (GET, POST)
# -------------------------------------------------------------------------------
@app.route('/api/settings', methods=['GET', 'POST'])
def api_settings():
    db = sqlite3.connect(DB_PATH)
    cur = db.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    if request.method == 'POST':
        data = request.get_json(force=True)
        for key in ['camera_mode', 'resolution_width', 'resolution_height', 'storage_path', 'event_name', 'show_splash', 'photo_timer']:
            if key in data:
                cur.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (key, str(data[key])))
        db.commit()
        db.close()
        return jsonify({'status': 'ok'})
    # GET
    cur.execute("SELECT key, value FROM settings")
    result = {k: v for k, v in cur.fetchall()}
    # show_splash als bool zurückgeben (Default: '1')
    if 'show_splash' not in result:
        result['show_splash'] = '1'
    if 'photo_timer' not in result:
        result['photo_timer'] = '5'
    db.close()
    return jsonify(result)

# -------------------------------------------------------------------------------
# /api/backup (POST)
# -------------------------------------------------------------------------------
@app.route('/api/backup', methods=['POST'])
def api_backup():
    import subprocess, sys
    proc = subprocess.Popen([sys.executable, 'manage_update.py', '--backup-only'], cwd=os.path.dirname(__file__), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate(timeout=120)
    if proc.returncode == 0:
        return out.decode() or 'Backup abgeschlossen.'
    else:
        return (err.decode() or 'Fehler beim Backup!'), 500

# -------------------------------------------------------------------------------
# /api/update (GET, POST)
# -------------------------------------------------------------------------------
@app.route('/api/update', methods=['GET', 'POST'])
def api_update():
    import subprocess, sys
    repo_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    if request.method == 'GET':
        try:
            subprocess.run(['git', '-C', repo_dir, 'fetch'], check=True)
            local = subprocess.check_output(['git', '-C', repo_dir, 'rev-parse', 'HEAD']).strip()
            remote = subprocess.check_output(['git', '-C', repo_dir, 'rev-parse', '@{u}']).strip()
            update_available = (local != remote)
            return jsonify({'update_available': update_available})
        except subprocess.CalledProcessError as e:
            return jsonify({'update_available': False, 'error': 'Git-Fehler', 'details': str(e)}), 500
        except Exception as e:
            return jsonify({'update_available': False, 'error': 'Unbekannter Fehler', 'details': str(e)}), 500
    # POST: Führe Update nur aus, wenn Update verfügbar
    proc = subprocess.Popen([sys.executable, 'manage_update.py'], cwd=os.path.dirname(__file__), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate(timeout=120)
    if proc.returncode == 0:
        return out.decode() or 'Update abgeschlossen.'
    else:
        return (err.decode() or 'Fehler beim Update!'), 500

# -------------------------------------------------------------------------------
# /update (POST)
# -------------------------------------------------------------------------------
@app.route('/update', methods=['POST'])
def update_backend():
    import subprocess, sys
    proc = subprocess.Popen([sys.executable, 'manage_update.py'], cwd=os.path.dirname(__file__), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate(timeout=120)
    if proc.returncode == 0:
        return out.decode() or 'Update/Backup abgeschlossen.'
    else:
        return (err.decode() or 'Fehler beim Update/Backup!'), 500

# -------------------------------------------------------------------------------
# /api/take_photo (POST)
# -------------------------------------------------------------------------------
@app.route('/api/take_photo', methods=['POST'])
def take_photo():
    import time
    data = request.get_json(silent=True) or {}
    delay = int(data.get('delay', 0))
    if delay > 0:
        time.sleep(delay)
    # Hier eigentliche Fotoaufnahme-Logik (Platzhalter)
    # ... Foto aufnehmen und speichern ...
    # Dummy-Implementierung:
    # time.sleep(1) # Simuliert Fotoaufnahme
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
