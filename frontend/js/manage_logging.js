/**
 * @file manage_logging.js
 * @description Verwaltungsmodul für Logging in Fotobox2
 * @module manage_logging
 */

import { apiPost, apiGet } from './manage_api.js';
import { Result } from './utils.js';

// API-Endpunkte
const API = {
    LOG: '/api/logging/log',
    CONFIG: '/api/logging/config',
    STATUS: '/api/logging/status',
    HISTORY: '/api/logging/history'
};

/**
 * @typedef {'debug'|'info'|'warn'|'error'} LogLevel
 */

/**
 * @typedef {Object} LogEntry
 * @property {LogLevel} level - Log-Level
 * @property {string} message - Nachricht
 * @property {Object} [context] - Zusätzlicher Kontext
 * @property {string} timestamp - Zeitstempel
 * @property {'frontend'|'backend'} source - Quelle des Logs
 * @property {string} [component] - Betroffene Komponente
 */

/**
 * @typedef {Object} LogConfig
 * @property {LogLevel} minLevel - Minimales Log-Level
 * @property {boolean} enableConsole - Konsolen-Logging aktiv
 * @property {boolean} enableServer - Server-Logging aktiv
 * @property {number} maxQueueSize - Maximale Queue-Größe
 * @property {boolean} logStackTraces - Stack-Traces loggen
 */

// Konfiguration
const LOG_LEVELS = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3
};

// Standard-Konfiguration
let config = {
    minLevel: 'info',
    enableConsole: true,
    enableServer: true,
    maxQueueSize: 100,
    logStackTraces: true
};

// Queue für offline/fehlerhafte Logs
let logQueue = [];

/**
 * Aktualisiert die Logging-Konfiguration
 * @param {Partial<LogConfig>} newConfig - Neue Konfigurationsoptionen
 */
export async function configure(newConfig) {
    try {
        const response = await apiPost(API.CONFIG, newConfig);
        if (response.success) {
            config = { ...config, ...newConfig };
            debug('Logging-Konfiguration aktualisiert');
            return Result.ok(config);
        }
        return Result.fail(response.error);
    } catch (err) {
        console.error('Fehler bei Logging-Konfiguration:', err);
        return Result.fail(err.message);
    }
}

/**
 * Sendet einen Log an den Server
 * @param {LogEntry} entry - Der zu sendende Log-Eintrag
 * @returns {Promise<Result>} Erfolg oder Fehler
 */
async function sendLogToServer(entry) {
    if (!config.enableServer) return Result.ok(null);
    
    try {
        const response = await apiPost(API.LOG, entry);
        if (response.success) {
            return Result.ok(null);
        }
        // Bei Fehler in Queue speichern
        if (logQueue.length < config.maxQueueSize) {
            logQueue.push(entry);
        }
        return Result.fail(response.error);
    } catch (err) {
        if (logQueue.length < config.maxQueueSize) {
            logQueue.push(entry);
        }
        return Result.fail('Server nicht erreichbar');
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
 * Loggt eine Nachricht
 * @param {LogLevel} level - Das Log-Level
 * @param {string} message - Die zu loggende Nachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 */
export function log(level, message, context = null) {
    if (LOG_LEVELS[level] === undefined) {
        console.warn(`Unbekanntes Log-Level: ${level}`);
        return;
    }
    
    if (LOG_LEVELS[level] >= LOG_LEVELS[config.minLevel]) {
        if (config.enableConsole) {
            console.log(`[${level.toUpperCase()}] ${message}`, context ? context : '');
        }
        sendLogToServer({ level, message, context, timestamp: new Date().toISOString(), source: 'frontend' });
    }
}

/**
 * Loggt eine Informationsnachricht
 * @param {string} message - Die zu loggende Nachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 */
export function info(message, context = null) {
    log('info', message, context);
}

/**
 * Loggt eine Fehlernachricht
 * @param {string} message - Die zu loggende Fehlernachricht
 * @param {Error|Object} [err] - Der Fehler oder zusätzlicher Kontext
 */
export function error(message, err = null) {
    if (LOG_LEVELS.error >= LOG_LEVELS[config.minLevel]) {
        if (config.enableConsole) {
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
        
        sendLogToServer({ level: 'error', message, context, timestamp: new Date().toISOString(), source: 'frontend' });
    }
}

/**
 * Loggt eine Warnungsnachricht
 * @param {string} message - Die zu loggende Warnungsnachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 */
export function warn(message, context = null) {
    log('warn', message, context);
}

/**
 * Loggt eine Debug-Nachricht (nur im Entwicklungsmodus)
 * @param {string} message - Die zu loggende Debug-Nachricht
 * @param {Object} [context] - Optionaler Kontext für die Nachricht
 */
export function debug(message, context = null) {
    log('debug', message, context);
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
log('info', 'Logging-Modul initialisiert');
