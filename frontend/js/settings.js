// filepath: c:\Users\HP 800 G1\OneDrive\Dokumente\Götze Dirk\Eigene Projekte\fotobox2\frontend\js\settings.js
// ------------------------------------------------------------------------------
// settings.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Einstellungsseite der Fotobox (settings.html) mit
// Login-System, Formular-Validierung und API-Kommunikation zur Konfiguration
// ------------------------------------------------------------------------------

// Importiere Systemmodule
import { throttledCheckForUpdates, installUpdate, getUpdateStatus, getVersionInfo, 
       checkDependencies, getDependenciesStatus, installDependencies } from './manage_update.js';
import { log, error } from './manage_logging.js';
import { showNotification, showDialog } from './ui_components.js';
import { login, validatePassword, changePassword } from './manage_auth.js';
import { loadSettings, loadSingleSetting, updateSettings, updateSingleSetting, validateSettings, resetToDefaults } from './manage_settings.js';

// Import der Kamera-Module
import * as camera from './manage_camera.js';
import { getSetting, setSetting } from './manage_database.js';

// =================================================================================
// Login-Funktionalität
// =================================================================================

/**
 * Event-Handler für das Login-Formular
 */
document.getElementById('loginForm').onsubmit = async function(e) {
    e.preventDefault();
    const password = document.getElementById('adminPassword').value;
    const status = document.getElementById('loginStatus');
    if (password.length < 4) {
        status.textContent = 'Passwort zu kurz (mind. 4 Zeichen)';
        status.className = 'status-error';
        return;
    }
    
    try {
        const isSuccess = await login(password);
        
        if (isSuccess) {
            document.getElementById('loginForm').classList.add('hidden');            document.getElementById('configForm').classList.add('form-visible');
            
            // Einstellungen laden
            loadSettingsAndUpdateUI().then(() => {
                // Nach Laden der Einstellungen die Live-Updates aktivieren
                if (typeof initLiveSettingsUpdate === 'function') {
                    initLiveSettingsUpdate();
                }
            });
        } else {
            status.textContent = 'Falsches Passwort';
            status.className = 'status-error';
        }
    } catch (error) {
        status.textContent = 'Verbindungsfehler';
        status.className = 'status-error';
        console.error('Login-Fehler:', error);
    }
};

// =================================================================================
// Einstellungen-Formular-Handling
// =================================================================================

// Der Form-Submit-Handler wurde entfernt, da die Einstellungen jetzt automatisch gespeichert werden
// Siehe live-settings-update.js für die Implementierung der automatischen Speicherung

// =================================================================================
// Daten laden
// =================================================================================

// Der Reset-Button wurde entfernt, da Änderungen nun automatisch gespeichert werden

/**
 * Einstellungen laden und UI aktualisieren
 */
async function loadSettingsAndUpdateUI() {
    try {
        // Verwende das neue Einstellungs-Modul
        const settings = await loadSettings();
        
        // Event-Name setzen (wenn vorhanden)
        if (document.getElementById('event_name')) {
            document.getElementById('event_name').value = settings.event_name || '';
            // Aktualisiere auch den Header-Titel
            setHeaderTitle(settings.event_name);
        }
        
        // Event-Datum setzen (wenn vorhanden)
        if (settings.event_date && document.getElementById('event_date')) {
            document.getElementById('event_date').value = settings.event_date;
        }
          // Kameraliste laden und UI aktualisieren
        await loadCameraList();
          // Kamera-Konfiguration setzen
        if (document.getElementById('camera_config_id') && settings.camera_config_id) {
            document.getElementById('camera_config_id').value = settings.camera_config_id;
            
            // Wenn eine Konfiguration gesetzt ist, auch in der Datenbank speichern
            if (settings.camera_config_id !== 'system') {
                setSetting('camera_config_id', settings.camera_config_id).catch(err => {
                    error('Fehler beim Speichern der Kamera-Konfiguration', err);
                });
            }
        }
        
        // Alte Kamera-Einstellung (für Abwärtskompatibilität)
        if (document.getElementById('camera_id') && settings.camera_id) {
            document.getElementById('camera_id').value = settings.camera_id;
        }
          
        // Nach dem Laden der Einstellungen automatisch nach Updates suchen
        // und auch die Abhängigkeiten prüfen
        setTimeout(() => {
            // Verzögerte Ausführung, um UI-Updates zu ermöglichen
            handleUpdateCheck();
            // Auch die Abhängigkeiten prüfen
            checkDependenciesAndUpdateUI().catch(err => {
                error('Fehler bei der automatischen Abhängigkeitsprüfung', err);
            });
        }, 500);
        
        // Anzeigemodus setzen
        if (document.getElementById('color_mode')) {
            document.getElementById('color_mode').value = settings.color_mode || 'system';
        }
        
        // Bildschirmschoner-Timeout setzen
        if (document.getElementById('screensaver_timeout')) {
            document.getElementById('screensaver_timeout').value = settings.screensaver_timeout || 120;
        }
        
        // Galerie-Timeout setzen
        if (document.getElementById('gallery_timeout')) {
            document.getElementById('gallery_timeout').value = settings.gallery_timeout || 60;
        }
        
        // Countdown-Dauer setzen
        if (document.getElementById('countdown_duration')) {
            document.getElementById('countdown_duration').value = settings.countdown_duration || 3;
        }
        
        // Kamera-Einstellungen
        if (document.getElementById('camera_id')) {
            document.getElementById('camera_id').value = settings.camera_id || 'auto';
        }
        
        if (document.getElementById('flash_mode')) {
            document.getElementById('flash_mode').value = settings.flash_mode || 'auto';
        }
        
        // Verfügbare Kameras laden und Dropdown aktualisieren
        loadAvailableCameras();
    } catch (err) {
        error('Fehler beim Laden der Einstellungen:', err);
        showNotification('Fehler beim Laden der Einstellungen', 'error');
    }
}

/**
 * Verfügbare Kameras laden und im Dropdown anzeigen
 */
async function loadAvailableCameras() {
    try {
        const cameraSelect = document.getElementById('camera_id');
        if (!cameraSelect) return;
        
        // Bestehende Option für "Systemstandard verwenden" speichern
        const defaultOption = cameraSelect.querySelector('option[value="system"]');
        
        // Dropdown leeren, aber Default-Option behalten
        cameraSelect.innerHTML = '';
        if (defaultOption) {
            cameraSelect.appendChild(defaultOption);
        }
        
        // Kameras vom Backend abrufen
        const response = await fetch('/api/camera/list');
        const data = await response.json();
        
        if (data.success && data.data && data.data.length > 0) {
            // Alle gefundenen Kameras als Optionen hinzufügen
            data.data.forEach(camera => {
                const option = document.createElement('option');
                option.value = camera.id;
                option.textContent = `${camera.name} (${camera.type})`;
                cameraSelect.appendChild(option);
            });
            
            log(`${data.data.length} Kameras gefunden und in die Auswahlliste geladen.`);
        } else {
            log('Keine Kameras gefunden oder Fehler beim Laden der Kameraliste.');
        }
    } catch (error) {
        error('Fehler beim Laden der Kameras:', error);
    }
}

/**
 * Lädt die Liste der verfügbaren Kamera-Konfigurationen und aktualisiert das Dropdown
 */
async function loadCameraList() {
    try {
        const configSelect = document.getElementById('camera_config_id');
        if (!configSelect) {
            error('Kamera-Konfigurations-Dropdown nicht gefunden');
            return;
        }
        
        // Bestehende Option für "Standardkonfiguration verwenden" speichern
        const defaultOption = configSelect.querySelector('option[value="system"]');
        
        // Dropdown leeren, aber Default-Option behalten
        configSelect.innerHTML = '';
        if (defaultOption) {
            configSelect.appendChild(defaultOption);
        }
        
        // Kamera-Konfigurationen vom Backend abrufen
        const response = await fetch('/api/camera/configs');
        const data = await response.json();
        
        if (data.success && data.data && data.data.length > 0) {
            // Alle verfügbaren Konfigurationen als Optionen hinzufügen
            data.data.forEach(config => {
                const option = document.createElement('option');
                option.value = config.id;
                option.textContent = config.name;
                if (config.description) {
                    option.title = config.description;
                }
                configSelect.appendChild(option);
            });
            
            // Aktive Konfiguration setzen
            const activeConfigResponse = await fetch('/api/camera/config');
            const activeConfigData = await activeConfigResponse.json();
            
            if (activeConfigData.success && activeConfigData.data && activeConfigData.data.id) {
                configSelect.value = activeConfigData.data.id;
            } else {
                configSelect.value = 'system';
            }
            
            // Event-Handler für Änderung der Konfiguration hinzufügen
            configSelect.addEventListener('change', handleCameraConfigChange);
            
            // Lade dynamische Einstellungen für die aktuelle Konfiguration
            await loadDynamicCameraSettings();
            
            // Vorschau initialisieren
            initCameraPreview();
            
            log(`${data.data.length} Kamera-Konfigurationen geladen`);
        } else {
            log('Keine Kamera-Konfigurationen gefunden oder Fehler beim Laden');
        }
    } catch (error) {
        error('Fehler beim Laden der Kamera-Konfigurationen:', error);
    }
}

/**
 * Event-Handler für die Änderung der Kamera-Konfiguration
 */
async function handleCameraConfigChange(event) {
    const configId = event.target.value;
      try {
        // Speichere die Konfiguration in der Datenbank für andere Seiten
        await setSetting('camera_config_id', configId);
        
        // Nutze die Kamera-Modul-Funktion, um die Konfiguration zu ändern
        const success = await camera.setActiveConfig(configId);
        
        if (success) {
            // Lade die dynamischen Einstellungen neu
            await loadDynamicCameraSettings();
            
            // Aktualisiere die Vorschau
            updateCameraPreview();
            
            // Speichere die Einstellung in der Datenbank
            await updateSingleSetting('camera_config_id', configId);
            
            showNotification('Kamera-Konfiguration aktualisiert', 'success');
        } else {
            showNotification('Fehler bei der Aktualisierung der Kamera-Konfiguration', 'error');
        }
    } catch (err) {
        error('Fehler bei der Änderung der Kamera-Konfiguration:', err);
        showNotification('Fehler bei der Änderung der Kamera-Konfiguration', 'error');
    }
}

/**
 * Lädt die dynamischen Kamera-Einstellungen basierend auf der aktiven Konfiguration
 */
async function loadDynamicCameraSettings() {
    const dynamicSettings = document.getElementById('dynamicCameraSettings');
    if (!dynamicSettings) return;
    
    // Container leeren
    dynamicSettings.innerHTML = '';
    
    try {
        // Aktive Konfiguration über das Kamera-Modul abrufen
        const activeConfig = await camera.getActiveConfig();
        
        if (!data.success || !data.data || !data.data.config) {        return; // Keine Konfiguration oder Fehler
        }
        
        if (!activeConfig || !activeConfig.config) {
            error('Keine aktive Kamera-Konfiguration gefunden');
            return;
        }
        
        const config = activeConfig.config;
        const settings = config.settings || {};
        
        // Titel hinzufügen
        const title = document.createElement('h4');
        title.textContent = 'Kamera-Spezifische Einstellungen';
        title.className = 'dynamic-settings-title';
        dynamicSettings.appendChild(title);
        
        // Auflösung-Einstellung
        if (settings.resolution) {
            const { width, height } = settings.resolution;
            addResolutionSetting(dynamicSettings, width, height);
        }
        
        // FPS-Einstellung
        if (settings.fps !== undefined) {
            addSliderSetting(dynamicSettings, 'fps', 'Bilder pro Sekunde', settings.fps, 5, 60);
        }
        
        // Kompression/Qualität
        if (settings.compression !== undefined) {
            addSliderSetting(dynamicSettings, 'compression', 'Bildqualität', settings.compression, 10, 100);
        }
        
        // Helligkeit (falls kamera.js diese Einstellung unterstützt)
        addSliderSetting(dynamicSettings, 'brightness', 'Helligkeit', 50, 0, 100);
        
        // Kontrast (falls kamera.js diese Einstellung unterstützt)
        addSliderSetting(dynamicSettings, 'contrast', 'Kontrast', 50, 0, 100);
        
        // DSLR-spezifische Einstellungen, falls es sich um eine DSLR handelt
        if (config.type === 'dslr') {
            // ISO-Einstellung
            if (settings.iso) {
                addDSLRISOSetting(dynamicSettings, settings.iso);
            }
            
            // Blenden-Einstellung
            if (settings.aperture) {
                addDSLRApertureSetting(dynamicSettings, settings.aperture);
            }
            
            // Verschlusszeit-Einstellung
            if (settings.shutter_speed) {
                addDSLRShutterSpeedSetting(dynamicSettings, settings.shutter_speed);
            }
        }
    } catch (err) {
        error('Fehler beim Laden der dynamischen Kamera-Einstellungen:', err);
    }
}

/**
 * Fügt eine Auflösungs-Einstellung zum Container hinzu
 */
function addResolutionSetting(container, width, height) {
    const div = document.createElement('div');
    div.className = 'input-field';
    
    const label = document.createElement('label');
    label.textContent = 'Auflösung';
    
    const select = document.createElement('select');
    select.id = 'resolution_setting';
    select.name = 'resolution_setting';
    
    // Gängige Auflösungen
    const resolutions = [
        { w: 640, h: 480, name: '640x480 (VGA)' },
        { w: 800, h: 600, name: '800x600 (SVGA)' },
        { w: 1280, h: 720, name: '1280x720 (HD 720p)' },
        { w: 1920, h: 1080, name: '1920x1080 (Full HD 1080p)' },
        { w: 2560, h: 1440, name: '2560x1440 (QHD)' },
        { w: 3840, h: 2160, name: '3840x2160 (4K UHD)' }
    ];
    
    resolutions.forEach(res => {
        const option = document.createElement('option');
        option.value = `${res.w}x${res.h}`;
        option.textContent = res.name;
        if (res.w === width && res.h === height) {
            option.selected = true;
        }
        select.appendChild(option);
    });
    
    // Event-Listener für Änderungen
    select.addEventListener('change', async function() {
        const [w, h] = this.value.split('x').map(Number);
        await updateCameraSetting('resolution', { width: w, height: h });
    });
    
    div.appendChild(label);
    div.appendChild(select);
    container.appendChild(div);
}

/**
 * Fügt einen Schieberegler für eine Kamera-Einstellung hinzu
 */
function addSliderSetting(container, settingName, displayName, value, min, max) {
    const div = document.createElement('div');
    div.className = 'slider-container';
    
    const label = document.createElement('label');
    label.textContent = displayName;
    
    const sliderContainer = document.createElement('div');
    sliderContainer.className = 'slider-with-value';
    
    const slider = document.createElement('input');
    slider.type = 'range';
    slider.id = `${settingName}_slider`;
    slider.name = `${settingName}_slider`;
    slider.min = min;
    slider.max = max;
    slider.value = value;
    
    const valueDisplay = document.createElement('span');
    valueDisplay.className = 'slider-value';
    valueDisplay.textContent = value;
    
    // Event-Listener für Änderungen
    slider.addEventListener('input', function() {
        valueDisplay.textContent = this.value;
    });
    
    slider.addEventListener('change', async function() {
        await updateCameraSetting(settingName, Number(this.value));
    });
    
    sliderContainer.appendChild(slider);
    sliderContainer.appendChild(valueDisplay);
    
    div.appendChild(label);
    div.appendChild(sliderContainer);
    container.appendChild(div);
}

/**
 * Fügt eine ISO-Einstellung für DSLR-Kameras hinzu
 */
function addDSLRISOSetting(container, currentValue) {
    const div = document.createElement('div');
    div.className = 'input-field';
    
    const label = document.createElement('label');
    label.textContent = 'ISO';
    
    const select = document.createElement('select');
    select.id = 'iso_setting';
    select.name = 'iso_setting';
    
    // Gängige ISO-Werte
    const isoValues = ['auto', '100', '200', '400', '800', '1600', '3200'];
    
    isoValues.forEach(iso => {
        const option = document.createElement('option');
        option.value = iso;
        option.textContent = iso === 'auto' ? 'Automatisch' : iso;
        if (iso === currentValue.toString()) {
            option.selected = true;
        }
        select.appendChild(option);
    });
    
    // Event-Listener für Änderungen
    select.addEventListener('change', async function() {
        await updateCameraSetting('iso', this.value);
    });
    
    div.appendChild(label);
    div.appendChild(select);
    container.appendChild(div);
}

/**
 * Fügt eine Blenden-Einstellung für DSLR-Kameras hinzu
 */
function addDSLRApertureSetting(container, currentValue) {
    const div = document.createElement('div');
    div.className = 'input-field';
    
    const label = document.createElement('label');
    label.textContent = 'Blende';
    
    const select = document.createElement('select');
    select.id = 'aperture_setting';
    select.name = 'aperture_setting';
    
    // Gängige Blendenwerte
    const apertureValues = ['auto', 'f/1.8', 'f/2.0', 'f/2.8', 'f/4.0', 'f/5.6', 'f/8.0', 'f/11', 'f/16', 'f/22'];
    
    apertureValues.forEach(aperture => {
        const option = document.createElement('option');
        option.value = aperture;
        option.textContent = aperture === 'auto' ? 'Automatisch' : aperture;
        if (aperture === currentValue.toString()) {
            option.selected = true;
        }
        select.appendChild(option);
    });
    
    // Event-Listener für Änderungen
    select.addEventListener('change', async function() {
        await updateCameraSetting('aperture', this.value);
    });
    
    div.appendChild(label);
    div.appendChild(select);
    container.appendChild(div);
}

/**
 * Fügt eine Verschlusszeit-Einstellung für DSLR-Kameras hinzu
 */
function addDSLRShutterSpeedSetting(container, currentValue) {
    const div = document.createElement('div');
    div.className = 'input-field';
    
    const label = document.createElement('label');
    label.textContent = 'Verschlusszeit';
    
    const select = document.createElement('select');
    select.id = 'shutter_speed_setting';
    select.name = 'shutter_speed_setting';
    
    // Gängige Verschlusszeiten
    const shutterValues = [
        'auto', '1/4000', '1/2000', '1/1000', '1/500', '1/250', '1/125', 
        '1/60', '1/30', '1/15', '1/8', '1/4', '1/2', '1'
    ];
    
    shutterValues.forEach(shutter => {
        const option = document.createElement('option');
        option.value = shutter;
        option.textContent = shutter === 'auto' ? 'Automatisch' : shutter + 's';
        if (shutter === currentValue.toString()) {
            option.selected = true;
        }
        select.appendChild(option);
    });
    
    // Event-Listener für Änderungen
    select.addEventListener('change', async function() {
        await updateCameraSetting('shutter_speed', this.value);
    });
    
    div.appendChild(label);
    div.appendChild(select);
    container.appendChild(div);
}

/**
 * Aktualisiert eine Kamera-Einstellung über die API
 */
async function updateCameraSetting(settingName, value) {
    try {
        const settings = {};
        settings[settingName] = value;
        
        const response = await fetch('/api/camera/settings', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(settings)
        });
        
        const data = await response.json();
        
        if (data.success) {
            // Vorschau aktualisieren
            updateCameraPreview();
            return true;
        } else {
            showNotification(`Fehler beim Aktualisieren der ${settingName}-Einstellung`, 'error');
            return false;
        }
    } catch (err) {
        error(`Fehler beim Aktualisieren der ${settingName}-Einstellung:`, err);
        return false;
    }
}

/**
 * Initialisiert die Kamera-Vorschau
 */
function initCameraPreview() {
    const previewContainer = document.getElementById('cameraPreviewSettings');
    if (!previewContainer) return;
    
    // Vorschau initial aktualisieren
    updateCameraPreview();
    
    // Event-Handler für Aktualisieren-Button
    const refreshBtn = document.getElementById('refreshPreviewBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', updateCameraPreview);
    }
    
    // Event-Handler für Test-Bild-Button
    const testCaptureBtn = document.getElementById('testCaptureBtn');
    if (testCaptureBtn) {
        testCaptureBtn.addEventListener('click', captureTestImage);
    }
}

/**
 * Aktualisiert die Kamera-Vorschau
 */
function updateCameraPreview() {
    const previewContainer = document.getElementById('cameraPreviewSettings');
    if (!previewContainer) return;
    
    // Vorschau-Container leeren
    previewContainer.innerHTML = 'Lade Vorschau...';
    
    // Neues Vorschaubild erstellen
    const img = document.createElement('img');
    
    // Zufallsparameter hinzufügen, um Cache zu umgehen
    const timestamp = new Date().getTime();
    img.src = `/api/camera/preview?t=${timestamp}`;
    
    img.onerror = function() {
        previewContainer.innerHTML = 'Keine Vorschau verfügbar. Ist die Kamera verbunden?';
    };
    
    img.onload = function() {
        previewContainer.innerHTML = '';
        previewContainer.appendChild(img);
    };
}

/**
 * Nimmt ein Testbild auf und zeigt es an
 */
async function captureTestImage() {
    try {
        showNotification('Testbild wird aufgenommen...', 'info');
        
        const response = await fetch('/api/camera/capture', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ test_image: true })
        });
        
        const data = await response.json();
        
        if (data.success && data.data && data.data.filepath) {
            // Zeige das Bild im Vorschau-Container an
            const previewContainer = document.getElementById('cameraPreviewSettings');
            if (previewContainer) {
                // Container leeren
                previewContainer.innerHTML = '';
                
                // Neues Bild erstellen
                const img = document.createElement('img');
                img.src = data.data.filepath;
                img.className = 'test-capture-image';
                previewContainer.appendChild(img);
                
                // Nach 3 Sekunden zurück zur Live-Vorschau
                setTimeout(() => {
                    updateCameraPreview();
                }, 3000);
            }
            
            showNotification('Testbild erfolgreich aufgenommen', 'success');
        } else {
            showNotification('Fehler bei der Aufnahme des Testbilds', 'error');
        }
    } catch (err) {
        error('Fehler beim Aufnehmen des Testbilds:', err);
        showNotification('Fehler beim Aufnehmen des Testbilds', 'error');
    }
}

// =================================================================================
// Abhängigkeiten-Verwaltung
// =================================================================================

// Button zum Installieren der fehlenden Abhängigkeiten
const fixDependenciesBtn = document.getElementById('fixDependenciesBtn');
if (fixDependenciesBtn) {
    fixDependenciesBtn.addEventListener('click', handleFixDependencies);
}

/**
 * Prüft die Abhängigkeiten und aktualisiert die UI
 * Wird automatisch bei der Initialisierung und nach Updates aufgerufen
 */
async function checkDependenciesAndUpdateUI() {
    const dependenciesStatus = document.getElementById('dependenciesStatus');
    const dependenciesList = document.getElementById('dependenciesList');
    const dependenciesStatusBadge = document.getElementById('dependenciesStatusBadge');
    const systemDependenciesList = document.getElementById('systemDependenciesList');
    const pythonDependenciesList = document.getElementById('pythonDependenciesList');
    const fixDependenciesBtn = document.getElementById('fixDependenciesBtn');
    
    // Wenn eines der Elemente fehlt, früh zurückkehren
    if (!dependenciesStatus || !dependenciesList || !dependenciesStatusBadge || 
        !systemDependenciesList || !pythonDependenciesList || !fixDependenciesBtn) {
        error('Erforderliche DOM-Elemente für Abhängigkeiten-Prüfung nicht gefunden');
        return;
    }
    
    try {
        // Abhängigkeiten-Status anzeigen
        dependenciesStatus.classList.remove('hidden');
        dependenciesStatusBadge.textContent = 'Prüfe...';
        dependenciesStatusBadge.className = 'status-badge';
        
        // Abhängigkeiten prüfen
        const deps = await checkDependencies();
        
        // Status-Badge aktualisieren
        if (deps.all_ok) {
            dependenciesStatusBadge.textContent = 'OK';
            dependenciesStatusBadge.className = 'status-badge status-ok';
            dependenciesList.classList.add('hidden');
            fixDependenciesBtn.classList.add('hidden');
            return; // Früh zurückkehren, wenn alles ok ist
        } else {
            // Es gibt Probleme mit den Abhängigkeiten
            const problemCount = (deps.system.missing.length + deps.system.outdated.length +
                                 deps.python.missing.length + deps.python.outdated.length);
            
            dependenciesStatusBadge.textContent = `${problemCount} Problem${problemCount > 1 ? 'e' : ''}`;
            dependenciesStatusBadge.className = 'status-badge status-warning';
            
            // Listen leeren
            systemDependenciesList.innerHTML = '';
            pythonDependenciesList.innerHTML = '';
            
            // System-Abhängigkeiten anzeigen
            if (deps.system.missing.length > 0 || deps.system.outdated.length > 0) {
                for (const pkg of deps.system.missing) {
                    const li = document.createElement('li');
                    li.className = 'dependency-item dependency-missing';
                    li.textContent = `${pkg} (fehlt)`;
                    systemDependenciesList.appendChild(li);
                }
                
                for (const pkg of deps.system.outdated) {
                    const li = document.createElement('li');
                    li.className = 'dependency-item dependency-outdated';
                    li.textContent = `${pkg} (veraltet)`;
                    systemDependenciesList.appendChild(li);
                }
            } else {
                const li = document.createElement('li');
                li.textContent = 'Alle System-Pakete sind installiert';
                systemDependenciesList.appendChild(li);
            }
            
            // Python-Abhängigkeiten anzeigen
            if (deps.python.missing.length > 0 || deps.python.outdated.length > 0) {
                for (const pkg of deps.python.missing) {
                    const li = document.createElement('li');
                    li.className = 'dependency-item dependency-missing';
                    li.textContent = `${pkg} (fehlt)`;
                    pythonDependenciesList.appendChild(li);
                }
                
                for (const pkg of deps.python.outdated) {
                    const li = document.createElement('li');
                    li.className = 'dependency-item dependency-outdated';
                    li.textContent = `${pkg} (veraltet)`;
                    pythonDependenciesList.appendChild(li);
                }
            } else {
                const li = document.createElement('li');
                li.textContent = 'Alle Python-Module sind installiert';
                pythonDependenciesList.appendChild(li);
            }
            
            // Abhängigkeitsliste und Button anzeigen
            dependenciesList.classList.remove('hidden');
            fixDependenciesBtn.classList.remove('hidden');
        }
    } catch (err) {
        error('Fehler bei der Abhängigkeiten-Prüfung', err);
        dependenciesStatusBadge.textContent = 'Fehler';
        dependenciesStatusBadge.className = 'status-badge status-error';
        
        // Fehlermeldung anzeigen
        systemDependenciesList.innerHTML = '';
        pythonDependenciesList.innerHTML = '';
        
        const li = document.createElement('li');
        li.className = 'dependency-item dependency-missing';
        li.textContent = `Fehler bei der Abhängigkeitsprüfung: ${err.message || 'Unbekannter Fehler'}`;
        systemDependenciesList.appendChild(li);
        
        // Listen anzeigen, Button verstecken
        dependenciesList.classList.remove('hidden');
        fixDependenciesBtn.classList.add('hidden');
    }
}

/**
 * Handler für den Button zum Installieren fehlender Abhängigkeiten
 */
async function handleFixDependencies() {
    const dependenciesStatusBadge = document.getElementById('dependenciesStatusBadge');
    const fixDependenciesBtn = document.getElementById('fixDependenciesBtn');
    
    if (!dependenciesStatusBadge || !fixDependenciesBtn) {
        error('Erforderliche DOM-Elemente für Abhängigkeiten-Installation nicht gefunden');
        return;
    }
    
    try {
        // Button deaktivieren und Status aktualisieren
        fixDependenciesBtn.disabled = true;
        dependenciesStatusBadge.textContent = 'Installiere...';
        dependenciesStatusBadge.className = 'status-badge';
        
        // Bestätigungsdialog anzeigen
        if (!await showDialog('Abhängigkeiten installieren', 
                              'Dies kann einige Minuten dauern und erfordert möglicherweise Root-Rechte. Fortfahren?', 
                              'Installieren', 'Abbrechen')) {
            fixDependenciesBtn.disabled = false;
            return;
        }
        
        // Abhängigkeiten installieren
        await installDependencies();
        
        // Erfolgsmeldung
        showNotification('Abhängigkeiten wurden installiert', 'success');
        
        // Nach kurzer Verzögerung erneut prüfen
        setTimeout(() => {
            checkDependenciesAndUpdateUI();
            fixDependenciesBtn.disabled = false;
        }, 2000);
    } catch (err) {
        error('Fehler bei der Installation der Abhängigkeiten', err);
        
        dependenciesStatusBadge.textContent = 'Fehler';
        dependenciesStatusBadge.className = 'status-badge status-error';
        
        showNotification(`Fehler: ${err.message || 'Unbekannter Fehler'}`, 'error');
        
        fixDependenciesBtn.disabled = false;
    }
}

// =================================================================================
// System-Update-Funktionen
// =================================================================================

/**
 * Globale Variablen für Update-Funktionalität
 */
let updateInProgress = false;

// Button zum Prüfen auf Updates - mit Nullprüfung
const checkUpdateBtn = document.getElementById('checkUpdateBtn');
if (checkUpdateBtn) {
    checkUpdateBtn.addEventListener('click', handleUpdateCheck);
}

// Button zum Installieren des Updates - mit Nullprüfung
const installUpdateBtn = document.getElementById('installUpdateBtn');
if (installUpdateBtn) {
    installUpdateBtn.addEventListener('click', handleUpdateInstall);
}

/**
 * Handler für den Update-Check-Button
 */
async function handleUpdateCheck() {
    // UI-Elemente
    const updateStatus = document.getElementById('updateStatus');
    const updateActions = document.getElementById('updateActions');
    const versionStatusText = document.getElementById('versionStatusText');
    
    if (!updateStatus || !updateActions || !checkUpdateBtn || !versionStatusText) {
        error('Erforderliche DOM-Elemente für Update-Prüfung nicht gefunden');
        return;
    }
    
    // Status auf "prüfe" setzen
    versionStatusText.textContent = '/ Suche nach Updates';
    versionStatusText.className = 'update-checking';
    updateStatus.classList.add('hidden');
    updateActions.classList.add('hidden');
    checkUpdateBtn.disabled = true;
    
    try {
        // Nutze das manage_update Modul für die Updateprüfung
        const updateInfo = await throttledCheckForUpdates();
        const versionInfo = getVersionInfo();
        
        // Aktuelle Version anzeigen
        document.querySelector('#currentVersion .version-number').textContent = versionInfo.current;
        
        // Abhängigkeiten prüfen
        checkDependenciesAndUpdateUI().catch(err => {
            error('Fehler bei der automatischen Abhängigkeitsprüfung', err);
        });
        
        if (updateInfo) {
            // Update verfügbar
            versionStatusText.textContent = `/ Online verfügbar ${updateInfo.version}`;
            versionStatusText.className = 'update-available';
            
            // Update-Version anzeigen
            document.querySelector('#availableVersion .version-number').textContent = updateInfo.version;
            
            // Update-Button aktivieren und anzeigen
            checkUpdateBtn.disabled = false;
            updateActions.classList.remove('hidden');
        } else {
            // Kein Update verfügbar
            versionStatusText.textContent = '/ Auf dem neuesten Stand';
            versionStatusText.className = 'update-up-to-date';
            checkUpdateBtn.disabled = true;
        }
    } catch (err) {
        error('Update-Prüfungs-Fehler:', err);
        versionStatusText.textContent = '/ Fehler bei der Update-Prüfung';
        versionStatusText.className = 'update-error';
        checkUpdateBtn.disabled = false;
    }
}

/**
 * Handler für das Installieren von Updates
 */
async function handleUpdateInstall() {
    if (updateInProgress) return;
    
    const updateStatus = document.getElementById('updateStatus');
    const updateActions = document.getElementById('updateActions');
    const updateProgress = document.getElementById('updateProgress');
    const updateProgressBar = document.getElementById('updateProgressBar');
    const updateProgressText = document.getElementById('updateProgressText');
    const versionStatusText = document.getElementById('versionStatusText');
    
    updateInProgress = true;
    
    // Update-Status anzeigen
    versionStatusText.textContent = '/ Aktualisiere System';
    versionStatusText.className = 'update-installing';
    updateActions.classList.add('hidden');
    updateProgress.classList.remove('hidden');
    
    try {
        // Fortschrittsbalken auf 0% setzen
        updateProgressBar.style.width = '0%';
        updateProgressText.textContent = 'Update wird vorbereitet...';
        
        // Update starten mit dem manage_update Modul
        await installUpdate();
        
        // Fortschrittsanzeige aktualisieren mit regelmäßigen Abfragen
        const statusUpdateInterval = setInterval(async () => {
            try {
                const status = await getUpdateStatus();
                
                // Fortschrittsbalken aktualisieren
                updateProgressBar.style.width = `${status.progress}%`;
                updateProgressText.textContent = status.message;
                
                // Wenn fertig oder Fehler aufgetreten, Interval beenden
                if (status.status === 'idle' || status.status === 'error' || status.progress >= 100) {
                    clearInterval(statusUpdateInterval);
                    
                    if (status.status === 'error') {
                        versionStatusText.textContent = '/ Fehler bei der Update-Installation';
                        versionStatusText.className = 'update-error';
                        updateProgressText.textContent = status.message;
                    } else if (status.progress >= 100) {
                        updateProgressText.textContent = 'Update abgeschlossen!';
                        // Nach 3 Sekunden ausblenden
                        setTimeout(() => {
                            updateProgress.classList.add('hidden');
                            // Erneut auf Updates prüfen
                            handleUpdateCheck();
                        }, 3000);
                    }
                    
                    updateInProgress = false;
                }
            } catch (err) {
                error('Fehler beim Abrufen des Update-Status', err);
            }
        }, 1000);
    } catch (err) {
        error('Update-Installations-Fehler:', err);
        versionStatusText.textContent = '/ Fehler bei der Update-Installation';
        versionStatusText.className = 'update-error';
        updateProgress.classList.add('hidden');
        updateProgressBar.style.width = '0%';
        updateInProgress = false;
    }
}

// =================================================================================
// Hilfs- und Initialisierungsfunktionen
// =================================================================================

/**
 * Event-Listener für die Seite, wenn das DOM vollständig geladen wurde
 */
document.addEventListener('DOMContentLoaded', function() {
    // Prüfen, ob bereits eingeloggt (für Reload-Fälle)
    checkLoginStatus();
    
    // Passwort-Validierung hinzufügen
    setupPasswordValidation();
});

/**
 * Prüft den Login-Status und zeigt das entsprechende Formular
 */
async function checkLoginStatus() {
    try {
        const response = await fetch('/api/session-check');
        if (response.ok) {
            const data = await response.json();
            
            if (data.authenticated) {
                // Bereits eingeloggt, Konfigurationsformular anzeigen
                document.getElementById('loginForm').classList.add('hidden');                document.getElementById('configForm').classList.add('form-visible');
                  // Einstellungen laden
                loadSettingsAndUpdateUI().then(() => {
                    if (typeof initLiveSettingsUpdate === 'function') {
                        initLiveSettingsUpdate();
                    }                // Nach dem Laden der Einstellungen automatisch nach Updates suchen
                    handleUpdateCheck();
                });
            }
        }
    } catch (error) {
        console.error('Fehler beim Prüfen des Login-Status:', error);
    }
}

/**
 * Setzt den Titel im Header
 */
function setHeaderTitle(title) {
    const headerTitle = document.getElementById('headerTitle');
    if (headerTitle) {
        headerTitle.textContent = title || 'Fotobox';
    }
}

/**
 * Richtet die Passwortvalidierung ein
 */
function setupPasswordValidation() {
    const newPassword = document.getElementById('new_password');
    const confirmPassword = document.getElementById('confirm_password');
    const statusElement = document.getElementById('password-match-status');
    
    // Funktion zum Überprüfen der Übereinstimmung
    function checkPasswordMatch() {
        if (newPassword.value === '' && confirmPassword.value === '') {
            statusElement.textContent = '';
            statusElement.className = '';
            return true;
        }
        
        if (newPassword.value.length < 4 && newPassword.value !== '') {
            statusElement.textContent = 'Passwort muss mindestens 4 Zeichen lang sein.';
            statusElement.className = 'password-mismatch';
            return false;
        }
        
        if (newPassword.value === confirmPassword.value) {
            if (newPassword.value !== '') {
                statusElement.textContent = 'Passwörter stimmen überein.';
                statusElement.className = 'password-match';
            } else {
                statusElement.textContent = '';
                statusElement.className = '';
            }
            return true;
        } else {
            statusElement.textContent = 'Passwörter stimmen nicht überein.';
            statusElement.className = 'password-mismatch';
            return false;
        }
    }
    
    // Event-Listener für beide Passwortfelder
    newPassword.addEventListener('input', checkPasswordMatch);
    confirmPassword.addEventListener('input', checkPasswordMatch);
    
    // Passwortfelder beim Laden überprüfen
    checkPasswordMatch();
}
