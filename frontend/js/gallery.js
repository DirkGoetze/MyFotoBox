// ------------------------------------------------------------------------------
// gallery.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Galerieansicht der Fotobox
// ------------------------------------------------------------------------------

// Importiere Systemmodule
import { getImageList, deleteImage } from './manage_filesystem.js';
import { log, error } from './manage_logging.js';
import { getSetting, query, insert, update, remove } from './manage_database.js';

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

// Bildmetadaten aus der Datenbank abrufen
async function getImageMetadata(filename) {
    try {
        const result = await query(
            'SELECT * FROM image_metadata WHERE filename = ?',
            [filename]
        );
        
        if (result.success && result.data && result.data.length > 0) {
            return result.data[0];
        }
        return null;
    } catch (err) {
        error('Fehler beim Abrufen der Bildmetadaten', err);
        return null;
    }
}

// Bildmetadaten in der Datenbank speichern
async function saveImageMetadata(filename, metadata = {}) {
    try {
        // Prüfen ob Metadaten bereits existieren
        const existingData = await getImageMetadata(filename);
        
        if (existingData) {
            // Update bestehender Metadaten
            return await update(
                'image_metadata',
                { 
                    timestamp: metadata.timestamp || new Date().toISOString(),
                    tags: JSON.stringify(metadata.tags || {})
                },
                'filename = ?',
                [filename]
            );
        } else {
            // Neue Metadaten erstellen
            return await insert(
                'image_metadata',
                {
                    filename: filename,
                    timestamp: metadata.timestamp || new Date().toISOString(),
                    tags: JSON.stringify(metadata.tags || {})
                }
            );
        }
    } catch (err) {
        error('Fehler beim Speichern der Bildmetadaten', err);
        return { success: false, error: err.message };
    }
}

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
        for (const photo of data.photos) {
            // Metadaten aus der Datenbank abrufen
            const metadata = await getImageMetadata(photo);
            
            const imgContainer = document.createElement('div');
            imgContainer.className = 'gallery-item';
            
            const img = document.createElement('img');
            img.src = '/photos/gallery/' + photo;
            img.alt = 'Foto';
            img.loading = 'lazy';
            img.className = 'gallery-img';
            
            imgContainer.appendChild(img);
            
            // Wenn Metadaten vorhanden sind, zeige zusätzliche Informationen
            if (metadata) {
                // Erstelle Metadaten-Anzeige
                const metaDiv = document.createElement('div');
                metaDiv.className = 'image-metadata';
                
                // Formatiertes Datum
                if (metadata.timestamp) {
                    const timestamp = new Date(metadata.timestamp);
                    const dateText = document.createElement('span');
                    dateText.className = 'metadata-date';
                    dateText.textContent = timestamp.toLocaleDateString() + ' ' + timestamp.toLocaleTimeString();
                    metaDiv.appendChild(dateText);
                }
                
                // Tags anzeigen, falls vorhanden
                if (metadata.tags) {
                    try {
                        const tags = JSON.parse(metadata.tags);
                        if (tags && Object.keys(tags).length > 0) {
                            const tagsDiv = document.createElement('div');
                            tagsDiv.className = 'metadata-tags';
                            
                            for (const [key, value] of Object.entries(tags)) {
                                const tagSpan = document.createElement('span');
                                tagSpan.className = 'tag';
                                tagSpan.textContent = `${key}: ${value}`;
                                tagsDiv.appendChild(tagSpan);
                            }
                            
                            metaDiv.appendChild(tagsDiv);
                        }
                    } catch (e) {
                        console.error('Fehler beim Parsen der Tags:', e);
                    }
                }
                
                imgContainer.appendChild(metaDiv);
            } else {
                // Wenn keine Metadaten vorhanden sind, erstelle welche mit aktueller Zeit
                const now = new Date();
                saveImageMetadata(photo, {
                    timestamp: now.toISOString(),
                    tags: { event: 'Unbekannt' }
                });
            }
            
            galleryDiv.appendChild(imgContainer);
            
            // Klick-Handler für Vollbildanzeige hinzufügen
            img.addEventListener('click', () => {
                showFullscreenImage(photo, metadata);
                // Jede Interaktion mit einem Bild setzt den Timeout zurück
                resetGalleryTimeout();
            });
        }
        
    } catch (err) {
        console.error('Fehler beim Laden der Galerie:', err);
        galleryDiv.innerHTML = '<div class="gallery-error">Fehler beim Laden der Galerie.</div>';
    }
}

/**
 * Zeigt ein Bild im Vollbild-Modus an
 * @param {string} photoName - Der Dateiname des Fotos
 * @param {Object} metadata - Die Metadaten des Bildes (optional)
 */
async function showFullscreenImage(photoName, metadata = null) {
    // Timeout zurücksetzen
    resetGalleryTimeout();
    
    // Falls keine Metadaten übergeben wurden, versuche sie aus der Datenbank zu laden
    if (!metadata) {
        metadata = await getImageMetadata(photoName);
    }
    
    // Erstelle oder hole das existierende Fullscreen-Container-Element
    let fullscreenContainer = document.getElementById('fullscreen-container');
    
    if (!fullscreenContainer) {
        fullscreenContainer = document.createElement('div');
        fullscreenContainer.id = 'fullscreen-container';
        document.body.appendChild(fullscreenContainer);
        
        // Event-Listener zum Schließen bei Klick hinzufügen
        fullscreenContainer.addEventListener('click', (e) => {
            if (e.target === fullscreenContainer) {
                closeFullscreen();
            }
        });
        
        // Event-Listener für ESC-Taste zum Schließen
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeFullscreen();
            }
        });
    }
    
    // Container anzeigen und mit Inhalt füllen
    fullscreenContainer.className = 'fullscreen-active';
    
    // Bild-Element
    const img = document.createElement('img');
    img.src = '/photos/gallery/' + photoName;
    img.alt = 'Foto in Vollansicht';
    img.id = 'fullscreen-image';
    
    // Metadaten-Container
    const metaContainer = document.createElement('div');
    metaContainer.className = 'fullscreen-metadata';
    
    let metaHTML = '';
    
    if (metadata) {
        let timestamp = 'Unbekannt';
        if (metadata.timestamp) {
            const date = new Date(metadata.timestamp);
            timestamp = `${date.toLocaleDateString()} ${date.toLocaleTimeString()}`;
        }
        
        metaHTML += `<div class="meta-timestamp">Aufnahmedatum: ${timestamp}</div>`;
        
        // Tags anzeigen, falls vorhanden
        if (metadata.tags) {
            try {
                const tags = JSON.parse(metadata.tags);
                if (tags && Object.keys(tags).length > 0) {
                    metaHTML += '<div class="meta-tags">Tags: ';
                    for (const [key, value] of Object.entries(tags)) {
                        metaHTML += `<span class="tag">${key}: ${value}</span>`;
                    }
                    metaHTML += '</div>';
                }
            } catch (e) {
                console.error('Fehler beim Parsen der Tags:', e);
            }
        }
        
        // Bearbeiten-Button für Tags
        metaHTML += `<button id="edit-tags-btn" class="btn">Tags bearbeiten</button>`;
    }
    
    // Schließen-Button
    metaHTML += `<button id="close-fullscreen-btn" class="btn btn-close">Schließen</button>`;
    
    metaContainer.innerHTML = metaHTML;
    
    // Container leeren und neue Elemente einfügen
    fullscreenContainer.innerHTML = '';
    fullscreenContainer.appendChild(img);
    fullscreenContainer.appendChild(metaContainer);
    
    // Event-Listener für Buttons
    document.getElementById('close-fullscreen-btn').addEventListener('click', closeFullscreen);
    
    const editTagsBtn = document.getElementById('edit-tags-btn');
    if (editTagsBtn) {
        editTagsBtn.addEventListener('click', () => {
            openTagEditor(photoName, metadata);
        });
    }
}

/**
 * Schließt die Vollbildansicht
 */
function closeFullscreen() {
    const fullscreenContainer = document.getElementById('fullscreen-container');
    if (fullscreenContainer) {
        fullscreenContainer.className = '';
    }
}

/**
 * Öffnet den Tag-Editor für ein Bild
 * @param {string} photoName - Der Dateiname des Bildes
 * @param {Object} metadata - Die aktuellen Metadaten
 */
async function openTagEditor(photoName, metadata) {
    // Einfacher Dialog zum Bearbeiten der Tags
    const tagsStr = metadata && metadata.tags ? metadata.tags : '{}';
    let tags = {};
    
    try {
        tags = JSON.parse(tagsStr);
    } catch (e) {
        console.error('Fehler beim Parsen der Tags:', e);
        tags = {};
    }
    
    // Erstelle ein Modal für die Tag-Bearbeitung
    const modal = document.createElement('div');
    modal.className = 'tag-editor-modal';
    
    let modalContent = `
        <div class="tag-editor">
            <h3>Tags bearbeiten</h3>
            <div class="tag-form">
                <div class="tag-row">
                    <input type="text" id="tag-key" placeholder="Tag-Name (z.B. Event)" value="Event">
                    <input type="text" id="tag-value" placeholder="Wert (z.B. Hochzeit)">
                    <button id="add-tag-btn" class="btn">Hinzufügen</button>
                </div>
                <div class="current-tags" id="current-tags">
    `;
    
    // Aktuelle Tags anzeigen
    for (const [key, value] of Object.entries(tags)) {
        modalContent += `
            <div class="tag-item" data-key="${key}">
                <span>${key}: ${value}</span>
                <button class="remove-tag-btn" data-key="${key}">×</button>
            </div>
        `;
    }
    
    modalContent += `
                </div>
            </div>
            <div class="tag-editor-actions">
                <button id="save-tags-btn" class="btn btn-primary">Speichern</button>
                <button id="cancel-tags-btn" class="btn">Abbrechen</button>
            </div>
        </div>
    `;
    
    modal.innerHTML = modalContent;
    document.body.appendChild(modal);
    
    // Event-Listener für Buttons
    document.getElementById('add-tag-btn').addEventListener('click', () => {
        const key = document.getElementById('tag-key').value.trim();
        const value = document.getElementById('tag-value').value.trim();
        
        if (key && value) {
            // Tag zur Liste hinzufügen
            tags[key] = value;
            updateTagsList();
            
            // Felder zurücksetzen
            document.getElementById('tag-value').value = '';
        }
    });
    
    document.getElementById('save-tags-btn').addEventListener('click', async () => {
        // Tags in Metadata aktualisieren
        const updatedMetadata = {
            ...metadata,
            tags: JSON.stringify(tags)
        };
        
        // In Datenbank speichern
        await saveImageMetadata(photoName, updatedMetadata);
        
        // Modal schließen und Vollbildansicht aktualisieren
        document.body.removeChild(modal);
        showFullscreenImage(photoName, updatedMetadata);
    });
    
    document.getElementById('cancel-tags-btn').addEventListener('click', () => {
        // Modal schließen ohne zu speichern
        document.body.removeChild(modal);
    });
    
    // Funktion zum Aktualisieren der Tag-Liste im Dialog
    function updateTagsList() {
        const tagsList = document.getElementById('current-tags');
        tagsList.innerHTML = '';
        
        for (const [key, value] of Object.entries(tags)) {
            const tagItem = document.createElement('div');
            tagItem.className = 'tag-item';
            tagItem.dataset.key = key;
            
            tagItem.innerHTML = `
                <span>${key}: ${value}</span>
                <button class="remove-tag-btn" data-key="${key}">×</button>
            `;
            
            tagsList.appendChild(tagItem);
            
            // Event-Listener für Löschen-Button
            tagItem.querySelector('.remove-tag-btn').addEventListener('click', function() {
                const tagKey = this.dataset.key;
                delete tags[tagKey];
                updateTagsList();
            });
        }
    }
    
    // Initialen Event-Listener für Löschen-Buttons hinzufügen
    document.querySelectorAll('.remove-tag-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const tagKey = this.dataset.key;
            delete tags[tagKey];
            updateTagsList();
        });
    });
}
