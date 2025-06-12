/**
 * @file manage_database.js
 * @description Verwaltungsmodul für Datenbankoperationen in Fotobox2
 * @module manage_database
 */

import { apiGet, apiPost } from './manage_api.js';
import { logInfo, logError, logDebug } from './manage_logging.js';

/**
 * Standard-Endpoint für Datenbank-Operationen
 * @const {string}
 */
const DB_ENDPOINT = '/api/database';

/**
 * @typedef {Object} DbResponse
 * @property {boolean} success - Gibt an, ob die Operation erfolgreich war
 * @property {Array|Object} [data] - Die Ergebnisdaten bei erfolgreicher Operation
 * @property {string} [error] - Fehlermeldung bei nicht erfolgreicher Operation
 * @property {number} [affected_rows] - Anzahl der betroffenen Zeilen bei UPDATE/DELETE
 * @property {number} [id] - ID des neuen Datensatzes bei INSERT
 */

/**
 * Führt eine Datenbankabfrage aus
 * @param {string} sql - SQL-Abfrage
 * @param {Array} [params] - Parameter für die Abfrage
 * @returns {Promise<DbResponse>} - Ergebnis der Abfrage
 */
export async function query(sql, params = null) {
    try {
        logDebug('DB Query ausführen', { sql, params });
        const response = await apiPost(`${DB_ENDPOINT}/query`, { sql, params });
        
        if (response && response.success) {
            return response;
        } else {
            logError('DB Query fehlgeschlagen', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        logError('Fehler bei DB Query', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Fügt Daten in eine Tabelle ein
 * @param {string} table - Tabellenname
 * @param {Object} data - Einzufügende Daten als Key-Value Objekt
 * @returns {Promise<DbResponse>} - Ergebnis der Operation
 */
export async function insert(table, data) {
    try {
        logDebug('DB Insert ausführen', { table, data });
        const response = await apiPost(`${DB_ENDPOINT}/insert`, { table, data });
        
        if (response && response.success) {
            return response;
        } else {
            logError('DB Insert fehlgeschlagen', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        logError('Fehler bei DB Insert', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Aktualisiert Daten in einer Tabelle
 * @param {string} table - Tabellenname
 * @param {Object} data - Zu aktualisierende Daten als Key-Value Objekt
 * @param {string} condition - WHERE-Bedingung
 * @param {Array} [params] - Parameter für die WHERE-Bedingung
 * @returns {Promise<DbResponse>} - Ergebnis der Operation
 */
export async function update(table, data, condition, params = null) {
    try {
        logDebug('DB Update ausführen', { table, data, condition, params });
        const response = await apiPost(`${DB_ENDPOINT}/update`, { 
            table, data, condition, params 
        });
        
        if (response && response.success) {
            return response;
        } else {
            logError('DB Update fehlgeschlagen', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        logError('Fehler bei DB Update', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Löscht Daten aus einer Tabelle
 * @param {string} table - Tabellenname
 * @param {string} condition - WHERE-Bedingung
 * @param {Array} [params] - Parameter für die WHERE-Bedingung
 * @returns {Promise<DbResponse>} - Ergebnis der Operation
 */
export async function remove(table, condition, params = null) {
    try {
        logDebug('DB Delete ausführen', { table, condition, params });
        // Verwende 'remove' als Funktion, da 'delete' ein reserviertes Wort ist
        const response = await apiPost(`${DB_ENDPOINT}/delete`, { 
            table, condition, params 
        });
        
        if (response && response.success) {
            return response;
        } else {
            logError('DB Delete fehlgeschlagen', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        logError('Fehler bei DB Delete', error.message);
        return { success: false, error: error.message };
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
        logDebug('DB Einstellung abrufen', { key });
        const response = await apiGet(`${DB_ENDPOINT}/settings/${encodeURIComponent(key)}`);
        
        if (response && response.success && response.data) {
            return response.data;
        } else {
            logDebug(`Einstellung ${key} nicht gefunden, verwende Standard`);
            return defaultValue;
        }
    } catch (error) {
        logError('Fehler beim Abrufen der Einstellung', error.message);
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
        logDebug('DB Einstellung speichern', { key, value });
        const response = await apiPost(`${DB_ENDPOINT}/settings`, { key, value });
        
        if (response && response.success) {
            return response;
        } else {
            logError('Fehler beim Speichern der Einstellung', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        logError('Fehler beim Speichern der Einstellung', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Prüft die Datenbankintegrität
 * @returns {Promise<DbResponse>} - Status der Integrität
 */
export async function checkIntegrity() {
    try {
        logDebug('DB Integritätsprüfung starten');
        const response = await apiGet(`${DB_ENDPOINT}/check-integrity`);
        
        if (response && response.success) {
            return response;
        } else {
            logError('DB Integritätsprüfung fehlgeschlagen', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        logError('Fehler bei DB Integritätsprüfung', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Ruft Datenbankstatistiken ab
 * @returns {Promise<DbResponse>} - Statistiken zur Datenbank
 */
export async function getStats() {
    try {
        logDebug('DB Statistiken abrufen');
        const response = await apiGet(`${DB_ENDPOINT}/stats`);
        
        if (response && response.success) {
            return response;
        } else {
            logError('Fehler beim Abrufen der DB Statistiken', response.error);
            return { success: false, error: response.error || 'Unbekannter Datenbankfehler' };
        }
    } catch (error) {
        logError('Fehler beim Abrufen der DB Statistiken', error.message);
        return { success: false, error: error.message };
    }
}
