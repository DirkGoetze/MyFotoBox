/**
 * @file manage_database.js
 * @description Verwaltungsmodul für Datenbankoperationen in Fotobox2
 * @module manage_database
 */

import { apiGet, apiPost } from './manage_api.js';
import { log, error, warn, debug } from './manage_logging.js';
import { Result } from './utils.js';

// API-Endpunkte
const API = {
    QUERY: '/api/database/query',
    BACKUP: '/api/database/backup',
    OPTIMIZE: '/api/database/optimize',
    SETTINGS: '/api/database/settings'
};

/**
 * @typedef {Object} DbResult
 * @property {boolean} success - Gibt an, ob die Operation erfolgreich war
 * @property {Array|Object} [data] - Die Ergebnisdaten
 * @property {string} [error] - Fehlermeldung
 * @property {number} [affected_rows] - Betroffene Zeilen
 * @property {number} [id] - ID des neuen Datensatzes
 */

/**
 * Führt eine Datenbankabfrage aus
 * @param {string} sql - SQL-Abfrage
 * @param {Array} [params] - Parameter für die Abfrage
 * @returns {Promise<Result<DbResult>>} - Ergebnis der Abfrage
 */
export async function query(sql, params = null) {
    try {
        debug('DB Query ausführen', { sql, params });
        const response = await apiPost(API.QUERY, { sql, params });
        
        if (response.success) {
            return Result.ok(response.data);
        } else {
            error('DB Query fehlgeschlagen:', response.error);
            return Result.fail(response.error || 'Datenbankfehler');
        }
    } catch (err) {
        error('Fehler bei DB Query:', err);
        return Result.fail(err.message);
    }
}

/**
 * Führt ein Datenbank-Backup durch
 * @returns {Promise<Result<string>>} - Pfad zur Backup-Datei
 */
export async function backup() {
    try {
        const response = await apiPost(API.BACKUP);
        
        if (response.success) {
            log('Datenbank-Backup erfolgreich erstellt');
            return Result.ok(response.data.backup_path);
        } else {
            error('Datenbank-Backup fehlgeschlagen:', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler beim Datenbank-Backup:', err);
        return Result.fail(err.message);
    }
}

/**
 * Optimiert die Datenbank
 * @returns {Promise<Result<boolean>>} - Erfolg der Operation
 */
export async function optimize() {
    try {
        const response = await apiPost(API.OPTIMIZE);
        
        if (response.success) {
            log('Datenbank-Optimierung erfolgreich');
            return Result.ok(true);
        } else {
            warn('Datenbank-Optimierung fehlgeschlagen:', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler bei Datenbank-Optimierung:', err);
        return Result.fail(err.message);
    }
}

/**
 * Ruft eine Einstellung aus der Datenbank ab
 * @param {string} key - Schlüssel der Einstellung
 * @param {*} defaultValue - Standardwert falls nicht gefunden
 * @returns {Promise<*>} - Wert der Einstellung
 */
export async function getSetting(key, defaultValue = null) {
    try {
        debug('DB Einstellung abrufen', { key });
        const response = await apiGet(`${API.SETTINGS}/${encodeURIComponent(key)}`);
        
        if (response && response.success && response.data) {
            return response.data;
        } else {
            debug(`Einstellung ${key} nicht gefunden, verwende Standard`);
            return defaultValue;
        }
    } catch (error) {
        error('Fehler beim Abrufen der Einstellung', error.message);
        return defaultValue;
    }
}

/**
 * Speichert eine Einstellung in der Datenbank
 * @param {string} key - Schlüssel der Einstellung
 * @param {*} value - Wert der Einstellung
 * @returns {Promise<DbResponse>} - Ergebnis der Operation
 */
export async function setSetting(key, value) {
    try {
        debug('DB Einstellung speichern', { key, value });
        const response = await apiPost(API.SETTINGS, { key, value });
        
        if (response && response.success) {
            return response;
        } else {
            error('Fehler beim Speichern der Einstellung', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        error('Fehler beim Speichern der Einstellung', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Prüft die Datenbankintegrität
 * @returns {Promise<DbResponse>} - Status der Integrität
 */
export async function checkIntegrity() {
    try {
        debug('DB Integritätsprüfung starten');
        const response = await apiGet(`${DB_ENDPOINT}/check-integrity`);
        
        if (response && response.success) {
            return response;
        } else {
            error('DB Integritätsprüfung fehlgeschlagen', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        error('Fehler bei DB Integritätsprüfung', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Ruft Datenbankstatistiken ab
 * @returns {Promise<DbResponse>} - Statistiken zur Datenbank
 */
export async function getStats() {
    try {
        debug('DB Statistiken abrufen');
        const response = await apiGet(`${DB_ENDPOINT}/stats`);
        
        if (response && response.success) {
            return response;
        } else {
            error('Fehler beim Abrufen der DB Statistiken', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        error('Fehler beim Abrufen der DB Statistiken', error.message);
        return { success: false, error: error.message };
    }
}
