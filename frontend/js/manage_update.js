/**
 * @file manage_update.js
 * @description Verwaltungsmodul für System-Updates in Fotobox2
 * @module manage_update
 */

import { apiGet, apiPost } from './manage_api.js';
import { log, error, warn, debug } from './manage_logging.js';
import { Result } from './utils.js';

// API-Endpunkte
const API = {
    CHECK: '/api/update/check',
    INFO: '/api/update/info',
    START: '/api/update/start',
    STATUS: '/api/update/status',
    CANCEL: '/api/update/cancel',
    DEPENDENCIES: '/api/update/dependencies',
    BACKUP: '/api/update/backup'
};

/**
 * Update-Status Enum
 * @readonly
 * @enum {string}
 */
export const UpdateStatus = {
    IDLE: 'idle',
    CHECKING: 'checking',
    DOWNLOADING: 'downloading',
    INSTALLING: 'installing',
    BACKING_UP: 'backing_up',
    VALIDATING: 'validating',
    ERROR: 'error',
    COMPLETE: 'complete'
};

/**
 * @typedef {Object} UpdateProgress
 * @property {UpdateStatus} status - Aktueller Status
 * @property {number} percent - Fortschritt in Prozent
 * @property {string} message - Statusmeldung
 * @property {Error} [error] - Optional: Aufgetretener Fehler
 */

/**
 * @typedef {Object} UpdateInfo
 * @property {string} currentVersion - Aktuelle Version
 * @property {string} latestVersion - Neueste verfügbare Version
 * @property {string[]} changes - Liste der Änderungen
 * @property {boolean} updateAvailable - Update verfügbar
 * @property {boolean} critical - Kritisches Update
 * @property {string} releaseDate - Veröffentlichungsdatum
 * @property {number} size - Update-Größe in Bytes
 */

// Update-Statusüberwachung
let _updateInterval = null;
let _statusCallbacks = new Set();
const UPDATE_CHECK_INTERVAL = 60000; // 1 Minute
const STATUS_CHECK_INTERVAL = 2000; // 2 Sekunden

/**
 * Prüft auf verfügbare Updates
 * @returns {Promise<Result<UpdateInfo>>} Update-Informationen
 */
export async function checkForUpdates() {
    try {
        const response = await apiPost(API.CHECK);
        
        if (response.success) {
            const updateInfo = response.data;
            if (updateInfo.updateAvailable) {
                log('Update verfügbar:', updateInfo.latestVersion);
            } else {
                debug('System ist aktuell');
            }
            return Result.ok(updateInfo);
        } else {
            warn('Update-Prüfung fehlgeschlagen:', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler bei Update-Prüfung:', err);
        return Result.fail(err.message);
    }
}

/**
 * Startet das Update
 * @returns {Promise<Result<boolean>>} Ergebnis des Update-Starts
 */
export async function startUpdate() {
    try {
        const response = await apiPost(API.START);
        
        if (response.success) {
            log('Update-Installation gestartet');
            return Result.ok(true);
        } else {
            error('Fehler beim Starten des Updates:', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler beim Starten des Updates:', err);
        return Result.fail(err.message);
    }
}

/**
 * Liefert den aktuellen Update-Status
 * @returns {Promise<Result<UpdateProgress>>} Aktueller Update-Fortschritt
 */
export async function getUpdateStatus() {
    try {
        const response = await apiGet(API.STATUS);
        
        if (response.success) {
            return Result.ok(response.data);
        } else {
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler beim Abrufen des Update-Status:', err);
        return Result.fail(err.message);
    }
}

/**
 * Setzt das Update zurück
 * @returns {Promise<Result<boolean>>} Ergebnis der Zurücksetzung
 */
export async function cancelUpdate() {
    try {
        const response = await apiPost(API.CANCEL);
        
        if (response.success) {
            log('Update zurückgesetzt');
            return Result.ok(true);
        } else {
            error('Fehler beim Zurücksetzen des Updates:', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler beim Zurücksetzen des Updates:', err);
        return Result.fail(err.message);
    }
}

/**
 * Prüft die System- und Python-Abhängigkeiten
 * @returns {Promise<Result<boolean>>} Ergebnis der Abhängigkeitsprüfung
 */
export async function checkDependencies() {
    try {
        const response = await apiGet(API.DEPENDENCIES);
        
        if (response.success) {
            const { system, python } = response.data;
            
            // Logik zur Überprüfung der Systemabhängigkeiten
            if (system.missing.length > 0) {
                log('Fehlende Systempakete:', system.missing.join(', '));
            }
            
            if (system.outdated.length > 0) {
                log('Veraltete Systempakete:', system.outdated.join(', '));
            }
            
            // Logik zur Überprüfung der Python-Abhängigkeiten
            if (python.missing.length > 0) {
                log('Fehlende Python-Pakete:', python.missing.join(', '));
            }
            
            if (python.outdated.length > 0) {
                log('Veraltete Python-Pakete:', python.outdated.join(', '));
            }
            
            return Result.ok(true);
        } else {
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler bei der Abhängigkeitsprüfung:', err);
        return Result.fail(err.message);
    }
}

/**
 * Erstellt ein Backup vor dem Update
 * @returns {Promise<Result<boolean>>} Ergebnis des Backup-Vorgangs
 */
export async function createBackup() {
    try {
        const response = await apiPost(API.BACKUP);
        
        if (response.success) {
            log('Backup erfolgreich erstellt');
            return Result.ok(true);
        } else {
            error('Fehler beim Erstellen des Backups:', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler beim Erstellen des Backups:', err);
        return Result.fail(err.message);
    }
}

/**
 * Initialisiert das Update-Modul
 * @returns {Promise<void>}
 */
export async function init() {
    try {
        // Initialisieren der Version (ggf. wird diese später durch checkForUpdates aktualisiert)
        const response = await apiGet('/api/update');
        if (response && response.local_version) {
            _versionInfo.current = response.local_version;
            
            // Prüfen, ob ein Update verfügbar ist
            if (response.update_available) {
                _versionInfo.updateAvailable = true;
                _versionInfo.remoteVersion = response.remote_version;
            }
        }
        
        // Auch die Abhängigkeiten prüfen (aber Fehler abfangen, damit die Initialisierung nicht scheitert)
        try {
            await checkDependencies();
        } catch (depErr) {
            error('Fehler bei der Prüfung der Abhängigkeiten', depErr);
            // Fehler nicht weiterleiten, damit die Initialisierung nicht scheitert
        }
        
        log('Update-Modul initialisiert mit Version ' + _versionInfo.current);
    } catch (err) {
        error('Fehler bei der Initialisierung des Update-Moduls', err);
    }
}

// Automatische Initialisierung beim Laden des Moduls
init().catch(err => {
    console.error('Fehler bei der Initialisierung des Update-Moduls:', err);
});
