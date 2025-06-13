/**
 * capture.js - Steuerungslogik für die Fotobox-Aufnahmeseite
 * 
 * Diese Datei implementiert die Hauptfunktionalität der Fotografie-Seite:
 * - Kamera-Vorschau anzeigen
 * - Foto-Aufnahme durchführen
 * - Countdown für Aufnahmen
 * - Anzeige aufgenommener Bilder
 * - Integration mit der Galerie
 */

// Importiere benötigte Module
import * as camera from './manage_camera.js';
import * as logging from './manage_logging.js';
import * as utils from './utils.js';
import { getSetting } from './manage_database.js';

// DOM-Elemente
let cameraPreviewElement;
let takePhotoButton;
let countdownElement;
let eventNameElement;
let resultImageElement;
let captureViewElement;
let resultViewElement;
let galleryButtonElement;
let newPhotoButtonElement;

// Status-Variablen
let isCountdownRunning = false;
let countdownDuration = 3; // Standardwert: 3 Sekunden
let currentTimer = null;

/**
 * Initialisiert die Capture-Seite
 */
export async function initialize() {
    logging.log('Initialisiere Capture-Seite', 'capture');
    
    // DOM-Elemente abrufen
    cameraPreviewElement = document.getElementById('cameraPreview');
    takePhotoButton = document.getElementById('takePhotoBtn');
    eventNameElement = document.getElementById('eventName');
    captureViewElement = document.getElementById('captureView');
    
    // Prüfe, ob alle notwendigen Elemente vorhanden sind
    if (!cameraPreviewElement || !takePhotoButton || !captureViewElement) {
        logging.error('Erforderliche DOM-Elemente für Capture-Seite nicht gefunden', 'capture');
        return false;
    }
    
    // Zusätzliche DOM-Elemente erstellen
    createAdditionalElements();
    
    // Event-Listener registrieren
    registerEventListeners();
    
    // Kamera initialisieren und verbinden
    await initializeCamera();
    
    // Ereignisname aus lokalen Einstellungen laden und anzeigen
    loadEventName();
    
    return true;
}

/**
 * Erstellt zusätzliche benötigte DOM-Elemente
 */
function createAdditionalElements() {
    // Countdown-Element erstellen
    countdownElement = document.createElement('div');
    countdownElement.id = 'countdown';
    countdownElement.className = 'countdown';
    countdownElement.style.display = 'none';
    captureViewElement.appendChild(countdownElement);
    
    // Kamera-Einstellungen-Panel
    const settingsPanel = document.createElement('div');
    settingsPanel.id = 'cameraSettingsPanel';
    settingsPanel.className = 'camera-settings-panel';
    
    // Einstellungs-Button
    const settingsToggleBtn = document.createElement('button');
    settingsToggleBtn.id = 'settingsToggleBtn';
    settingsToggleBtn.className = 'settings-toggle-btn';
    settingsToggleBtn.innerHTML = '<i class="fas fa-cog"></i>';
    settingsToggleBtn.title = 'Kamera-Einstellungen';
    
    // Einstellungs-Inhalt (initial ausgeblendet)
    const settingsContent = document.createElement('div');
    settingsContent.id = 'settingsContent';
    settingsContent.className = 'settings-content';
    settingsContent.style.display = 'none';
    
    // Füge Standard-Einstellungsoptionen hinzu
    settingsContent.innerHTML = `
        <h3>Kamera-Einstellungen</h3>
        <div class="setting-item">
            <label for="countdownSetting">Countdown:</label>
            <select id="countdownSetting">
                <option value="0">Aus</option>
                <option value="3" selected>3 Sekunden</option>
                <option value="5">5 Sekunden</option>
                <option value="10">10 Sekunden</option>
            </select>
        </div>
        <div class="setting-item">
            <label for="effectSetting">Effekt:</label>
            <select id="effectSetting">
                <option value="none" selected>Kein Effekt</option>
                <option value="bw">Schwarz/Weiß</option>
                <option value="sepia">Sepia</option>
                <option value="vintage">Vintage</option>
            </select>
        </div>
        <div id="advancedCameraSettings">
            <!-- Wird dynamisch befüllt, wenn verfügbar -->
        </div>
    `;
    
    // Einstellungsbutton zum Capture-View hinzufügen
    settingsPanel.appendChild(settingsToggleBtn);
    settingsPanel.appendChild(settingsContent);
    captureViewElement.appendChild(settingsPanel);
    
    // Ergebnis-Ansicht erstellen
    resultViewElement = document.createElement('div');
    resultViewElement.id = 'resultView';
    resultViewElement.className = 'result-view';
    resultViewElement.style.display = 'none';
    
    // Ergebnis-Bild erstellen
    resultImageElement = document.createElement('img');
    resultImageElement.id = 'resultImage';
    resultImageElement.className = 'result-image';
    resultImageElement.alt = 'Aufgenommenes Foto';
    resultViewElement.appendChild(resultImageElement);
    
    // Button-Container für Ergebnis-Ansicht
    const buttonContainer = document.createElement('div');
    buttonContainer.className = 'result-buttons';
    
    // "Neues Foto"-Button
    newPhotoButtonElement = document.createElement('button');
    newPhotoButtonElement.id = 'newPhotoBtn';
    newPhotoButtonElement.className = 'action-btn';
    newPhotoButtonElement.innerHTML = '<i class="fas fa-camera"></i> Neues Foto';
    buttonContainer.appendChild(newPhotoButtonElement);
    
    // "Zur Galerie"-Button
    galleryButtonElement = document.createElement('button');
    galleryButtonElement.id = 'galleryBtn';
    galleryButtonElement.className = 'action-btn';
    galleryButtonElement.innerHTML = '<i class="fas fa-images"></i> Zur Galerie';
    buttonContainer.appendChild(galleryButtonElement);
    
    resultViewElement.appendChild(buttonContainer);
    
    // Füge die Ergebnis-Ansicht zum DOM hinzu
    captureViewElement.parentNode.insertBefore(resultViewElement, captureViewElement.nextSibling);
}

/**
 * Registriert Event-Listener für Benutzerinteraktionen
 */
function registerEventListeners() {
    // Foto aufnehmen Button
    takePhotoButton.addEventListener('click', handleTakePhoto);
    
    // Einstellungs-Toggle-Button
    const settingsToggleBtn = document.getElementById('settingsToggleBtn');
    const settingsContent = document.getElementById('settingsContent');
    
    if (settingsToggleBtn && settingsContent) {
        settingsToggleBtn.addEventListener('click', () => {
            // Toggle Einstellungsmenü
            const isVisible = settingsContent.style.display === 'block';
            settingsContent.style.display = isVisible ? 'none' : 'block';
            settingsToggleBtn.classList.toggle('active', !isVisible);
        });
    }
    
    // Countdown-Einstellung
    const countdownSetting = document.getElementById('countdownSetting');
    if (countdownSetting) {
        // Gespeicherte Einstellung laden
        const storedDuration = localStorage.getItem('countdownDuration');
        if (storedDuration) {
            countdownSetting.value = storedDuration;
        }
        
        // Änderungen speichern
        countdownSetting.addEventListener('change', () => {
            countdownDuration = parseInt(countdownSetting.value);
            localStorage.setItem('countdownDuration', countdownDuration.toString());
        });
    }
    
    // Effekt-Einstellung
    const effectSetting = document.getElementById('effectSetting');
    if (effectSetting) {
        // Gespeicherte Einstellung laden
        const storedEffect = localStorage.getItem('photoEffect');
        if (storedEffect) {
            effectSetting.value = storedEffect;
        }
        
        // Änderungen speichern
        effectSetting.addEventListener('change', () => {
            const selectedEffect = effectSetting.value;
            localStorage.setItem('photoEffect', selectedEffect);
            applyPhotoEffect(selectedEffect);
        });
        
        // Initial anwenden
        applyPhotoEffect(effectSetting.value);
    }
    
    // Neues Foto Button
    if (newPhotoButtonElement) {
        newPhotoButtonElement.addEventListener('click', () => {
            showCaptureView();
        });
    }
    
    // Galerie Button
    if (galleryButtonElement) {
        galleryButtonElement.addEventListener('click', () => {
            window.location.href = 'gallery.html';
        });
    }
}

/**
 * Wendet einen visuellen Effekt auf die Vorschau an
 * @param {string} effect - Der anzuwendende Effekt
 */
function applyPhotoEffect(effect) {
    const previewImage = document.getElementById('cameraPreviewImage');
    if (!previewImage) return;
    
    // Zurücksetzen von Filtern
    previewImage.style.filter = '';
    
    // Effekt anwenden
    switch (effect) {
        case 'bw':
            previewImage.style.filter = 'grayscale(100%)';
            break;
        case 'sepia':
            previewImage.style.filter = 'sepia(100%)';
            break;
        case 'vintage':
            previewImage.style.filter = 'sepia(50%) contrast(85%) brightness(90%)';
            break;
        default:
            // Kein Effekt
            break;
    }
}

/**
 * Initialisiert die Kamera und startet die Vorschau
 */
async function initializeCamera() {
    try {
        // Status-Feedback für den Benutzer anzeigen
        const statusElement = document.createElement('div');
        statusElement.className = 'camera-status';
        statusElement.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Kamera wird initialisiert...';
        cameraPreviewElement.appendChild(statusElement);
        
        // Überprüfe, ob eine Kamera-Konfiguration in den Einstellungen gespeichert ist
        let configId = localStorage.getItem('camera_config_id');
        
        if (configId && configId !== 'system') {
            // Versuche, die gespeicherte Konfiguration zu laden
            logging.log(`Verwende gespeicherte Kamera-Konfiguration: ${configId}`, 'capture');
            
            // Aktive Konfiguration auslesen
            const configResponse = await fetch('/api/camera/config');
            const configData = await configResponse.json();
            
            if (!configData.success || !configData.data || configData.data.id !== configId) {
                // Konfiguration setzen, wenn sie nicht aktuell aktiv ist
                logging.log(`Setze Kamera-Konfiguration: ${configId}`, 'capture');
                await fetch('/api/camera/config', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ config_id: configId })
                });
            }
        } else {
            // Bei 'system' oder wenn nichts gesetzt ist: Standard-Konfiguration laden
            logging.log('Verwende System-Standard-Konfiguration', 'capture');
        }
        
        // Kameraliste abrufen (nach dem Setzen der Konfiguration)
        const cameras = await camera.listCameras();
        
        if (cameras && cameras.length > 0) {
            // Verwende die erste verfügbare Kamera (basierend auf der aktiven Konfiguration)
            const selectedCameraId = cameras[0].id;
            
            // Verbindung zur Kamera herstellen
            const connected = await camera.connectCamera(selectedCameraId);
            
            if (connected) {
                // Status-Element entfernen
                if (statusElement.parentNode) {
                    statusElement.parentNode.removeChild(statusElement);
                }
                
                // Vorschau starten
                camera.startLivePreview('cameraPreview');
                logging.log('Kamera verbunden und Vorschau gestartet', 'capture');
                  // Button aktivieren
                takePhotoButton.disabled = false;
                
                // Erweiterte Kameraeinstellungen laden
                await loadAdvancedCameraSettings();
                
                // Verfügbare Kamera-Konfigurationen laden
                await loadCameraConfigurations();
                
                // Gespeicherten Effekt anwenden (falls vorhanden)
                const storedEffect = localStorage.getItem('photoEffect');
                if (storedEffect) {
                    applyPhotoEffect(storedEffect);
                }
            } else {
                // Status-Element entfernen
                if (statusElement.parentNode) {
                    statusElement.parentNode.removeChild(statusElement);
                }
                
                showCameraError('Konnte keine Verbindung zur Kamera herstellen');
            }
        } else {
            // Status-Element entfernen
            if (statusElement.parentNode) {
                statusElement.parentNode.removeChild(statusElement);
            }
            
            showCameraError('Keine Kameras gefunden');
        }
    } catch (error) {
        logging.error(`Fehler bei Kamera-Initialisierung: ${error.message}`, 'capture');
        showCameraError('Kamerafehler: ' + error.message);
    }
}

/**
 * Zeigt einen Kamerafehler in der Vorschau an
 * @param {string} message - Fehlermeldung
 */
function showCameraError(message) {
    if (cameraPreviewElement) {
        cameraPreviewElement.innerHTML = `
            <div class="camera-error">
                <i class="fas fa-exclamation-triangle"></i>
                <p>${message}</p>
                <button id="retryBtn" class="retry-btn">
                    <i class="fas fa-sync"></i> Erneut versuchen
                </button>
            </div>
        `;
        
        // Retry-Button aktivieren
        const retryBtn = document.getElementById('retryBtn');
        if (retryBtn) {
            retryBtn.addEventListener('click', initializeCamera);
        }
        
        // Button deaktivieren
        if (takePhotoButton) {
            takePhotoButton.disabled = true;
        }
    }
}

/**
 * Behandelt den Klick auf den "Foto aufnehmen"-Button
 */
function handleTakePhoto() {
    if (isCountdownRunning) return;
    
    // Countdown-Dauer aus Einstellungen laden oder Standardwert verwenden
    const storedDuration = localStorage.getItem('countdownDuration');
    countdownDuration = storedDuration ? parseInt(storedDuration) : 3;
    
    if (countdownDuration > 0) {
        // Mit Countdown fotografieren
        startCountdown(countdownDuration);
    } else {
        // Sofort fotografieren
        takePicture();
    }
}

/**
 * Startet den Countdown für die Bildaufnahme
 * @param {number} duration - Countdown-Dauer in Sekunden
 */
function startCountdown(duration) {
    if (isCountdownRunning) return;
    
    isCountdownRunning = true;
    let secondsLeft = duration;
    
    // Countdown-Element anzeigen und aktualisieren
    countdownElement.textContent = secondsLeft;
    countdownElement.style.display = 'flex';
    
    // Button deaktivieren während des Countdowns
    if (takePhotoButton) {
        takePhotoButton.disabled = true;
    }
    
    // Countdown starten
    currentTimer = setInterval(() => {
        secondsLeft--;
        
        if (secondsLeft <= 0) {
            // Countdown beenden und Foto aufnehmen
            clearInterval(currentTimer);
            currentTimer = null;
            
            countdownElement.style.display = 'none';
            isCountdownRunning = false;
            
            // Foto aufnehmen
            takePicture();
            
            // Button wieder aktivieren
            if (takePhotoButton) {
                takePhotoButton.disabled = false;
            }
        } else {
            // Countdown aktualisieren
            countdownElement.textContent = secondsLeft;
        }
    }, 1000);
}

/**
 * Nimmt ein Bild auf und zeigt es an
 */
async function takePicture() {
    try {
        // Status-Feedback für den Benutzer anzeigen
        const statusElement = document.createElement('div');
        statusElement.className = 'camera-status';
        statusElement.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Foto wird aufgenommen...';
        cameraPreviewElement.appendChild(statusElement);
        
        // Blitzeffekt anzeigen
        showFlashEffect();
        
        // Bild aufnehmen
        const result = await camera.captureImage();
        
        // Status-Element entfernen
        if (statusElement.parentNode) {
            statusElement.parentNode.removeChild(statusElement);
        }
        
        if (result && result.success !== false) {
            // Ergebnisbild anzeigen
            showCapturedImage(result.filepath);
            
            // Speichern in lokaler Historie
            saveToPhotoHistory(result);
        } else {
            // Fehler anzeigen
            logging.error('Fehler bei Bildaufnahme: ' + (result ? result.error : 'Unbekannter Fehler'), 'capture');
            showCameraError('Fehler bei der Bildaufnahme: ' + (result ? result.error : 'Bitte versuchen Sie es erneut.'));
        }
    } catch (error) {
        logging.error(`Fehler bei Bildaufnahme: ${error.message}`, 'capture');
        showCameraError('Kamerafehler: ' + error.message);
    }
}

/**
 * Speichert das Foto in der lokalen Fotohistorie
 * @param {Object} photoData - Daten des aufgenommenen Fotos
 */
function saveToPhotoHistory(photoData) {
    try {
        // Hole bestehende Historie oder erstelle neue
        let photoHistory = JSON.parse(localStorage.getItem('photoHistory') || '[]');
        
        // Füge neues Foto hinzu (maximal 10 Einträge)
        photoHistory.unshift({
            filepath: photoData.filepath,
            thumbnail: photoData.thumbnail || photoData.filepath,
            timestamp: new Date().toISOString()
        });
        
        // Begrenze auf 10 Einträge
        if (photoHistory.length > 10) {
            photoHistory = photoHistory.slice(0, 10);
        }
        
        // Speichere Historie
        localStorage.setItem('photoHistory', JSON.stringify(photoHistory));
    } catch (error) {
        logging.error(`Fehler beim Speichern der Fotohistorie: ${error.message}`, 'capture');
    }
}

/**
 * Zeigt einen Blitzeffekt bei der Bildaufnahme
 */
function showFlashEffect() {
    const flashElement = document.createElement('div');
    flashElement.className = 'flash-effect';
    document.body.appendChild(flashElement);
    
    // Blitz nach kurzer Zeit wieder entfernen
    setTimeout(() => {
        document.body.removeChild(flashElement);
    }, 500);
}

/**
 * Zeigt das aufgenommene Bild im Ergebnis-View an
 * @param {string} imagePath - Pfad zum aufgenommenen Bild
 */
function showCapturedImage(imagePath) {
    // Vorschau stoppen
    camera.stopLivePreview();
    
    // Bildpfad für das Ergebnisbild setzen
    resultImageElement.src = imagePath;
    
    // Capture-View ausblenden und Result-View anzeigen
    captureViewElement.style.display = 'none';
    resultViewElement.style.display = 'block';
}

/**
 * Wechselt zurück zur Aufnahme-Ansicht
 */
function showCaptureView() {
    // Result-View ausblenden und Capture-View anzeigen
    resultViewElement.style.display = 'none';
    captureViewElement.style.display = 'block';
    
    // Vorschau neu starten
    camera.startLivePreview('cameraPreview');
}

/**
 * Lädt den Ereignisnamen aus den lokalen Einstellungen und zeigt ihn an
 */
function loadEventName() {
    try {
        const eventName = localStorage.getItem('eventName') || '';
        
        if (eventNameElement && eventName) {
            eventNameElement.textContent = eventName;
            eventNameElement.style.display = 'block';
        } else if (eventNameElement) {
            eventNameElement.style.display = 'none';
        }
    } catch (error) {
        logging.error(`Fehler beim Laden des Ereignisnamens: ${error.message}`, 'capture');
    }
}

/**
 * Lädt erweiterte Kameraeinstellungen vom Backend und fügt sie zur Benutzeroberfläche hinzu
 */
async function loadAdvancedCameraSettings() {
    try {
        const settings = await camera.getCameraSettings();
        
        if (Object.keys(settings).length === 0) {
            logging.log('Keine erweiterten Kamera-Einstellungen verfügbar', 'capture');
            return;
        }
        
        const advancedSettingsContainer = document.getElementById('advancedCameraSettings');
        if (!advancedSettingsContainer) return;
        
        // Container leeren
        advancedSettingsContainer.innerHTML = '<h4>Erweiterte Einstellungen</h4>';
        
        // Verfügbare Einstellungen dynamisch hinzufügen
        for (const [key, value] of Object.entries(settings)) {
            // Ignoriere interne oder komplexe Eigenschaften
            if (key.startsWith('_') || typeof value === 'object' || typeof value === 'function') {
                continue;
            }
            
            const settingId = `setting_${key}`;
            const settingItem = document.createElement('div');
            settingItem.className = 'setting-item';
            
            // Verschiedene Eingabefelder je nach Werttyp
            if (typeof value === 'boolean') {
                // Checkbox für Boolean-Werte
                settingItem.innerHTML = `
                    <label for="${settingId}">${formatSettingName(key)}:</label>
                    <input type="checkbox" id="${settingId}" ${value ? 'checked' : ''}>
                `;
            } else if (typeof value === 'number') {
                // Slider oder Nummerneingabe für Zahlen
                // Begrenze die Werte sinnvoll basierend auf typischen Kameraeinstellungen
                let min = 0;
                let max = 100;
                let step = 1;
                
                if (key.includes('iso')) {
                    min = 100;
                    max = 6400;
                    step = 100;
                } else if (key.includes('exposure')) {
                    min = -3;
                    max = 3;
                    step = 0.5;
                }
                
                settingItem.innerHTML = `
                    <label for="${settingId}">${formatSettingName(key)}:</label>
                    <input type="range" id="${settingId}" min="${min}" max="${max}" step="${step}" value="${value}">
                    <span id="${settingId}_value">${value}</span>
                `;
            } else {
                // Textfeld für andere Werte
                settingItem.innerHTML = `
                    <label for="${settingId}">${formatSettingName(key)}:</label>
                    <input type="text" id="${settingId}" value="${value}">
                `;
            }
            
            advancedSettingsContainer.appendChild(settingItem);
            
            // Event-Listener für Änderungen
            const inputElement = document.getElementById(settingId);
            if (inputElement) {
                inputElement.addEventListener('change', async (e) => {
                    const newValue = e.target.type === 'checkbox' ? e.target.checked : 
                                    e.target.type === 'range' || e.target.type === 'number' ? 
                                    parseFloat(e.target.value) : e.target.value;
                    
                    // Aktualisiere die Wertanzeige für Slider
                    if (e.target.type === 'range') {
                        const valueDisplay = document.getElementById(`${settingId}_value`);
                        if (valueDisplay) {
                            valueDisplay.textContent = newValue;
                        }
                    }
                    
                    // Sende aktualisierte Einstellung an das Backend
                    const updateResult = await camera.updateCameraSettings({ [key]: newValue });
                    
                    if (!updateResult) {
                        logging.error(`Fehler beim Aktualisieren der Einstellung ${key}`, 'capture');
                    }
                });
            }
        }
        
        // Lade verfügbare Kamerakonfigurationen
        await loadCameraConfigurations();
        
    } catch (error) {
        logging.error(`Fehler beim Laden erweiterter Kameraeinstellungen: ${error.message}`, 'capture');
    }
}

/**
 * Lädt die verfügbaren Kamerakonfigurationen und fügt sie zum Einstellungsmenü hinzu
 */
async function loadCameraConfigurations() {
    try {
        const configs = await camera.listCameraConfigs();
        
        if (!configs || configs.length === 0) {
            logging.log('Keine Kamera-Konfigurationen verfügbar', 'capture');
            return;
        }
        
        const advancedSettingsContainer = document.getElementById('advancedCameraSettings');
        if (!advancedSettingsContainer) return;
        
        // Konfigurationsauswahl erstellen
        const configSection = document.createElement('div');
        configSection.className = 'setting-item config-selection';
        
        // Überschrift
        const configHeader = document.createElement('h4');
        configHeader.textContent = 'Kamera-Konfiguration';
        configSection.appendChild(configHeader);
        
        // Select-Element erstellen
        const configSelect = document.createElement('select');
        configSelect.id = 'configSelect';
        
        // Standard-Option hinzufügen
        const defaultOption = document.createElement('option');
        defaultOption.value = 'system';
        defaultOption.textContent = 'System-Standard';
        configSelect.appendChild(defaultOption);
        
        // Konfigurationen hinzufügen
        configs.forEach(config => {
            const option = document.createElement('option');
            option.value = config.id;
            option.textContent = config.name;
            configSelect.appendChild(option);
        });
        
        // Aktuelle Auswahl setzen
        const currentConfigId = localStorage.getItem('camera_config_id') || 'system';
        configSelect.value = currentConfigId;
        
        // Event-Listener für Änderungen hinzufügen
        configSelect.addEventListener('change', async () => {
            const selectedConfigId = configSelect.value;
            localStorage.setItem('camera_config_id', selectedConfigId);
            
            // Statusmeldung anzeigen
            const statusElement = document.createElement('div');
            statusElement.className = 'camera-status';
            statusElement.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Konfiguration wird angewendet...';
            cameraPreviewElement.appendChild(statusElement);
            
            try {
                // Kamera trennen und Vorschau stoppen
                camera.stopLivePreview();
                await camera.disconnectCamera();
                
                // Neue Konfiguration setzen und Kamera neu initialisieren
                if (selectedConfigId !== 'system') {
                    await camera.setActiveConfig(selectedConfigId);
                }
                
                // Kamera neu verbinden
                await initializeCamera();
                
                // Statusmeldung entfernen
                if (statusElement.parentNode) {
                    statusElement.parentNode.removeChild(statusElement);
                }
            } catch (error) {
                logging.error(`Fehler beim Wechseln der Kamera-Konfiguration: ${error.message}`, 'capture');
                
                // Statusmeldung entfernen und Fehlermeldung anzeigen
                if (statusElement.parentNode) {
                    statusElement.parentNode.removeChild(statusElement);
                }
                
                showCameraError(`Fehler beim Anwenden der Konfiguration: ${error.message}`);
            }
        });
        
        configSection.appendChild(configSelect);
        
        // Am Anfang des Containers einfügen
        advancedSettingsContainer.insertBefore(configSection, advancedSettingsContainer.firstChild);
        
    } catch (error) {
        logging.error(`Fehler beim Laden der Kamera-Konfigurationen: ${error.message}`, 'capture');
    }
}

/**
 * Formatiert den Namen einer Einstellung für benutzerfreundliche Anzeige
 * @param {string} name - Der Rohdatenname der Einstellung
 * @returns {string} - Formatierter Name
 */
function formatSettingName(name) {
    return name
        // Unterstriche durch Leerzeichen ersetzen
        .replace(/_/g, ' ')
        // Erster Buchstabe groß
        .replace(/\b\w/g, l => l.toUpperCase());
}

/**
 * Räumt Ressourcen auf (wird beim Verlassen der Seite aufgerufen)
 */
export function cleanup() {
    // Countdown stoppen, falls aktiv
    if (currentTimer) {
        clearInterval(currentTimer);
        currentTimer = null;
    }
    
    // Kamera-Vorschau stoppen
    camera.stopLivePreview();
    
    // Kamera trennen
    camera.disconnectCamera();
}

// Initialisiere die Seite beim Laden
document.addEventListener('DOMContentLoaded', initialize);

// Ressourcen beim Verlassen der Seite aufräumen
window.addEventListener('beforeunload', cleanup);
