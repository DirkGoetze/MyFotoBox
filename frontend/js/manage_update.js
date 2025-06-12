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
 * @property {string} remoteVersion - Die neueste verfügbare Version (falls vorhanden)
 */

/**
 * @typedef {Object} StatusObject
 * @property {string} status - Aktueller Status ("idle", "checking", "downloading", "installing", "error")
 * @property {number} progress - Fortschritt in Prozent (0-100)
 * @property {string} message - Statusmeldung
 */

/**
 * @typedef {Object} DependenciesStatus
 * @property {boolean} all_ok - Gibt an, ob alle Abhängigkeiten in Ordnung sind
 * @property {Object} system - Status der Systemabhängigkeiten
 * @property {string[]} system.missing - Fehlende Systempakete
 * @property {string[]} system.outdated - Veraltete Systempakete
 * @property {boolean} system.ok - Gibt an, ob alle Systemabhängigkeiten in Ordnung sind
 * @property {Object} python - Status der Python-Abhängigkeiten
 * @property {string[]} python.missing - Fehlende Python-Pakete
 * @property {string[]} python.outdated - Veraltete Python-Pakete
 * @property {boolean} python.ok - Gibt an, ob alle Python-Abhängigkeiten in Ordnung sind
 */

// Rate Limiting für Update-Checks
const UPDATE_CHECK_THROTTLE_MS = 60000; // Mindestens 1 Minute zwischen den Updateprüfungen
let lastUpdateCheck = 0;

// Lokale Variablen
let _updateStatus = {
    status: 'idle',
    progress: 0,
    message: 'Bereit'
};

let _versionInfo = {
    current: '0.0.0',
    lastCheck: null,
    updateAvailable: false,
    remoteVersion: null
};

// Neue Variable für den Abhängigkeitsstatus
let _dependenciesStatus = null;
let _updateInfo = null;
let _updateCheckDebounceTimer = null;

/**
 * Prüft auf verfügbare Updates mit Ratenbegrenzung
 * @returns {Promise<UpdateInfo>} Updateinformationen oder null
 */
export async function throttledCheckForUpdates() {
    const now = Date.now();
    
    // Prüfe, ob seit der letzten Prüfung genug Zeit vergangen ist
    if (now - lastUpdateCheck < UPDATE_CHECK_THROTTLE_MS) {
        log('Update-Prüfung übersprungen (Ratenbegrenzung)');
        return null;
    }
    
    // Debounce (bei mehreren schnell aufeinanderfolgenden Aufrufen nur den letzten ausführen)
    if (_updateCheckDebounceTimer) {
        clearTimeout(_updateCheckDebounceTimer);
    }
    
    return new Promise((resolve) => {
        _updateCheckDebounceTimer = setTimeout(async () => {
            try {
                const result = await checkForUpdates();
                _updateCheckDebounceTimer = null;
                lastUpdateCheck = Date.now();
                resolve(result);
            } catch (err) {
                _updateCheckDebounceTimer = null;
                resolve(null);
            }
        }, 500);
    });
}

/**
 * Prüft auf verfügbare Updates
 * @returns {Promise<UpdateInfo>} Informationen über das verfügbare Update oder null, wenn kein Update verfügbar ist
 */
export async function checkForUpdates() {
    try {
        _updateStatus = { status: 'checking', progress: 0, message: 'Prüfe auf Updates...' };
        
        // API-Aufruf zum Backend
        // Anpassung an die vorhandene API-Struktur
        const response = await apiGet('/api/update');
        
        if (response.update_available) {
            _updateInfo = {
                version: response.remote_version,
                releaseDate: response.release_date || new Date().toISOString(),
                changes: response.changes || [],
                size: response.size || 0,
                critical: response.critical || false
            };
            
            _versionInfo.updateAvailable = true;
            _versionInfo.lastCheck = new Date().toISOString();
            _versionInfo.remoteVersion = response.remote_version;
            _versionInfo.current = response.local_version;
            
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
            _versionInfo.current = response.local_version;
            
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
            message: 'Fehler bei der Update-Prüfung: ' + (err.message || 'Unbekannter Fehler')
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
            const response = await apiGet('/api/update/status');
            if (response && response.status) {
                _updateStatus = {
                    status: response.status,
                    progress: response.progress || 0,
                    message: response.message || 'Update wird installiert...'
                };
            }
        }
        
        return _updateStatus;
    } catch (err) {
        error('Fehler beim Abrufen des Update-Status', err);
        return _updateStatus;
    }
}

/**
 * Installiert verfügbares Update
 * @returns {Promise<boolean>} true, wenn Update erfolgreich installiert wurde
 */
export async function installUpdate() {
    if (!_versionInfo.updateAvailable || !_versionInfo.remoteVersion) {
        throw new Error('Kein Update verfügbar');
    }
    
    try {
        _updateStatus = { 
            status: 'downloading', 
            progress: 0, 
            message: 'Lade Update herunter...' 
        };
        
        // API-Aufruf zum Backend, um Update zu starten
        // Anpassung an die vorhandene API-Struktur
        const response = await apiPost('/api/update', {
            from_version: _versionInfo.current,
            to_version: _versionInfo.remoteVersion
        });
        
        _updateStatus = { 
            status: 'installing', 
            progress: 30, 
            message: 'Installiere Update...' 
        };
        
        log('Update-Installation gestartet');
        
        return true;
    } catch (err) {
        error('Fehler bei der Update-Installation', err);
        _updateStatus = { 
            status: 'error', 
            progress: 0, 
            message: 'Fehler bei der Update-Installation: ' + (err.message || 'Unbekannter Fehler')
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
        
        const response = await apiPost('/api/update/rollback');
        
        if (response && !response.error) {
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
            message: 'Fehler beim Zurücksetzen: ' + (err.message || 'Unbekannter Fehler')
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
    if (!_versionInfo.updateAvailable || !_versionInfo.remoteVersion) {
        throw new Error('Kein Update verfügbar für Planung');
    }
    
    try {
        const response = await apiPost('/api/update/schedule', {
            version: _versionInfo.remoteVersion,
            scheduled_time: scheduledTime.toISOString()
        });
        
        if (response && !response.error) {
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
 * Prüft die System- und Python-Abhängigkeiten
 * @returns {Promise<DependenciesStatus>} Status der Abhängigkeiten
 */
export async function checkDependencies() {
    try {
        const response = await apiGet('/api/update/dependencies');
        
        if (response && response.success) {
            _dependenciesStatus = response.dependencies;
            
            // Logge die Ergebnisse
            if (!_dependenciesStatus.all_ok) {
                log('Probleme mit Abhängigkeiten gefunden:');
                
                if (_dependenciesStatus.system.missing.length > 0) {
                    log(`Fehlende Systempakete: ${_dependenciesStatus.system.missing.join(', ')}`);
                }
                
                if (_dependenciesStatus.system.outdated.length > 0) {
                    log(`Veraltete Systempakete: ${_dependenciesStatus.system.outdated.join(', ')}`);
                }
                
                if (_dependenciesStatus.python.missing.length > 0) {
                    log(`Fehlende Python-Pakete: ${_dependenciesStatus.python.missing.join(', ')}`);
                }
                
                if (_dependenciesStatus.python.outdated.length > 0) {
                    log(`Veraltete Python-Pakete: ${_dependenciesStatus.python.outdated.join(', ')}`);
                }
            } else {
                log('Alle Abhängigkeiten sind in Ordnung');
            }
            
            return _dependenciesStatus;
        } else {
            throw new Error(response.error || 'Fehler bei der Abhängigkeitsprüfung');
        }
    } catch (err) {
        error('Fehler bei der Abhängigkeitsprüfung', err);
        throw err;
    }
}

/**
 * Gibt den Status der Abhängigkeiten zurück
 * @returns {DependenciesStatus} Status der Abhängigkeiten oder null, wenn noch nicht geprüft
 */
export function getDependenciesStatus() {
    return _dependenciesStatus;
}

/**
 * Installiert fehlende Abhängigkeiten 
 * @returns {Promise<boolean>} true, wenn die Installation erfolgreich war
 */
export async function installDependencies() {
    try {
        _updateStatus = {
            status: 'installing',
            progress: 0,
            message: 'Installiere fehlende Abhängigkeiten...'
        };
        
        // API-Aufruf zum Installieren der Abhängigkeiten
        const response = await apiPost('/api/update', {
            fix_dependencies: true
        });
        
        if (response && response.success) {
            _updateStatus = {
                status: 'idle',
                progress: 100,
                message: 'Abhängigkeiten wurden installiert'
            };
            
            log('Abhängigkeiten wurden installiert');
            return true;
        } else {
            _updateStatus = {
                status: 'error',
                progress: 0,
                message: 'Fehler bei der Installation der Abhängigkeiten: ' + (response.error || 'Unbekannter Fehler')
            };
            
            throw new Error(response.error || 'Fehler bei der Installation der Abhängigkeiten');
        }
    } catch (err) {
        error('Fehler bei der Installation der Abhängigkeiten', err);
        _updateStatus = {
            status: 'error',
            progress: 0,
            message: 'Fehler bei der Installation der Abhängigkeiten: ' + err.message
        };
        throw err;
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
