// ------------------------------------------------------------------------------
// install.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Ersteinrichtung der Fotobox (install.html) mit 
// Passwort-Setup und API-Kommunikation zur Konfigurationsspeicherung
// ------------------------------------------------------------------------------

/**
 * Event-Handler für das Absenden des Setup-Formulars
 */
document.getElementById('setupForm').onsubmit = async function(e) {
    e.preventDefault();
    const pw = document.getElementById('setupPassword').value;
    const eventName = document.getElementById('setupEventName') ? 
                     document.getElementById('setupEventName').value : '';
    const status = document.getElementById('setupStatus');
      if(pw.length < 4) {
        status.textContent = 'Passwort zu kurz! (mind. 4 Zeichen)';
        status.className = 'error status-visible';
        return;
    }
      // Daten für API vorbereiten
    const settings = { 
        new_password: pw 
    };
    
    // Event-Name hinzufügen, wenn angegeben
    if (eventName && eventName.trim()) {
        settings.event_name = eventName.trim();
    }
    
    // Einstellungen speichern
    try {
        const res = await fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(settings)
        });
          if(res.ok) {
            status.textContent = 'Passwort gespeichert! Weiterleitung ...';
            status.className = 'success status-visible';
            setTimeout(() => { 
                window.location.href = 'capture.html'; 
            }, 1200);
        } else {
            status.textContent = 'Fehler beim Speichern!';
            status.className = 'error';
            status.style.display = 'block';
        }    } catch (error) {
        status.textContent = 'Verbindungsfehler!';
        status.className = 'error status-visible';
        console.error('Setup-Fehler:', error);
    }
};
