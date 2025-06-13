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

// Import der benötigten Hilfsfunktionen
import * as utils from './utils.js';
import * as logging from './manage_logging.js';

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
 * @returns {Promise<Array>} - Liste der verfügbaren Kameras
 */
export async function listCameras() {
    try {
        const response = await fetch('/api/camera/list');
        const data = await response.json();
        
        if (data.success) {
            _cameras = data.data;
            logging.log('Kameraliste erfolgreich abgerufen', 'manage_camera');
            return _cameras;
        } else {
            logging.error(`Fehler beim Abrufen der Kameraliste: ${data.message}`, 'manage_camera');
            return [];
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Abrufen der Kameraliste: ${error.message}`, 'manage_camera');
        return [];
    }
}

/**
 * Stellt eine Verbindung zu einer Kamera her
 * @param {string} cameraId - ID der zu verbindenden Kamera
 * @returns {Promise<Object>} - Verbundene Kamera oder null bei Fehler
 */
export async function connectCamera(cameraId) {
    try {
        const response = await fetch('/api/camera/connect', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ camera_id: cameraId })
        });
        
        const data = await response.json();
        
        if (data.success) {
            _activeCamera = data.data;
            logging.log(`Kamera verbunden: ${_activeCamera.name}`, 'manage_camera');
            return _activeCamera;
        } else {
            logging.error(`Fehler beim Verbinden der Kamera: ${data.message}`, 'manage_camera');
            return null;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Verbinden der Kamera: ${error.message}`, 'manage_camera');
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
        const response = await fetch('/api/camera/disconnect', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            _activeCamera = null;
            logging.log('Kamera getrennt', 'manage_camera');
            return true;
        } else {
            logging.error(`Fehler beim Trennen der Kamera: ${data.message}`, 'manage_camera');
            return false;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Trennen der Kamera: ${error.message}`, 'manage_camera');
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
        const response = await fetch('/api/camera/capture', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(options)
        });
        
        const data = await response.json();
        
        if (data.success) {
            logging.log(`Bild aufgenommen: ${data.data.filename}`, 'manage_camera');
            
            // Event-Callbacks aufrufen
            _captureCallbacks.forEach(callback => {
                try {
                    callback(data.data);
                } catch (err) {
                    logging.error(`Fehler in Capture-Callback: ${err.message}`, 'manage_camera');
                }
            });
            
            return data.data;
        } else {
            logging.error(`Fehler bei Bildaufnahme: ${data.message}`, 'manage_camera');
            return { success: false, error: data.message };
        }
    } catch (error) {
        logging.error(`Netzwerkfehler bei Bildaufnahme: ${error.message}`, 'manage_camera');
        return { success: false, error: error.message };
    }
}

/**
 * Ruft die aktuellen Kameraeinstellungen ab
 * @returns {Promise<Object>} - Kameraeinstellungen
 */
export async function getCameraSettings() {
    try {
        const response = await fetch('/api/camera/settings');
        const data = await response.json();
        
        if (data.success) {
            logging.log('Kameraeinstellungen erfolgreich abgerufen', 'manage_camera');
            return data.data;
        } else {
            logging.error(`Fehler beim Abrufen der Kameraeinstellungen: ${data.message}`, 'manage_camera');
            return {};
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Abrufen der Kameraeinstellungen: ${error.message}`, 'manage_camera');
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
        const response = await fetch('/api/camera/settings', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(settings)
        });
        
        const data = await response.json();
        
        if (data.success) {
            logging.log('Kameraeinstellungen erfolgreich aktualisiert', 'manage_camera');
            return true;
        } else {
            logging.error(`Fehler beim Aktualisieren der Kameraeinstellungen: ${data.message}`, 'manage_camera');
            return false;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Aktualisieren der Kameraeinstellungen: ${error.message}`, 'manage_camera');
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
        logging.error(`Vorschau-Container mit ID "${containerId}" nicht gefunden`, 'manage_camera');
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
        logging.log('Kameravorschau gestartet', 'manage_camera');
        return true;
    } catch (error) {
        logging.error(`Fehler beim Starten der Kameravorschau: ${error.message}`, 'manage_camera');
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
        logging.log('Kameravorschau gestoppt', 'manage_camera');
        return true;
    } catch (error) {
        logging.error(`Fehler beim Stoppen der Kameravorschau: ${error.message}`, 'manage_camera');
        return false;
    }
}

/**
 * Ruft den Status der Kamera ab
 * @returns {Promise<Object>} - Kamerastatus
 */
export async function getCameraStatus() {
    try {
        const response = await fetch('/api/camera/status');
        const data = await response.json();
        
        if (data.success) {
            return data.data;
        } else {
            logging.error(`Fehler beim Abrufen des Kamerastatus: ${data.message}`, 'manage_camera');
            return { active_camera: null, status: 'error' };
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Abrufen des Kamerastatus: ${error.message}`, 'manage_camera');
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
        const response = await fetch('/api/camera/configs');
        const data = await response.json();
        
        if (data.success) {
            _cameraConfigs = data.data;
            logging.log('Kamera-Konfigurationen erfolgreich abgerufen', 'manage_camera');
            return _cameraConfigs;
        } else {
            logging.error(`Fehler beim Abrufen der Kamera-Konfigurationen: ${data.message}`, 'manage_camera');
            return [];
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Abrufen der Kamera-Konfigurationen: ${error.message}`, 'manage_camera');
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
        const response = await fetch(`/api/camera/config/${configId}`);
        const data = await response.json();
        
        if (data.success) {
            logging.log(`Kamera-Konfiguration ${configId} abgerufen`, 'manage_camera');
            return data.data;
        } else {
            logging.error(`Fehler beim Abrufen der Kamera-Konfiguration: ${data.message}`, 'manage_camera');
            return null;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Abrufen der Kamera-Konfiguration: ${error.message}`, 'manage_camera');
        return null;
    }
}

/**
 * Ruft die aktive Kamera-Konfiguration ab
 * @returns {Promise<Object>} - Aktive Konfiguration oder null
 */
export async function getActiveConfig() {
    try {
        const response = await fetch('/api/camera/config');
        const data = await response.json();
        
        if (data.success && data.data) {
            _activeConfig = data.data;
            logging.log('Aktive Kamera-Konfiguration abgerufen', 'manage_camera');
            return _activeConfig;
        } else {
            logging.error(`Fehler beim Abrufen der aktiven Konfiguration: ${data.message}`, 'manage_camera');
            return null;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Abrufen der aktiven Konfiguration: ${error.message}`, 'manage_camera');
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
        const response = await fetch('/api/camera/config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config_id: configId })
        });
        
        const data = await response.json();
        
        if (data.success) {
            logging.log(`Kamera-Konfiguration gesetzt: ${configId}`, 'manage_camera');
            
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
            logging.error(`Fehler beim Setzen der Kamera-Konfiguration: ${data.message}`, 'manage_camera');
            return false;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Setzen der Kamera-Konfiguration: ${error.message}`, 'manage_camera');
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
        const response = await fetch('/api/camera/config/create', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(config)
        });
        
        const data = await response.json();
        
        if (data.success) {
            logging.log(`Neue Kamera-Konfiguration erstellt: ${config.name}`, 'manage_camera');
            return data.data.id;
        } else {
            logging.error(`Fehler beim Erstellen der Kamera-Konfiguration: ${data.message}`, 'manage_camera');
            return null;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Erstellen der Konfiguration: ${error.message}`, 'manage_camera');
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
        const response = await fetch(`/api/camera/config/${configId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(config)
        });
        
        const data = await response.json();
        
        if (data.success) {
            logging.log(`Kamera-Konfiguration ${configId} aktualisiert`, 'manage_camera');
            return true;
        } else {
            logging.error(`Fehler beim Aktualisieren der Kamera-Konfiguration: ${data.message}`, 'manage_camera');
            return false;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Aktualisieren der Konfiguration: ${error.message}`, 'manage_camera');
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
        const response = await fetch(`/api/camera/config/${configId}`, {
            method: 'DELETE'
        });
        
        const data = await response.json();
        
        if (data.success) {
            logging.log(`Kamera-Konfiguration ${configId} gelöscht`, 'manage_camera');
            return true;
        } else {
            logging.error(`Fehler beim Löschen der Kamera-Konfiguration: ${data.message}`, 'manage_camera');
            return false;
        }
    } catch (error) {
        logging.error(`Netzwerkfehler beim Löschen der Konfiguration: ${error.message}`, 'manage_camera');
        return false;
    }
}

/**
 * Initialisiert die Kamera-Funktionalität
 * Wird automatisch beim Import dieses Moduls aufgerufen
 */
export async function initialize() {
    logging.log('Kamera-Modul wird initialisiert', 'manage_camera');
    
    try {
        // Liste der verfügbaren Kameras abrufen
        await listCameras();
        return true;
    } catch (error) {
        logging.error(`Fehler bei Kamera-Modul-Initialisierung: ${error.message}`, 'manage_camera');
        return false;
    }
}

// Automatische Initialisierung
initialize();
