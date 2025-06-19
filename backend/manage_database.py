#!/usr/bin/env python3
"""
@file manage_database.py
@description Verwaltungsmodul für Datenbankoperationen in Fotobox2
@module manage_database
"""
# -------------------------------------------------------------------------------
# manage_database.py
# -------------------------------------------------------------------------------
# Funktion: Zentrale Verwaltung aller Datenbank-Aktivitäten der Fotobox
# (Initialisierung, Migration, Optimierung, Aufräumen, Struktur-Updates)
# -------------------------------------------------------------------------------
import os
import sqlite3
import shutil
import json
import logging
from datetime import datetime
import traceback

# Pfadkonfiguration über das zentrale Verzeichnismanagement
try:
    from manage_folders import get_data_dir
    DB_DIR = get_data_dir()
except ImportError:
    # Fallback falls manage_folders nicht verfügbar ist
    DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))

DB_PATH = os.path.join(DB_DIR, 'fotobox_settings.db')
OLD_DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), 'fotobox_settings.db'))

# Logging konfigurieren
try:
    from manage_logging import setup_logger
    logger = setup_logger('database')
except ImportError:
    # Fallback falls manage_logging nicht verfügbar ist
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger('database')

# -------------------------------------------------------------------------------
# connect_db
# -------------------------------------------------------------------------------
# Funktion: Stellt Verbindung zur Datenbank her
# Parameter: None
# Return: sqlite3.Connection - Datenbankverbindung
# -------------------------------------------------------------------------------
def connect_db():
    """Stellt eine Verbindung zur Datenbank her und gibt ein Connection-Objekt zurück"""
    try:
        os.makedirs(DB_DIR, exist_ok=True)
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row  # Ermöglicht den Zugriff auf Spalten über Namen
        return conn
    except Exception as e:
        logger.error(f"Fehler beim Verbinden zur Datenbank: {str(e)}")
        logger.debug(traceback.format_exc())
        raise

# -------------------------------------------------------------------------------
# init_db
# -------------------------------------------------------------------------------
# Funktion: Erstellt das Datenbankverzeichnis und die Datenbank, legt Tabellen an
# -------------------------------------------------------------------------------
def init_db():
    """Initialisiert die Datenbankstruktur"""
    try:
        os.makedirs(DB_DIR, exist_ok=True)
        conn = connect_db()
        cursor = conn.cursor()
        
        # Basis-Tabellen erstellen
        cursor.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        cursor.execute("CREATE TABLE IF NOT EXISTS image_metadata (id INTEGER PRIMARY KEY, filename TEXT, timestamp TEXT, tags TEXT)")
        cursor.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT UNIQUE, password_hash TEXT, role TEXT)")
        
        # Version in der Datenbank speichern
        cursor.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", 
                      ('db_version', '1.0.0'))
        
        conn.commit()
        conn.close()
        logger.info(f"Datenbankinitialisierung abgeschlossen: {DB_PATH}")
        return True
    except Exception as e:
        logger.error(f"Fehler bei der Datenbankinitialisierung: {str(e)}")
        logger.debug(traceback.format_exc())
        return False

# -------------------------------------------------------------------------------
# migrate_db
# -------------------------------------------------------------------------------
# Funktion: Verschiebt alte Datenbank ins neue data-Verzeichnis (Migration)
# -------------------------------------------------------------------------------
def migrate_db():
    """Migriert die Datenbank von alten zu neuen Strukturen"""
    try:
        if os.path.exists(OLD_DB_PATH) and not os.path.exists(DB_PATH):
            os.makedirs(DB_DIR, exist_ok=True)
            shutil.move(OLD_DB_PATH, DB_PATH)
            logger.info(f"Datenbankmigration erfolgreich: {OLD_DB_PATH} -> {DB_PATH}")
            return True
        else:
            logger.info("Keine Datenbankmigration erforderlich.")
            return True
    except Exception as e:
        logger.error(f"Fehler bei der Datenbankmigration: {str(e)}")
        logger.debug(traceback.format_exc())
        return False

# -------------------------------------------------------------------------------
# cleanup_db
# -------------------------------------------------------------------------------
# Funktion: Löscht nicht mehr benötigte Daten/Tabellen
# -------------------------------------------------------------------------------
def cleanup_db():
    """Bereinigt die Datenbank von temporären oder nicht mehr benötigten Daten"""
    try:
        conn = connect_db()
        cursor = conn.cursor()
        # Temporäre Einträge löschen
        cursor.execute("DELETE FROM settings WHERE key LIKE 'temp%'")
        conn.commit()
        conn.close()
        logger.info("Datenbank-Cleanup abgeschlossen")
        return True
    except Exception as e:
        logger.error(f"Fehler beim Datenbank-Cleanup: {str(e)}")
        logger.debug(traceback.format_exc())
        return False

# -------------------------------------------------------------------------------
# optimize_db
# -------------------------------------------------------------------------------
# Funktion: Optimiert die Datenbank (VACUUM)
# -------------------------------------------------------------------------------
def optimize_db():
    """Optimiert die Datenbank durch VACUUM-Operation"""
    try:
        conn = connect_db()
        conn.execute("VACUUM")
        conn.close()
        logger.info("Datenbankoptimierung abgeschlossen")
        return True
    except Exception as e:
        logger.error(f"Fehler bei der Datenbankoptimierung: {str(e)}")
        logger.debug(traceback.format_exc())
        return False

# -------------------------------------------------------------------------------
# CRUD-Operationen
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# query
# -------------------------------------------------------------------------------
# Funktion: Führt eine SELECT-Abfrage aus
# Parameter: sql - SQL-Query als String
#            params - Parameter für die Query (optional)
# Return: List[dict] - Ergebnisliste als Dictionary
# -------------------------------------------------------------------------------
def query(sql, params=None):
    """Führt eine SQL-Abfrage aus und gibt das Ergebnis zurück"""
    try:
        conn = connect_db()
        cursor = conn.cursor()
        
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
            
        result = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return {"success": True, "data": result}
    except Exception as e:
        logger.error(f"Fehler bei Datenbankabfrage: {str(e)}")
        logger.debug(f"SQL: {sql}, Params: {params}")
        logger.debug(traceback.format_exc())
        return {"success": False, "error": str(e), "sql": sql}

# -------------------------------------------------------------------------------
# insert
# -------------------------------------------------------------------------------
# Funktion: Fügt Daten in eine Tabelle ein
# Parameter: table - Name der Zieltabelle
#            data - Dictionary mit Spaltennamen und Werten
# Return: dict - Ergebnis mit lastrowid
# -------------------------------------------------------------------------------
def insert(table, data):
    """Fügt einen neuen Datensatz in die Datenbank ein"""
    try:
        conn = connect_db()
        cursor = conn.cursor()
        
        columns = ', '.join(data.keys())
        placeholders = ', '.join(['?' for _ in data])
        values = list(data.values())
        
        sql = f"INSERT INTO {table} ({columns}) VALUES ({placeholders})"
        cursor.execute(sql, values)
        
        last_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        logger.debug(f"Datensatz in {table} eingefügt, ID: {last_id}")
        return {"success": True, "id": last_id}
    except Exception as e:
        logger.error(f"Fehler beim Einfügen in {table}: {str(e)}")
        logger.debug(f"Daten: {data}")
        logger.debug(traceback.format_exc())
        return {"success": False, "error": str(e), "table": table}

# -------------------------------------------------------------------------------
# update
# -------------------------------------------------------------------------------
# Funktion: Aktualisiert Daten in einer Tabelle
# Parameter: table - Name der Zieltabelle
#            data - Dictionary mit zu aktualisierenden Spalten
#            condition - WHERE-Bedingung als String
#            params - Parameter für die Bedingung
# Return: dict - Ergebnis mit Anzahl betroffener Zeilen
# -------------------------------------------------------------------------------
def update(table, data, condition, params=None):
    """Aktualisiert Datensätze in der Datenbank"""
    try:
        conn = connect_db()
        cursor = conn.cursor()
        
        set_clause = ', '.join([f"{key} = ?" for key in data.keys()])
        values = list(data.values())
        
        sql = f"UPDATE {table} SET {set_clause} WHERE {condition}"
        
        if params:
            values.extend(params)
            cursor.execute(sql, values)
        else:
            cursor.execute(sql, values)
            
        affected_rows = cursor.rowcount
        conn.commit()
        conn.close()
        
        logger.debug(f"{affected_rows} Datensätze in {table} aktualisiert")
        return {"success": True, "affected_rows": affected_rows}
    except Exception as e:
        logger.error(f"Fehler beim Aktualisieren von {table}: {str(e)}")
        logger.debug(f"Daten: {data}, Bedingung: {condition}")
        logger.debug(traceback.format_exc())
        return {"success": False, "error": str(e), "table": table}

# -------------------------------------------------------------------------------
# delete
# -------------------------------------------------------------------------------
# Funktion: Löscht Daten aus einer Tabelle
# Parameter: table - Name der Zieltabelle
#            condition - WHERE-Bedingung als String
#            params - Parameter für die Bedingung
# Return: dict - Ergebnis mit Anzahl betroffener Zeilen
# -------------------------------------------------------------------------------
def delete(table, condition, params=None):
    """Löscht Datensätze aus der Datenbank"""
    try:
        conn = connect_db()
        cursor = conn.cursor()
        
        sql = f"DELETE FROM {table} WHERE {condition}"
        
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
            
        affected_rows = cursor.rowcount
        conn.commit()
        conn.close()
        
        logger.debug(f"{affected_rows} Datensätze aus {table} gelöscht")
        return {"success": True, "affected_rows": affected_rows}
    except Exception as e:
        logger.error(f"Fehler beim Löschen aus {table}: {str(e)}")
        logger.debug(f"Bedingung: {condition}, Parameter: {params}")
        logger.debug(traceback.format_exc())
        return {"success": False, "error": str(e), "table": table}

# -------------------------------------------------------------------------------
# get_setting
# -------------------------------------------------------------------------------
# Funktion: Holt eine Einstellung aus der settings-Tabelle
# Parameter: key - Schlüssel der gesuchten Einstellung
#            default - Standardwert falls nicht gefunden (optional)
# Return: Wert der Einstellung oder default-Wert
# -------------------------------------------------------------------------------
def get_setting(key, default=None):
    """Holt eine Einstellung aus der Datenbank"""
    try:
        result = query("SELECT value FROM settings WHERE key = ?", [key])
        if result["success"] and result["data"]:
            return result["data"][0]["value"]
        return default
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Einstellung {key}: {str(e)}")
        return default

# -------------------------------------------------------------------------------
# set_setting
# -------------------------------------------------------------------------------
# Funktion: Speichert eine Einstellung in der settings-Tabelle
# Parameter: key - Schlüssel der Einstellung
#            value - Wert der Einstellung
# Return: dict - Erfolgsstatus
# -------------------------------------------------------------------------------
def set_setting(key, value):
    """Speichert eine Einstellung in der Datenbank"""
    try:
        # Überprüfen, ob der Key bereits existiert
        result = query("SELECT key FROM settings WHERE key = ?", [key])
        
        if result["success"] and result["data"]:
            # Update vorhandener Eintrag
            return update("settings", {"value": value}, "key = ?", [key])
        else:
            # Neuen Eintrag anlegen
            return insert("settings", {"key": key, "value": value})
    except Exception as e:
        logger.error(f"Fehler beim Speichern der Einstellung {key}: {str(e)}")
        logger.debug(traceback.format_exc())
        return {"success": False, "error": str(e)}

# -------------------------------------------------------------------------------
# check_integrity
# -------------------------------------------------------------------------------
# Funktion: Prüft die Integrität der Datenbank
# Return: dict - Ergebnisstatus und Informationen
# -------------------------------------------------------------------------------
def check_integrity():
    """Überprüft die Integrität der Datenbank"""
    try:
        conn = connect_db()
        cursor = conn.cursor()
        
        # Integrity Check durchführen
        cursor.execute("PRAGMA integrity_check")
        integrity_result = cursor.fetchone()
        
        # Foreign Key Check durchführen
        cursor.execute("PRAGMA foreign_key_check")
        foreign_key_result = cursor.fetchall()
        
        conn.close()
        
        if integrity_result and integrity_result[0] == 'ok' and not foreign_key_result:
            logger.info("Datenbank-Integritätsprüfung erfolgreich")
            return {
                "success": True, 
                "integrity": "ok",
                "foreign_keys": "ok"
            }
        else:
            logger.warning("Datenbank-Integritätsprüfung fehlgeschlagen")
            return {
                "success": False, 
                "integrity": integrity_result[0] if integrity_result else "failed",
                "foreign_keys": "failed" if foreign_key_result else "ok"
            }
    except Exception as e:
        logger.error(f"Fehler bei der Datenbank-Integritätsprüfung: {str(e)}")
        logger.debug(traceback.format_exc())
        return {"success": False, "error": str(e)}

# -------------------------------------------------------------------------------
# CLI-Interface
# -------------------------------------------------------------------------------
if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Verwendung: python manage_database.py [init|migrate|cleanup|optimize|check]")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "init":
        success = init_db()
        sys.exit(0 if success else 1)
    elif cmd == "migrate":
        success = migrate_db()
        sys.exit(0 if success else 1)
    elif cmd == "cleanup":
        success = cleanup_db()
        sys.exit(0 if success else 1)
    elif cmd == "optimize":
        success = optimize_db()
        sys.exit(0 if success else 1)
    elif cmd == "check":
        result = check_integrity()
        print(json.dumps(result, indent=2))
        sys.exit(0 if result["success"] else 1)
    else:
        print(f"Unbekannter Befehl: {cmd}")
        sys.exit(1)
