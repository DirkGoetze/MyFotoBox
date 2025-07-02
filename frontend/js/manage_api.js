/**
 * @file manage_api.js
 * @description Verwaltungsmodul für API-Kommunikation in Fotobox2
 * @module manage_api
 */

import { error, warn, info } from './manage_logging.js';

// Konfiguration
let _baseUrl = '';
let _defaultHeaders = { 'Content-Type': 'application/json' };
let _authToken = null;

/**
 * Setzt die Basis-URL für API-Anfragen
 * @param {string} url - Die zu verwendende Basis-URL
 */
export function setApiBaseUrl(url) {
    _baseUrl = url;
}

/**
 * Setzt den Auth-Token für API-Anfragen
 * @param {string} token - Der JWT Token
 */
export function setAuthToken(token) {
    _authToken = token;
    if (token) {
        _defaultHeaders['X-Auth-Token'] = token;
    } else {
        delete _defaultHeaders['X-Auth-Token'];
    }
}

/**
 * Prüft ob die API-Antwort einen neuen Token enthält und aktualisiert diesen
 * @param {Response} response - Die API-Antwort
 */
function checkForNewToken(response) {
    const newToken = response.headers.get('X-New-Auth-Token');
    if (newToken) {
        setAuthToken(newToken);
        info('Auth-Token aktualisiert');
    }
}

/**
 * Baut die vollständige URL mit Query-Parametern
 * @param {string} endpoint - Der API-Endpunkt
 * @param {Object} [queryParams] - Optionale Query-Parameter
 * @returns {string} Die vollständige URL
 */
function buildUrl(endpoint, queryParams = {}) {
    const url = new URL(_baseUrl + endpoint);
    Object.entries(queryParams).forEach(([key, value]) => {
        url.searchParams.append(key, value);
    });
    return url.toString();
}

/**
 * Behandelt API-Fehler einheitlich
 * @param {Error} err - Der aufgetretene Fehler
 * @param {string} method - Die HTTP-Methode
 * @param {string} endpoint - Der API-Endpunkt
 * @returns {Promise<Object>} Fehler-Response
 */
function handleApiError(err, method, endpoint) {
    error(`API ${method} ${endpoint} fehlgeschlagen:`, err);
    return Promise.reject({
        success: false,
        error: err.message || 'Unbekannter Fehler',
        endpoint,
        method
    });
}

/**
 * Verarbeitet die API-Antwort einheitlich
 * @param {Response} response - Die API-Antwort
 * @returns {Promise<Object>} Verarbeitete Response
 */
async function handleResponse(response) {
    checkForNewToken(response);
    
    const contentType = response.headers.get('content-type');
    const isJson = contentType && contentType.includes('application/json');
    
    if (!response.ok) {
        const error = isJson ? await response.json() : { message: response.statusText };
        if (response.status === 401 && _authToken) {
            // Token ist abgelaufen oder ungültig
            setAuthToken(null);
            warn('Auth-Token ungültig - Benutzer muss sich neu anmelden');
        }
        return Promise.reject(error);
    }
    
    return isJson ? response.json() : response.text();
}

/**
 * Führt einen GET-Request aus
 * @param {string} endpoint - Der API-Endpunkt
 * @param {Object} [queryParams] - Optionale Query-Parameter
 * @returns {Promise<any>} Die Antwort des Servers als JSON
 */
export async function apiGet(endpoint, queryParams = {}) {
    try {
        const url = buildUrl(endpoint, queryParams);
        const response = await fetch(url, {
            method: 'GET',
            headers: _defaultHeaders
        });
        
        return handleResponse(response);
    } catch (err) {
        return handleApiError(err, 'GET', endpoint);
    }
}

/**
 * Führt einen POST-Request aus
 * @param {string} endpoint - Der API-Endpunkt
 * @param {Object} data - Die zu sendenden Daten
 * @returns {Promise<any>} Die Antwort des Servers als JSON
 */
export async function apiPost(endpoint, data = {}) {
    try {
        const url = buildUrl(endpoint);
        const response = await fetch(url, {
            method: 'POST',
            headers: _defaultHeaders,
            body: JSON.stringify(data)
        });
        
        return handleResponse(response);
    } catch (err) {
        return handleApiError(err, 'POST', endpoint);
    }
}

/**
 * Führt einen PUT-Request aus
 * @param {string} endpoint - Der API-Endpunkt
 * @param {Object} data - Die zu sendenden Daten
 * @returns {Promise<any>} Die Antwort des Servers als JSON
 */
export async function apiPut(endpoint, data = {}) {
    try {
        const url = buildUrl(endpoint);
        const response = await fetch(url, {
            method: 'PUT',
            headers: _defaultHeaders,
            body: JSON.stringify(data)
        });
        
        return handleResponse(response);
    } catch (err) {
        return handleApiError(err, 'PUT', endpoint);
    }
}

/**
 * Führt einen DELETE-Request aus
 * @param {string} endpoint - Der API-Endpunkt
 * @param {Object} data - Die zu sendenden Daten
 * @returns {Promise<any>} Die Antwort des Servers als JSON
 */
export async function apiDelete(endpoint, data = {}) {
    try {
        const url = buildUrl(endpoint);
        const response = await fetch(url, {
            method: 'DELETE',
            headers: _defaultHeaders,
            body: JSON.stringify(data)
        });
        
        return handleResponse(response);
    } catch (err) {
        return handleApiError(err, 'DELETE', endpoint);
    }
}

// Initialisierung
// In einer realen Implementierung würde die Basis-URL aus einer Konfiguration geladen
// Für dieses Beispiel verwenden wir eine leere Basis-URL (relative Pfade)
setApiBaseUrl('');
