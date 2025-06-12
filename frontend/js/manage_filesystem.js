/**
 * @file manage_filesystem.js
 * @description Verwaltungsmodul für Dateisystem-Operationen in Fotobox2
 * @module manage_filesystem
 */

import { apiGet, apiPost } from './manage_api.js';
import { log, error, debug } from './manage_logging.js';

/**
 * @typedef {Object} ImageList
 * @property {Array<string>} photos - Liste von Bilddateipfaden
 */

/**
 * @typedef {Object} SaveResult
 * @property {boolean} success - Gibt an, ob das Speichern erfolgreich war
 * @property {string} [path] - Pfad der gespeicherten Datei
 * @property {string} [error] - Fehlermeldung bei nicht erfolgreicher Operation
 */

/**
 * @typedef {Object} FileInfo
 * @property {string} name - Name der Datei
 * @property {string} path - Pfad zur Datei
 * @property {number} size - Dateigröße in Bytes
 * @property {string} type - MIME-Typ der Datei
 * @property {Date} created - Erstellungszeitpunkt
 * @property {Date} modified - Letzter Änderungszeitpunkt
 */

/**
 * @typedef {Object} SpaceInfo
 * @property {number} total - Gesamtspeicherplatz in Bytes
 * @property {number} free - Freier Speicherplatz in Bytes
 * @property {number} used - Genutzter Speicherplatz in Bytes
 * @property {number} percentUsed - Prozentualer Anteil des genutzten Speichers
 */

/**
 * Standard-Bildverzeichnis für die Galerie
 * @const {string}
 */
const GALLERY_DIR = 'gallery';

/**
 * Ruft eine Liste aller Bilder von der API ab
 * @param {string} [directory=GALLERY_DIR] - Das Verzeichnis, aus dem die Bilder abgerufen werden sollen
 * @returns {Promise<ImageList>} - Liste der Bilder
 */
export async function getImageList(directory = GALLERY_DIR) {
    try {
        debug('Bilderliste abrufen', { directory });
        const response = await apiGet(`/api/filesystem/images?directory=${directory}`);
        
        if (response && response.success) {
            log(`${response.photos.length} Bilder erfolgreich aus ${directory} abgerufen`);
            return response;
        } else {
            error('Fehler beim Abrufen der Bilderliste', response.error);
            return { success: false, photos: [], error: response.error || 'Unbekannter Fehler' };
        }
    } catch (err) {
        error('Fehler beim Abrufen der Bilderliste', err.message);
        return { success: false, photos: [], error: err.message };
    }
}

/**
 * Speichert ein Bild auf dem Server
 * @param {Blob|File|string} image - Das zu speichernde Bild (als Blob, File oder Base64-String)
 * @param {Object} options - Optionen für das Speichern
 * @param {string} [options.filename] - Name der Datei
 * @param {string} [options.directory=GALLERY_DIR] - Zielverzeichnis
 * @param {string} [options.type='image/jpeg'] - MIME-Typ des Bildes
 * @returns {Promise<SaveResult>} - Ergebnis des Speicherns
 */
export async function saveImage(image, options = {}) {
    const { filename = `photo_${Date.now()}.jpg`, directory = GALLERY_DIR, type = 'image/jpeg' } = options;
    
    try {
        debug('Bild speichern', { filename, directory });
        
        // FormData für das Hochladen vorbereiten
        const formData = new FormData();
        
        // Wenn das Bild ein Blob oder File ist, direkt verwenden
        if (image instanceof Blob || image instanceof File) {
            formData.append('image', image, filename);
        } 
        // Wenn das Bild ein Base64-String ist
        else if (typeof image === 'string' && image.startsWith('data:')) {
            // Base64 in Blob umwandeln
            const response = await fetch(image);
            const blob = await response.blob();
            formData.append('image', blob, filename);
        }
        // Ungültiges Format
        else {
            error('Ungültiges Bildformat beim Speichern');
            return { success: false, error: 'Ungültiges Bildformat' };
        }
        
        formData.append('directory', directory);
        formData.append('type', type);
        
        // API-Aufruf mit FormData
        const response = await fetch('/api/filesystem/save', {
            method: 'POST',
            body: formData
            // Keine Content-Type Header, wird automatisch gesetzt bei FormData
        });
        
        if (response.ok) {
            const result = await response.json();
            log('Bild erfolgreich gespeichert', { path: result.path });
            return { success: true, path: result.path };
        } else {
            const errorData = await response.json();
            error('Fehler beim Speichern des Bildes', errorData);
            return { success: false, error: errorData.error || 'Unbekannter Fehler beim Speichern' };
        }
    } catch (err) {
        error('Fehler beim Speichern des Bildes', err.message);
        return { success: false, error: err.message };
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
 * Ruft Metadaten einer Datei ab
 * @param {string} filename - Name der Datei
 * @param {string} [directory=GALLERY_DIR] - Verzeichnis der Datei
 * @returns {Promise<FileInfo|null>} - Metadaten der Datei oder null bei Fehler
 */
export async function getFileInfo(filename, directory = GALLERY_DIR) {
    try {
        debug('Dateimetadaten abrufen', { filename, directory });
        const response = await apiGet(`/api/filesystem/info?filename=${filename}&directory=${directory}`);
        
        if (response && response.success) {
            // Datum-Strings in Date-Objekte umwandeln
            if (response.data) {
                response.data.created = new Date(response.data.created);
                response.data.modified = new Date(response.data.modified);
            }
            
            return response.data;
        } else {
            error('Fehler beim Abrufen der Dateimetadaten', response.error);
            return null;
        }
    } catch (err) {
        error('Fehler beim Abrufen der Dateimetadaten', err.message);
        return null;
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
