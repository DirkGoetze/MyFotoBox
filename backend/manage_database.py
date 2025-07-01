#!/usr/bin/env python3
"""
manage_database.py - Verwaltungsmodul für Datenbankoperationen in Fotobox2

Dieses Modul stellt zentrale Funktionen für alle Datenbankoperationen bereit und
stellt sicher, dass Datenbankzugriffe einheitlich und sicher erfolgen.
"""

import os
import sqlite3
import shutil
import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List, Tuple
from pathlib import Path

# Modul-Logger konfigurieren
logger = logging.getLogger(__name__)

# Importiere FolderManager für zentrale Pfadverwaltung
from manage_folders import FolderManager, get_data_dir, get_backup_dir

class DatabaseError(Exception):
    """Basisklasse für Datenbank-bezogene Fehler"""
    pass

class DatabaseConfigError(DatabaseError):
    """Fehler in der Datenbank-Konfiguration"""
    pass

class DatabaseManager:
    """Zentrale Verwaltungsklasse für Datenbankoperationen"""
    
    def __init__(self):
        self.folder_manager = FolderManager()
        self.data_dir = get_data_dir()
        self.backup_dir = get_backup_dir()
        self.db_path = os.path.join(self.data_dir, 'fotobox_settings.db')
        self._ensure_db_directory()
        self._init_database()
        
    def _ensure_db_directory(self) -> None:
        """Stellt sicher, dass das Datenbankverzeichnis existiert"""
        os.makedirs(self.data_dir, mode=0o755, exist_ok=True)
        
    def _init_database(self) -> None:
        """Initialisiert die Datenbankstruktur"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS settings (
                        key TEXT PRIMARY KEY,
                        value TEXT,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS camera_configs (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT NOT NULL,
                        config TEXT NOT NULL,
                        is_active INTEGER DEFAULT 0,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                conn.commit()
        except sqlite3.Error as e:
            logger.error(f"Fehler bei Datenbankinitialisierung: {e}")
            raise DatabaseError(f"Datenbankinitialisierung fehlgeschlagen: {e}")
            
    def backup_database(self) -> str:
        """Erstellt ein Backup der Datenbank"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = os.path.join(
                self.backup_dir,
                f"fotobox_settings_{timestamp}.db"
            )
            
            if os.path.exists(self.db_path):
                shutil.copy2(self.db_path, backup_path)
                logger.info(f"Datenbank-Backup erstellt: {backup_path}")
                return backup_path
            else:
                raise DatabaseError("Keine Datenbank zum Backup gefunden")
                
        except Exception as e:
            logger.error(f"Fehler beim Datenbank-Backup: {e}")
            raise DatabaseError(f"Backup fehlgeschlagen: {e}")
            
    def restore_database(self, backup_path: str) -> bool:
        """Stellt ein Datenbank-Backup wieder her"""
        try:
            if not os.path.exists(backup_path):
                raise DatabaseError(f"Backup-Datei nicht gefunden: {backup_path}")
                
            # Aktuelles Backup erstellen
            self.backup_database()
            
            # Backup wiederherstellen
            shutil.copy2(backup_path, self.db_path)
            logger.info(f"Datenbank wiederhergestellt von: {backup_path}")
            return True
            
        except Exception as e:
            logger.error(f"Fehler bei Datenbank-Wiederherstellung: {e}")
            raise DatabaseError(f"Wiederherstellung fehlgeschlagen: {e}")

# Globale Instanz
_db_manager = DatabaseManager()

# Convenience-Funktionen
def get_connection() -> sqlite3.Connection:
    """Gibt eine Datenbankverbindung zurück"""
    try:
        conn = sqlite3.connect(_db_manager.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error as e:
        logger.error(f"Fehler beim Verbindungsaufbau: {e}")
        raise DatabaseError(f"Verbindungsaufbau fehlgeschlagen: {e}")

def backup_db() -> str:
    """Erstellt ein Backup der Datenbank"""
    return _db_manager.backup_database()

def restore_db(backup_path: str) -> bool:
    """Stellt ein Datenbank-Backup wieder her"""
    return _db_manager.restore_database(backup_path)

def execute_query(query: str, params: tuple = (), fetch: bool = False) -> Optional[List[sqlite3.Row]]:
    """Führt eine SQL-Query aus"""
    try:
        with get_connection() as conn:
            cur = conn.execute(query, params)
            if fetch:
                return cur.fetchall()
            conn.commit()
            return None
    except sqlite3.Error as e:
        logger.error(f"Fehler bei Query-Ausführung: {e}")
        raise DatabaseError(f"Query-Ausführung fehlgeschlagen: {e}")

def get_setting(key: str, default: Any = None) -> Any:
    """Liest eine Einstellung aus der Datenbank"""
    try:
        result = execute_query(
            "SELECT value FROM settings WHERE key = ?",
            (key,),
            fetch=True
        )
        if result:
            return json.loads(result[0]['value'])
        return default
    except Exception as e:
        logger.error(f"Fehler beim Lesen von Einstellung {key}: {e}")
        return default

def set_setting(key: str, value: Any) -> bool:
    """Speichert eine Einstellung in der Datenbank"""
    try:
        execute_query(
            """
            INSERT OR REPLACE INTO settings (key, value, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            """,
            (key, json.dumps(value))
        )
        return True
    except Exception as e:
        logger.error(f"Fehler beim Speichern von Einstellung {key}: {e}")
        return False
