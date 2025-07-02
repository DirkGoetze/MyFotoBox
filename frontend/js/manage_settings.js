/**
 * @file manage_settings.js
 * @description Verwaltungsmodul für Einstellungen in Fotobox2
 * @module manage_settings
 */

import { apiGet, apiPost } from './manage_api.js';
import { log, error, debug } from './manage_logging.js';
import { Result } from './utils.js';

// API-Endpunkte
const API = {
    SETTINGS: '/api/settings',
    DEFAULTS: '/api/settings/defaults',
    VALIDATE: '/api/settings/validate'
};

/**
 * @typedef {Object} SettingsObject
 * @property {string} [event_name] - Name des Events
 * @property {string} [event_date] - Datum des Events
 * @property {string} [color_mode] - Anzeigemodus (light, dark, system)
 * @property {number} [screensaver_timeout] - Timeout für den Bildschirmschoner
 * @property {number} [gallery_timeout] - Timeout für die Galerie-Ansicht
 * @property {number} [countdown_duration] - Dauer des Countdowns
 * @property {string} [camera_id] - ID der zu verwendenden Kamera
 * @property {string} [flash_mode] - Blitzmodus für die Kamera
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
 * Lädt alle Einstellungen vom Server
 * @returns {Promise<Result<SettingsObject>>} Einstellungen oder Fehler
 */
export async function loadSettings() {
    try {
        const response = await apiGet(API.SETTINGS);
        
        if (response.success) {
            const settings = { ...DEFAULT_SETTINGS, ...response.data };
            log('Einstellungen erfolgreich geladen');
            return Result.ok(settings);
        } else {
            warn('Fehler beim Laden der Einstellungen, verwende Standardwerte');
            return Result.ok(DEFAULT_SETTINGS);
        }
    } catch (err) {
        error('Fehler beim Laden der Einstellungen:', err);
        return Result.fail(err.message);
    }
}

/**
 * Speichert Einstellungen auf dem Server
 * @param {SettingsObject} settings - Zu speichernde Einstellungen
 * @returns {Promise<Result<boolean>>} Erfolg oder Fehler
 */
export async function saveSettings(settings) {
    try {
        // Validiere Einstellungen vor dem Speichern
        const validationResult = await validateSettings(settings);
        if (!validationResult.success) {
            return validationResult;
        }
        
        const response = await apiPost(API.SETTINGS, settings);
        
        if (response.success) {
            log('Einstellungen erfolgreich gespeichert');
            return Result.ok(true);
        } else {
            error('Fehler beim Speichern der Einstellungen:', response.error);
            return Result.fail(response.error);
        }
    } catch (err) {
        error('Fehler beim Speichern der Einstellungen:', err);
        return Result.fail(err.message);
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
