// ------------------------------------------------------------------------------
// splash.js
// ------------------------------------------------------------------------------
// Funktion: Steuert den Splash-Screen (index.html) mit Progressbar und 
// automatischer Weiterleitung basierend auf der Setup-Status-Prüfung
// ------------------------------------------------------------------------------

// Splash-Overlay mit Progressbar und Passwort-Check
const splashDuration = 8000; // ms
const progressBar = document.getElementById('progressBar');
let start = Date.now();

/**
 * Animiert die Fortschrittsanzeige
 */
function animateProgress() {
    const elapsed = Date.now() - start;
    const percent = Math.min(100, (elapsed / splashDuration) * 100);
    progressBar.style.width = percent + '%';
    if (elapsed < splashDuration) {
        requestAnimationFrame(animateProgress);
    }
}
animateProgress();

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

// Nach der Animation prüfen und weiterleiten
setTimeout(async () => {
    const isSet = await checkPasswordSet();
    if (isSet) {
        window.location.href = 'capture.html';
    } else {
        window.location.href = 'install.html';
    }
}, splashDuration);
