/**
 * @file manage_logging.js
 * @description Verwaltungsmodul für Logging in Fotobox2
 * @module manage_logging
 */

import { apiPost } from './manage_api.js';

// Konfiguration
const LOG_LEVEL = {
    DEBUG: 0,
    INFO: 1,
    WARN: 2,
    ERROR: 3
};

let currentLogLevel = LOG_LEVEL.INFO; // Standard-Loglevel
let enableServerLogging = true; // Ob Logs auch an den Server gesendet werden sollen
let enableConsoleLogging = true; // Ob Logs auch in der Konsole angezeigt werden sollen
let logQueue = []; // Queue für Logs, wenn Server nicht erreichbar
const MAX_QUEUE_SIZE = 100;

/**
 * Sendet ein Log an den Backend-Server
 * @param {string} level - Log-Level (INFO, WARN, ERROR, DEBUG)
 * @param {string} message - Die zu loggende Nachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 * @returns {Promise<boolean>} - Ob der Log erfolgreich gesendet wurde
 */
async function sendLogToServer(level, message, context = null) {
    if (!enableServerLogging) return false;
    
    try {
        const logData = {
            level,
            message,
            context,
            timestamp: new Date().toISOString(),
            source: 'frontend'
        };
        
        await apiPost('/api/log', logData);
        return true;
    } catch (err) {
        // Wenn der Server nicht erreichbar ist, fügen wir den Log zur Queue hinzu
        if (logQueue.length < MAX_QUEUE_SIZE) {
            logQueue.push({
                level,
                message,
                context,
                timestamp: new Date().toISOString()
            });
        }
        return false;
    }
}

/**
 * Versucht, aufgestaute Logs aus der Queue zu senden
 */
export async function processLogQueue() {
    if (logQueue.length === 0) return;
    
    try {
        // Wir senden maximal 10 Logs auf einmal
        const logsToSend = logQueue.splice(0, 10);
        await apiPost('/api/logs/batch', { logs: logsToSend });
        
        // Wenn erfolgreich, versuchen wir weitere Logs zu senden
        if (logQueue.length > 0) {
            setTimeout(processLogQueue, 1000);
        }
    } catch (err) {
        // Bei Fehler warten wir länger, bevor wir es erneut versuchen
        setTimeout(processLogQueue, 5000);
    }
}

/**
 * Konfiguriert das Logging-Modul
 * @param {Object} options - Konfigurationsoptionen
 * @param {string} [options.logLevel] - Das Log-Level (DEBUG, INFO, WARN, ERROR)
 * @param {boolean} [options.enableServerLogging] - Ob Logs an den Server gesendet werden sollen
 * @param {boolean} [options.enableConsoleLogging] - Ob Logs in der Konsole angezeigt werden sollen
 */
export function configureLogging(options = {}) {
    if (options.logLevel && LOG_LEVEL[options.logLevel.toUpperCase()] !== undefined) {
        currentLogLevel = LOG_LEVEL[options.logLevel.toUpperCase()];
    }
    
    if (options.enableServerLogging !== undefined) {
        enableServerLogging = Boolean(options.enableServerLogging);
    }
    
    if (options.enableConsoleLogging !== undefined) {
        enableConsoleLogging = Boolean(options.enableConsoleLogging);
    }
}

/**
 * Loggt eine Informationsnachricht
 * @param {string} message - Die zu loggende Nachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 */
export function log(message, context = null) {
    if (currentLogLevel <= LOG_LEVEL.INFO) {
        if (enableConsoleLogging) {
            console.log(`[INFO] ${message}`, context ? context : '');
        }
        sendLogToServer('INFO', message, context);
    }
}

/**
 * Loggt eine Fehlernachricht
 * @param {string} message - Die zu loggende Fehlernachricht
 * @param {Error|Object} [err] - Der Fehler oder zusätzlicher Kontext
 */
export function error(message, err = null) {
    if (currentLogLevel <= LOG_LEVEL.ERROR) {
        if (enableConsoleLogging) {
            console.error(`[ERROR] ${message}`, err ? err : '');
        }
        
        let context = null;
        if (err instanceof Error) {
            context = {
                name: err.name,
                message: err.message,
                stack: err.stack
            };
        } else if (err) {
            context = err;
        }
        
        sendLogToServer('ERROR', message, context);
    }
}

/**
 * Loggt eine Warnungsnachricht
 * @param {string} message - Die zu loggende Warnungsnachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 */
export function warn(message, context = null) {
    if (currentLogLevel <= LOG_LEVEL.WARN) {
        if (enableConsoleLogging) {
            console.warn(`[WARN] ${message}`, context ? context : '');
        }
        sendLogToServer('WARNING', message, context);
    }
}

/**
 * Loggt eine Debug-Nachricht (nur im Entwicklungsmodus)
 * @param {string} message - Die zu loggende Debug-Nachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 */
export function debug(message, context = null) {
    if (currentLogLevel <= LOG_LEVEL.DEBUG) {
        if (enableConsoleLogging) {
            console.debug(`[DEBUG] ${message}`, context ? context : '');
        }
        sendLogToServer('DEBUG', message, context);
    }
}

/**
 * Ruft Logs vom Server ab
 * @param {Object} options - Optionen für die Abfrage
 * @param {string} [options.level] - Filter nach Log-Level
 * @param {number} [options.limit=100] - Maximale Anzahl abzurufender Logs
 * @param {number} [options.offset=0] - Offset für Paginierung
 * @param {string} [options.startDate] - Filter - Logs nach diesem Datum (ISO-Format)
 * @param {string} [options.endDate] - Filter - Logs vor diesem Datum (ISO-Format)
 * @param {string} [options.source] - Filter nach Log-Quelle
 * @returns {Promise<Array>} - Liste von Logeinträgen
 */
export async function getLogs(options = {}) {
    try {
        const response = await apiPost('/api/logs', options);
        return response.logs || [];
    } catch (err) {
        error('Fehler beim Abrufen der Logs', err);
        return [];
    }
}

/**
 * Löscht Logs
 * @param {Object} options - Optionen für das Löschen (z.B. Zeitraum)
 * @returns {Promise<boolean>} true wenn erfolgreich
 */
export async function clearLogs(options = {}) {
    try {
        const response = await apiPost('/api/logs/clear', options);
        return response.success || false;
    } catch (err) {
        error('Fehler beim Löschen der Logs', err);
        return false;
    }
}

// Initialisierung und regelmäßige Verarbeitung der Log-Queue
setTimeout(processLogQueue, 5000);

// Initialisierung des Logging-Moduls
log('Logging-Modul initialisiert');
