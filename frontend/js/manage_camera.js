/**
 * manage_camera.js - Kamera-Steuerungsmodul für das Frontend der Fotobox2
 * 
 * Dieses Modul stellt Funktionen zur Steuerung und Interaktion mit der Kamera bereit.
 * Es kommuniziert über die Kamera-API mit dem Backend und bietet Funktionen für:
 * - Abrufen der verfügbaren Kameras
 * - Verbinden und Trennen von Kameras
 * - Bildaufnahme
 * - Konfiguration von Kameraeinstellungen
 * - Kamera-Vorschau im Frontend
 */

import { apiGet, apiPost } from './manage_api.js';
import { log, error, warn, debug } from './manage_logging.js';
import { Result } from './utils.js';

// API-Endpunkte
const API = {
    LIST: '/api/camera/list',
    CONNECT: '/api/camera/connect',
    DISCONNECT: '/api/camera/disconnect',
    CAPTURE: '/api/camera/capture',
    PREVIEW: '/api/camera/preview',
    CONFIG: '/api/camera/config',
    STATUS: '/api/camera/status'
};

/**
 * Kamera-Status Enum
 * @readonly
 * @enum {string}
 */
export const CameraStatus = {
    DISCONNECTED: 'disconnected',
    CONNECTING: 'connecting',
    CONNECTED: 'connected',
    ERROR: 'error'
};

/**
 * Kamera-Objekte und Status
 */
let _cameras = [];          // Liste der verfügbaren Kameras
let _activeCamera = null;   // Aktuell verbundene Kamera
let _previewInterval = null; // Intervall für die Vorschau-Aktualisierung
let _previewRunning = false; // Status der Vorschau
let _previewTarget = null;   // Element-ID für die Vorschau
let _captureCallbacks = []; // Event-Callbacks für Bildaufnahmen
let _cameraConfigs = [];    // Liste der verfügbaren Kamera-Konfigurationen
let _activeConfig = null;   // Aktuell aktive Kamera-Konfiguration

/**
 * Ruft die Liste der verfügbaren Kameras vom Backend ab
 * @returns {Promise<Result>} - Liste der verfügbaren Kameras
 */
export async function listCameras() {
    try {
        const response = await apiGet(API.LIST);
        
        if (response.success) {
            _cameras = response.data;
            log('Kameraliste erfolgreich abgerufen');
            return Result.ok(_cameras);
        } else {
            warn('Keine Kameras gefunden oder Fehler beim Abruf');
            return Result.fail(response.error || 'Keine Kameras gefunden');
        }
    } catch (err) {
        error('Netzwerkfehler beim Abrufen der Kameraliste:', err);
        return Result.fail(err.message);
    }
}

/**
 * Stellt eine Verbindung zu einer Kamera her
 * @param {string} cameraId - ID der zu verbindenden Kamera
 * @returns {Promise<Object>} - Verbundene Kamera oder null bei Fehler
 */
export async function connectCamera(cameraId) {
    try {
        const response = await apiPost(API.CONNECT, { camera_id: cameraId });
        
        if (response.success) {
            _activeCamera = response.data;
            log(`Kamera verbunden: ${_activeCamera.name}`);
            return _activeCamera;
        } else {
            error(`Fehler beim Verbinden der Kamera: ${response.message}`);
            return null;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Verbinden der Kamera: ${error.message}`);
        return null;
    }
}

/**
 * Trennt die Verbindung zur aktuellen Kamera
 * @returns {Promise<boolean>} - true bei Erfolg, false bei Fehler
 */
export async function disconnectCamera() {
    // Falls eine Vorschau läuft, diese zuerst stoppen
    if (_previewRunning) {
        stopLivePreview();
    }
    
    try {
        const response = await apiPost(API.DISCONNECT);
        
        if (response.success) {
            _activeCamera = null;
            log('Kamera getrennt');
            return true;
        } else {
            error(`Fehler beim Trennen der Kamera: ${response.message}`);
            return false;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Trennen der Kamera: ${error.message}`);
        return false;
    }
}

/**
 * Nimmt ein Bild mit der aktuellen Kamera auf
 * @param {Object} options - Optionen für die Aufnahme (optional)
 * @returns {Promise<Object>} - Informationen zum aufgenommenen Bild oder Fehlermeldung
 */
export async function captureImage(options = {}) {
    try {
        const response = await apiPost(API.CAPTURE, options);
        
        if (response.success) {
            log(`Bild aufgenommen: ${response.data.filename}`);
            
            // Event-Callbacks aufrufen
            _captureCallbacks.forEach(callback => {
                try {
                    callback(response.data);
                } catch (err) {
                    error(`Fehler in Capture-Callback: ${err.message}`);
                }
            });
            
            return response.data;
        } else {
            error(`Fehler bei Bildaufnahme: ${response.message}`);
            return { success: false, error: response.message };
        }
    } catch (error) {
        error(`Netzwerkfehler bei Bildaufnahme: ${error.message}`);
        return { success: false, error: error.message };
    }
}

/**
 * Ruft die aktuellen Kameraeinstellungen ab
 * @returns {Promise<Object>} - Kameraeinstellungen
 */
export async function getCameraSettings() {
    try {
        const response = await apiGet('/api/camera/settings');
        
        if (response.success) {
            log('Kameraeinstellungen erfolgreich abgerufen');
            return response.data;
        } else {
            error(`Fehler beim Abrufen der Kameraeinstellungen: ${response.message}`);
            return {};
        }
    } catch (error) {
        error(`Netzwerkfehler beim Abrufen der Kameraeinstellungen: ${error.message}`);
        return {};
    }
}

/**
 * Aktualisiert die Kameraeinstellungen
 * @param {Object} settings - Zu aktualisierende Einstellungen
 * @returns {Promise<boolean>} - true bei Erfolg, false bei Fehler
 */
export async function updateCameraSettings(settings) {
    try {
        const response = await apiPost('/api/camera/settings', settings);
        
        if (response.success) {
            log('Kameraeinstellungen erfolgreich aktualisiert');
            return true;
        } else {
            error(`Fehler beim Aktualisieren der Kameraeinstellungen: ${response.message}`);
            return false;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Aktualisieren der Kameraeinstellungen: ${error.message}`);
        return false;
    }
}

/**
 * Startet eine Live-Vorschau der Kamera in einem HTML-Element
 * @param {string} containerId - ID des HTML-Elements für die Vorschau
 * @param {Object} options - Optionen für die Vorschau (optional)
 * @returns {boolean} - true bei Erfolg, false bei Fehler
 */
export function startLivePreview(containerId, options = {}) {
    const container = document.getElementById(containerId);
    if (!container) {
        error(`Vorschau-Container mit ID "${containerId}" nicht gefunden`);
        return false;
    }
    
    // Speichere die Target-ID für späteren Neustart
    _previewTarget = containerId;
    
    // Falls bereits eine Vorschau läuft, diese zuerst stoppen
    if (_previewRunning) {
        stopLivePreview();
    }
    
    try {
        // Vorschau-Bild-Element erstellen
        const imgElement = document.createElement('img');
        imgElement.id = 'cameraPreviewImage';
        imgElement.alt = 'Kamera-Vorschau';
        imgElement.style.width = '100%';
        imgElement.style.height = 'auto';
        
        // Vorhandene Inhalte im Container löschen
        container.innerHTML = '';
        container.appendChild(imgElement);
        
        // MJPEG-Stream als Quelle setzen für flüssigere Vorschau
        imgElement.src = '/api/camera/preview/stream';
        
        _previewRunning = true;
        log('Kameravorschau gestartet');
        return true;
    } catch (error) {
        error(`Fehler beim Starten der Kameravorschau: ${error.message}`);
        return false;
    }
}

/**
 * Stoppt die Live-Vorschau
 * @returns {boolean} - true bei Erfolg, false bei Fehler
 */
export function stopLivePreview() {
    try {
        // Interval stoppen, falls vorhanden
        if (_previewInterval) {
            clearInterval(_previewInterval);
            _previewInterval = null;
        }
        
        // Vorschau-Bild-Element finden und löschen
        const imgElement = document.getElementById('cameraPreviewImage');
        if (imgElement) {
            imgElement.src = ''; // Stream stoppen
            
            try {
                // Versuche, das Element zu entfernen
                imgElement.parentNode.removeChild(imgElement);
            } catch (e) {
                // Ignoriere Fehler, falls das Element bereits entfernt wurde
            }        }
        
        _previewRunning = false;
        // Setze _previewTarget nicht zurück, damit wir die Vorschau später wiederherstellen können
        log('Kameravorschau gestoppt');
        return true;
    } catch (error) {
        error(`Fehler beim Stoppen der Kameravorschau: ${error.message}`);
        return false;
    }
}

/**
 * Ruft den Status der Kamera ab
 * @returns {Promise<Object>} - Kamerastatus
 */
export async function getCameraStatus() {
    try {
        const response = await apiGet(API.STATUS);
        
        if (response.success) {
            return response.data;
        } else {
            error(`Fehler beim Abrufen des Kamerastatus: ${response.message}`);
            return { active_camera: null, status: 'error' };
        }
    } catch (error) {
        error(`Netzwerkfehler beim Abrufen des Kamerastatus: ${error.message}`);
        return { active_camera: null, status: 'network_error' };
    }
}

/**
 * Fügt einen Event-Listener für Bildaufnahmen hinzu
 * @param {function} callback - Callback-Funktion, die aufgerufen wird, wenn ein Bild aufgenommen wurde
 */
export function addCaptureEventListener(callback) {
    if (typeof callback === 'function' && !_captureCallbacks.includes(callback)) {
        _captureCallbacks.push(callback);
    }
}

/**
 * Entfernt einen Event-Listener für Bildaufnahmen
 * @param {function} callback - Zu entfernende Callback-Funktion
 */
export function removeCaptureEventListener(callback) {
    const index = _captureCallbacks.indexOf(callback);
    if (index !== -1) {
        _captureCallbacks.splice(index, 1);
    }
}

/**
 * Ruft die Liste der verfügbaren Kamera-Konfigurationen ab
 * @returns {Promise<Array>} - Liste der verfügbaren Konfigurationen
 */
export async function listCameraConfigs() {
    try {
        const response = await apiGet('/api/camera/configs');
        
        if (response.success) {
            _cameraConfigs = response.data;
            log('Kamera-Konfigurationen erfolgreich abgerufen');
            return _cameraConfigs;
        } else {
            error(`Fehler beim Abrufen der Kamera-Konfigurationen: ${response.message}`);
            return [];
        }
    } catch (error) {
        error(`Netzwerkfehler beim Abrufen der Kamera-Konfigurationen: ${error.message}`);
        return [];
    }
}

/**
 * Ruft eine bestimmte Kamera-Konfiguration ab
 * @param {string} configId - ID der Konfiguration
 * @returns {Promise<Object>} - Konfigurationsdaten oder null bei Fehler
 */
export async function getCameraConfig(configId) {
    try {
        const response = await apiGet(`/api/camera/config/${configId}`);
        
        if (response.success) {
            log(`Kamera-Konfiguration ${configId} abgerufen`);
            return response.data;
        } else {
            error(`Fehler beim Abrufen der Kamera-Konfiguration: ${response.message}`);
            return null;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Abrufen der Kamera-Konfiguration: ${error.message}`);
        return null;
    }
}

/**
 * Ruft die aktive Kamera-Konfiguration ab
 * @returns {Promise<Object>} - Aktive Konfiguration oder null
 */
export async function getActiveConfig() {
    try {
        const response = await apiGet('/api/camera/config');
        
        if (response.success && response.data) {
            _activeConfig = response.data;
            log('Aktive Kamera-Konfiguration abgerufen');
            return _activeConfig;
        } else {
            error(`Fehler beim Abrufen der aktiven Konfiguration: ${response.message}`);
            return null;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Abrufen der aktiven Konfiguration: ${error.message}`);
        return null;
    }
}

/**
 * Setzt die aktiv verwendete Kamera-Konfiguration
 * @param {string} configId - ID der zu verwendenden Konfiguration
 * @returns {Promise<boolean>} - true bei Erfolg, false bei Fehler
 */
export async function setActiveConfig(configId) {
    try {
        const response = await apiPost('/api/camera/config', { config_id: configId });
        
        if (response.success) {
            log(`Kamera-Konfiguration gesetzt: ${configId}`);
            
            // Konfiguration aktualisieren
            const activeConfig = await getActiveConfig();
            
            // Kamera neu initialisieren, wenn bereits eine Verbindung besteht
            if (_activeCamera) {
                // Falls eine Vorschau läuft, diese kurz unterbrechen
                const wasPreviewRunning = _previewRunning;
                if (wasPreviewRunning) {
                    stopLivePreview();
                }
                
                // Neu verbinden mit aktueller Kamera
                await connectCamera(_activeCamera.id);
                
                // Vorschau wieder starten, falls sie aktiv war
                if (wasPreviewRunning && _previewTarget) {
                    startLivePreview(_previewTarget);
                }
            }
            
            return true;
        } else {
            error(`Fehler beim Setzen der Kamera-Konfiguration: ${response.message}`);
            return false;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Setzen der Kamera-Konfiguration: ${error.message}`);
        return false;
    }
}

/**
 * Erstellt eine neue Kamera-Konfiguration
 * @param {Object} config - Konfigurationsdaten
 * @returns {Promise<string>} - ID der erstellten Konfiguration oder null
 */
export async function createCameraConfig(config) {
    try {
        const response = await apiPost('/api/camera/config/create', config);
        
        if (response.success) {
            log(`Neue Kamera-Konfiguration erstellt: ${config.name}`);
            return response.data.id;
        } else {
            error(`Fehler beim Erstellen der Kamera-Konfiguration: ${response.message}`);
            return null;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Erstellen der Konfiguration: ${error.message}`);
        return null;
    }
}

/**
 * Aktualisiert eine Kamera-Konfiguration
 * @param {string} configId - ID der Konfiguration
 * @param {Object} config - Neue Konfigurationsdaten
 * @returns {Promise<boolean>} - true bei Erfolg, false bei Fehler
 */
export async function updateCameraConfig(configId, config) {
    try {
        const response = await apiPost(`/api/camera/config/${configId}`, config);
        
        if (response.success) {
            log(`Kamera-Konfiguration ${configId} aktualisiert`);
            return true;
        } else {
            error(`Fehler beim Aktualisieren der Kamera-Konfiguration: ${response.message}`);
            return false;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Aktualisieren der Konfiguration: ${error.message}`);
        return false;
    }
}

/**
 * Löscht eine Kamera-Konfiguration
 * @param {string} configId - ID der Konfiguration
 * @returns {Promise<boolean>} - true bei Erfolg, false bei Fehler
 */
export async function deleteCameraConfig(configId) {
    try {
        const response = await apiPost(`/api/camera/config/${configId}`, { _method: 'delete' });
        
        if (response.success) {
            log(`Kamera-Konfiguration ${configId} gelöscht`);
            return true;
        } else {
            error(`Fehler beim Löschen der Kamera-Konfiguration: ${response.message}`);
            return false;
        }
    } catch (error) {
        error(`Netzwerkfehler beim Löschen der Konfiguration: ${error.message}`);
        return false;
    }
}

/**
 * Initialisiert die Kamera-Funktionalität
 * Wird automatisch beim Import dieses Moduls aufgerufen
 */
export async function initialize() {
    log('Kamera-Modul wird initialisiert');
    
    try {
        // Liste der verfügbaren Kameras abrufen
        await listCameras();
        return true;
    } catch (error) {
        error(`Fehler bei Kamera-Modul-Initialisierung: ${error.message}`);
        return false;
    }
}

// Automatische Initialisierung
initialize();
