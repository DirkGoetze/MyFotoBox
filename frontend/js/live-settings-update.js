// ----------------------------------------------------------------------------------
// live-settings-update.js
// ----------------------------------------------------------------------------------
// Bietet Funktionalität für sofortige Einstellungsaktualisierung nach dem Ändern
// eines Felds, anstatt auf das Absenden des gesamten Formulars zu warten.
// ----------------------------------------------------------------------------------

// Globale Variablen für die sofortige Einstellungsübernahme
const fieldOriginalValues = new Map(); // Speichert die ursprünglichen Werte der Felder
let notificationTimeouts = new Map(); // Map für Timeouts zum automatischen Ausblenden von Benachrichtigungen
let notificationCounter = 0; // Zähler für eindeutige Benachrichtigungs-IDs

// =================================================================================
// Event-Handler und Initialisierung
// =================================================================================

/**
 * Initialisiert die sofortigen Einstellungsaktualisierungen
 * Wird nach erfolgreichem Login aufgerufen
 */
function initLiveSettingsUpdate() {
    // Alle Nicht-Passwort Eingabefelder auswählen
    const inputFields = document.querySelectorAll('#configForm input:not([id="new_password"]):not([id="confirm_password"]), #configForm select');
    
    // Spezielles Handling für Passwortfelder
    setupPasswordFieldUpdates();
    
    inputFields.forEach(field => {
        // Speichert den ursprünglichen Wert beim Fokussieren
        field.addEventListener('focus', function() {
            // Typgerechter Wert je nach Input-Typ
            const value = getFieldValue(field);
            fieldOriginalValues.set(field.id, value);
            
            // Parent-Element für visuelle Markierung
            const parentField = field.closest('.input-field');
            if (parentField) {
                parentField.classList.remove('edited', 'error');
            }
        });
        // Prüft auf Änderungen beim Verlassen des Feldes und speichert diese
        field.addEventListener('blur', async function() {
            if (fieldOriginalValues.has(field.id)) {
                const originalValue = fieldOriginalValues.get(field.id);
                const currentValue = getFieldValue(field);
                
                // Nur weitermachen, wenn sich der Wert geändert hat
                if (originalValue !== currentValue) {
                    const parentField = field.closest('.input-field');
                    
                    // Validierung durchführen
                    const validationResult = validateField(field, currentValue);
                    
                    if (validationResult.valid) {
                        // Wert in die DB schreiben
                        try {
                            const success = await updateSingleSetting(field.name, currentValue);
                            
                            if (success) {
                                if (parentField) parentField.classList.add('edited');
                                showNotification(`Einstellung "${getFieldLabel(field)}" erfolgreich gespeichert`, 'success');
                                
                                // Wert als neuen Originalwert merken
                                fieldOriginalValues.set(field.id, currentValue);
                            } else {
                                // Bei Fehler zurück zum alten Wert
                                setFieldValue(field, originalValue);
                                if (parentField) parentField.classList.add('error');
                                showNotification(`Fehler beim Speichern von "${getFieldLabel(field)}"`, 'error');
                            }
                        } catch (error) {
                            console.error('Fehler beim Speichern der Einstellung:', error);
                            if (parentField) parentField.classList.add('error');
                            showNotification(`Verbindungsfehler beim Speichern`, 'error');
                            
                            // Bei Fehler zurück zum alten Wert
                            setFieldValue(field, originalValue);
                        }                    } else {
                        // Ungültiger Wert
                        if (parentField) parentField.classList.add('error');
                        
                        // Bestimme den Typ der Benachrichtigung (Info oder Error)
                        const notificationType = validationResult.type || 'error';
                        showNotification(validationResult.message, notificationType);
                        
                        // Bei Validierungsfehler zurück zum alten Wert
                        setFieldValue(field, originalValue);
                    }
                }
            }
        });
        
        // Bei Select-Feldern direktes Update bei Änderung
        if (field.tagName === 'SELECT') {
            field.addEventListener('change', function() {
                // Blur-Event auslösen, um die normale Logik zu verwenden
                field.blur();
            });
        }
    });
}

// =================================================================================
// API-Kommunikation
// =================================================================================

/**
 * Speichert eine einzelne Einstellung in der Datenbank
 * @param {string} name - Der Name der Einstellung
 * @param {any} value - Der zu speichernde Wert
 * @returns {Promise<boolean>} - True bei Erfolg, False bei Fehler
 * 
 * Verwendet einen POST-Request an den API-Endpunkt /api/settings für einzelne Einstellungen.
 * Struktur der gesendeten Daten: { einstellungs_name: einstellungs_wert }
 */
async function updateSingleSetting(name, value) {
    try {
        // Erstelle ein Objekt mit nur der einen Einstellung
        const settingObj = {};
        settingObj[name] = value;
        
        // API-Aufruf um die einzelne Einstellung zu speichern
        const response = await fetch('/api/settings', {
            method: 'POST', // Verwende POST, da der Server PUT nicht unterstützt
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(settingObj)
        });
        
        if (response.ok) {
            // Header aktualisieren, wenn der Event-Name geändert wurde
            if (name === 'event_name') {
                setHeaderTitle(value);
            }
              // Nach der Einstellungsänderung auf Updates prüfen, falls die throttledCheckForUpdates Funktion existiert
            if (typeof throttledCheckForUpdates === 'function') {
                throttledCheckForUpdates();
            }
            
            return true;
        } else {
            console.error('API-Fehler beim Speichern:', await response.text());
            return false;
        }
    } catch (error) {
        console.error('Fehler beim Speichern der Einstellung:', error);
        return false;
    }
}

// =================================================================================
// Validierung und Datenformatierung
// =================================================================================

/**
 * Validiert ein Eingabefeld basierend auf dem Feldtyp und Namen
 * @param {HTMLElement} field - Das zu validierende Feld
 * @param {any} value - Der zu validierende Wert
 * @returns {Object} - Objekt mit valid (boolean) und message (string)
 */
function validateField(field, value) {
    const fieldName = field.name;
    const fieldType = field.type;
      // Validierungsregeln basierend auf dem Feldnamen und Typ
    switch (fieldName) {
        case 'event_name':
            if (!value || value.trim() === '') {
                return { valid: false, message: 'Event-Name darf nicht leer sein' };
            }
            if (value.length > 50) {
                return { valid: false, message: 'Event-Name darf maximal 50 Zeichen lang sein' };
            }
            break;
            
        case 'countdown_duration':
            const countdownValue = parseInt(value);
            if (isNaN(countdownValue) || countdownValue < 1 || countdownValue > 10) {
                return { valid: false, message: 'Countdown muss zwischen 1 und 10 Sekunden liegen' };
            }
            break;
            
        case 'screensaver_timeout':
            const screensaverValue = parseInt(value);
            if (isNaN(screensaverValue)) {
                return { valid: false, message: 'Bitte geben Sie eine gültige Zahl ein' };
            }
            if (screensaverValue < 30 || screensaverValue > 600) {
                // Hier verwenden wir info statt error, da der Wert außerhalb des erlaubten Bereichs liegt
                // Die Validierung schlägt fehl, aber wir wollen eine informative Nachricht anzeigen
                return { 
                    valid: false, 
                    message: 'Bildschirmschoner-Timeout muss zwischen 30 und 600 Sekunden liegen', 
                    type: 'info'
                };
            }
            break;
            
        case 'gallery_timeout':
            const galleryValue = parseInt(value);
            if (isNaN(galleryValue)) {
                return { valid: false, message: 'Bitte geben Sie eine gültige Zahl ein' };
            }
            if (galleryValue < 30 || galleryValue > 300) {
                return { 
                    valid: false, 
                    message: 'Galerie-Timeout muss zwischen 30 und 300 Sekunden liegen',
                    type: 'info'
                };
            }
            break;
    }
    
    // Standard-Validierungen basierend auf dem Input-Typ
    switch (fieldType) {
        case 'number':
            if (isNaN(parseFloat(value))) {
                return { valid: false, message: 'Bitte geben Sie eine gültige Zahl ein' };
            }
            break;
            
        case 'date':
            if (value && !isValidDate(value)) {
                return { valid: false, message: 'Bitte geben Sie ein gültiges Datum ein' };
            }
            break;
    }
    
    // Wenn keine spezifische Validierung greift, ist der Wert gültig
    return { valid: true, message: '' };
}

/**
 * Prüft, ob ein Datumstring ein gültiges Datum darstellt
 * @param {string} dateString - Das zu prüfende Datum
 * @returns {boolean} - True wenn gültig
 */
function isValidDate(dateString) {
    const date = new Date(dateString);
    return !isNaN(date.getTime());
}

// =================================================================================
// UI-Benachrichtigungen und Feedback
// =================================================================================

/**
 * Zeigt eine Benachrichtigung an
 * @param {string} message - Die anzuzeigende Nachricht
 * @param {string} type - Der Typ der Nachricht (success, error, warning)
 */
function showNotification(message, type = 'info') {
    // Container für gestapelte Benachrichtigungen erstellen oder finden
    let notificationsContainer = document.getElementById('notificationsContainer');
    if (!notificationsContainer) {
        notificationsContainer = document.createElement('div');
        notificationsContainer.id = 'notificationsContainer';
        notificationsContainer.className = 'notifications-container';
        document.body.appendChild(notificationsContainer);
    }
    
    // Eindeutige ID für diese Benachrichtigung generieren
    const notificationId = 'notification-' + (++notificationCounter);
    
    // Neue Benachrichtigung erstellen
    const notification = document.createElement('div');
    notification.id = notificationId;
    notification.className = `settings-notification ${type}`;
    notification.innerHTML = `
        <span>${message}</span>
        <button class="close-notification">×</button>
    `;
    
    // Schließen-Button-Event-Handler
    const closeBtn = notification.querySelector('.close-notification');
    closeBtn.addEventListener('click', () => {
        hideNotification(notificationId);
    });
    
    // Benachrichtigung zum Container hinzufügen
    notificationsContainer.appendChild(notification);
    
    // Verzögerung hinzufügen, damit Animation funktioniert
    setTimeout(() => {
        notification.classList.add('visible');
    }, 10);
      // Timeout für automatisches Ausblenden setzen
    // Standard-Dauer für Erfolg: 3000ms, für Info: 4500ms, für Fehler: 6000ms (doppelt)
    let timeoutDuration;
    if (type === 'error') {
        timeoutDuration = 6000; // Längste Anzeigedauer für Fehler
    } else if (type === 'info') {
        timeoutDuration = 4500; // Mittlere Anzeigedauer für Infos
    } else {
        timeoutDuration = 3000; // Standarddauer für Erfolg und andere
    }
    
    const timeout = setTimeout(() => {
        hideNotification(notificationId);
    }, timeoutDuration);
    
    // Timeout speichern
    notificationTimeouts.set(notificationId, timeout);
    
    return notificationId;
}

/**
 * Blendet eine Benachrichtigung aus
 * @param {string} notificationId - Die ID der auszublendenden Benachrichtigung
 */
function hideNotification(notificationId) {
    const notification = document.getElementById(notificationId);
    if (!notification) return;
    
    // Timeout löschen
    if (notificationTimeouts.has(notificationId)) {
        clearTimeout(notificationTimeouts.get(notificationId));
        notificationTimeouts.delete(notificationId);
    }
    
    // Animation für das Ausblenden
    notification.classList.remove('visible');
    notification.classList.add('hiding');
    
    // Nach der Animation aus dem DOM entfernen
    setTimeout(() => {
        notification.remove();
        
        // Container entfernen, wenn keine Benachrichtigungen mehr vorhanden sind
        const container = document.getElementById('notificationsContainer');
        if (container && container.children.length === 0) {
            container.remove();
        }
    }, 300);
}

// =================================================================================
// Hilfsfunktionen
// =================================================================================

/**
 * Holt den aktuellen Wert eines Feldes je nach Feldtyp
 * @param {HTMLElement} field - Das Feld
 * @returns {any} - Der Wert in passender Datenform
 */
function getFieldValue(field) {
    if (field.type === 'checkbox') {
        return field.checked;
    } else if (field.type === 'number') {
        return field.value === '' ? '' : Number(field.value);
    } else {
        return field.value;
    }
}

/**
 * Setzt den Wert eines Feldes je nach Feldtyp
 * @param {HTMLElement} field - Das Feld
 * @param {any} value - Der zu setzende Wert
 */
function setFieldValue(field, value) {
    if (field.type === 'checkbox') {
        field.checked = Boolean(value);
    } else {
        field.value = value;
    }
}

/**
 * Ermittelt ein lesbares Label für ein Feld
 * @param {HTMLElement} field - Das Feld
 * @returns {string} - Der Anzeigename des Feldes
 */
function getFieldLabel(field) {
    // Versuche, ein Label zu finden
    const parentField = field.closest('.input-field');
    if (parentField) {
        const label = parentField.querySelector('label');
        if (label) {
            return label.textContent;
        }
    }
    
    // Fallback: Feldname verwenden
    return field.name;
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
 * Richtet die Eventhandler für die Passwortfelder ein
 */
function setupPasswordFieldUpdates() {
    const newPassword = document.getElementById('new_password');
    const confirmPassword = document.getElementById('confirm_password');
    const statusElement = document.getElementById('password-match-status');
    
    // Nur wenn beide existieren
    if (!newPassword || !confirmPassword) return;
    
    // Event für Passwort-Änderung einrichten
    confirmPassword.addEventListener('blur', async function() {
        // Passwörter leer lassen ist erlaubt (keine Änderung)
        if (newPassword.value === '' && confirmPassword.value === '') {
            return;
        }
        
        // Beide Passwörter müssen übereinstimmen und lang genug sein
        if (newPassword.value === confirmPassword.value && newPassword.value.length >= 4) {
            const parentField = newPassword.closest('.input-field');
            
            try {
                // Passwort über die API aktualisieren
                const success = await updateSingleSetting('new_password', newPassword.value);
                
                if (success) {
                    if (parentField) parentField.classList.add('edited');
                    showNotification('Admin-Passwort wurde erfolgreich aktualisiert', 'success');
                    
                    // Passwortfelder leeren
                    newPassword.value = '';
                    confirmPassword.value = '';
                    statusElement.textContent = '';
                    statusElement.className = '';
                } else {
                    if (parentField) parentField.classList.add('error');
                    showNotification('Fehler beim Aktualisieren des Passworts', 'error');
                }
            } catch (error) {
                console.error('Fehler beim Speichern des Passworts:', error);
                if (parentField) parentField.classList.add('error');
                showNotification('Verbindungsfehler beim Speichern des Passworts', 'error');
            }
        } else if (newPassword.value !== '' || confirmPassword.value !== '') {
            // Anzeige einer Fehlermeldung, wenn die Passwörter nicht übereinstimmen
            // oder zu kurz sind, und ein Feld nicht leer ist
            showNotification('Passwörter stimmen nicht überein oder sind zu kurz (min. 4 Zeichen)', 'error');
        }
    });
}
