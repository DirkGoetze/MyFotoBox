/**
 * @file ui_components.js
 * @description Gemeinsame UI-Komponenten für Fotobox2
 * @module ui_components
 */

import { log, error } from './manage_logging.js';

/**
 * Zeigt eine Benachrichtigung für den Benutzer an
 * @param {string} message - Die anzuzeigende Nachricht
 * @param {string} [type='info'] - Der Typ der Nachricht ('info', 'success', 'warn', 'error')
 * @param {number} [duration=3000] - Anzeigedauer in Millisekunden
 */
export function showNotification(message, type = 'info', duration = 3000) {
    let notificationContainer = document.getElementById('notificationContainer');
    
    // Container erstellen, falls nicht vorhanden
    if (!notificationContainer) {
        notificationContainer = document.createElement('div');
        notificationContainer.id = 'notificationContainer';
        notificationContainer.style.position = 'fixed';
        notificationContainer.style.top = '20px';
        notificationContainer.style.right = '20px';
        notificationContainer.style.zIndex = '1000';
        document.body.appendChild(notificationContainer);
    }
    
    // Notification-Element erstellen
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <div class="notification-icon"></div>
        <div class="notification-message">${message}</div>
        <div class="notification-close">×</div>
    `;
    
    notification.style.marginBottom = '10px';
    notification.style.padding = '10px 15px';
    notification.style.borderRadius = '5px';
    notification.style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)';
    notification.style.display = 'flex';
    notification.style.alignItems = 'center';
    notification.style.justifyContent = 'space-between';
    notification.style.opacity = '0';
    notification.style.transform = 'translateX(50px)';
    notification.style.transition = 'opacity 0.3s, transform 0.3s';
    
    // Farben je nach Typ
    switch(type) {
        case 'success':
            notification.style.backgroundColor = '#d4edda';
            notification.style.color = '#155724';
            break;
        case 'warn':
            notification.style.backgroundColor = '#fff3cd';
            notification.style.color = '#856404';
            break;
        case 'error':
            notification.style.backgroundColor = '#f8d7da';
            notification.style.color = '#721c24';
            break;
        default: // info
            notification.style.backgroundColor = '#d1ecf1';
            notification.style.color = '#0c5460';
    }
    
    // Close-Button-Ereignisbehandlung
    notification.querySelector('.notification-close').addEventListener('click', () => {
        closeNotification(notification);
    });
    
    // Animation hinzufügen
    notificationContainer.appendChild(notification);
    
    // Animation starten (kleine Verzögerung für den DOM-Update)
    setTimeout(() => {
        notification.style.opacity = '1';
        notification.style.transform = 'translateX(0)';
    }, 10);
    
    // Automatisches Entfernen nach Dauer
    const timeout = setTimeout(() => {
        closeNotification(notification);
    }, duration);
    
    // Speichere das Timeout, um es bei manuellem Schließen zu löschen
    notification._timeout = timeout;
    
    // Log erstellen
    log(`Benachrichtigung (${type}): ${message}`);
    
    return notification;
}

/**
 * Schließt eine Benachrichtigung
 * @param {HTMLElement} notification - Das zu schließende Benachrichtigungselement
 */
function closeNotification(notification) {
    // Timeout löschen, wenn es existiert
    if (notification._timeout) {
        clearTimeout(notification._timeout);
    }
    
    // Animation zum Ausblenden
    notification.style.opacity = '0';
    notification.style.transform = 'translateX(50px)';
    
    // Nach Animationsende entfernen
    setTimeout(() => {
        if (notification.parentElement) {
            notification.parentElement.removeChild(notification);
        }
    }, 300);
}

/**
 * Zeigt einen Dialog an
 * @param {Object} options - Optionen für den Dialog
 * @param {string} options.title - Titel des Dialogs
 * @param {string|HTMLElement} options.content - Inhalt des Dialogs (HTML oder DOM-Element)
 * @param {Array<{text: string, action: Function|string, primary: boolean}>} [options.buttons] - Schaltflächen
 * @param {boolean} [options.closable=true] - Ob der Dialog schließbar ist
 * @returns {Promise<any>} - Gibt das Ergebnis der Aktion zurück
 */
export function showDialog(options) {
    return new Promise((resolve) => {
        // Bestehenden Dialog entfernen, falls vorhanden
        const existingDialog = document.querySelector('.dialog-overlay');
        if (existingDialog) {
            existingDialog.parentElement.removeChild(existingDialog);
        }
        
        // Dialog erstellen
        const dialogOverlay = document.createElement('div');
        dialogOverlay.className = 'dialog-overlay';
        dialogOverlay.style.position = 'fixed';
        dialogOverlay.style.top = '0';
        dialogOverlay.style.left = '0';
        dialogOverlay.style.width = '100%';
        dialogOverlay.style.height = '100%';
        dialogOverlay.style.backgroundColor = 'rgba(0,0,0,0.5)';
        dialogOverlay.style.display = 'flex';
        dialogOverlay.style.alignItems = 'center';
        dialogOverlay.style.justifyContent = 'center';
        dialogOverlay.style.zIndex = '2000';
        
        const dialogBox = document.createElement('div');
        dialogBox.className = 'dialog-box';
        dialogBox.style.backgroundColor = '#fff';
        dialogBox.style.borderRadius = '5px';
        dialogBox.style.boxShadow = '0 3px 7px rgba(0,0,0,0.3)';
        dialogBox.style.width = '90%';
        dialogBox.style.maxWidth = '500px';
        dialogBox.style.maxHeight = '80vh';
        dialogBox.style.display = 'flex';
        dialogBox.style.flexDirection = 'column';
        dialogBox.style.opacity = '0';
        dialogBox.style.transform = 'translateY(-20px)';
        dialogBox.style.transition = 'opacity 0.3s, transform 0.3s';
        
        // Dialog-Header
        const dialogHeader = document.createElement('div');
        dialogHeader.className = 'dialog-header';
        dialogHeader.style.padding = '15px';
        dialogHeader.style.borderBottom = '1px solid #e5e5e5';
        dialogHeader.style.display = 'flex';
        dialogHeader.style.alignItems = 'center';
        dialogHeader.style.justifyContent = 'space-between';
        
        const dialogTitle = document.createElement('h3');
        dialogTitle.className = 'dialog-title';
        dialogTitle.textContent = options.title;
        dialogTitle.style.margin = '0';
        dialogTitle.style.padding = '0';
        dialogTitle.style.fontSize = '18px';
        
        dialogHeader.appendChild(dialogTitle);
        
        // Schließen-Button wenn schließbar
        if (options.closable !== false) {
            const closeButton = document.createElement('button');
            closeButton.className = 'dialog-close-btn';
            closeButton.innerHTML = '&times;';
            closeButton.style.background = 'none';
            closeButton.style.border = 'none';
            closeButton.style.fontSize = '24px';
            closeButton.style.cursor = 'pointer';
            closeButton.style.padding = '0';
            closeButton.style.lineHeight = '1';
            closeButton.setAttribute('aria-label', 'Dialog schließen');
            
            closeButton.addEventListener('click', () => {
                closeDialog(dialogOverlay, 'close');
                resolve('close');
            });
            
            dialogHeader.appendChild(closeButton);
        }
        
        dialogBox.appendChild(dialogHeader);
        
        // Dialog-Content
        const dialogContent = document.createElement('div');
        dialogContent.className = 'dialog-content';
        dialogContent.style.padding = '15px';
        dialogContent.style.overflowY = 'auto';
        
        // Content kann String oder HTMLElement sein
        if (typeof options.content === 'string') {
            dialogContent.innerHTML = options.content;
        } else if (options.content instanceof HTMLElement) {
            dialogContent.appendChild(options.content);
        }
        
        dialogBox.appendChild(dialogContent);
        
        // Dialog-Footer mit Buttons
        if (options.buttons && options.buttons.length > 0) {
            const dialogFooter = document.createElement('div');
            dialogFooter.className = 'dialog-footer';
            dialogFooter.style.padding = '15px';
            dialogFooter.style.borderTop = '1px solid #e5e5e5';
            dialogFooter.style.display = 'flex';
            dialogFooter.style.justifyContent = 'flex-end';
            dialogFooter.style.gap = '10px';
            
            options.buttons.forEach((buttonConfig) => {
                const button = document.createElement('button');
                button.textContent = buttonConfig.text;
                button.className = buttonConfig.primary ? 'primary-button' : 'secondary-button';
                button.style.padding = '8px 16px';
                button.style.borderRadius = '4px';
                button.style.cursor = 'pointer';
                
                if (buttonConfig.primary) {
                    button.style.backgroundColor = '#007bff';
                    button.style.color = '#fff';
                    button.style.border = 'none';
                } else {
                    button.style.backgroundColor = '#f8f9fa';
                    button.style.color = '#212529';
                    button.style.border = '1px solid #d9d9d9';
                }
                
                button.addEventListener('click', () => {
                    // Button-Action ausführen
                    let result;
                    if (typeof buttonConfig.action === 'function') {
                        result = buttonConfig.action();
                    } else {
                        result = buttonConfig.action;
                    }
                    
                    // Dialog schließen, außer die Aktion gibt false zurück
                    if (result !== false) {
                        closeDialog(dialogOverlay, result || buttonConfig.action);
                        resolve(result || buttonConfig.action);
                    }
                });
                
                dialogFooter.appendChild(button);
            });
            
            dialogBox.appendChild(dialogFooter);
        }
        
        dialogOverlay.appendChild(dialogBox);
        document.body.appendChild(dialogOverlay);
        
        // Animation starten (kleine Verzögerung für den DOM-Update)
        setTimeout(() => {
            dialogBox.style.opacity = '1';
            dialogBox.style.transform = 'translateY(0)';
        }, 10);
        
        // ESC-Taste zum Schließen, wenn schließbar
        if (options.closable !== false) {
            const keyHandler = (e) => {
                if (e.key === 'Escape') {
                    closeDialog(dialogOverlay, 'close');
                    resolve('close');
                    document.removeEventListener('keydown', keyHandler);
                }
            };
            document.addEventListener('keydown', keyHandler);
        }
        
        // Klick auf Overlay zum Schließen, wenn schließbar
        if (options.closable !== false) {
            dialogOverlay.addEventListener('click', (event) => {
                if (event.target === dialogOverlay) {
                    closeDialog(dialogOverlay, 'close');
                    resolve('close');
                }
            });
        }
    });
}

/**
 * Schließt einen Dialog mit Animation
 * @param {HTMLElement} dialogOverlay - Das Overlay-Element des Dialogs
 * @param {any} result - Das Ergebnis, das zurückgegeben werden soll
 */
function closeDialog(dialogOverlay, result) {
    const dialogBox = dialogOverlay.querySelector('.dialog-box');
    if (dialogBox) {
        // Animation zum Ausblenden
        dialogBox.style.opacity = '0';
        dialogBox.style.transform = 'translateY(-20px)';
    }
    
    dialogOverlay.style.opacity = '0';
    
    // Nach Animationsende entfernen
    setTimeout(() => {
        if (dialogOverlay.parentElement) {
            dialogOverlay.parentElement.removeChild(dialogOverlay);
        }
    }, 300);
    
    return result;
}

/**
 * Erstellt einen Fortschrittsbalken
 * @param {Object} options - Optionen für den Fortschrittsbalken
 * @param {string} options.containerId - ID des Container-Elements
 * @param {string} [options.labelId] - ID für das Label-Element (optional)
 * @param {number} [options.initialProgress=0] - Anfänglicher Fortschritt (0-100)
 * @param {string} [options.color='#007bff'] - Farbe des Fortschrittsbalkens
 * @returns {Object} Methoden zum Aktualisieren des Fortschritts
 */
export function createProgressBar(options) {
    const container = document.getElementById(options.containerId);
    if (!container) {
        error(`Container mit ID ${options.containerId} nicht gefunden`);
        return null;
    }
    
    // Container-Stil
    container.style.width = '100%';
    container.style.backgroundColor = '#e9ecef';
    container.style.borderRadius = '4px';
    container.style.overflow = 'hidden';
    
    // Fortschrittsbalken erstellen
    const progressBar = document.createElement('div');
    progressBar.className = 'progress-bar';
    progressBar.style.height = '8px';
    progressBar.style.width = `${options.initialProgress || 0}%`;
    progressBar.style.backgroundColor = options.color || '#007bff';
    progressBar.style.transition = 'width 0.3s ease';
    
    container.appendChild(progressBar);
    
    // Label erstellen, falls ID angegeben
    let label = null;
    if (options.labelId) {
        label = document.getElementById(options.labelId);
        if (!label) {
            // Label erstellen, wenn nicht gefunden
            label = document.createElement('div');
            label.id = options.labelId;
            label.className = 'progress-label';
            label.style.marginTop = '5px';
            label.style.fontSize = '14px';
            label.textContent = `${options.initialProgress || 0}%`;
            
            // Label nach dem Container einfügen
            container.parentNode.insertBefore(label, container.nextSibling);
        }
    }
    
    // Methoden zum Aktualisieren des Fortschritts
    return {
        /**
         * Aktualisiert den Fortschritt
         * @param {number} progress - Fortschritt (0-100)
         * @param {string} [message] - Optionale Nachricht
         */
        updateProgress(progress, message) {
            progress = Math.max(0, Math.min(100, progress)); // 0-100 beschränken
            progressBar.style.width = `${progress}%`;
            
            if (label) {
                label.textContent = message ? `${progress}% - ${message}` : `${progress}%`;
            }
        },
        
        /**
         * Setzt den Fortschrittsbalken zurück
         */
        reset() {
            progressBar.style.width = '0%';
            if (label) {
                label.textContent = '0%';
            }
        }
    };
}

// Initialisierung des UI-Components-Moduls
log('UI-Components-Modul initialisiert');
