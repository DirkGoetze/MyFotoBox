import sqlite3
from flask import Flask, request, jsonify, session, redirect, url_for, render_template_string, send_from_directory
import os
import subprocess
import bcrypt

# -------------------------------------------------------------------------------
# DB_PATH und Datenverzeichnis sicherstellen
# -------------------------------------------------------------------------------
DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')
os.makedirs(DB_DIR, exist_ok=True)

app = Flask(__name__)
app.secret_key = os.environ.get('FOTOBOX_SECRET_KEY', 'fotobox_default_secret')

# Cache-Kontrolle für die Testphase
@app.after_request
def add_no_cache_headers(response):
    """
    Fügt No-Cache-Header zu allen Antworten für die Testphase hinzu
    """
    # Prüfe, ob wir uns im Testmodus befinden
    test_mode = os.environ.get('FOTOBOX_TEST_MODE', 'true').lower() == 'true'
    
    if test_mode:
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = '0'
        
        # Debug-Header hinzufügen, um zu zeigen, dass die Cache-Deaktivierung aktiv ist
        response.headers['X-Fotobox-Test-Mode'] = 'active'
    
    return response

# Datenbank initialisieren (bei jedem Start sicherstellen)
subprocess.run(['python3', os.path.join(os.path.dirname(__file__), 'manage_database.py'), 'init'])

# -------------------------------------------------------------------------------
# check_password (bcrypt)
# -------------------------------------------------------------------------------
def check_password(pw):
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    cur.execute("SELECT value FROM settings WHERE key='config_password'")
    row = cur.fetchone()
    con.close()
    if not row:
        return False
    hashval = row[0]
    try:
        return bcrypt.checkpw(pw.encode(), hashval.encode())
    except Exception:
        return False

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
        return redirect('/setup.html')
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
    if check_first_run():
        return redirect('/setup.html')
    return render_template_string('<h2>Fotobox Konfiguration</h2>\n    <a href="/logout">Logout</a>')

# -------------------------------------------------------------------------------
# /api/login (POST)
# -------------------------------------------------------------------------------
@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.get_json(force=True)
    pw = data.get('password', '')
    if check_password(pw):
        session['logged_in'] = True
        return jsonify({'success': True})
    else:
        return jsonify({'success': False}), 401

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
        # Admin-Passwort setzen/ändern
        if 'admin_password' in data and data['admin_password'] and len(data['admin_password']) >= 4:
            hashval = bcrypt.hashpw(data['admin_password'].encode(), bcrypt.gensalt()).decode()
            cur.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ('config_password', hashval))
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
    import sys
    import urllib.request
    local_version = None
    remote_version = None
    try:
        with open(os.path.join(os.path.dirname(__file__), '../conf/version.inf'), 'r') as f:
            local_version = f.read().strip()
    except Exception:
        pass
    try:
        url = 'https://raw.githubusercontent.com/DirkGoetze/MyFotoBox/main/conf/version.inf'
        with urllib.request.urlopen(url, timeout=5) as response:
            remote_version = response.read().decode('utf-8').strip()
    except Exception:
        pass
    if request.method == 'GET':
        if local_version and remote_version:
            update_available = (local_version != remote_version)
            return jsonify({'update_available': update_available, 'local_version': local_version, 'remote_version': remote_version})
        return jsonify({'update_available': False, 'error': 'Versionsvergleich nicht möglich', 'local_version': local_version, 'remote_version': remote_version}), 500
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

# -------------------------------------------------------------------------------
# /api/nginx_status (GET)
# -------------------------------------------------------------------------------
@app.route('/api/nginx_status', methods=['GET'])
def api_nginx_status():
    """
    Gibt die aktuelle NGINX-Konfiguration als JSON zurück (liefert die Ausgabe von manage_nginx.sh get_nginx_status json).
    """
    import subprocess
    script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'manage_nginx.sh')
    try:
        result = subprocess.run(['bash', script_path, 'get_nginx_status', 'json'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and result.stdout.strip().startswith('{'):
            return result.stdout, 200, {'Content-Type': 'application/json'}
        else:
            return jsonify({'error': 'Fehler beim Auslesen der NGINX-Konfiguration', 'details': result.stderr}), 500
    except Exception as e:
        return jsonify({'error': 'Exception beim Auslesen der NGINX-Konfiguration', 'details': str(e)}), 500

# -------------------------------------------------------------------------------
# /api/gallery (GET)
# -------------------------------------------------------------------------------
# Funktion: Gibt eine Liste der Fotos im gallery-Ordner zurück
# -------------------------------------------------------------------------------
@app.route('/api/gallery', methods=['GET'])
def api_gallery():
    gallery_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'frontend', 'photos', 'gallery'))
    os.makedirs(gallery_dir, exist_ok=True)
    
    # Dateien auflisten und nach Datum sortieren (neuste zuerst)
    files = []
    for f in os.listdir(gallery_dir):
        if f.lower().endswith(('.png', '.jpg', '.jpeg', '.gif')):
            files.append(f)
    
    # Sortiere nach Dateiänderungsdatum (neuste zuerst)
    files.sort(key=lambda x: os.path.getmtime(os.path.join(gallery_dir, x)), reverse=True)
    
    return jsonify({'photos': files})

# -------------------------------------------------------------------------------
# /api/photos (GET)
# -------------------------------------------------------------------------------
# Funktion: Gibt eine Liste der Originalfotos zurück
# -------------------------------------------------------------------------------
@app.route('/api/photos', methods=['GET'])
def api_photos():
    photos_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'frontend', 'photos', 'originals'))
    os.makedirs(photos_dir, exist_ok=True)
    
    files = []
    for f in os.listdir(photos_dir):
        if f.lower().endswith(('.png', '.jpg', '.jpeg', '.gif')):
            files.append(f)
    
    # Sortiere nach Dateiänderungsdatum (neuste zuerst)
    files.sort(key=lambda x: os.path.getmtime(os.path.join(photos_dir, x)), reverse=True)
    
    return jsonify({'photos': files})

# -------------------------------------------------------------------------------
# /api/check_password_set (GET)
# -------------------------------------------------------------------------------
# Funktion: Prüft, ob ein Admin-Passwort gesetzt ist (für Erstinstallation)
# -------------------------------------------------------------------------------
@app.route('/api/check_password_set', methods=['GET'])
def api_check_password_set():
    is_password_set = not check_first_run()
    return jsonify({'password_set': is_password_set})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
