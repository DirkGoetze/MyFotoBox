// ----------------------------------------------------------------------------------
// live-settings-update.js
// ----------------------------------------------------------------------------------
// Bietet Funktionalität für sofortige Einstellungsaktualisierung nach dem Ändern
// eines Felds, anstatt auf das Absenden des gesamten Formulars zu warten.
// ----------------------------------------------------------------------------------

// Globale Variablen für die sofortige Einstellungsübernahme
const fieldOriginalValues = new Map(); // Speichert die ursprünglichen Werte der Felder
let notificationTimeout = null; // Timeout für das automatische Ausblenden der Benachrichtigung

// =================================================================================
// Event-Handler und Initialisierung
// =================================================================================

/**
 * Initialisiert die sofortigen Einstellungsaktualisierungen
 * Wird nach erfolgreichem Login aufgerufen
 */
function initLiveSettingsUpdate() {
    // Event-Handler für den "Schließen"-Button der Benachrichtigung
    document.getElementById('closeNotification').addEventListener('click', function() {
        hideNotification();
    });
    
    // Alle Eingabefelder auswählen (input, select) - aber nicht das Passwortfeld
    const inputFields = document.querySelectorAll('#configForm input:not([type="password"]), #configForm select');
    
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
                        }
                    } else {
                        // Ungültiger Wert
                        if (parentField) parentField.classList.add('error');
                        showNotification(validationResult.message, 'error');
                        
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
 * Verwendet einen PUT-Request an den API-Endpunkt /api/settings für einzelne Einstellungen.
 * Struktur der gesendeten Daten: { einstellungs_name: einstellungs_wert }
 */
async function updateSingleSetting(name, value) {
    try {
        // Erstelle ein Objekt mit nur der einen Einstellung
        const settingObj = {};
        settingObj[name] = value;
        
        // API-Aufruf um die einzelne Einstellung zu speichern
        const response = await fetch('/api/settings', {
            method: 'PUT', // PUT für einzelne Einstellungen, POST für komplette Formulare
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(settingObj)
        });
        
        if (response.ok) {
            // Header aktualisieren, wenn der Event-Name geändert wurde
            if (name === 'event_name') {
                setHeaderTitle(value);
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
            const numValue = parseInt(value);
            if (isNaN(numValue) || numValue < 1 || numValue > 10) {
                return { valid: false, message: 'Countdown muss zwischen 1 und 10 Sekunden liegen' };
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
    const notification = document.getElementById('settingsNotification');
    const textElement = document.getElementById('notificationText');
    
    // Vorherigen Timeout abbrechen, falls vorhanden
    if (notificationTimeout) {
        clearTimeout(notificationTimeout);
        notificationTimeout = null;
    }
    
    // Nachricht und Typ setzen
    textElement.textContent = message;
    notification.className = `settings-notification ${type}`;
    
    // Timeout für automatisches Ausblenden (außer bei Fehlern)
    if (type !== 'error') {
        notificationTimeout = setTimeout(() => {
            hideNotification();
        }, 3000);
    }
}

/**
 * Blendet die Benachrichtigung aus
 */
function hideNotification() {
    const notification = document.getElementById('settingsNotification');
    notification.classList.add('hidden');
    
    if (notificationTimeout) {
        clearTimeout(notificationTimeout);
        notificationTimeout = null;
    }
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
