// ------------------------------------------------------------------------------
// gallery.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Galerieansicht der Fotobox
// ------------------------------------------------------------------------------

// Importiere Systemmodule
import { getImageList, deleteImage } from './manage_filesystem.js';
import { log, error } from './manage_logging.js';
import { getSetting } from './manage_database.js';

// =================================================================================
// Galerie-Funktionalität
// =================================================================================

/**
 * Initialisierung der Galerie-Funktionalitäten
 */
document.addEventListener('DOMContentLoaded', function() {
    // Prüfen, ob wir auf der gallery.html sind
    const galleryDiv = document.getElementById('galleryPhotos');
    if (!galleryDiv) return;
    
    initGalleryView();
});

// Globale Variablen für die Galerie-Ansicht
let galleryTimeout = null;
let galleryTimeoutMs = 60000; // Default 60s, wird aus Settings geladen
let lastInteraction = Date.now();

/**
 * Initialisiert die Galerie-Ansicht auf der gallery.html Seite
 */
function initGalleryView() {
    console.log("Galerie wird initialisiert...");
    
    // Fotos laden
    loadGalleryPhotos();
    
    // Einstellungen für Gallery-Timeout laden
    loadGallerySettings();
    
    // Event-Listener für Benutzerinteraktionen
    document.addEventListener('mousemove', resetGalleryTimeout);
    document.addEventListener('keydown', resetGalleryTimeout);
    document.addEventListener('click', resetGalleryTimeout);
    document.addEventListener('touchstart', resetGalleryTimeout);
}

/**
 * Lädt relevante Einstellungen für die Galerie aus der Datenbank
 */
async function loadGallerySettings() {
    try {
        // Event-Name direkt aus der Datenbank laden
        const eventName = await getSetting('event_name', 'Fotobox Event');
        if (eventName && document.getElementById('headerTitle')) {
            document.getElementById('headerTitle').textContent = eventName;
        }
        
        // Gallery-Timeout direkt aus der Datenbank laden
        const galleryTimeout = await getSetting('gallery_timeout', 60);
        if (galleryTimeout) {
            // Wert in Sekunden aus Einstellungen mal 1000 für Millisekunden
            galleryTimeoutMs = parseInt(galleryTimeout) * 1000 || 60000;
            log(`Gallery-Timeout gesetzt auf ${galleryTimeout} Sekunden (${galleryTimeoutMs}ms)`);
        }
        
        // Initialer Timeout starten
        resetGalleryTimeout();
    } catch (err) {
        error('Fehler beim Laden der Galerieeinstellungen:', err.message);
    }
}

/**
 * Setzt den Timeout zurück, der die Galerie verlässt
 */
function resetGalleryTimeout() {
    lastInteraction = Date.now();
    
    // Bestehenden Timeout löschen
    if (galleryTimeout) {
        clearTimeout(galleryTimeout);
    }
    
    // Neuen Timeout setzen
    galleryTimeout = setTimeout(() => {
        console.log("Gallery-Timeout: Keine Interaktion - kehre zur Home-Seite zurück");
        navigateToHome();
    }, galleryTimeoutMs);
}

/**
 * Navigiert zurück zur Home-Seite (capture.html)
 */
function navigateToHome() {
    window.location.href = 'capture.html';
}

/**
 * Lädt und zeigt alle Fotos in der Galerie an
 */
async function loadGalleryPhotos() {
    const galleryDiv = document.getElementById('galleryPhotos');
    if (!galleryDiv) return;
    
    try {
        // Verwende das neue Filesystem-Modul statt direkter API-Aufrufe
        const data = await getImageList('gallery');
        galleryDiv.innerHTML = '';
        
        if (!data.photos || data.photos.length === 0) {
            galleryDiv.innerHTML = '<div class="gallery-empty">Noch keine Fotos vorhanden.</div>';
            return;
        }
        
        // Dynamischer DOM-Aufbau
        data.photos.forEach(photo => {
            const img = document.createElement('img');
            img.src = '/photos/gallery/' + photo;
            img.alt = 'Foto';
            img.loading = 'lazy';
            img.className = 'gallery-img';
            galleryDiv.appendChild(img);
            
            // Klick-Handler für Vollbildanzeige hinzufügen
            img.addEventListener('click', () => {
                showFullscreenImage(photo);
                // Jede Interaktion mit einem Bild setzt den Timeout zurück
                resetGalleryTimeout();
            });
        });
        
    } catch (err) {
        console.error('Fehler beim Laden der Galerie:', err);
        galleryDiv.innerHTML = '<div class="gallery-error">Fehler beim Laden der Galerie.</div>';
    }
}

/**
 * Zeigt ein Bild im Vollbild-Modus an
 * @param {string} photoName - Der Dateiname des Fotos
 */
function showFullscreenImage(photoName) {
    // Hier könnte Code für eine Vollbildanzeige implementiert werden
    console.log(`Vollbild für Foto: ${photoName}`);
    
    // Auch hier den Timeout zurücksetzen
    resetGalleryTimeout();
}
