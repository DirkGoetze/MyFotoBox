/**
 * @file i18n.js
 * @description Internationalisierungsmodul für die Fotobox2-Anwendung
 * @module i18n
 */

import { EVENTS } from './constants.js';
import { getSetting, setSetting } from './manage_database.js';

/**
 * Speichert die aktuell geladenen Übersetzungen
 * @private
 * @type {Object}
 */
let _translations = {};

/**
 * Speichert die aktuelle Sprache
 * @private
 * @type {string}
 */
let _currentLanguage = 'de';

/**
 * Speichert die Fallback-Sprache
 * @private
 * @type {string}
 */
let _fallbackLanguage = 'en';

/**
 * Initialisiert das i18n-Modul mit Übersetzungen und Standardsprache
 * @param {Object} translations - Übersetzungsobjekt mit Schlüsseln und mehrsprachigen Werten
 * @param {string} defaultLanguage - Standardsprache, die verwendet wird, wenn keine gespeichert ist
 * @param {string} [fallbackLanguage='en'] - Fallback-Sprache für fehlende Übersetzungen
 */
export async function init(translations, defaultLanguage, fallbackLanguage = 'en') {
    _translations = translations || {};
    _fallbackLanguage = fallbackLanguage;
    
    // Versuche, die gespeicherte Sprache aus der Datenbank zu laden
    try {
        const storedLanguage = await getSetting('language', null);
        _currentLanguage = storedLanguage || defaultLanguage;
    } catch (error) {
        console.error('Fehler beim Laden der Spracheinstellung:', error);
        _currentLanguage = defaultLanguage;
    }
    
    // HTML-Element mit Sprache kennzeichnen
    document.documentElement.lang = _currentLanguage;
    
    // Event-Dispatcher initialisieren
    console.log(`i18n initialisiert mit Sprache: ${_currentLanguage}`);
}

/**
 * Ändert die aktuelle Sprache und speichert die Präferenz
 * @param {string} language - Der Sprachcode (z.B. 'de', 'en')
 * @returns {Promise<boolean>} Promise, das zu true aufgelöst wird, wenn die Sprache erfolgreich geändert wurde
 */
export async function setLanguage(language) {
    if (language === _currentLanguage) return true;
    
    _currentLanguage = language;
    
    // Speichere die Sprachpräferenz in der Datenbank
    try {
        await setSetting('language', language);
    } catch (error) {
        console.error('Fehler beim Speichern der Spracheinstellung:', error);
    }
    
    // HTML-Element mit Sprache kennzeichnen
    document.documentElement.lang = language;
    
    // Informiere andere Komponenten über die Sprachänderung
    document.dispatchEvent(new CustomEvent(EVENTS.LANGUAGE_CHANGED, { 
        detail: { language } 
    }));
    
    console.log(`Sprache geändert auf: ${language}`);
    return true;
}

/**
 * Gibt die aktuelle Sprache zurück
 * @returns {string} Der aktuell verwendete Sprachcode
 */
export function getCurrentLanguage() {
    return _currentLanguage;
}

/**
 * Gibt alle verfügbaren Sprachen zurück
 * @returns {string[]} Liste der verfügbaren Sprachcodes
 */
export function getAvailableLanguages() {
    const languages = new Set();
    
    // Sammle alle verfügbaren Sprachen aus den Übersetzungen
    Object.values(_translations).forEach(translation => {
        Object.keys(translation).forEach(lang => {
            languages.add(lang);
        });
    });
    
    return Array.from(languages);
}

/**
 * Gibt einen übersetzten Text zurück
 * @param {string} key - Der Übersetzungsschlüssel
 * @param {Object} [replacements] - Objekt mit Ersetzungswerten
 * @returns {string} Der übersetzte Text oder der Schlüssel, wenn keine Übersetzung gefunden wurde
 */
export function t(key, replacements = {}) {
    // Prüfe, ob der Schlüssel existiert
    if (!_translations[key]) {
        console.warn(`Übersetzungsschlüssel nicht gefunden: ${key}`);
        return key;
    }
    
    // Versuche, die Übersetzung in der aktuellen Sprache zu finden
    let text = _translations[key][_currentLanguage];
    
    // Fallback auf die Standardsprache, wenn keine Übersetzung gefunden wurde
    if (!text) {
        text = _translations[key][_fallbackLanguage];
        
        // Wenn auch keine Fallback-Übersetzung existiert, verwende den ersten verfügbaren Text
        if (!text) {
            const availableLanguages = Object.keys(_translations[key]);
            if (availableLanguages.length > 0) {
                text = _translations[key][availableLanguages[0]];
            } else {
                return key;
            }
        }
    }
    
    // Ersetzungen durchführen
    if (replacements && typeof replacements === 'object') {
        Object.entries(replacements).forEach(([replaceKey, value]) => {
            text = text.replace(new RegExp(`{{\\s*${replaceKey}\\s*}}`, 'g'), value);
        });
    }
    
    return text;
}

/**
 * Lädt eine Sprachdatei asynchron nach
 * @param {string} language - Der Sprachcode der zu ladenden Sprache
 * @param {string} url - Die URL zur JSON-Sprachdatei
 * @returns {Promise<Object>} Promise mit den geladenen Übersetzungen
 */
export async function loadLanguage(language, url) {
    try {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP-Fehler beim Laden der Sprache: ${response.status}`);
        }
        
        const translations = await response.json();
        
        // Füge die Übersetzungen zum vorhandenen Übersetzungsobjekt hinzu
        Object.entries(translations).forEach(([key, value]) => {
            if (!_translations[key]) {
                _translations[key] = {};
            }
            _translations[key][language] = value;
        });
        
        console.log(`Sprache ${language} erfolgreich geladen`);
        
        // Wenn die aktuelle Sprache geladen wurde, löse ein Event aus
        if (language === _currentLanguage) {
            document.dispatchEvent(new CustomEvent(EVENTS.LANGUAGE_CHANGED, { 
                detail: { language } 
            }));
        }
        
        return translations;
    } catch (error) {
        console.error(`Fehler beim Laden der Sprache ${language}:`, error);
        throw error;
    }
}

/**
 * Überprüft, ob ein bestimmter Sprachschlüssel existiert
 * @param {string} key - Der zu prüfende Übersetzungsschlüssel
 * @returns {boolean} True, wenn der Schlüssel existiert
 */
export function hasTranslation(key) {
    return !!_translations[key];
}

/**
 * Registriert einen DOM-Knoten für automatische Übersetzungen
 * @param {Element} element - Das DOM-Element, das übersetzt werden soll
 */
export function translateElement(element) {
    const elements = element.querySelectorAll('[data-i18n]');
    
    elements.forEach(el => {
        const key = el.getAttribute('data-i18n');
        if (key) {
            el.textContent = t(key);
        }
        
        // Attribute übersetzen
        for (const attr of el.attributes) {
            if (attr.name.startsWith('data-i18n-attr-')) {
                const attrName = attr.name.replace('data-i18n-attr-', '');
                const attrValue = attr.value;
                el.setAttribute(attrName, t(attrValue));
            }
        }
    });
}

// Automatische Übersetzung beim Laden der Seite und bei Sprachänderungen
document.addEventListener('DOMContentLoaded', () => {
    translateElement(document);
});

document.addEventListener(EVENTS.LANGUAGE_CHANGED, () => {
    translateElement(document);
});
