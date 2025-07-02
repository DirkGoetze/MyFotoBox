/**
 * @file manage_auth.js
 * @description Verwaltungsmodul für Authentifizierung in Fotobox2
 * @module manage_auth
 */

import { apiGet, apiPost, setAuthToken } from './manage_api.js';
import { log, error, warn } from './manage_logging.js';

// Konstanten
const AUTH_TOKEN_KEY = 'fotobox_auth_token';
const TOKEN_REFRESH_INTERVAL = 15 * 60 * 1000; // 15 Minuten

// Timer für Token-Refresh
let _refreshTimer = null;

/**
 * Initialisiert die Authentifizierung
 * Lädt gespeicherten Token und startet Token-Refresh
 */
export function initAuth() {
    const savedToken = localStorage.getItem(AUTH_TOKEN_KEY);
    if (savedToken) {
        setAuthToken(savedToken);
        verifyAndRefreshToken();
    }
}

/**
 * Führt Login durch und speichert Token
 * @param {string} password - Das eingegebene Passwort
 * @returns {Promise<boolean>} True wenn Login erfolgreich
 */
export async function login(password) {
    try {
        const res = await apiPost('/api/auth/login', { password });
        if (res.success && res.data.token) {
            localStorage.setItem(AUTH_TOKEN_KEY, res.data.token);
            setAuthToken(res.data.token);
            startTokenRefresh();
            log('Login erfolgreich');
            return true;
        }
        warn('Login fehlgeschlagen:', res.error);
        return false;
    } catch (err) {
        error('Login-Fehler:', err);
        return false;
    }
}

/**
 * Führt Logout durch und entfernt Token
 */
export async function logout() {
    try {
        await apiPost('/api/auth/logout');
    } catch (err) {
        warn('Logout-API-Fehler:', err);
    } finally {
        clearAuth();
    }
}

/**
 * Entfernt alle Auth-Daten
 */
function clearAuth() {
    localStorage.removeItem(AUTH_TOKEN_KEY);
    setAuthToken(null);
    stopTokenRefresh();
    log('Auth-Daten entfernt');
}

/**
 * Startet periodischen Token-Refresh
 */
function startTokenRefresh() {
    stopTokenRefresh();
    _refreshTimer = setInterval(verifyAndRefreshToken, TOKEN_REFRESH_INTERVAL);
}

/**
 * Stoppt Token-Refresh
 */
function stopTokenRefresh() {
    if (_refreshTimer) {
        clearInterval(_refreshTimer);
        _refreshTimer = null;
    }
}

/**
 * Prüft und aktualisiert Token wenn nötig
 */
async function verifyAndRefreshToken() {
    try {
        const res = await apiGet('/api/auth/verify');
        if (!res.success || !res.data.valid) {
            warn('Token ungültig - Logout erforderlich');
            clearAuth();
        }
    } catch (err) {
        error('Token-Verifikation fehlgeschlagen:', err);
        clearAuth();
    }
}

/**
 * Prüft ob Benutzer authentifiziert ist
 * @returns {boolean} True wenn authentifiziert
 */
export function isAuthenticated() {
    return !!localStorage.getItem(AUTH_TOKEN_KEY);
}

/**
 * Ändert das Passwort
 * @param {string} currentPassword - Aktuelles Passwort
 * @param {string} newPassword - Neues Passwort
 * @returns {Promise<boolean>} True wenn erfolgreich
 */
export async function changePassword(currentPassword, newPassword) {
    try {
        const res = await apiPost('/api/auth/password', {
            current_password: currentPassword,
            new_password: newPassword
        });
        
        if (res.success && res.data.token) {
            localStorage.setItem(AUTH_TOKEN_KEY, res.data.token);
            setAuthToken(res.data.token);
            log('Passwort erfolgreich geändert');
            return true;
        }
        
        warn('Passwort-Änderung fehlgeschlagen:', res.error);
        return false;
    } catch (err) {
        error('Fehler bei Passwort-Änderung:', err);
        return false;
    }
}

// Automatische Initialisierung
initAuth();
