/**
 * @file manage_update.js
 * @description Verwaltungsmodul für System-Updates in Fotobox2
 * @module manage_update
 */

// Abhängigkeiten
import { apiGet, apiPost } from './manage_api.js';
import { log, error } from './manage_logging.js';

/**
 * @typedef {Object} UpdateInfo
 * @property {string} version - Verfügbare Version
 * @property {string} releaseDate - Veröffentlichungsdatum
 * @property {string[]} changes - Liste der Änderungen
 * @property {number} size - Größe des Updates in Bytes
 * @property {boolean} critical - Gibt an, ob es sich um ein kritisches Update handelt
 */

/**
 * @typedef {Object} VersionInfo
 * @property {string} current - Aktuelle Version
 * @property {string} lastCheck - Zeitpunkt der letzten Prüfung
 * @property {boolean} updateAvailable - Gibt an, ob ein Update verfügbar ist
 */

/**
 * @typedef {Object} StatusObject
 * @property {string} status - Aktueller Status ("idle", "checking", "downloading", "installing", "error")
 * @property {number} progress - Fortschritt in Prozent (0-100)
 * @property {string} message - Statusmeldung
 */

// Lokale Variablen
let _updateStatus = {
    status: 'idle',
    progress: 0,
    message: 'Bereit'
};

let _versionInfo = {
    current: '0.0.0',
    lastCheck: null,
    updateAvailable: false
};

let _updateInfo = null;

/**
 * Prüft auf verfügbare Updates
 * @returns {Promise<UpdateInfo>} Informationen über das verfügbare Update oder null, wenn kein Update verfügbar ist
 */
export async function checkForUpdates() {
    try {
        _updateStatus = { status: 'checking', progress: 0, message: 'Prüfe auf Updates...' };
        
        // API-Aufruf zum Backend
        const response = await apiGet('/api/v1/update/check');
        
        if (response.updateAvailable) {
            _updateInfo = response.updateInfo;
            _versionInfo.updateAvailable = true;
            _versionInfo.lastCheck = new Date().toISOString();
            
            log('Update verfügbar: ' + _updateInfo.version);
            
            _updateStatus = { 
                status: 'idle', 
                progress: 0, 
                message: `Update auf Version ${_updateInfo.version} verfügbar` 
            };
            
            return _updateInfo;
        } else {
            _versionInfo.updateAvailable = false;
            _versionInfo.lastCheck = new Date().toISOString();
            
            log('Kein Update verfügbar');
            
            _updateStatus = { 
                status: 'idle', 
                progress: 0, 
                message: 'System ist aktuell' 
            };
            
            return null;
        }
    } catch (err) {
        error('Fehler bei der Update-Prüfung', err);
        _updateStatus = { 
            status: 'error', 
            progress: 0, 
            message: 'Fehler bei der Update-Prüfung: ' + err.message 
        };
        throw err;
    }
}

/**
 * Liefert aktuellen Update-Status
 * @returns {Promise<StatusObject>} Status-Objekt
 */
export async function getUpdateStatus() {
    try {
        // Bei Bedarf aktualisierten Status vom Backend abrufen
        if (_updateStatus.status === 'downloading' || _updateStatus.status === 'installing') {
            const response = await apiGet('/api/v1/update/status');
            _updateStatus = response;
        }
        
        return _updateStatus;
    } catch (err) {
        error('Fehler beim Abrufen des Update-Status', err);
        throw err;
    }
}

/**
 * Installiert verfügbares Update
 * @returns {Promise<boolean>} true, wenn Update erfolgreich installiert wurde
 */
export async function installUpdate() {
    if (!_updateInfo) {
        throw new Error('Kein Update verfügbar');
    }
    
    try {
        _updateStatus = { 
            status: 'downloading', 
            progress: 0, 
            message: 'Lade Update herunter...' 
        };
        
        // API-Aufruf zum Backend, um Update zu starten
        const response = await apiPost('/api/v1/update/install', { version: _updateInfo.version });
        
        _updateStatus = { 
            status: 'installing', 
            progress: 0, 
            message: 'Installiere Update...' 
        };
        
        // In der Praxis würde hier ein Polling-Mechanismus zum Einsatz kommen,
        // um den Fortschritt zu überwachen - für dieses Beispiel vereinfacht
        
        log('Update-Installation gestartet');
        
        return true;
    } catch (err) {
        error('Fehler bei der Update-Installation', err);
        _updateStatus = { 
            status: 'error', 
            progress: 0, 
            message: 'Fehler bei der Update-Installation: ' + err.message 
        };
        throw err;
    }
}

/**
 * Setzt fehlgeschlagenes Update zurück
 * @returns {Promise<boolean>} true, wenn Zurücksetzung erfolgreich
 */
export async function rollbackUpdate() {
    try {
        _updateStatus = { 
            status: 'installing', 
            progress: 0, 
            message: 'Setze Update zurück...' 
        };
        
        const response = await apiPost('/api/v1/update/rollback');
        
        if (response.success) {
            _updateStatus = { 
                status: 'idle', 
                progress: 0, 
                message: 'Update wurde zurückgesetzt' 
            };
            
            log('Update zurückgesetzt');
            return true;
        } else {
            throw new Error(response.error || 'Unbekannter Fehler');
        }
    } catch (err) {
        error('Fehler beim Zurücksetzen des Updates', err);
        _updateStatus = { 
            status: 'error', 
            progress: 0, 
            message: 'Fehler beim Zurücksetzen: ' + err.message 
        };
        throw err;
    }
}

/**
 * Liefert Informationen zur aktuellen Version
 * @returns {VersionInfo} Versionsinformationen
 */
export function getVersionInfo() {
    return { ..._versionInfo };
}

/**
 * Plant automatisches Update
 * @param {Date} scheduledTime - Zeitpunkt für das geplante Update
 * @returns {Promise<boolean>} true, wenn Update erfolgreich geplant wurde
 */
export async function scheduleUpdate(scheduledTime) {
    if (!_updateInfo) {
        throw new Error('Kein Update verfügbar für Planung');
    }
    
    try {
        const response = await apiPost('/api/v1/update/schedule', {
            version: _updateInfo.version,
            scheduledTime: scheduledTime.toISOString()
        });
        
        if (response.success) {
            log(`Update geplant für ${scheduledTime.toLocaleString()}`);
            return true;
        } else {
            throw new Error(response.error || 'Unbekannter Fehler');
        }
    } catch (err) {
        error('Fehler bei der Update-Planung', err);
        throw err;
    }
}

/**
 * Initialisiert das Update-Modul
 * @returns {Promise<void>}
 */
export async function init() {
    try {
        // Aktuelle Version vom Backend abrufen
        const response = await apiGet('/api/v1/update/version');
        _versionInfo.current = response.version;
        
        log('Update-Modul initialisiert mit Version ' + _versionInfo.current);
    } catch (err) {
        error('Fehler bei der Initialisierung des Update-Moduls', err);
        throw err;
    }
}

// Automatische Initialisierung
init().catch(err => {
    console.error('Fehler bei der Initialisierung des Update-Moduls:', err);
});
