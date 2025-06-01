// main.js
// -----------------------------------------------------------------------------
// Funktion: Zentrales JavaScript für das Fotobox-Frontend
// -----------------------------------------------------------------------------

// index.html Funktionen
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

// config.html Funktionen
if (document.getElementById('loginForm')) {
    // Passwortschutz
    const ADMIN_PASS = 'fotobox2025'; // TODO: Sicher speichern!
    document.getElementById('loginForm').onsubmit = function(e) {
        e.preventDefault();
        if(document.getElementById('adminPassword').value === ADMIN_PASS) {
            document.getElementById('loginForm').style.display = 'none';
            document.getElementById('configForm').style.display = '';
            document.getElementById('updateForm').style.display = '';
            loadConfigFromServer();
        } else {
            document.getElementById('loginStatus').textContent = 'Falsches Passwort!';
        }
    };
    // Einstellungen vom Server laden
    function loadConfigFromServer() {
        fetch('/api/settings').then(r=>r.json()).then(config => {
            if(config.camera_mode) document.getElementById('camera_mode').value = config.camera_mode;
            if(config.resolution) document.getElementById('resolution').value = config.resolution;
            if(config.storage_path) document.getElementById('storage_path').value = config.storage_path;
            if(config.event_name) document.getElementById('event_name').value = config.event_name;
            if(config.gallery_timeout_ms) document.getElementById('gallery_timeout').value = Math.round(config.gallery_timeout_ms/1000);
        });
    }
    // Einstellungen speichern
    document.getElementById('configForm').onsubmit = function(e) {
        e.preventDefault();
        const config = {
            camera_mode: document.getElementById('camera_mode').value,
            resolution: document.getElementById('resolution').value,
            storage_path: document.getElementById('storage_path').value,
            event_name: document.getElementById('event_name').value,
            gallery_timeout_ms: parseInt(document.getElementById('gallery_timeout').value,10)*1000||60000
        };
        fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        }).then(()=>{
            document.getElementById('status').textContent = 'Gespeichert!';
            setTimeout(()=>document.getElementById('status').textContent='', 1500);
        });
    };
    // Update/Backup auslösen
    document.getElementById('updateForm').onsubmit = function(e) {
        e.preventDefault();
        document.getElementById('updateStatus').textContent = 'Update läuft ...';
        fetch('/update', { method: 'POST' })
            .then(r => r.text())
            .then(txt => {
                document.getElementById('updateStatus').textContent = txt || 'Update/Backup abgeschlossen.';
            })
            .catch(()=>{
                document.getElementById('updateStatus').textContent = 'Fehler beim Update/Backup!';
            });
    };
}
