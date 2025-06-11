// ------------------------------------------------------------------------------
// splash.js
// ------------------------------------------------------------------------------
// Funktion: Steuert den Splash-Screen (index.html) mit Progressbar, 
// Versionsprüfung und automatischer Weiterleitung
// ------------------------------------------------------------------------------

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
function handlePhases(percent) {
    // Phase: Prüfe Version (bei 30%)
    if (percent >= PHASES.CHECK_VERSION.percent && currentPhase !== PHASES.CHECK_VERSION) {
        currentPhase = PHASES.CHECK_VERSION;
        statusMessage.textContent = PHASES.CHECK_VERSION.message;
        statusMessage.className = 'splash-status status-checking';
        // API-Aufruf zum Prüfen der Version
        checkForUpdates();
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
async function checkForUpdates() {
    try {
        const response = await fetch('/api/update');
        if (!response.ok) throw new Error('Fehler bei der Update-Prüfung');
        
        const data = await response.json();
        currentPhase = PHASES.VERSION_RESULT;
        
        if (data.update_available) {
            // Update verfügbar
            updateAvailable = true;
            updateVersion = data.remote_version;
            statusMessage.textContent = `Update auf Version ${data.remote_version} verfügbar`;
            statusMessage.className = 'splash-status status-updateavailable';
            console.log(`Update verfügbar: ${data.local_version} → ${data.remote_version}`);
            
            // Optional: Anzeige länger erhalten, damit Benutzer die Nachricht lesen kann
            // Dies beeinflusst nicht die Gesamtdauer des Splash-Screens
        } else {
            // System ist aktuell
            statusMessage.textContent = `System ist aktuell (v${data.local_version})`;
            statusMessage.className = 'splash-status status-uptodate';
            console.log(`System ist aktuell: ${data.local_version}`);
        }
    } catch (error) {
        console.error('Fehler bei der Update-Prüfung:', error);
        statusMessage.textContent = 'Update-Status konnte nicht ermittelt werden';
        statusMessage.className = 'splash-status status-error';
    }
}

/**
 * Prüft, ob ein Passwort gesetzt ist über den speziellen Endpunkt
 * @returns {Promise<boolean>} True wenn ein Passwort gesetzt ist
 */
async function checkPasswordSet() {
    try {
        // Verwende den speziellen Endpunkt zur Passwortprüfung
        const res = await fetch('/api/check_password_set');
        if (!res.ok) throw new Error();
        const data = await res.json();
        return data.password_set;
    } catch {
        return false;
    }
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
