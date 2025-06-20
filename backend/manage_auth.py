#!/usr/bin/env python3
"""
@file manage_auth.py
@description Verwaltungsmodul für Authentifizierung in Fotobox2
@module manage_auth
"""

import os
import sqlite3
import bcrypt
from flask import session, request, redirect, jsonify
from functools import wraps

# Pfad zur Datenbank
DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')

def is_password_set():
    """
    Prüft, ob ein Passwort in der Datenbank gesetzt ist
    
    Returns:
        bool: True wenn ein Passwort gesetzt ist, sonst False
    """
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    cur.execute("SELECT COUNT(*) FROM settings WHERE key='config_password'")
    count = cur.fetchone()[0]
    con.close()
    return count > 0

def validate_password(password):
    """
    Validiert das eingegebene Passwort gegen den Hash in der Datenbank
    
    Args:
        password (str): Das zu validierende Passwort
        
    Returns:
        bool: True wenn das Passwort korrekt ist, sonst False
    """
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
        return bcrypt.checkpw(password.encode(), hashval.encode())
    except Exception:
        return False

def set_password(password):
    """
    Setzt ein neues Passwort in der Datenbank
    
    Args:
        password (str): Das zu setzende Passwort
        
    Returns:
        bool: True wenn das Passwort erfolgreich gesetzt wurde, sonst False
    """
    if len(password) < 4:
        return False
    
    try:
        hashval = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
        
        con = sqlite3.connect(DB_PATH)
        cur = con.cursor()
        cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        cur.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", 
                    ('config_password', hashval))
        con.commit()
        con.close()
        return True
    except Exception:
        return False

def change_password(old_password, new_password):
    """
    Ändert ein bestehendes Passwort
    
    Args:
        old_password (str): Das alte Passwort zur Verifikation
        new_password (str): Das neue Passwort
        
    Returns:
        bool: True wenn das Passwort erfolgreich geändert wurde, sonst False
    """
    if not validate_password(old_password) or len(new_password) < 4:
        return False
    
    return set_password(new_password)

def get_login_status():
    """
    Gibt den aktuellen Login-Status zurück
    
    Returns:
        dict: Statusobjekt mit 'authenticated' Boolean
    """
    return {
        'authenticated': session.get('logged_in', False)
    }

def login(password):
    """
    Meldet einen Benutzer an
    
    Args:
        password (str): Das eingegebene Passwort
        
    Returns:
        bool: True wenn die Anmeldung erfolgreich war, sonst False
    """
    if validate_password(password):
        session['logged_in'] = True
        session['role'] = 'admin'  # In der einfachen Implementierung gibt es nur Admin-Nutzer
        session['user_id'] = 'admin'
        return True
    return False

def logout():
    """
    Meldet den Benutzer ab
    
    Returns:
        bool: Immer True, da die Abmeldung nicht fehlschlagen kann
    """
    if 'logged_in' in session:
        session.pop('logged_in')
        session.pop('role', None)
        session.pop('user_id', None)
    return True

def login_required(f):
    """
    Decorator für passwortgeschützte Routen, die HTML-Seiten zurückgeben
    
    Args:
        f: Die zu schützende Funktion
        
    Returns:
        function: Die dekorierte Funktion
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            return redirect('/login')
        return f(*args, **kwargs)
    return decorated

def require_auth(f):
    """
    Decorator für passwortgeschützte API-Routen, die JSON zurückgeben
    
    Args:
        f: Die zu schützende Funktion
        
    Returns:
        function: Die dekorierte Funktion
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            return jsonify({'success': False, 'error': 'Authentifizierung erforderlich'}), 401
        return f(*args, **kwargs)
    return decorated

def is_admin():
    """
    Prüft, ob der aktuelle Benutzer Admin-Rechte hat
    
    Returns:
        bool: True wenn der Benutzer Admin ist, sonst False
    """
    return session.get('role') == 'admin'

def hash_password(password):
    """
    Erstellt einen Hash für das gegebene Passwort
    
    Args:
        password (str): Das zu hashende Passwort
        
    Returns:
        str: Der Hash des Passworts
    """
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def verify_password(password, hashed):
    """
    Überprüft, ob das gegebene Passwort zum Hash passt
    
    Args:
        password (str): Das zu überprüfende Passwort
        hashed (str): Der gespeicherte Hash
        
    Returns:
        bool: True wenn das Passwort zum Hash passt, sonst False
    """
    try:
        return bcrypt.checkpw(password.encode(), hashed.encode())
    except Exception:
        return False

def check_credentials(username, password):
    """
    Überprüft Benutzername und Passwort gegen die Datenbank
    
    Args:
        username (str): Der zu überprüfende Benutzername
        password (str): Das zu überprüfende Passwort
        
    Returns:
        dict: Ergebnis der Überprüfung mit Status und ggf. Benutzerrolle
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Prüfen, ob Benutzer existiert
        cursor.execute("SELECT password, role FROM users WHERE username = ?", (username,))
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            return {"success": False, "error": "Benutzer nicht gefunden"}
        
        stored_password, role = result
        
        # Passwort überprüfen
        if verify_password(password, stored_password):
            return {"success": True, "role": role, "user_id": username}
        else:
            return {"success": False, "error": "Falsches Passwort"}
            
    except Exception as e:
        return {"success": False, "error": str(e)}
