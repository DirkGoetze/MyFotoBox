/**
 * @file utils.js
 * @description Allgemeine Hilfsfunktionen für Fotobox2
 * @module utils
 */

import { log, debug } from './manage_logging.js';

/**
 * Formatiert eine Dateigröße in eine lesbare Form
 * @param {number} bytes - Anzahl der Bytes
 * @param {number} [decimals=2] - Anzahl der Dezimalstellen
 * @returns {string} Formatierte Größe (z.B. "1.23 MB")
 */
export function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(decimals)) + ' ' + sizes[i];
}

/**
 * Verzögert den Aufruf einer Funktion
 * @param {Function} func - Die zu verzögernde Funktion
 * @param {number} wait - Verzögerungszeit in ms
 * @param {boolean} [immediate=false] - Ob die Funktion sofort ausgeführt werden soll
 * @returns {Function} Die verzögerte Funktion
 */
export function debounce(func, wait, immediate = false) {
    let timeout;
    
    return function executedFunction(...args) {
        const context = this;
        
        const later = function() {
            timeout = null;
            if (!immediate) func.apply(context, args);
        };
        
        const callNow = immediate && !timeout;
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
        
        if (callNow) func.apply(context, args);
    };
}

/**
 * Drosselt die Ausführung einer Funktion
 * @param {Function} func - Die zu drosselnde Funktion
 * @param {number} limit - Minimale Zeit zwischen Aufrufen in ms
 * @returns {Function} Die gedrosselte Funktion
 */
export function throttle(func, limit) {
    let lastCall = 0;
    
    return function executedFunction(...args) {
        const now = Date.now();
        const context = this;
        
        if (now - lastCall >= limit) {
            func.apply(context, args);
            lastCall = now;
        }
    };
}

/**
 * Analysiert einen URL-Query-String
 * @param {string} [queryString=window.location.search] - Der zu analysierende Query-String
 * @returns {Object} Objekt mit den Query-Parametern
 */
export function parseQueryString(queryString = window.location.search) {
    const params = {};
    const queries = queryString.substring(1).split('&');
    
    for (let i = 0; i < queries.length; i++) {
        const pair = queries[i].split('=');
        if (pair[0] && pair[0].trim()) {
            params[decodeURIComponent(pair[0])] = pair.length > 1 ? decodeURIComponent(pair[1]) : '';
        }
    }
    
    return params;
}

/**
 * Generiert eine UUID v4
 * @returns {string} Die generierte UUID
 */
export function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

/**
 * Formatiert ein Datum als String im deutschen Format
 * @param {Date} [date=new Date()] - Das zu formatierende Datum
 * @param {boolean} [includeTime=false] - Ob die Uhrzeit eingeschlossen werden soll
 * @returns {string} Das formatierte Datum
 */
export function formatDate(date = new Date(), includeTime = false) {
    const day = date.getDate().toString().padStart(2, '0');
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const year = date.getFullYear();
    
    let result = `${day}.${month}.${year}`;
    
    if (includeTime) {
        const hours = date.getHours().toString().padStart(2, '0');
        const minutes = date.getMinutes().toString().padStart(2, '0');
        result += ` ${hours}:${minutes}`;
    }
    
    return result;
}

/**
 * Prüft, ob ein String eine gültige E-Mail-Adresse ist
 * @param {string} email - Die zu prüfende E-Mail-Adresse
 * @returns {boolean} True wenn gültig, sonst false
 */
export function isValidEmail(email) {
    const re = /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
    return re.test(String(email).toLowerCase());
}

/**
 * Prüft, ob ein String ein gültiges Datum im Format DD.MM.YYYY ist
 * @param {string} dateString - Das zu prüfende Datum
 * @returns {boolean} True wenn gültig, sonst false
 */
export function isValidDate(dateString) {
    // Prüfen ob das Format stimmt (DD.MM.YYYY)
    if (!/^\d{2}\.\d{2}\.\d{4}$/.test(dateString)) {
        return false;
    }
    
    const parts = dateString.split('.');
    const day = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10) - 1;
    const year = parseInt(parts[2], 10);
    
    // Datum erstellen und prüfen ob die Werte übereinstimmen
    const date = new Date(year, month, day);
    return date.getFullYear() === year && 
           date.getMonth() === month && 
           date.getDate() === day;
}

/**
 * Tiefe Kopie eines Objekts
 * @param {Object} obj - Das zu kopierende Objekt
 * @returns {Object} Eine tiefe Kopie des Objekts
 */
export function deepCopy(obj) {
    if (obj === null || typeof obj !== 'object') {
        return obj;
    }
    
    if (obj instanceof Date) {
        return new Date(obj);
    }
    
    if (obj instanceof Array) {
        return obj.map(item => deepCopy(item));
    }
    
    if (obj instanceof Object) {
        const copy = {};
        for (const key in obj) {
            if (Object.prototype.hasOwnProperty.call(obj, key)) {
                copy[key] = deepCopy(obj[key]);
            }
        }
        return copy;
    }
    
    throw new Error('Typ kann nicht kopiert werden');
}

/**
 * Fügt einen Query-Parameter zu einer URL hinzu oder aktualisiert ihn
 * @param {string} url - Die URL
 * @param {string} param - Der Parameter-Name
 * @param {string} value - Der Parameter-Wert
 * @returns {string} Die aktualisierte URL
 */
export function updateQueryParam(url, param, value) {
    const re = new RegExp("([?&])" + param + "=.*?(&|$)", "i");
    const separator = url.indexOf('?') !== -1 ? "&" : "?";
    
    if (url.match(re)) {
        return url.replace(re, '$1' + param + "=" + value + '$2');
    } else {
        return url + separator + param + "=" + value;
    }
}

/**
 * Wartet für eine bestimmte Zeit
 * @param {number} ms - Zeit in Millisekunden
 * @returns {Promise} Promise, das nach der angegebenen Zeit aufgelöst wird
 */
export function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Initialisierungscode
log('Utils-Modul geladen');
