/**
 * @file manage_settings.js
 * @description Verwaltungsmodul für Einstellungen in Fotobox2
 * @module manage_settings
 */

import { apiGet, apiPost } from './manage_api.js';
import { log, error, debug } from './manage_logging.js';
import { getSetting, setSetting } from './manage_database.js';

/**
 * @typedef {Object} SettingsObject
 * @property {string} [event_name] - Name des Events
 * @property {string} [event_date] - Datum des Events
 * @property {string} [color_mode] - Anzeigemodus der Anwendung (light, dark, system)
 * @property {number} [screensaver_timeout] - Timeout für den Bildschirmschoner in Sekunden
 * @property {number} [gallery_timeout] - Timeout für die Galerie-Ansicht in Sekunden
 * @property {number} [countdown_duration] - Dauer des Countdowns in Sekunden
 * @property {string} [camera_id] - ID der zu verwendenden Kamera
 * @property {string} [flash_mode] - Blitzmodus für die Kamera
 */

/**
 * @typedef {Object} ValidationResult
 * @property {boolean} valid - Gibt an, ob die Einstellungen gültig sind
 * @property {Object} [errors] - Fehlerinformationen, wenn nicht gültig
 */

/**
 * Standard-Einstellungen
 * @type {SettingsObject}
 */
const DEFAULT_SETTINGS = {
    event_name: 'Fotobox Event',
    event_date: new Date().toISOString().split('T')[0],
    color_mode: 'system',
    screensaver_timeout: 120,
    gallery_timeout: 60,
    countdown_duration: 3,
    camera_id: 'auto',
    flash_mode: 'auto'
};

/**
 * Validierungsregeln für Einstellungen
 * @type {Object}
 */
const VALIDATION_RULES = {
    event_name: {
        required: true,
        maxLength: 50
    },
    screensaver_timeout: {
        required: true,
        type: 'number',
        min: 30,
        max: 600
    },
    gallery_timeout: {
        required: true,
        type: 'number',
        min: 30,
        max: 300
    },
    countdown_duration: {
        required: true,
        type: 'number',
        min: 1,
        max: 10
    }
};

/**
 * Lädt alle Einstellungen
 * @returns {Promise<SettingsObject>} Alle Einstellungen
 */
export async function loadSettings() {
    try {
        debug('Lade alle Einstellungen');
        const response = await apiGet('/api/settings');
        
        if (response && Object.keys(response).length > 0) {
            log('Einstellungen erfolgreich geladen');
            return response;
        } else {
            warn('Keine Einstellungen gefunden, verwende Standardeinstellungen');
            return { ...DEFAULT_SETTINGS };
        }
    } catch (err) {
        error('Fehler beim Laden der Einstellungen', err);
        throw new Error(`Einstellungen konnten nicht geladen werden: ${err.message}`);
    }
}

/**
 * Lädt eine einzelne Einstellung
 * @param {string} key - Schlüssel der Einstellung
 * @param {*} [defaultValue=null] - Standardwert, falls die Einstellung nicht existiert
 * @returns {Promise<*>} Wert der Einstellung
 */
export async function loadSingleSetting(key, defaultValue = null) {
    try {
        debug(`Lade Einstellung: ${key}`);
        // Wir verwenden hier getSetting aus dem Database-Modul
        const value = await getSetting(key, defaultValue);
        
        // Wenn kein Wert gefunden wurde und ein Standardwert in DEFAULT_SETTINGS existiert
        if (value === null && DEFAULT_SETTINGS.hasOwnProperty(key)) {
            return DEFAULT_SETTINGS[key];
        }
        
        return value;
    } catch (err) {
        error(`Fehler beim Laden der Einstellung ${key}`, err);
        
        // Fallback auf Standard-Einstellungen, wenn verfügbar
        if (DEFAULT_SETTINGS.hasOwnProperty(key)) {
            return DEFAULT_SETTINGS[key];
        }
        
        return defaultValue;
    }
}

/**
 * Aktualisiert mehrere Einstellungen
 * @param {SettingsObject} settings - Zu aktualisierende Einstellungen
 * @returns {Promise<boolean>} True wenn alle Einstellungen erfolgreich aktualisiert wurden
 */
export async function updateSettings(settings) {
    try {
        debug('Aktualisiere mehrere Einstellungen', settings);
        
        // Validiere Einstellungen vor dem Speichern
        const validationResult = validateSettings(settings);
        if (!validationResult.valid) {
            error('Einstellungsvalidierung fehlgeschlagen', validationResult.errors);
            return false;
        }
        
        const response = await apiPost('/api/settings', settings);
        
        if (response && response.status === 'ok') {
            log('Einstellungen erfolgreich aktualisiert');
            return true;
        } else {
            error('Fehler beim Aktualisieren von Einstellungen', response);
            return false;
        }
    } catch (err) {
        error('Fehler beim Aktualisieren von Einstellungen', err);
        return false;
    }
}

/**
 * Aktualisiert eine einzelne Einstellung
 * @param {string} key - Schlüssel der Einstellung
 * @param {*} value - Neuer Wert
 * @returns {Promise<boolean>} True wenn die Einstellung erfolgreich aktualisiert wurde
 */
export async function updateSingleSetting(key, value) {
    try {
        debug(`Aktualisiere Einstellung: ${key}`, value);
        
        // Einzelne Einstellung validieren
        const settingObj = {};
        settingObj[key] = value;
        const validationResult = validateSettings(settingObj, [key]);
        
        if (!validationResult.valid) {
            error(`Validierung für ${key} fehlgeschlagen`, validationResult.errors);
            return false;
        }
        
        // Wir könnten hier theoretisch setSetting aus manage_database.js verwenden,
        // aber für die Konsistenz verwenden wir den gleichen API-Endpunkt wie für updateSettings
        const response = await apiPost('/api/settings', settingObj);
        
        if (response && response.status === 'ok') {
            log(`Einstellung ${key} erfolgreich aktualisiert`);
            return true;
        } else {
            error(`Fehler beim Aktualisieren der Einstellung ${key}`, response);
            return false;
        }
    } catch (err) {
        error(`Fehler beim Aktualisieren der Einstellung ${key}`, err);
        return false;
    }
}

/**
 * Validiert Einstellungen
 * @param {SettingsObject} settings - Zu validierende Einstellungen
 * @param {Array<string>} [keys=null] - Optionale Liste von Schlüsseln, die validiert werden sollen
 * @returns {ValidationResult} Validierungsergebnis
 */
export function validateSettings(settings, keys = null) {
    const errors = {};
    const keysToValidate = keys || Object.keys(settings);
    
    for (const key of keysToValidate) {
        if (!settings.hasOwnProperty(key)) continue;
        
        const value = settings[key];
        const rules = VALIDATION_RULES[key];
        
        if (!rules) continue; // Keine Validierungsregeln für diesen Schlüssel
        
        // Prüfung auf Pflichtfeld
        if (rules.required && (value === undefined || value === null || value === '')) {
            errors[key] = `${key} ist ein Pflichtfeld`;
            continue;
        }
        
        // Prüfung auf Zahlentyp
        if (rules.type === 'number' && typeof value !== 'undefined' && value !== null) {
            const numValue = Number(value);
            if (isNaN(numValue)) {
                errors[key] = `${key} muss eine Zahl sein`;
                continue;
            }
            
            // Minimalwert-Prüfung
            if (rules.min !== undefined && numValue < rules.min) {
                errors[key] = `${key} muss mindestens ${rules.min} sein`;
                continue;
            }
            
            // Maximalwert-Prüfung
            if (rules.max !== undefined && numValue > rules.max) {
                errors[key] = `${key} darf höchstens ${rules.max} sein`;
                continue;
            }
        }
        
        // Prüfung auf Textlänge
        if (typeof value === 'string' && rules.maxLength !== undefined && value.length > rules.maxLength) {
            errors[key] = `${key} darf höchstens ${rules.maxLength} Zeichen enthalten`;
            continue;
        }
    }
    
    return {
        valid: Object.keys(errors).length === 0,
        errors: errors
    };
}

/**
 * Setzt Einstellungen auf Standardwerte zurück
 * @param {Array<string>} [keys=null] - Optionale Liste von Schlüsseln, die zurückgesetzt werden sollen
 * @returns {Promise<boolean>} True wenn die Einstellungen erfolgreich zurückgesetzt wurden
 */
export async function resetToDefaults(keys = null) {
    try {
        debug('Setze Einstellungen auf Standardwerte zurück', keys ? keys : 'alle');
        
        const settingsToReset = {};
        const keysToReset = keys || Object.keys(DEFAULT_SETTINGS);
        
        // Nur Schlüssel zurücksetzen, die auch in DEFAULT_SETTINGS existieren
        for (const key of keysToReset) {
            if (DEFAULT_SETTINGS.hasOwnProperty(key)) {
                settingsToReset[key] = DEFAULT_SETTINGS[key];
            }
        }
        
        if (Object.keys(settingsToReset).length === 0) {
            debug('Keine Einstellungen zum Zurücksetzen gefunden');
            return true; // Nichts zu tun, daher erfolgreich
        }
        
        const response = await apiPost('/api/settings/reset', { 
            keys: Object.keys(settingsToReset) 
        });
        
        if (response && response.status === 'ok') {
            log('Einstellungen erfolgreich auf Standardwerte zurückgesetzt');
            return true;
        } else {
            error('Fehler beim Zurücksetzen der Einstellungen auf Standardwerte', response);
            return false;
        }
    } catch (err) {
        error('Fehler beim Zurücksetzen der Einstellungen auf Standardwerte', err);
        return false;
    }
}

// Export von Hilfsfunktionen
export { DEFAULT_SETTINGS };

// Initialisierungscode
log('Einstellungsmodul geladen');
