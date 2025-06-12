// ------------------------------------------------------------------------------
// index.js
// ------------------------------------------------------------------------------
// Funktion: Steuert den Splash-Screen (index.html) mit Progressbar, 
// Versionsprüfung und automatischer Weiterleitung
// ------------------------------------------------------------------------------

// Abhängigkeiten aus Systemmodulen
import { checkForUpdates } from './manage_update.js';
import { log, error } from './manage_logging.js';
import { isPasswordSet } from './manage_auth.js';

// Splash-Overlay mit Progressbar und Passwort-Check
const splashDuration = 8000; // ms
const progressBar = document.getElementById('progressBar');
const statusMessage = document.getElementById('statusMessage');
let start = Date.now();
let updateAvailable = false;
let updateVersion = null;

/**
 * Die verschiedenen Status-Phasen des Splash Screens
 */
const PHASES = {
    INIT: {percent: 0, message: ''},
    CHECK_VERSION: {percent: 30, message: 'Prüfe auf Updates...'},
    VERSION_RESULT: {percent: 45, message: ''},
    CHECK_CONFIG: {percent: 70, message: 'Lade Konfiguration...'},
    COMPLETE: {percent: 100, message: 'Starte Fotobox...'}
};

let currentPhase = PHASES.INIT;

/**
 * Animiert die Fortschrittsanzeige und führt Phasen-Aktionen aus
 */
function animateProgress() {
    const elapsed = Date.now() - start;
    const percent = Math.min(100, (elapsed / splashDuration) * 100);
    progressBar.style.width = percent + '%';
    
    // Phasenbasierte Aktionen
    handlePhases(percent);
    
    if (elapsed < splashDuration) {
        requestAnimationFrame(animateProgress);
    }
}

/**
 * Verwaltet die verschiedenen Phasen des Splash-Screens basierend auf dem Fortschritt
 */
function handlePhases(percent) {    // Phase: Prüfe Version (bei 30%)
    if (percent >= PHASES.CHECK_VERSION.percent && currentPhase !== PHASES.CHECK_VERSION) {
        currentPhase = PHASES.CHECK_VERSION;
        statusMessage.textContent = PHASES.CHECK_VERSION.message;
        statusMessage.className = 'splash-status status-checking';
        // API-Aufruf zum Prüfen der Version
        checkForUpdateStatus();
    }
    
    // Phase: Konfiguration prüfen (bei 70%)
    if (percent >= PHASES.CHECK_CONFIG.percent && currentPhase !== PHASES.CHECK_CONFIG) {
        currentPhase = PHASES.CHECK_CONFIG;
        if (!statusMessage.classList.contains('status-updateavailable')) {
            statusMessage.textContent = PHASES.CHECK_CONFIG.message;
            statusMessage.className = 'splash-status';
        }
    }
    
    // Phase: Fertigstellung (bei 100%)
    if (percent >= PHASES.COMPLETE.percent && currentPhase !== PHASES.COMPLETE) {
        currentPhase = PHASES.COMPLETE;
        if (!statusMessage.classList.contains('status-updateavailable')) {
            statusMessage.textContent = PHASES.COMPLETE.message;
        }
    }
}

/**
 * Prüft, ob Updates verfügbar sind 
 */
async function checkForUpdateStatus() {
    try {
        const updateInfo = await checkForUpdates();
        currentPhase = PHASES.VERSION_RESULT;
        
        if (updateInfo) {
            // Update verfügbar
            updateAvailable = true;
            updateVersion = updateInfo.version;
            statusMessage.textContent = `Update auf Version ${updateInfo.version} verfügbar`;
            statusMessage.className = 'splash-status status-updateavailable';
            log(`Update verfügbar: ${updateInfo.version}`);
            
            // Optional: Anzeige länger erhalten, damit Benutzer die Nachricht lesen kann
            // Dies beeinflusst nicht die Gesamtdauer des Splash-Screens
        } else {
            // System ist aktuell
            const versionInfo = await import('./manage_update.js').then(module => module.getVersionInfo());
            statusMessage.textContent = `System ist aktuell (v${versionInfo.current})`;
            statusMessage.className = 'splash-status status-uptodate';
            log(`System ist aktuell: ${versionInfo.current}`);
        }
    } catch (error) {
        console.error('Fehler bei der Update-Prüfung:', error);
        statusMessage.textContent = 'Update-Status konnte nicht ermittelt werden';
        statusMessage.className = 'splash-status status-error';
    }
}

/**
 * Prüft, ob ein Passwort gesetzt ist über den Authentifizierungsmodul
 * @returns {Promise<boolean>} True wenn ein Passwort gesetzt ist
 */
async function checkPasswordSet() {
    return isPasswordSet();
}

// Starte die Animation
animateProgress();

// Nach der Animation prüfen und weiterleiten
setTimeout(async () => {
    const isSet = await checkPasswordSet();
    
    // Wenn ein Update verfügbar ist, auf die Startseite leiten
    // unabhängig vom Passwort-Status, damit der Nutzer das Update sehen kann
    if (isSet) {
        // Falls Update verfügbar, füge einen Query-Parameter hinzu, um auf der Startseite
        // ein Update-Banner anzuzeigen
        if (updateAvailable) {
            window.location.href = `capture.html?update=${updateVersion}`;
        } else {
            window.location.href = 'capture.html';
        }
    } else {
        window.location.href = 'install.html';
    }
}, splashDuration);
