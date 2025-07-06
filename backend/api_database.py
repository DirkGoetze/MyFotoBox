"""
api_database.py - API-Endpunkte für Datenbankoperationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Datenbankoperationen bereit und
dient als Schnittstelle zwischen dem Frontend und dem manage_database-Modul.
"""

# TODO: Integration mit dem neuen manage_database.sh-Modul
# - API-Endpunkte für die neuen Funktionen bereitstellen (Backup, Validierung, etc.)
# - Validierung von Anfragen anpassen (hierarchische Schlüssel)
# - Response-Format vereinheitlichen
# - Siehe detaillierte Anforderungen in 2025-07-02 Konfigurationswerte_neu.todo

from flask import Blueprint, request
from typing import Dict, Any, List, Optional
import logging
import os
import sqlite3

from manage_api import ApiResponse, handle_api_exception
from api_auth import token_required
import manage_database
from manage_folders import FolderManager

# Logger konfigurieren
logger = logging.getLogger(__name__)

# Blueprint für die Datenbank-API erstellen
api_database = Blueprint('api_database', __name__)

# FolderManager Instanz
folder_manager = FolderManager()

# Liste erlaubter SQL-Operationen für Nicht-Admins
ALLOWED_SQL_OPS = {'SELECT'}

def validate_sql_query(sql: str, is_admin: bool = False) -> bool:
    """
    Validiert eine SQL-Abfrage auf potenziell gefährliche Operationen
    
    Args:
        sql: Die zu prüfende SQL-Abfrage
        is_admin: Ob der Benutzer Admin-Rechte hat
    
    Returns:
        bool: True wenn die Abfrage sicher ist
    
    Raises:
        ValueError: Wenn die Abfrage potenziell gefährlich ist
    """
    if is_admin:
        return True
        
    sql_upper = sql.upper()
    ops = {word for word in sql_upper.split() if word in 
           {'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'CREATE', 'TRUNCATE'}}
    
    if not ops.issubset(ALLOWED_SQL_OPS):
        forbidden = ops - ALLOWED_SQL_OPS
        raise ValueError(f"Nicht erlaubte SQL-Operationen: {', '.join(forbidden)}")
        
    return True

# -------------------------------------------------------------------------------
# API-Endpunkte für Datenbankoperationen
# -------------------------------------------------------------------------------

@api_database.route('/api/database/query', methods=['POST'])
@token_required
def db_query() -> Dict[str, Any]:
    """
    API-Endpunkt für Datenbankabfragen
    
    Returns:
        Dict mit Abfrageergebnis
    """
    try:
        data = request.get_json()
        if not data or 'sql' not in data:
            return ApiResponse.error(
                message="SQL-Statement fehlt",
                status_code=400
            )
            
        sql = data['sql']
        params = data.get('params', [])
        
        # SQL-Validierung
        try:
            validate_sql_query(sql, is_admin=False)  # TODO: Admin-Status prüfen
        except ValueError as e:
            logger.warning(f"SQL-Validierung fehlgeschlagen: {e}")
            return ApiResponse.error(
                message="Operation nicht erlaubt",
                details=str(e),
                status_code=403
            )
        
        # Führe die Abfrage durch
        result = manage_database.query(sql, params)
        if not result['success']:
            return ApiResponse.error(
                message="Datenbankabfrage fehlgeschlagen",
                details=result.get('error'),
                status_code=400
            )
            
        return ApiResponse.success(data=result.get('data', []))
        
    except Exception as e:
        logger.error(f"Fehler bei DB-Abfrage: {e}")
        return handle_api_exception(e, endpoint='/api/database/query')

@api_database.route('/api/database/insert', methods=['POST'])
@token_required
def db_insert() -> Dict[str, Any]:
    """
    API-Endpunkt zum Einfügen von Daten
    
    Returns:
        Dict mit Status der Operation
    """
    try:
        data = request.get_json()
        if not data or 'table' not in data or 'data' not in data:
            return ApiResponse.error(
                message="Tabelle oder Daten fehlen",
                status_code=400
            )
            
        table = data['table']
        insert_data = data['data']
        
        # Führe den Insert durch
        result = manage_database.insert(table, insert_data)
        if not result['success']:
            return ApiResponse.error(
                message="Einfügen fehlgeschlagen",
                details=result.get('error'),
                status_code=400
            )
            
        return ApiResponse.success(
            message="Daten erfolgreich eingefügt",
            data={'id': result.get('last_id')}
        )
        
    except Exception as e:
        logger.error(f"Fehler beim DB-Insert: {e}")
        return handle_api_exception(e, endpoint='/api/database/insert')

@api_database.route('/api/database/update', methods=['POST'])
@token_required
def db_update() -> Dict[str, Any]:
    """
    API-Endpunkt zum Aktualisieren von Daten
    
    Returns:
        Dict mit Status der Operation
    """
    try:
        data = request.get_json()
        if not data or 'table' not in data or 'data' not in data or 'condition' not in data:
            return ApiResponse.error(
                message="Tabelle, Daten oder Bedingung fehlen",
                status_code=400
            )
            
        table = data['table']
        update_data = data['data']
        condition = data['condition']
        params = data.get('params', [])
        
        # Führe das Update durch
        result = manage_database.update(table, update_data, condition, params)
        if not result['success']:
            return ApiResponse.error(
                message="Aktualisierung fehlgeschlagen",
                details=result.get('error'),
                status_code=400
            )
            
        return ApiResponse.success(
            message="Daten erfolgreich aktualisiert",
            data={'rows_affected': result.get('rows_affected', 0)}
        )
        
    except Exception as e:
        logger.error(f"Fehler beim DB-Update: {e}")
        return handle_api_exception(e, endpoint='/api/database/update')

@api_database.route('/api/database/delete', methods=['POST'])
@token_required
def db_delete() -> Dict[str, Any]:
    """
    API-Endpunkt zum Löschen von Daten
    
    Returns:
        Dict mit Status der Operation
    """
    try:
        data = request.get_json()
        if not data or 'table' not in data or 'condition' not in data:
            return ApiResponse.error(
                message="Tabelle oder Bedingung fehlen",
                status_code=400
            )
            
        table = data['table']
        condition = data['condition']
        params = data.get('params', [])
        
        # Führe das Delete durch
        result = manage_database.delete(table, condition, params)
        if not result['success']:
            return ApiResponse.error(
                message="Löschen fehlgeschlagen",
                details=result.get('error'),
                status_code=400
            )
            
        return ApiResponse.success(
            message="Daten erfolgreich gelöscht",
            data={'rows_affected': result.get('rows_affected', 0)}
        )
        
    except Exception as e:
        logger.error(f"Fehler beim DB-Delete: {e}")
        return handle_api_exception(e, endpoint='/api/database/delete')

@api_database.route('/api/database/settings/<key>', methods=['GET'])
@token_required
def get_db_setting(key) -> Dict[str, Any]:
    """API-Endpunkt zum Abrufen einer Einstellung"""
    try:
        value = manage_database.get_setting(key)
        if value is None:
            return ApiResponse.error(
                message="Einstellung nicht gefunden",
                status_code=404
            )
        return ApiResponse.success(data=value)
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Einstellung {key}: {e}")
        return handle_api_exception(e, endpoint=f'/api/database/settings/{key}')

@api_database.route('/api/database/settings', methods=['POST'])
@token_required
def set_db_setting() -> Dict[str, Any]:
    """API-Endpunkt zum Speichern einer Einstellung"""
    try:
        data = request.get_json()
        key = data.get('key')
        value = data.get('value')
        
        if not key:
            return ApiResponse.error(
                message="Schlüssel fehlt",
                status_code=400
            )
            
        result = manage_database.set_setting(key, value)
        if not result['success']:
            return ApiResponse.error(
                message="Speichern der Einstellung fehlgeschlagen",
                details=result.get('error'),
                status_code=400
            )
            
        return ApiResponse.success(message="Einstellung erfolgreich gespeichert")
    except Exception as e:
        logger.error(f"Fehler beim Speichern der Einstellung: {e}")
        return handle_api_exception(e, endpoint='/api/database/settings')

@api_database.route('/api/database/check-integrity', methods=['GET'])
@token_required
def check_db_integrity() -> Dict[str, Any]:
    """API-Endpunkt zur Überprüfung der Datenbankintegrität"""
    try:
        result = manage_database.check_integrity()
        return ApiResponse.success(data=result)
    except Exception as e:
        logger.error(f"Fehler bei der Datenbankintegritätsprüfung: {e}")
        return handle_api_exception(e, endpoint='/api/database/check-integrity')

@api_database.route('/api/database/stats', methods=['GET'])
@token_required
def get_db_stats() -> Dict[str, Any]:
    """API-Endpunkt zum Abrufen von Datenbankstatistiken"""
    try:
        # Hier müssen wir die Statistiken manuell sammeln, da diese nicht direkt in manage_database implementiert sind
        conn = manage_database.connect_db()
        cursor = conn.cursor()
        
        # Tabellen auflisten
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row['name'] for row in cursor.fetchall()]
        
        # Statistiken pro Tabelle sammeln
        stats = {}
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) as count FROM {table}")
            count_result = cursor.fetchone()
            count = count_result['count'] if count_result else 0
            stats[table] = {'rows': count}
        
        # Datenbankgröße ermitteln
        db_size = os.path.getsize(manage_database.DB_PATH) if os.path.exists(manage_database.DB_PATH) else 0
        
        conn.close()
        
        return ApiResponse.success(data={
            'tables': tables,
            'stats': stats,
            'size_bytes': db_size,
            'size_mb': round(db_size / (1024 * 1024), 2)
        })
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Datenbankstatistiken: {e}")
        return handle_api_exception(e, endpoint='/api/database/stats')

@api_database.route('/api/database/backup', methods=['POST'])
@token_required
def backup_database() -> Dict[str, Any]:
    """API-Endpunkt zum Erstellen einer Datenbanksicherung"""
    try:
        # Datenbankdatei sichern
        import time
        import shutil
        
        # Backup-Verzeichnis erstellen, falls es nicht existiert
        backup_dir = os.path.join(os.path.dirname(manage_database.DB_PATH), 'backups')
        os.makedirs(backup_dir, exist_ok=True)
        
        # Eindeutigen Dateinamen erstellen
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        db_filename = os.path.basename(manage_database.DB_PATH)
        backup_filename = f"{os.path.splitext(db_filename)[0]}_{timestamp}.db"
        backup_path = os.path.join(backup_dir, backup_filename)
        
        # Datenbank-Verbindung sicherstellen und schließen
        conn = manage_database.connect_db()
        conn.close()
        
        # Datei kopieren
        shutil.copy2(manage_database.DB_PATH, backup_path)
        
        logger.info(f"Datenbanksicherung erstellt: {backup_path}")
        return ApiResponse.success(
            data={
                'filename': backup_filename,
                'path': backup_path,
                'size': os.path.getsize(backup_path)
            }
        )
    except Exception as e:
        logger.error(f"Fehler bei der Datenbanksicherung: {e}")
        return handle_api_exception(e, endpoint='/api/database/backup')

@api_database.route('/api/database/sync-metadata', methods=['POST'])
@token_required
def sync_metadata_with_filesystem() -> Dict[str, Any]:
    """API-Endpunkt zum Synchronisieren von Bildmetadaten mit dem Dateisystem"""
    try:
        import glob
        from manage_photo import PHOTO_DIR
        
        logger.info("Starte Metadaten-Synchronisation mit dem Dateisystem")
        
        # Zähle erstellt und aktualisierte Metadaten
        created_count = 0
        updated_count = 0
        
        # Verbindung zur Datenbank herstellen
        conn = manage_database.connect_db()
        cursor = conn.cursor()
        
        # Alle JPG-Dateien im Fotoverzeichnis finden
        photos = glob.glob(os.path.join(PHOTO_DIR, "**/*.jpg"), recursive=True)
        
        for photo_path in photos:
            # Relativen Pfad extrahieren (relativ zum PHOTO_DIR)
            rel_path = os.path.relpath(photo_path, PHOTO_DIR)
            
            # Prüfen, ob Metadaten bereits existieren
            cursor.execute("SELECT id FROM image_metadata WHERE filename = ?", (rel_path,))
            result = cursor.fetchone()
            
            # Dateiinformationen abrufen
            file_stat = os.stat(photo_path)
            timestamp = file_stat.st_mtime
            
            if result:
                # Metadaten aktualisieren
                cursor.execute(
                    "UPDATE image_metadata SET timestamp = ? WHERE id = ?",
                    (timestamp, result['id'])
                )
                updated_count += 1
            else:
                # Neue Metadaten erstellen
                # Standard-Tags mit Eventnamen extrahieren (falls verfügbar)
                event_name = manage_database.get_setting('event_name', 'Unbekannt')
                tags = {
                    'event': event_name,
                    'favorite': False
                }
                
                import json
                cursor.execute(
                    "INSERT INTO image_metadata (filename, timestamp, tags) VALUES (?, ?, ?)",
                    (rel_path, timestamp, json.dumps(tags))
                )
                created_count += 1
        
        # Änderungen speichern
        conn.commit()
        conn.close()
        
        logger.info(f"Metadaten-Synchronisation abgeschlossen. Erstellt: {created_count}, Aktualisiert: {updated_count}")
        return ApiResponse.success(
            data={
                'created': created_count,
                'updated': updated_count
            }
        )
    except Exception as e:
        logger.error(f"Fehler bei der Metadaten-Synchronisation: {e}")
        return handle_api_exception(e, endpoint='/api/database/sync-metadata')

@api_database.route('/api/database/cleanup-metadata', methods=['POST'])
@token_required
def cleanup_orphaned_metadata() -> Dict[str, Any]:
    """API-Endpunkt zum Bereinigen verwaister Metadateneinträge"""
    try:
        import glob
        from manage_photo import PHOTO_DIR
        
        logger.info("Starte Bereinigung verwaister Metadateneinträge")
        
        # Verbindung zur Datenbank herstellen
        conn = manage_database.connect_db()
        cursor = conn.cursor()
        
        # Alle Metadateneinträge laden
        cursor.execute("SELECT id, filename FROM image_metadata")
        metadata_entries = cursor.fetchall()
        
        # Verwaiste Einträge identifizieren und löschen
        removed_count = 0
        
        for entry in metadata_entries:
            # Überprüfen, ob die Datei existiert
            file_path = os.path.join(PHOTO_DIR, entry['filename'])
            if not os.path.exists(file_path):
                # Wenn die Datei nicht existiert, Metadaten löschen
                cursor.execute("DELETE FROM image_metadata WHERE id = ?", (entry['id'],))
                removed_count += 1
                logger.debug(f"Verwaisten Metadateneintrag entfernt: {entry['filename']}")
        
        # Änderungen speichern
        conn.commit()
        conn.close()
        
        logger.info(f"Bereinigung verwaister Metadateneinträge abgeschlossen. Entfernt: {removed_count}")
        return ApiResponse.success(
            data={
                'removed': removed_count
            }
        )
    except Exception as e:
        logger.error(f"Fehler bei der Bereinigung verwaister Metadaten: {e}")
        return handle_api_exception(e, endpoint='/api/database/cleanup-metadata')

def init_app(app):
    """Initialisiert die Datenbank-API mit der Flask-Anwendung"""
    app.register_blueprint(api_database)
