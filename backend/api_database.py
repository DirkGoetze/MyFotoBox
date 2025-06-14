"""
api_database.py - API-Endpunkte für Datenbankoperationen in Fotobox2

Dieses Modul stellt die Flask-API-Endpunkte für Datenbankoperationen bereit und
dient als Schnittstelle zwischen dem Frontend und dem manage_database-Modul.
"""

from flask import Blueprint, request, jsonify, session
import os
import sqlite3

import manage_database
import manage_logging
import manage_auth
import manage_api

# Blueprint für die Datenbank-API erstellen
api_database = Blueprint('api_database', __name__)

# -------------------------------------------------------------------------------
# API-Endpunkte für Datenbankoperationen
# -------------------------------------------------------------------------------

@api_database.route('/api/database/query', methods=['POST'])
@manage_auth.require_auth
def db_query():
    """API-Endpunkt für Datenbankabfragen"""
    try:
        data = request.get_json()
        sql = data.get('sql')
        params = data.get('params')
        
        if not sql:
            return jsonify({'success': False, 'error': 'SQL-Statement fehlt'}), 400
            
        # SQL-Injection-Prüfung
        if not manage_auth.is_admin():
            # Einfache Sicherheitsprüfung für Nicht-Admins
            forbidden_patterns = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'CREATE', 'TRUNCATE']
            if any(pattern in sql.upper() for pattern in forbidden_patterns):
                manage_logging.warn(f"Versuchter SQL-Injection-Angriff: {sql}", 
                                  context={'user_id': session.get('user_id')})
                return jsonify({'success': False, 'error': 'Operation nicht erlaubt'}), 403
        
        # Führe die Abfrage durch
        result = manage_database.query(sql, params)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler bei DB-Abfrage: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/insert', methods=['POST'])
@manage_auth.require_auth
def db_insert():
    """API-Endpunkt zum Einfügen von Daten"""
    try:
        data = request.get_json()
        table = data.get('table')
        insert_data = data.get('data')
        
        if not table or not insert_data:
            return jsonify({'success': False, 'error': 'Tabelle oder Daten fehlen'}), 400
            
        # Führe den Insert durch
        result = manage_database.insert(table, insert_data)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim DB-Insert: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/update', methods=['POST'])
@manage_auth.require_auth
def db_update():
    """API-Endpunkt zum Aktualisieren von Daten"""
    try:
        data = request.get_json()
        table = data.get('table')
        update_data = data.get('data')
        condition = data.get('condition')
        params = data.get('params')
        
        if not table or not update_data or not condition:
            return jsonify({'success': False, 'error': 'Tabelle, Daten oder Bedingung fehlen'}), 400
            
        # Führe das Update durch
        result = manage_database.update(table, update_data, condition, params)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim DB-Update: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/delete', methods=['POST'])
@manage_auth.require_auth
def db_delete():
    """API-Endpunkt zum Löschen von Daten"""
    try:
        data = request.get_json()
        table = data.get('table')
        condition = data.get('condition')
        params = data.get('params')
        
        if not table or not condition:
            return jsonify({'success': False, 'error': 'Tabelle oder Bedingung fehlen'}), 400
            
        # Führe das Delete durch
        result = manage_database.delete(table, condition, params)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim DB-Delete: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/settings/<key>', methods=['GET'])
@manage_auth.require_auth
def get_db_setting(key):
    """API-Endpunkt zum Abrufen einer Einstellung"""
    try:
        value = manage_database.get_setting(key)
        if value is None:
            return jsonify({'success': False, 'error': 'Einstellung nicht gefunden'}), 404
        return jsonify({'success': True, 'data': value})
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Einstellung {key}: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/settings', methods=['POST'])
@manage_auth.require_auth
def set_db_setting():
    """API-Endpunkt zum Speichern einer Einstellung"""
    try:
        data = request.get_json()
        key = data.get('key')
        value = data.get('value')
        
        if not key:
            return jsonify({'success': False, 'error': 'Schlüssel fehlt'}), 400
            
        result = manage_database.set_setting(key, value)
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler beim Speichern der Einstellung: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/check-integrity', methods=['GET'])
@manage_auth.require_auth
def check_db_integrity():
    """API-Endpunkt zur Überprüfung der Datenbankintegrität"""
    try:
        result = manage_database.check_integrity()
        return jsonify(result)
    except Exception as e:
        manage_logging.error(f"Fehler bei der Datenbankintegritätsprüfung: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/stats', methods=['GET'])
@manage_auth.require_auth
def get_db_stats():
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
        
        return jsonify({
            'success': True,
            'data': {
                'tables': tables,
                'stats': stats,
                'size_bytes': db_size,
                'size_mb': round(db_size / (1024 * 1024), 2)
            }
        })
    except Exception as e:
        manage_logging.error(f"Fehler beim Abrufen der Datenbankstatistiken: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/backup', methods=['POST'])
@manage_auth.require_auth
def backup_database():
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
        
        manage_logging.info(f"Datenbanksicherung erstellt: {backup_path}")
        return jsonify({
            'success': True,
            'data': {
                'filename': backup_filename,
                'path': backup_path,
                'size': os.path.getsize(backup_path)
            }
        })
    except Exception as e:
        manage_logging.error(f"Fehler bei der Datenbanksicherung: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/sync-metadata', methods=['POST'])
@manage_auth.require_auth
def sync_metadata_with_filesystem():
    """API-Endpunkt zum Synchronisieren von Bildmetadaten mit dem Dateisystem"""
    try:
        import glob
        from manage_photo import PHOTO_DIR
        
        manage_logging.info("Starte Metadaten-Synchronisation mit dem Dateisystem")
        
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
        
        manage_logging.info(f"Metadaten-Synchronisation abgeschlossen. Erstellt: {created_count}, Aktualisiert: {updated_count}")
        return jsonify({
            'success': True,
            'data': {
                'created': created_count,
                'updated': updated_count
            }
        })
    except Exception as e:
        manage_logging.error(f"Fehler bei der Metadaten-Synchronisation: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

@api_database.route('/api/database/cleanup-metadata', methods=['POST'])
@manage_auth.require_auth
def cleanup_orphaned_metadata():
    """API-Endpunkt zum Bereinigen verwaister Metadateneinträge"""
    try:
        import glob
        from manage_photo import PHOTO_DIR
        
        manage_logging.info("Starte Bereinigung verwaister Metadateneinträge")
        
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
                manage_logging.debug(f"Verwaisten Metadateneintrag entfernt: {entry['filename']}")
        
        # Änderungen speichern
        conn.commit()
        conn.close()
        
        manage_logging.info(f"Bereinigung verwaister Metadateneinträge abgeschlossen. Entfernt: {removed_count}")
        return jsonify({
            'success': True,
            'data': {
                'removed': removed_count
            }
        })
    except Exception as e:
        manage_logging.error(f"Fehler bei der Bereinigung verwaister Metadaten: {str(e)}", exception=e)
        return jsonify({'success': False, 'error': str(e)}), 500

def init_app(app):
    """Initialisiert die Datenbank-API mit der Flask-Anwendung"""
    app.register_blueprint(api_database)
