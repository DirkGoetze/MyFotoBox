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
