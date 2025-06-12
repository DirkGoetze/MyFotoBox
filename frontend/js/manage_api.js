/**
 * @file manage_api.js
 * @description Verwaltungsmodul für API-Kommunikation in Fotobox2
 * @module manage_api
 */

import { error } from './manage_logging.js';

// Konfiguration
let _baseUrl = '';
let _defaultHeaders = { 'Content-Type': 'application/json' };

/**
 * Setzt die Basis-URL für API-Anfragen
 * @param {string} url - Die zu verwendende Basis-URL
 */
export function setApiBaseUrl(url) {
    _baseUrl = url;
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

/**
 * Behandelt Fehler bei API-Aufrufen
 * @param {Error} err - Der aufgetretene Fehler
 * @param {string} method - Die verwendete HTTP-Methode
 * @param {string} endpoint - Der verwendete API-Endpunkt
 * @returns {Promise<never>} - Gibt einen Fehler zurück
 * @private
 */
export async function handleApiError(err, method, endpoint) {
    error(`API-Fehler bei ${method} ${endpoint}`, err);
    throw err;
}

/**
 * Überprüft die Antwort auf Fehler und gibt die JSON-Daten zurück
 * @param {Response} response - Die Antwort des Servers
 * @returns {Promise<any>} Die Antwort als JSON
 * @private
 */
async function handleResponse(response) {
    if (!response.ok) {
        let errorMessage;
        
        try {
            const errorData = await response.json();
            errorMessage = errorData.message || `HTTP-Fehler: ${response.status}`;
        } catch (e) {
            errorMessage = `HTTP-Fehler: ${response.status}`;
        }
        
        const error = new Error(errorMessage);
        error.status = response.status;
        throw error;
    }
    
    return await response.json();
}

/**
 * Baut die vollständige URL für API-Anfragen
 * @param {string} endpoint - Der API-Endpunkt
 * @param {Object} [queryParams] - Optionale Query-Parameter
 * @returns {string} Die vollständige URL
 * @private
 */
function buildUrl(endpoint, queryParams = {}) {
    // Wenn der Endpoint bereits mit einem / beginnt, dieses entfernen
    const cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    
    // Basis-URL verwenden oder beim Endpunkt bleiben (falls keine Basis-URL konfiguriert)
    let url = _baseUrl ? `${_baseUrl}/${cleanEndpoint}` : `/${cleanEndpoint}`;
    
    // Query-Parameter hinzufügen
    if (Object.keys(queryParams).length > 0) {
        const queryString = new URLSearchParams(queryParams).toString();
        url = `${url}?${queryString}`;
    }
    
    return url;
}

// Initialisierung
// In einer realen Implementierung würde die Basis-URL aus einer Konfiguration geladen
// Für dieses Beispiel verwenden wir eine leere Basis-URL (relative Pfade)
setApiBaseUrl('');
