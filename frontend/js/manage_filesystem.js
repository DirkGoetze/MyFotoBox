/**
 * @file manage_filesystem.js
 * @description Verwaltungsmodul für Dateisystem-Operationen in Fotobox2
 * @module manage_filesystem
 */

import { apiGet, apiPost, apiDelete } from './manage_api.js';
import { log, error, debug, warn } from './manage_logging.js';
import { Result } from './utils.js';

// API-Endpunkte
const API = {
    LIST: '/api/filesystem/list',
    INFO: '/api/filesystem/info',
    SPACE: '/api/filesystem/space',
    CREATE: '/api/filesystem/create',
    DELETE: '/api/filesystem/delete',
    MOVE: '/api/filesystem/move',
    COPY: '/api/filesystem/copy',
    UPLOAD: '/api/filesystem/upload',
    DOWNLOAD: '/api/filesystem/download'
};

/**
 * @typedef {Object} FileSystemResult
 * @property {boolean} success - Operationserfolg
 * @property {any} [data] - Rückgabedaten
 * @property {string} [error] - Fehlermeldung
 */

/**
 * @typedef {Object} FileInfo
 * @property {string} name - Dateiname
 * @property {string} path - Pfad
 * @property {number} size - Größe in Bytes
 * @property {string} type - MIME-Typ
 * @property {string} created - Erstellungsdatum
 * @property {string} modified - Änderungsdatum
 * @property {string} [checksum] - Optional: MD5-Prüfsumme
 */

/**
 * @typedef {Object} SpaceInfo
 * @property {number} total - Gesamtgröße in Bytes
 * @property {number} free - Freier Speicher in Bytes
 * @property {number} used - Belegter Speicher in Bytes
 * @property {number} percentUsed - Prozentuale Auslastung
 */

/**
 * Ruft Dateiliste eines Verzeichnisses ab
 * @param {string} path - Verzeichnispfad
 * @param {Object} [options] - Zusätzliche Optionen
 * @param {boolean} [options.recursive=false] - Rekursive Listung
 * @param {string} [options.filter] - Dateifilter (z.B. "*.jpg")
 * @returns {Promise<Result<FileInfo[]>>} Liste der Dateien
 */
export async function listFiles(path, options = {}) {
    try {
        const response = await apiGet(API.LIST, { path, ...options });
        
        if (response.success) {
            debug('Dateiliste erfolgreich abgerufen', { path, count: response.data.length });
            return Result.ok(response.data);
        } else {
            warn('Fehler beim Abrufen der Dateiliste', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler bei Dateisystem-Operation:', err);
        return Result.fail(err.message);
    }
}

/**
 * Ruft Detailinformationen einer Datei ab
 * @param {string} path - Dateipfad
 * @returns {Promise<Result<FileInfo>>} Dateiinformationen
 */
export async function getFileInfo(path) {
    try {
        const response = await apiGet(API.INFO, { path });
        
        if (response.success) {
            debug('Dateiinfo erfolgreich abgerufen', { path });
            return Result.ok(response.data);
        } else {
            warn('Fehler beim Abrufen der Dateiinfo', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler bei Dateisystem-Operation:', err);
        return Result.fail(err.message);
    }
}

/**
 * Erstellt ein Verzeichnis
 * @param {string} path - Zu erstellendes Verzeichnis
 * @returns {Promise<boolean>} - True bei erfolgreicher Erstellung
 */
export async function createDirectory(path) {
    try {
        debug('Verzeichnis erstellen', { path });
        const response = await apiPost('/api/filesystem/mkdir', { path });
        
        if (response && response.success) {
            log('Verzeichnis erfolgreich erstellt', { path });
            return true;
        } else {
            error('Fehler beim Erstellen des Verzeichnisses', response.error);
            return false;
        }
    } catch (err) {
        error('Fehler beim Erstellen des Verzeichnisses', err.message);
        return false;
    }
}

/**
 * Löscht ein Bild vom Server
 * @param {string} filename - Name der zu löschenden Datei
 * @param {string} [directory=GALLERY_DIR] - Verzeichnis der Datei
 * @returns {Promise<boolean>} - True bei erfolgreicher Löschung
 */
export async function deleteImage(filename, directory = GALLERY_DIR) {
    try {
        debug('Bild löschen', { filename, directory });
        const response = await apiPost('/api/filesystem/delete', { 
            filename,
            directory 
        });
        
        if (response && response.success) {
            log('Bild erfolgreich gelöscht', { filename, directory });
            return true;
        } else {
            error('Fehler beim Löschen des Bildes', response.error);
            return false;
        }
    } catch (err) {
        error('Fehler beim Löschen des Bildes', err.message);
        return false;
    }
}

/**
 * Prüft den verfügbaren Speicherplatz
 * @returns {Promise<SpaceInfo|null>} - Informationen über den Speicherplatz oder null bei Fehler
 */
export async function checkDiskSpace() {
    try {
        debug('Verfügbaren Speicherplatz prüfen');
        const response = await apiGet('/api/filesystem/space');
        
        if (response && response.success) {
            log('Speicherplatzinformationen abgerufen', { 
                free: formatFileSize(response.free),
                total: formatFileSize(response.total) 
            });
            return response;
        } else {
            error('Fehler beim Prüfen des Speicherplatzes', response.error);
            return null;
        }
    } catch (err) {
        error('Fehler beim Prüfen des Speicherplatzes', err.message);
        return null;
    }
}

/**
 * Formatiert eine Dateigröße in Bytes in eine lesbare Form
 * @param {number} size - Größe in Bytes
 * @returns {string} - Formatierte Größe (z.B. "1.23 MB")
 */
function formatFileSize(size) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let formattedSize = size;
    let unitIndex = 0;
    
    while (formattedSize >= 1024 && unitIndex < units.length - 1) {
        formattedSize /= 1024;
        unitIndex++;
    }
    
    return `${formattedSize.toFixed(2)} ${units[unitIndex]}`;
}

// Exportiere formatFileSize als Hilfsfunktion
export { formatFileSize };

// Initialisierungscode
log('Dateisystem-Modul geladen');
