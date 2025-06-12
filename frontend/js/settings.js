// filepath: c:\Users\HP 800 G1\OneDrive\Dokumente\Götze Dirk\Eigene Projekte\fotobox2\frontend\js\settings.js
// ------------------------------------------------------------------------------
// settings.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Einstellungsseite der Fotobox (settings.html) mit
// Login-System, Formular-Validierung und API-Kommunikation zur Konfiguration
// ------------------------------------------------------------------------------

// Importiere Systemmodule
import { throttledCheckForUpdates, installUpdate, getUpdateStatus, getVersionInfo } from './manage_update.js';
import { log, error } from './manage_logging.js';
import { showNotification, showDialog } from './ui_components.js';
import { login, validatePassword, changePassword } from './manage_auth.js';

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
            document.getElementById('loginForm').classList.add('hidden');
            document.getElementById('configForm').classList.add('form-visible');
            
            // Einstellungen laden
            loadSettings().then(() => {
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
 * Einstellungen aus der Datenbank laden
 */
async function loadSettings() {
    try {
        const response = await fetch('/api/settings');
        if (response.ok) {
            const settings = await response.json();
            
            // Event-Name setzen (wenn vorhanden)
            if (document.getElementById('event_name')) {
                document.getElementById('event_name').value = settings.event_name || '';
                // Aktualisiere auch den Header-Titel
                setHeaderTitle(settings.event_name);
            }
              // Event-Datum setzen (wenn vorhanden)
            if (settings.event_date && document.getElementById('event_date')) {
                document.getElementById('event_date').value = settings.event_date;
            }                // Nach dem Laden der Einstellungen automatisch nach Updates suchen
                    setTimeout(() => {
                        // Verzögerte Ausführung, um UI-Updates zu ermöglichen
                        handleUpdateCheck();
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
                document.getElementById('camera_id').value = settings.camera_id || 'system';
            }
            
            if (document.getElementById('flash_mode')) {
                document.getElementById('flash_mode').value = settings.flash_mode || 'system';
            }
            
            // Verfügbare Kameras laden und Dropdown aktualisieren
            loadAvailableCameras();
        }
    } catch (error) {
        console.error('Fehler beim Laden der Einstellungen:', error);
    }
}

/**
 * Verfügbare Kameras laden und im Dropdown anzeigen
 */
async function loadAvailableCameras() {
    try {
        const response = await fetch('/api/cameras');
        if (response.ok) {
            const cameras = await response.json();
            const cameraSelect = document.getElementById('camera_id');
            
            // Bestehende Optionen außer "auto" entfernen
            Array.from(cameraSelect.options).forEach(option => {
                if (option.value !== 'auto') {
                    cameraSelect.removeChild(option);
                }
            });
            
            // Neue Kamera-Optionen hinzufügen
            cameras.forEach(camera => {
                const option = document.createElement('option');
                option.value = camera.id;
                option.textContent = camera.name;
                cameraSelect.appendChild(option);
            });
        }
    } catch (error) {
        console.error('Fehler beim Laden der Kameras:', error);
    }
}

/**
 * Die initFancyInputs Funktion wurde entfernt, da Labels jetzt permanent
 * oberhalb der Eingabefelder angezeigt werden.
 */

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
                document.getElementById('loginForm').classList.add('hidden');
                document.getElementById('configForm').classList.add('form-visible');
                  // Einstellungen laden
                loadSettings().then(() => {
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
