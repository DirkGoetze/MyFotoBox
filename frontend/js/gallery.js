// gallery.js
// Enthält alle Funktionen und Event-Handler, die ausschließlich für die Galerie- und Aufnahmeansicht (index.html, gallery.html) benötigt werden.

if (document.getElementById('showGallery')) {
    let galleryTimeout = null;
    let galleryTimeoutMs = 60000; // Default 60s, wird aus Settings geladen
    let lastInteraction = Date.now();

    function resetGalleryTimeout() {
        lastInteraction = Date.now();
        if (galleryTimeout) clearTimeout(galleryTimeout);
        galleryTimeout = setTimeout(() => {
            if (document.getElementById('galleryView').style.display !== 'none') {
                showCaptureView();
            }
        }, galleryTimeoutMs);
    }

    function showGalleryView() {
        document.getElementById('captureView').style.display = 'none';
        document.getElementById('galleryView').style.display = '';
        loadGalleryPhotos();
        resetGalleryTimeout();
        document.onmousemove = document.onkeydown = resetGalleryTimeout;
    }
    function showCaptureView() {
        document.getElementById('galleryView').style.display = 'none';
        document.getElementById('captureView').style.display = '';
        document.onmousemove = document.onkeydown = null;
    }
    document.getElementById('showGallery').onclick = showGalleryView;
    document.getElementById('showCapture').onclick = showCaptureView;
    document.getElementById('backBtn').onclick = showCaptureView;

    // Eventname aus Konfiguration anzeigen (per API)
    fetch('/api/settings').then(r=>r.json()).then(config => {
        if(config.event_name) {
            document.getElementById('eventName').textContent = config.event_name;
        }
        if(config.gallery_timeout_ms) {
            galleryTimeoutMs = parseInt(config.gallery_timeout_ms)||60000;
        }
    });
    async function loadPhotos() {
        const res = await fetch('/api/photos');
        const data = await res.json();
        const photosDiv = document.getElementById('photos');
        photosDiv.innerHTML = '';
        data.photos.forEach(photo => {
            const img = document.createElement('img');
            img.src = '/photos/' + photo;
            photosDiv.appendChild(img);
        });
    }
    async function loadGalleryPhotos() {
        const res = await fetch('/api/gallery');
        const data = await res.json();
        const galleryDiv = document.getElementById('galleryPhotos');
        galleryDiv.innerHTML = '';
        data.photos.forEach(photo => {
            const img = document.createElement('img');
            img.src = '/photos/gallery/' + photo;
            galleryDiv.appendChild(img);
        });
    }
    document.getElementById('takePhotoBtn').onclick = async () => {
        await fetch('/api/take_photo', { method: 'POST' });
        loadPhotos();
    };
    loadPhotos();
    showCaptureView();
}

// ------------------------------------------------------------------------------
// gallery.js
// ------------------------------------------------------------------------------
// Funktion: Lädt die Galerie-Bilder dynamisch aus dem Backend und baut das DOM
//           für die Galerieansicht (gallery.html) auf.
// ------------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', () => {
    // Prüfen, ob wir auf der gallery.html sind
    const galleryDiv = document.getElementById('galleryPhotos');
    if (!galleryDiv) return;

    // Funktion: Lädt die Bildliste per API und rendert sie in die Galerie
    async function loadGalleryPhotos() {
        try {
            const res = await fetch('/api/gallery');
            if (!res.ok) throw new Error('Fehler beim Laden der Galerie');
            const data = await res.json();
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
            });
        } catch (err) {
            galleryDiv.innerHTML = '<div class="gallery-error">Fehler beim Laden der Galerie.</div>';
        }
    }

    // Initialer Aufruf
    loadGalleryPhotos();

    // Optional: Später kann hier ein Polling oder WebSocket für Live-Updates ergänzt werden
});
