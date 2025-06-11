// ------------------------------------------------------------------------------
// settings.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Einstellungsseite der Fotobox (settings.html) mit
// Login-System, Formular-Validierung und API-Kommunikation zur Konfiguration
// ------------------------------------------------------------------------------

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
            loadSettings();        } else {
            status.textContent = 'Falsches Passwort';
            status.className = 'status-error';
        }
    } catch (error) {
        status.textContent = 'Verbindungsfehler';
        status.className = 'status-error';
        console.error('Login-Fehler:', error);
    }
};

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
        }    } catch (error) {
        console.error('Fehler beim Laden der Kameras:', error);
    }
}

/**
 * Initialisiert die schwebenden Labels für alle Fancy-Inputs
 * - Labels werden als Platzhalter behandelt, wenn das Feld leer ist
 * - Labels schweben nach oben, wenn das Feld fokussiert ist oder Text enthält
 */
function initFancyInputs() {
    const fancyInputs = document.querySelectorAll('.fancy-input');
    
    fancyInputs.forEach(container => {
        const input = container.querySelector('input, select');
        const label = container.querySelector('label');
        
        if (!input || !label) return;
        
        // Anfangszustand: Wenn das Input leer ist, zeige Label als Platzhalter
        if (input.value === '') {
            label.classList.add('like-placeholder');
        }
        
        // Focus-Event: Label nach oben bewegen
        input.addEventListener('focus', () => {
            label.classList.remove('like-placeholder');
        });
        
        // Blur-Event: Label zurücksetzen, wenn Input leer ist
        input.addEventListener('blur', () => {
            if (input.value === '') {
                label.classList.add('like-placeholder');
            }
        });
        
        // Input-Event: Label korrekt platzieren, wenn Wert sich ändert
        input.addEventListener('input', () => {
            if (input.value === '') {
                if (!document.activeElement === input) {
                    label.classList.add('like-placeholder');
                }
            } else {
                label.classList.remove('like-placeholder');
            }
        });
    });
}

// Nach dem Laden der Seite und nach dem Laden der Einstellungen die Fancy-Inputs initialisieren
document.addEventListener('DOMContentLoaded', initFancyInputs);

// Auch nach dem Laden der Einstellungen die Inputs neu initialisieren
const originalLoadSettings = loadSettings;
loadSettings = function() {
    originalLoadSettings();
    // Wir warten kurz, damit die Werte in die Felder geladen werden können
    setTimeout(initFancyInputs, 100);
};
