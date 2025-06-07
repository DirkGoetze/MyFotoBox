#!/usr/bin/env python3
import sqlite3
import os

# -------------------------------------------------------------------------------
# Hilfsskript zum Prüfen des Passwort-Status in der Datenbank
# -------------------------------------------------------------------------------

DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')

def check_password_status():
    """Überprüft, ob ein Admin-Passwort gesetzt ist"""
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    
    # Prüfe, ob config_password existiert
    cur.execute("SELECT value FROM settings WHERE key='config_password'")
    row = cur.fetchone()
    
    if row:
        print("✅ Passwort ist gesetzt (config_password existiert in der Datenbank)")
        # Wir zeigen den Hash nicht an, da das ein Sicherheitsrisiko wäre
        print("   Hash ist vorhanden (wird aus Sicherheitsgründen nicht angezeigt)")
    else:
        print("❌ Kein Passwort gesetzt (config_password existiert nicht in der Datenbank)")
    
    # Zeige alle Einstellungen in der Datenbank an (außer das Passwort)
    print("\n--- Alle Einstellungen in der Datenbank ---")
    cur.execute("SELECT key, value FROM settings WHERE key != 'config_password'")
    rows = cur.fetchall()
    
    if rows:
        for key, value in rows:
            print(f"{key}: {value}")
    else:
        print("Keine weiteren Einstellungen gefunden")
    
    con.close()

if __name__ == "__main__":
    check_password_status()
