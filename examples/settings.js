/**
 * @file settings.js
 * @description Seitenspezifischer Code für die Einstellungsseite
 */

// Importiere Systemmodule
import { loadSettings, updateSingleSetting, validateSettings } from './manage_settings.js';
import { checkForUpdates, installUpdate, getUpdateStatus } from './manage_update.js';
import { setupPasswordValidation, changePassword } from './manage_auth.js';
import { showNotification, showDialog } from './ui_components.js';
import { log, error } from './manage_logging.js';

// DOM-Elemente
const settingsForm = document.getElementById('settings-form');
const updateButton = document.getElementById('check-update-btn');
const installUpdateButton = document.getElementById('install-update-btn');
const passwordSection = document.getElementById('password-section');
const saveButton = document.getElementById('save-settings-btn');

/**
 * Initialisiert die Einstellungs-UI
 */
async function initSettingsUI() {
    try {
        // Einstellungen vom Backend laden
        const settings = await loadSettings();
        
        // UI mit den geladenen Einstellungen füllen
        populateSettingsForm(settings);
        
        // Event-Listener einrichten
        bindSettingsEvents();
        
        log('Einstellungs-UI initialisiert');
    } catch (err) {
        error('Fehler bei der Initialisierung der Einstellungs-UI', err);
        showNotification('Fehler beim Laden der Einstellungen', 'error');
    }
}

/**
 * Befüllt das Einstellungsformular mit den geladenen Daten
 * @param {Object} settings - Die geladenen Einstellungen
 */
function populateSettingsForm(settings) {
    // Durchlaufe alle Formularfelder und setze die Werte
    for (const field of settingsForm.elements) {
        if (field.name && settings[field.name] !== undefined) {
            if (field.type === 'checkbox') {
                field.checked = Boolean(settings[field.name]);
            } else {
                field.value = settings[field.name];
            }
        }
    }
    
    // Zusätzliche UI-Anpassungen basierend auf den Einstellungen
    updateUIBasedOnSettings(settings);
}

/**
 * Passt die UI basierend auf den geladenen Einstellungen an
 * @param {Object} settings - Die geladenen Einstellungen
 */
function updateUIBasedOnSettings(settings) {
    // Beispiel: Verstecke oder zeige bestimmte Sektionen basierend auf Einstellungen
    if (settings.enablePasswordProtection) {
        passwordSection.classList.remove('hidden');
    } else {
        passwordSection.classList.add('hidden');
    }
    
    // Weitere UI-Anpassungen je nach Bedarf
}

/**
 * Bindet Event-Listener an UI-Elemente
 */
function bindSettingsEvents() {
    // Update-Button
    updateButton.addEventListener('click', async (event) => {
        event.preventDefault();
        await handleUpdateCheck();
    });
    
    // Install-Update-Button
    installUpdateButton.addEventListener('click', async (event) => {
        event.preventDefault();
        await handleUpdateInstallation();
    });
    
    // Passwort-Validierung einrichten
    setupPasswordValidation(
        document.getElementById('current-password'),
        document.getElementById('new-password'),
        document.getElementById('confirm-password')
    );
    
    // Live-Validierung der Formularfelder
    for (const field of settingsForm.elements) {
        if (field.name) {
            field.addEventListener('change', (event) => {
                validateFieldAndUpdateUI(field);
            });
        }
    }
    
    // Speichern-Button
    saveButton.addEventListener('click', async (event) => {
        event.preventDefault();
        await handleSaveSettings();
    });
}

/**
 * Verarbeitet den Klick auf den Update-Check-Button
 */
async function handleUpdateCheck() {
    try {
        // Deaktiviere Button während der Prüfung
        updateButton.disabled = true;
        updateButton.textContent = 'Prüfe...';
        
        // Auf Updates prüfen (aus manage_update.js)
        const updateInfo = await checkForUpdates();
        
        if (updateInfo) {
            // Update verfügbar
            showNotification(`Update auf Version ${updateInfo.version} verfügbar`, 'info');
            installUpdateButton.classList.remove('hidden');
            
            // Zeige Dialog mit Updatedetails
            showUpdateDetailsDialog(updateInfo);
        } else {
            // Kein Update verfügbar
            showNotification('Das System ist bereits auf dem neuesten Stand', 'success');
            installUpdateButton.classList.add('hidden');
        }
    } catch (err) {
        error('Fehler bei der Update-Prüfung', err);
        showNotification('Fehler bei der Update-Prüfung: ' + err.message, 'error');
    } finally {
        // Button zurücksetzen
        updateButton.disabled = false;
        updateButton.textContent = 'Auf Updates prüfen';
    }
}

/**
 * Zeigt einen Dialog mit Update-Details an
 * @param {Object} updateInfo - Informationen zum Update
 */
function showUpdateDetailsDialog(updateInfo) {
    const changesList = updateInfo.changes.map(change => `<li>${change}</li>`).join('');
    
    showDialog({
        title: `Update auf Version ${updateInfo.version}`,
        content: `
            <p>Veröffentlicht am: ${new Date(updateInfo.releaseDate).toLocaleDateString()}</p>
            <p>Größe: ${formatBytes(updateInfo.size)}</p>
            <h4>Änderungen:</h4>
            <ul>${changesList}</ul>
            ${updateInfo.critical ? '<p class="critical-update">Dies ist ein kritisches Update!</p>' : ''}
        `,
        buttons: [
            {
                text: 'Später',
                action: 'close'
            },
            {
                text: 'Jetzt installieren',
                action: () => handleUpdateInstallation(),
                primary: true
            }
        ]
    });
}

/**
 * Verarbeitet die Installation eines Updates
 */
async function handleUpdateInstallation() {
    try {
        // Dialog anzeigen
        const confirmResult = await showDialog({
            title: 'Update installieren',
            content: 'Möchten Sie das Update jetzt installieren? Das System wird während der Installation neu gestartet.',
            buttons: [
                {
                    text: 'Abbrechen',
                    action: 'close'
                },
                {
                    text: 'Installieren',
                    action: 'confirm',
                    primary: true
                }
            ]
        });
        
        if (confirmResult !== 'confirm') {
            return;
        }
        
        // Installiere Update (aus manage_update.js)
        await installUpdate();
        
        // Zeige Fortschritt an
        showUpdateProgressDialog();
        
    } catch (err) {
        error('Fehler bei der Update-Installation', err);
        showNotification('Fehler bei der Update-Installation: ' + err.message, 'error');
    }
}

/**
 * Zeigt einen Dialog mit dem Update-Fortschritt an
 */
function showUpdateProgressDialog() {
    const dialogContent = document.createElement('div');
    dialogContent.innerHTML = `
        <div class="progress-container">
            <div class="progress-bar" id="update-progress-bar" style="width: 0%"></div>
        </div>
        <p id="update-status-message">Starte Update-Prozess...</p>
    `;
    
    showDialog({
        title: 'Update wird installiert',
        content: dialogContent,
        closable: false
    });
    
    // Starte Polling für Update-Status
    const progressBar = document.getElementById('update-progress-bar');
    const statusMessage = document.getElementById('update-status-message');
    
    const statusInterval = setInterval(async () => {
        try {
            const status = await getUpdateStatus();
            
            progressBar.style.width = `${status.progress}%`;
            statusMessage.textContent = status.message;
            
            if (status.status === 'error') {
                clearInterval(statusInterval);
                showNotification('Fehler beim Update: ' + status.message, 'error');
                // Dialog schließen
                document.querySelector('.dialog-close-btn').click();
            } else if (status.status === 'idle' && status.progress === 100) {
                clearInterval(statusInterval);
                showNotification('Update erfolgreich installiert. Seite wird neu geladen...', 'success');
                setTimeout(() => {
                    window.location.reload();
                }, 3000);
            }
        } catch (err) {
            error('Fehler beim Abrufen des Update-Status', err);
        }
    }, 1000);
}

/**
 * Validiert ein Formularfeld und aktualisiert die UI entsprechend
 * @param {HTMLElement} field - Das zu validierende Formularfeld
 */
function validateFieldAndUpdateUI(field) {
    // Basisvalidierung
    let isValid = field.checkValidity();
    let errorMessage = field.validationMessage;
    
    // Erweiterte Validierung für bestimmte Felder
    if (isValid && field.dataset.customValidation) {
        const validationName = field.dataset.customValidation;
        
        switch (validationName) {
            case 'email':
                isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(field.value);
                if (!isValid) errorMessage = 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                break;
            case 'password':
                isValid = field.value.length >= 8;
                if (!isValid) errorMessage = 'Das Passwort muss mindestens 8 Zeichen lang sein';
                break;
            // Weitere benutzerdefinierte Validierungen...
        }
    }
    
    // UI aktualisieren
    const fieldContainer = field.closest('.form-field');
    const errorDisplay = fieldContainer.querySelector('.field-error');
    
    if (isValid) {
        field.classList.remove('invalid');
        field.classList.add('valid');
        if (errorDisplay) {
            errorDisplay.textContent = '';
            errorDisplay.classList.add('hidden');
        }
    } else {
        field.classList.remove('valid');
        field.classList.add('invalid');
        if (errorDisplay) {
            errorDisplay.textContent = errorMessage;
            errorDisplay.classList.remove('hidden');
        }
    }
    
    return isValid;
}

/**
 * Verarbeitet das Speichern der Einstellungen
 */
async function handleSaveSettings() {
    try {
        // Alle Felder validieren
        let isFormValid = true;
        
        for (const field of settingsForm.elements) {
            if (field.name) {
                const isFieldValid = validateFieldAndUpdateUI(field);
                isFormValid = isFormValid && isFieldValid;
            }
        }
        
        if (!isFormValid) {
            showNotification('Bitte korrigieren Sie die markierten Felder', 'warn');
            return;
        }
        
        // Sammle Formular-Daten
        const formData = new FormData(settingsForm);
        const settings = {};
        
        for (const [key, value] of formData.entries()) {
            // Checkbox-Werte in Booleans umwandeln
            const field = settingsForm.elements[key];
            if (field && field.type === 'checkbox') {
                settings[key] = field.checked;
            } else {
                settings[key] = value;
            }
        }
        
        // Validiere gesammelte Einstellungen
        const validationResult = await validateSettings(settings);
        
        if (!validationResult.isValid) {
            showNotification(validationResult.message || 'Ungültige Einstellungen', 'error');
            
            // Fehlerhafte Felder markieren
            for (const fieldName of validationResult.invalidFields || []) {
                const field = settingsForm.elements[fieldName];
                if (field) {
                    field.classList.add('invalid');
                    
                    const fieldContainer = field.closest('.form-field');
                    const errorDisplay = fieldContainer.querySelector('.field-error');
                    
                    if (errorDisplay) {
                        errorDisplay.textContent = validationResult.fieldErrors[fieldName] || 'Ungültiger Wert';
                        errorDisplay.classList.remove('hidden');
                    }
                }
            }
            
            return;
        }
        
        // Speichere Passwortänderungen separat
        if (settings.newPassword) {
            const passwordResult = await changePassword(
                settings.currentPassword,
                settings.newPassword
            );
            
            if (!passwordResult.success) {
                showNotification(passwordResult.message || 'Fehler beim Ändern des Passworts', 'error');
                return;
            }
            
            // Entferne Passwortfelder aus den zu speichernden Einstellungen
            delete settings.currentPassword;
            delete settings.newPassword;
            delete settings.confirmPassword;
        }
        
        // Speichere alle Einstellungen
        for (const [key, value] of Object.entries(settings)) {
            await updateSingleSetting(key, value);
        }
        
        showNotification('Einstellungen erfolgreich gespeichert', 'success');
        
    } catch (err) {
        error('Fehler beim Speichern der Einstellungen', err);
        showNotification('Fehler beim Speichern der Einstellungen: ' + err.message, 'error');
    }
}

/**
 * Formatiert Bytes in lesbare Größenangabe
 * @param {number} bytes - Anzahl der Bytes
 * @returns {string} Formatierte Größenangabe
 */
function formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Initialisiere die Seite beim Laden
document.addEventListener('DOMContentLoaded', initSettingsUI);
