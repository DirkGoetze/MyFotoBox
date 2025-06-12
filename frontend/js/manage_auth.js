/**
 * @file manage_auth.js
 * @description Verwaltungsmodul für Authentifizierung in Fotobox2
 * @module manage_auth
 */

// Abhängigkeiten
import { apiGet, apiPost } from './manage_api.js';
import { log, error } from './manage_logging.js';

/**
 * @typedef {Object} LoginStatus
 * @property {boolean} authenticated - Gibt an, ob der Benutzer authentifiziert ist
 */

/**
 * @typedef {Object} PasswordStatus
 * @property {boolean} passwordSet - Gibt an, ob ein Passwort gesetzt ist
 */

/**
 * Prüft, ob ein Passwort gesetzt ist
 * @returns {Promise<boolean>} True wenn ein Passwort gesetzt ist, sonst False
 */
export async function isPasswordSet() {
    try {
        const res = await apiGet('/api/check_password_set');
        return res.password_set;
    } catch (err) {
        error('Fehler bei der Passwort-Statusprüfung:', err);
        return false;
    }
}

/**
 * Validiert eingegebenes Passwort
 * @param {string} password - Das zu validierende Passwort
 * @returns {Promise<boolean>} True wenn das Passwort korrekt ist, sonst False
 */
export async function validatePassword(password) {
    try {
        const res = await apiPost('/api/login', { password });
        return res.success;
    } catch (err) {
        error('Fehler bei der Passwortvalidierung:', err);
        return false;
    }
}

/**
 * Setzt neues Passwort (bei Erstinstallation)
 * @param {string} password - Das zu setzende Passwort
 * @returns {Promise<boolean>} True wenn das Passwort erfolgreich gesetzt wurde, sonst False
 */
export async function setPassword(password) {
    if (password.length < 4) {
        return false;
    }
    
    try {
        const res = await apiPost('/api/settings', { admin_password: password });
        return res.status === 'ok';
    } catch (err) {
        error('Fehler beim Setzen des Passworts:', err);
        return false;
    }
}

/**
 * Ändert bestehendes Passwort
 * @param {string} newPassword - Das neue Passwort
 * @returns {Promise<boolean>} True wenn das Passwort erfolgreich geändert wurde, sonst False
 */
export async function changePassword(newPassword) {
    if (newPassword.length < 4) {
        return false;
    }
    
    try {
        const res = await apiPost('/api/settings', { new_password: newPassword });
        return res.status === 'ok';
    } catch (err) {
        error('Fehler beim Ändern des Passworts:', err);
        return false;
    }
}

/**
 * Gibt aktuellen Login-Status zurück
 * @returns {Promise<LoginStatus>} Loginstatusinformation
 */
export async function getLoginStatus() {
    try {
        return await apiGet('/api/session-check');
    } catch (err) {
        error('Fehler beim Abrufen des Login-Status:', err);
        return { authenticated: false };
    }
}

/**
 * Führt Login durch
 * @param {string} password - Das eingegebene Passwort
 * @returns {Promise<boolean>} True wenn die Anmeldung erfolgreich war, sonst False
 */
export async function login(password) {
    try {
        const res = await apiPost('/api/login', { password });
        if (res.success) {
            log('Login erfolgreich');
            return true;
        }
        return false;
    } catch (err) {
        error('Fehler beim Login:', err);
        return false;
    }
}

/**
 * Meldet Benutzer ab
 * @returns {Promise<boolean>} True wenn die Abmeldung erfolgreich war
 */
export async function logout() {
    try {
        await apiGet('/logout');
        return true;
    } catch (err) {
        error('Fehler beim Logout:', err);
        return false;
    }
}

// Initialisierungscode (falls benötigt)
log('Authentifizierungsmodul geladen');
