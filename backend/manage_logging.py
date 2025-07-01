#!/usr/bin/env python3
"""
@file manage_logging.py
@description Verwaltungsmodul für Logging in Fotobox2
@module manage_logging
"""

import os
import logging
import json
import sqlite3
from datetime import datetime
import traceback

# Initialisiere Basis-Logging für Bootstrapping-Phase
bootstrap_logger = logging.getLogger('bootstrap')
console_handler = logging.StreamHandler()
console_handler.setFormatter(logging.Formatter('[%(levelname)s] %(message)s'))
bootstrap_logger.addHandler(console_handler)
bootstrap_logger.setLevel(logging.INFO)

# Pfadkonfiguration über das zentrale Verzeichnismanagement
try:
    from manage_folders import get_log_dir, get_data_dir
    LOG_DIR = get_log_dir()
    DB_DIR = get_data_dir()
    
    # Stelle sicher, dass die Verzeichnisse existieren
    os.makedirs(LOG_DIR, exist_ok=True)
    os.makedirs(DB_DIR, exist_ok=True)
    
    bootstrap_logger.info(f"Log-Verzeichnis initialisiert: {LOG_DIR}")
    bootstrap_logger.info(f"Datenbank-Verzeichnis initialisiert: {DB_DIR}")
    
except ImportError as e:
    bootstrap_logger.error(f"Fehler beim Import von manage_folders: {e}")
    # Fallback falls manage_folders nicht verfügbar ist
    LOG_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'log'))
    DB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data'))
    
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        os.makedirs(DB_DIR, exist_ok=True)
        bootstrap_logger.info("Fallback-Verzeichnisse erstellt")
    except Exception as e:
        bootstrap_logger.error(f"Kritischer Fehler bei Verzeichniserstellung: {e}")
        raise

DB_PATH = os.path.join(DB_DIR, 'fotobox_logs.db')
LOG_FILE = os.path.join(LOG_DIR, f"{datetime.now().strftime('%Y-%m-%d')}_fotobox.log")
DEBUG_LOG_FILE = os.path.join(LOG_DIR, f"{datetime.now().strftime('%Y-%m-%d')}_fotobox_debug.log")

# Logging-Level konfigurieren - kann aus einer Konfigurationsdatei geladen werden
DEFAULT_LOG_LEVEL = logging.INFO

try:
    # Setup für Dateilogging
    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))

    # Setup für Debug-Logging
    debug_handler = logging.FileHandler(DEBUG_LOG_FILE)
    debug_handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s - %(pathname)s:%(lineno)d'))
    debug_handler.setLevel(logging.DEBUG)

    # Root Logger konfigurieren
    logger = logging.getLogger('fotobox')
    logger.setLevel(DEFAULT_LOG_LEVEL)
    logger.addHandler(file_handler)
    logger.addHandler(debug_handler)
    logger.addHandler(console_handler)
    
    bootstrap_logger.info("Logging-System erfolgreich initialisiert")
    
except Exception as e:
    bootstrap_logger.error(f"Fehler bei der Logger-Initialisierung: {e}")
    raise

def _init_db():
    """
    Initialisiert die Datenbank für die Log-Speicherung
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            level TEXT NOT NULL,
            message TEXT NOT NULL,
            context TEXT,
            source TEXT,
            user_id TEXT
        )
        ''')
        conn.commit()
        conn.close()
    except Exception as e:
        # Fallback zu Dateilogging, wenn DB nicht verfügbar ist
        logger.error(f"Fehler bei DB-Initialisierung: {e}")

def _store_log_in_db(level, message, context=None, source=None, user_id=None):
    """
    Speichert einen Logeintrag in der Datenbank
    
    Args:
        level: Log-Level (INFO, WARNING, ERROR, etc.)
        message: Die Lognachricht
        context: Zusätzlicher Kontext als Dict
        source: Quelle des Logs (Funktion, Modul, etc.)
        user_id: Optionale Benutzer-ID
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        timestamp = datetime.now().isoformat()
        context_json = json.dumps(context) if context else None
        cursor.execute(
            "INSERT INTO logs (timestamp, level, message, context, source, user_id) VALUES (?, ?, ?, ?, ?, ?)",
            (timestamp, level, message, context_json, source, user_id)
        )
        conn.commit()
        conn.close()
    except Exception as e:
        # Falls ein Fehler beim DB-Speichern auftritt, loggen wir in die Datei
        logger.error(f"Fehler beim Speichern des Logs in DB: {e}")

def log(message, context=None, source=None, user_id=None):
    """
    Loggt eine Informationsnachricht
    
    Args:
        message: Die zu loggende Nachricht
        context: Optionaler Kontext als Dict
        source: Quelle des Logs (Funktion, Modul, etc.)
        user_id: Optionale Benutzer-ID
    """
    logger.info(message)
    _store_log_in_db("INFO", message, context, source, user_id)

def error(message, exception=None, context=None, source=None, user_id=None):
    """
    Loggt eine Fehlernachricht
    
    Args:
        message: Die zu loggende Fehlernachricht
        exception: Optionale Exception
        context: Optionaler Kontext als Dict
        source: Quelle des Logs (Funktion, Modul, etc.)
        user_id: Optionale Benutzer-ID
    """
    if exception:
        error_details = {
            "exception_type": type(exception).__name__,
            "exception_message": str(exception),
            "traceback": traceback.format_exc()
        }
        if context:
            context.update(error_details)
        else:
            context = error_details
        logger.error(f"{message}: {exception}")
    else:
        logger.error(message)
    
    _store_log_in_db("ERROR", message, context, source, user_id)

def warn(message, context=None, source=None, user_id=None):
    """
    Loggt eine Warnungsnachricht
    
    Args:
        message: Die zu loggende Warnungsnachricht
        context: Optionaler Kontext als Dict
        source: Quelle des Logs (Funktion, Modul, etc.)
        user_id: Optionale Benutzer-ID
    """
    logger.warning(message)
    _store_log_in_db("WARNING", message, context, source, user_id)

def debug(message, context=None, source=None, user_id=None):
    """
    Loggt eine Debug-Nachricht (nur im Debug-Modus)
    
    Args:
        message: Die zu loggende Debug-Nachricht
        context: Optionaler Kontext als Dict
        source: Quelle des Logs (Funktion, Modul, etc.)
        user_id: Optionale Benutzer-ID
    """
    logger.debug(message)
    # Debug-Logs werden optional auch in DB gespeichert
    if logger.level <= logging.DEBUG:
        _store_log_in_db("DEBUG", message, context, source, user_id)

def get_logs(level=None, limit=100, offset=0, start_date=None, end_date=None, source=None):
    """
    Ruft Logs aus der Datenbank ab
    
    Args:
        level: Optional - Filter nach Log-Level
        limit: Maximale Anzahl zurückzugebender Logs
        offset: Offset für Paginierung
        start_date: Filter - Logs nach diesem Datum (ISO-Format)
        end_date: Filter - Logs vor diesem Datum (ISO-Format)
        source: Filter nach Log-Quelle
        
    Returns:
        Liste von Logeinträgen
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        query = "SELECT id, timestamp, level, message, context, source, user_id FROM logs"
        conditions = []
        params = []
        
        if level:
            conditions.append("level = ?")
            params.append(level)
            
        if start_date:
            conditions.append("timestamp >= ?")
            params.append(start_date)
            
        if end_date:
            conditions.append("timestamp <= ?")
            params.append(end_date)
            
        if source:
            conditions.append("source = ?")
            params.append(source)
            
        if conditions:
            query += " WHERE " + " AND ".join(conditions)
            
        query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        logs = []
        for row in rows:
            log_entry = {
                "id": row[0],
                "timestamp": row[1],
                "level": row[2],
                "message": row[3],
                "context": json.loads(row[4]) if row[4] else None,
                "source": row[5],
                "user_id": row[6]
            }
            logs.append(log_entry)
            
        conn.close()
        return logs
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Logs: {e}")
        return []

def clear_logs(older_than=None):
    """
    Löscht Logs aus der Datenbank
    
    Args:
        older_than: Optional - Nur Logs älter als dieses Datum (ISO-Format) löschen
        
    Returns:
        Anzahl gelöschter Logeinträge
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        if older_than:
            cursor.execute("DELETE FROM logs WHERE timestamp < ?", (older_than,))
        else:
            cursor.execute("DELETE FROM logs")
            
        deleted_count = cursor.rowcount
        conn.commit()
        conn.close()
        
        logger.info(f"{deleted_count} Logeinträge wurden gelöscht")
        return deleted_count
    except Exception as e:
        logger.error(f"Fehler beim Löschen der Logs: {e}")
        return 0

def set_log_level(level):
    """
    Setzt das Log-Level
    
    Args:
        level: Das zu setzende Log-Level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        
    Returns:
        Boolean, ob das Log-Level erfolgreich gesetzt wurde
    """
    try:
        log_level = getattr(logging, level.upper())
        logger.setLevel(log_level)
        logger.info(f"Log-Level auf {level.upper()} gesetzt")
        return True
    except (AttributeError, TypeError):
        logger.error(f"Ungültiges Log-Level: {level}")
        return False

# Initialisiere die Datenbank beim Import des Moduls
_init_db()
