// filepath: c:\Users\HP 800 G1\OneDrive\Dokumente\Götze Dirk\Eigene Projekte\fotobox2\frontend\js\settings.js
// ------------------------------------------------------------------------------
// settings.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Einstellungsseite der Fotobox (settings.html) mit
// Login-System, Formular-Validierung und API-Kommunikation zur Konfiguration
// ------------------------------------------------------------------------------

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
        const response = await fetch('/api/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ password: password })
        });
        
        if (response.ok) {            // Login erfolgreich
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
            }
            
            // Nach dem Laden der Einstellungen automatisch nach Updates suchen
            setTimeout(() => {
                // Verzögerte Ausführung, um UI-Updates zu ermöglichen
                checkForUpdates();
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
let remoteVersion = null;
let localVersion = null;

// Button zum Prüfen auf Updates
document.getElementById('checkUpdateBtn').addEventListener('click', checkForUpdates);

// Button zum Installieren des Updates
document.getElementById('installUpdateBtn').addEventListener('click', installUpdate);

/**
 * Prüft, ob Updates verfügbar sind
 */
async function checkForUpdates() {
    const updateStatus = document.getElementById('updateStatus');
    const updateActions = document.getElementById('updateActions');
    const checkUpdateBtn = document.getElementById('checkUpdateBtn');
    const versionStatusText = document.getElementById('versionStatusText');
    
    // Status auf "prüfe" setzen
    versionStatusText.textContent = '/ Suche nach Updates';
    versionStatusText.className = 'update-checking';
    updateStatus.classList.add('hidden');
    updateActions.classList.add('hidden');
    checkUpdateBtn.disabled = true;
    
    try {
        const response = await fetch('/api/update');
        if (!response.ok) throw new Error('Fehler bei der Update-Prüfung');
        
        const data = await response.json();
        localVersion = data.local_version;
        remoteVersion = data.remote_version;
        
        // Aktuelle Version anzeigen
        document.querySelector('#currentVersion .version-number').textContent = localVersion;
        
        if (data.update_available) {
            // Update verfügbar
            versionStatusText.textContent = `/ Online verfügbar ${remoteVersion}`;
            versionStatusText.className = 'update-available';
            
            // Update-Version anzeigen
            document.querySelector('#availableVersion .version-number').textContent = remoteVersion;
            
            // Update-Button aktivieren und anzeigen
            checkUpdateBtn.disabled = false;
            updateActions.classList.remove('hidden');
        } else {
            // Kein Update verfügbar
            versionStatusText.textContent = '/ Auf dem neuesten Stand';
            versionStatusText.className = 'update-up-to-date';
            checkUpdateBtn.disabled = true;
        }
    } catch (error) {
        console.error('Update-Prüfungs-Fehler:', error);
        versionStatusText.textContent = '/ Fehler bei der Update-Prüfung';
        versionStatusText.className = 'update-error';
        checkUpdateBtn.disabled = false;
    }
}

/**
 * Installiert das verfügbare Update
 */
async function installUpdate() {
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
        
        // Update starten
        const response = await fetch('/api/update', { 
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ from_version: localVersion, to_version: remoteVersion })
        });
        
        if (!response.ok) throw new Error('Installation fehlgeschlagen');
        
        // Fortschrittsbalken auf 30%
        updateProgressBar.style.width = '30%';
        updateProgressText.textContent = 'Dateien werden heruntergeladen...';
        
        // In der Praxis würde hier ein Polling für den Fortschritt erfolgen
        // Für diese Demo simulieren wir den Fortschritt
        setTimeout(() => {
            updateProgressBar.style.width = '60%';
            updateProgressText.textContent = 'Anwendung wird aktualisiert...';
        }, 2000);
        
        setTimeout(() => {
            updateProgressBar.style.width = '90%';
            updateProgressText.textContent = 'Fast fertig...';
        }, 4000);
        
        setTimeout(() => {
            // Update abgeschlossen
            updateProgressBar.style.width = '100%';
            updateProgressText.textContent = 'Update abgeschlossen!';
            
            // Nach dem Update erneut auf Updates prüfen
            setTimeout(() => {
                updateProgressBar.style.width = '0%';
                updateProgress.classList.add('hidden');
                updateInProgress = false;
                
                // Prüfen, ob das Update erfolgreich war
                checkForUpdates();
            }, 3000);
        }, 6000);
    } catch (error) {
        console.error('Update-Installations-Fehler:', error);
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
                    }
                    // Nach dem Laden der Einstellungen automatisch nach Updates suchen
                    checkForUpdates();
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
