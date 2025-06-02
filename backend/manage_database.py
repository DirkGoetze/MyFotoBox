# -------------------------------------------------------------------------------
# manage_database.py
# -------------------------------------------------------------------------------
# Funktion: Zentrale Verwaltung aller Datenbank-Aktivitäten der Fotobox
# (Initialisierung, Migration, Optimierung, Aufräumen, Struktur-Updates)
# -------------------------------------------------------------------------------
import os
import sqlite3
import shutil

DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')
OLD_DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), 'fotobox_settings.db'))

# -------------------------------------------------------------------------------
# init_db
# -------------------------------------------------------------------------------
# Funktion: Erstellt das Datenbankverzeichnis und die Datenbank, legt Tabellen an
# -------------------------------------------------------------------------------
def init_db():
    os.makedirs(DB_DIR, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    con.commit()
    con.close()
    print(f"Initialisierung abgeschlossen: {DB_PATH}")

# -------------------------------------------------------------------------------
# migrate_db
# -------------------------------------------------------------------------------
# Funktion: Verschiebt alte Datenbank ins neue data-Verzeichnis (Migration)
# -------------------------------------------------------------------------------
def migrate_db():
    if os.path.exists(OLD_DB_PATH) and not os.path.exists(DB_PATH):
        os.makedirs(DB_DIR, exist_ok=True)
        shutil.move(OLD_DB_PATH, DB_PATH)
        print(f"Migration: {OLD_DB_PATH} -> {DB_PATH}")
    else:
        print("Keine Migration erforderlich.")

# -------------------------------------------------------------------------------
# cleanup_db
# -------------------------------------------------------------------------------
# Funktion: Löscht nicht mehr benötigte Daten/Tabellen
# -------------------------------------------------------------------------------
def cleanup_db():
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    # Beispiel: Lösche alle Einträge mit key='temp'
    cur.execute("DELETE FROM settings WHERE key='temp'")
    con.commit()
    con.close()
    print("Cleanup abgeschlossen.")

# -------------------------------------------------------------------------------
# optimize_db
# -------------------------------------------------------------------------------
# Funktion: Optimiert die Datenbank (VACUUM)
# -------------------------------------------------------------------------------
def optimize_db():
    con = sqlite3.connect(DB_PATH)
    con.execute("VACUUM")
    con.close()
    print("Optimierung abgeschlossen.")

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Verwendung: python manage_database.py [init|migrate|cleanup|optimize]")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "init":
        init_db()
    elif cmd == "migrate":
        migrate_db()
    elif cmd == "cleanup":
        cleanup_db()
    elif cmd == "optimize":
        optimize_db()
    else:
        print(f"Unbekannter Befehl: {cmd}")
        sys.exit(1)
