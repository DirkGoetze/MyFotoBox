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

/**
 * Event-Handler für das Speichern der Einstellungen
 */
document.getElementById('configForm').onsubmit = async function(e) {
    e.preventDefault();
    
    // Statusanzeige erstellen, wenn nicht vorhanden
    let statusDiv = document.getElementById('configStatus');
    if (!statusDiv) {
        statusDiv = document.createElement('div');
        statusDiv.id = 'configStatus';
        statusDiv.style.margin = '1em 0';
        statusDiv.style.padding = '0.5em 1em';
        statusDiv.style.borderRadius = '4px';
        this.querySelector('.form-actions').after(statusDiv);
    }
    
    try {
        // Einstellungen sammeln
        const settings = {
            event_name: document.getElementById('event_name').value,
            event_date: document.getElementById('event_date').value,
            color_mode: document.getElementById('color_mode').value,
            countdown_duration: parseInt(document.getElementById('countdown_duration').value, 10),
            camera_id: document.getElementById('camera_id').value,
            flash_mode: document.getElementById('flash_mode').value
        };
        
        // Optional: Passwort ändern, wenn angegeben
        const newPassword = document.getElementById('new_password').value;
        if (newPassword.length > 0) {
            if (newPassword.length < 4) {
                statusDiv.textContent = 'Neues Passwort zu kurz (mind. 4 Zeichen)';
                statusDiv.style.backgroundColor = '#ffdddd';
                statusDiv.style.color = '#c00';
                return;
            }
            settings.admin_password = newPassword;
        }
        
        // Einstellungen an API senden
        const response = await fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(settings)
        });
        
        if (response.ok) {
            statusDiv.textContent = 'Einstellungen erfolgreich gespeichert!';
            statusDiv.style.backgroundColor = '#ddffdd';
            statusDiv.style.color = '#080';
            
            // Header-Titel aktualisieren
            setHeaderTitle(settings.event_name);
        } else {
            statusDiv.textContent = 'Fehler beim Speichern der Einstellungen';
            statusDiv.style.backgroundColor = '#ffdddd';
            statusDiv.style.color = '#c00';
        }
    } catch (error) {
        statusDiv.textContent = 'Verbindungsfehler beim Speichern';
        statusDiv.style.backgroundColor = '#ffdddd';
        statusDiv.style.color = '#c00';
        console.error('Speichern-Fehler:', error);
    }
};

// =================================================================================
// Daten laden und Reset-Funktionen
// =================================================================================

/**
 * Reset-Button Funktionalität
 */
document.getElementById('reset_config').onclick = function() {
    if (confirm('Einstellungen auf Standardwerte zurücksetzen?')) {
        loadSettings();
    }
};

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
            
            // Farbmodus setzen
            if (document.getElementById('color_mode')) {
                document.getElementById('color_mode').value = settings.color_mode || 'auto';
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
    
    // Status auf "prüfe" setzen
    updateStatus.textContent = 'Prüfe auf Updates...';
    updateStatus.className = 'update-status status-checking';
    updateStatus.classList.remove('hidden');
    updateActions.classList.add('hidden');
    
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
            updateStatus.textContent = `Update auf Version ${remoteVersion} verfügbar`;
            updateStatus.className = 'update-status status-update-available';
            
            // Update-Version anzeigen
            document.querySelector('#availableVersion .version-number').textContent = remoteVersion;
            
            // Update-Button anzeigen
            updateActions.classList.remove('hidden');
        } else {
            // Kein Update verfügbar
            updateStatus.textContent = 'Die Fotobox ist auf dem neuesten Stand';
            updateStatus.className = 'update-status status-up-to-date';
        }
    } catch (error) {
        console.error('Update-Prüfungs-Fehler:', error);
        updateStatus.textContent = 'Fehler bei der Update-Prüfung';
        updateStatus.className = 'update-status status-error';
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
    
    updateInProgress = true;
    
    // Update-Status anzeigen
    updateStatus.textContent = 'Update wird installiert...';
    updateStatus.className = 'update-status status-installing';
    updateActions.classList.add('hidden');
    updateProgress.classList.remove('hidden');
    
    try {
        // Fortschrittsbalken auf 0% setzen
        updateProgressBar.style.width = '0%';
        updateProgressText.textContent = 'Update wird vorbereitet...';
        
        // Update starten
        const response = await fetch('/api/update/install', { 
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
            
            updateStatus.textContent = 'Update erfolgreich installiert! Die Anwendung wird in Kürze neu geladen...';
            updateStatus.className = 'update-status status-success';
            
            // Seite nach 3 Sekunden neu laden
            setTimeout(() => {
                window.location.reload();
            }, 3000);
        }, 6000);
    } catch (error) {
        console.error('Update-Installations-Fehler:', error);
        updateStatus.textContent = 'Fehler bei der Update-Installation';
        updateStatus.className = 'update-status status-error';
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
