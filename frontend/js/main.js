// ------------------------------------------------------------------------------
// main.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Interaktion der Fotobox-Weboberfläche (z.B. Fotoaufnahme,
// Galerieanzeige, Kommunikation mit Backend per HTTP).
// [Optional: Event-Handler, AJAX, DOM-Manipulation.]
// ------------------------------------------------------------------------------

// Globale Konstante für das Admin-Passwort (nur Demo, produktiv serverseitig prüfen!)
// const ADMIN_PASS = 'fotobox2025'; // ENTFERNT, jetzt serverseitig
// ------------------------------------------------------------------------------
// Funktionsblock: Galerie- und Aufnahmeansicht (index.html)
// ------------------------------------------------------------------------------
// Funktion: Steuert Umschaltung zwischen Galerie- und Aufnahmeansicht, Timeout-
// Handling, Eventname-Anzeige und Fotoladen.
// ------------------------------------------------------------------------------

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

// ------------------------------------------------------------------------------
// Funktionsblock: Update & Backup Buttons
// ------------------------------------------------------------------------------
// Funktion: Steuert die separaten Buttons für Backup und Update, Statusanzeige.
// ------------------------------------------------------------------------------

// Update & Backup Buttons getrennt
if(document.getElementById('backupBtn')) {
    document.getElementById('backupBtn').onclick = function() {
        const status = document.getElementById('updateStatus');
        status.textContent = 'Backup läuft ...';
        fetch('/api/backup', { method: 'POST' })
            .then(r => r.text())
            .then(txt => {
                status.textContent = txt || 'Backup abgeschlossen.';
            })
            .catch(()=>{
                status.textContent = 'Fehler beim Backup!';
            });
    };
}
if(document.getElementById('updateBtn')) {
    const updateBtn = document.getElementById('updateBtn');
    const updateInfoText = document.getElementById('updateInfoText');
    const versionInfo = document.getElementById('versionInfo');
    const updateExplanation = document.getElementById('updateExplanation');
    updateBtn.onclick = function() {
        showAutosaveToast('Update läuft ...', true);
        fetch('/api/update', { method: 'POST' })
            .then(r => r.text())
            .then(txt => {
                showAutosaveToast('Update abgeschlossen.', true);
            })
            .catch(()=>{
                showAutosaveToast('Fehler beim Update!', false);
            });
    };
    // Prüfe, ob ein Update verfügbar ist und zeige immer den Button
    fetch('/api/update', { method: 'GET' })
        .then(r => r.json())
        .then(data => {
            // Zeige Button immer, aber aktiviere/deaktiviere je nach Update
            updateBtn.style.display = '';
            updateBtn.disabled = !data.update_available;
            if(data.update_available) {
                updateBtn.classList.remove('disabled');
                updateBtn.title = '';
                if(updateInfoText) {
                    updateInfoText.style.display = 'none';
                }
                if(versionInfo) {
                    versionInfo.innerHTML = `Lokale Version: <b>${data.local_version||'-'}</b><br>Online-Version: <b>${data.remote_version||'-'}</b>`;
                }
                if(updateExplanation) {
                    updateExplanation.textContent = 'Es ist ein Update verfügbar. Bitte führen Sie das Update aus, um die neueste Version zu erhalten.';
                }
            } else {
                updateBtn.classList.add('disabled');
                updateBtn.title = 'System ist aktuell';
                if(updateInfoText) {
                    updateInfoText.style.display = '';
                }
                if(versionInfo) {
                    versionInfo.innerHTML = `Lokale Version: <b>${data.local_version||'-'}</b><br>Online-Version: <b>${data.remote_version||'-'}</b>`;
                }
                if(updateExplanation) {
                    updateExplanation.textContent = 'Ihr System ist auf dem aktuellen Stand.';
                }
            }
        })
        .catch(()=>{
            updateBtn.style.display = '';
            updateBtn.disabled = true;
            if(updateInfoText) updateInfoText.style.display = 'none';
            if(versionInfo) versionInfo.innerHTML = 'Versionsprüfung fehlgeschlagen.';
            if(updateExplanation) updateExplanation.textContent = 'Die Update-Prüfung konnte nicht durchgeführt werden.';
        });
}

// ------------------------------------------------------------------------------
// Funktionsblock: Autosave für Konfigurationsfelder
// ------------------------------------------------------------------------------
// Funktion: Automatisches Speichern von Konfigurationsfeldern mit Toast-Anzeige.
// ------------------------------------------------------------------------------

// Autosave für Konfigurationsseite
function showAutosaveToast(msg, success=true) {
    const toast = document.getElementById('autosaveToast');
    toast.textContent = msg;
    toast.className = success ? 'success' : 'error';
    toast.style.display = 'block';
    clearTimeout(window._autosaveToastTimeout);
    window._autosaveToastTimeout = setTimeout(() => {
        toast.style.display = 'none';
    }, 7000);
}

function autosaveConfigField(field, label) {
    field.addEventListener('change', function() {
        const config = {};
        if(field.name === 'photo_timer') {
            let val = parseInt(field.value, 10);
            if(isNaN(val) || val < 2 || val > 10) {
                showAutosaveToast('Timer muss zwischen 2 und 10 Sekunden liegen!', false);
                field.value = 5;
                return;
            }
            config['photo_timer'] = val;
        } else {
            config[field.name] = (field.type === 'number') ? parseInt(field.value, 10) : field.value;
            if(field.name === 'gallery_timeout') config['gallery_timeout_ms'] = config['gallery_timeout']*1000;
        }
        fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        }).then(r => {
            if(r.ok) {
                showAutosaveToast(label + ' angepasst ...', true);
            } else {
                showAutosaveToast(label + ' konnte nicht gespeichert werden!', false);
            }
        }).catch(() => {
            showAutosaveToast(label + ' konnte nicht gespeichert werden!', false);
        });
    });
}

if(document.getElementById('configForm')) {
    const fields = [
        {id:'color_mode', label:'Farbschema'},
        {id:'gallery_timeout', label:'Galerie-Timeout'},
        {id:'event_name', label:'Eventname'},
        {id:'storage_path', label:'Speicherpfad'},
        {id:'camera_mode', label:'Kamera-Modus'},
        {id:'photo_timer', label:'Foto-Timer'}
    ];
    fields.forEach(f => {
        const el = document.getElementById(f.id);
        if(el) autosaveConfigField(el, f.label);
    });
    // Speziell für Auflösung (Breite/Höhe)
    const resW = document.getElementById('resolution_width');
    const resH = document.getElementById('resolution_height');
    if(resW && resH) {
        [resW, resH].forEach(field => {
            field.addEventListener('change', function() {
                const config = {
                    resolution_width: parseInt(resW.value, 10) || '',
                    resolution_height: parseInt(resH.value, 10) || ''
                };
                fetch('/api/settings', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(config)
                }).then(function(r) {
                    if(r.ok) {
                        showAutosaveToast('Foto-Auflösung angepasst ...', true);
                    } else {
                        showAutosaveToast('Foto-Auflösung konnte nicht gespeichert werden!', false);
                    }
                }).catch(function() {
                    showAutosaveToast('Foto-Auflösung konnte nicht gespeichert werden!', false);
                });
            });
        });
    }
}

// ------------------------------------------------------------------------------
// Funktionsblock: Farbschema-Umschaltung
// ------------------------------------------------------------------------------
// Funktion: Setzt und speichert das Farbschema (Light/Dark/Auto) für die Oberfläche.
// ------------------------------------------------------------------------------

// Farbschema-Umschaltung (Light/Dark/Auto)
function applyColorMode(mode) {
    if (mode === 'auto') {
        const hour = new Date().getHours();
        if (hour >= 7 && hour < 20) {
            document.body.classList.remove('dark');
        } else {
            document.body.classList.add('dark');
        }
    } else if (mode === 'dark') {
        document.body.classList.add('dark');
    } else {
        document.body.classList.remove('dark');
    }
}
function getColorMode() {
    return localStorage.getItem('color_mode') || 'auto';
}
function setColorMode(mode) {
    localStorage.setItem('color_mode', mode);
    applyColorMode(mode);
}
// Initial anwenden
applyColorMode(getColorMode());
// Wenn auf der Konfigurationsseite, Auswahlfeld synchronisieren und speichern
if (document.getElementById('color_mode')) {
    document.getElementById('color_mode').value = getColorMode();
    document.getElementById('color_mode').onchange = function() {
        setColorMode(this.value);
    };
}

// ------------------------------------------------------------------------------
// Funktionsblock: Header/Footer Dynamik
// ------------------------------------------------------------------------------
// Funktion: Setzt dynamisch den Header-Titel und Footer-Text je nach Seite/Event.
// ------------------------------------------------------------------------------

// header-footer-dynamik
// -------------------------------------------------------------------------------
// Funktion: Setzt dynamisch den Header-Titel (Eventname/Projektnamen)
// -------------------------------------------------------------------------------
function setHeaderTitle(title) {
    var el = document.getElementById('headerTitle');
    if(el) el.textContent = title || 'Fotobox';
}
// Für index.html: Eventname dynamisch aus Settings
if(document.getElementById('headerTitle') && window.location.pathname.endsWith('index.html')) {
    fetch('/api/settings').then(function(r){return r.json();}).then(function(config) {
        setHeaderTitle(config.event_name || 'Fotobox');
        // Footer ggf. auch Eventname anzeigen
        var f = document.getElementById('footerText');
        if(f && config.event_name) f.textContent = '© 2025 ' + config.event_name;
    });
}
// Für config.html und start.html statisch (Fotobox/Fotobox Konfiguration)
if(document.getElementById('headerTitle') && (window.location.pathname.endsWith('config.html') || window.location.pathname.endsWith('start.html'))) {
    setHeaderTitle(document.title.replace('Start','Fotobox').replace('Konfiguration','Fotobox Konfiguration'));
    // Footer bleibt © 2025 Fotobox
}

// ------------------------------------------------------------------------------
// Funktionsblock: Hamburger-Menü für alle Seiten
// ------------------------------------------------------------------------------
// Funktion: Steuert das Hamburger-Menü im Header (öffnen, schließen, Fokus, ESC, Mausverlassen, Auswahl)
// ------------------------------------------------------------------------------
function setupHamburgerMenu() {
    const btn = document.getElementById('hamburgerBtn');
    const menu = document.getElementById('headerMenu');
    if(btn && menu) {
        function closeMenu() {
            menu.style.display = 'none';
            btn.setAttribute('aria-expanded','false');
        }
        function openMenu() {
            menu.style.display = 'block';
            btn.setAttribute('aria-expanded','true');
            const first = menu.querySelector('a');
            if(first) first.focus();
        }
        btn.onclick = function(e) {
            e.stopPropagation();
            if(menu.style.display==='block') {
                closeMenu();
            } else {
                openMenu();
            }
        };
        btn.onkeydown = function(e) {
            if(e.key==='Enter' || e.key===' ') {
                e.preventDefault();
                btn.click();
            }
        };
        document.addEventListener('click', function(e){
            if(menu.style.display==='block' && !menu.contains(e.target) && !btn.contains(e.target)) {
                closeMenu();
            }
        });
        document.addEventListener('keydown', function(e){
            if(e.key==='Escape') closeMenu();
        });
        menu.querySelectorAll('a').forEach(a=>{
            a.addEventListener('click', closeMenu);
        });
        menu.addEventListener('mouseleave', closeMenu);
        closeMenu();
    }
}

document.addEventListener('DOMContentLoaded', function() {
    setupHamburgerMenu();
    // Splash-Checkbox-Logik für start.html
    var splashBox = document.getElementById('showSplashConfig') || document.getElementById('disableSplash');
    if(splashBox) {
        fetch('/api/settings').then(r=>r.json()).then(settings => {
            var showSplash = (settings.show_splash === undefined || settings.show_splash === '1' || settings.show_splash === 1);
            if(splashBox.id === 'showSplashConfig') {
                splashBox.checked = showSplash;
            } else {
                splashBox.checked = !showSplash;
                if(!showSplash && window.location.pathname.endsWith('start.html')) {
                    window.location.href = 'index.html';
                }
            }
        });
        splashBox.addEventListener('change', function() {
            var val = (this.id === 'showSplashConfig') ? (this.checked ? '1' : '0') : (this.checked ? '0' : '1');
            fetch('/api/settings', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ show_splash: val })
            });
        });
    }
    // Footer-Logik für kleine Bildschirme (nur auf Seiten mit Footer)
    var footer = document.getElementById('mainFooter');
    if(footer) {
        function handleFooterVisibility() {
            if(window.innerWidth <= 900) {
                var scrollBottom = window.innerHeight + window.scrollY >= document.body.offsetHeight - 2;
                footer.style.display = scrollBottom ? 'block' : 'none';
            } else {
                footer.style.display = 'block';
            }
        }
        window.addEventListener('scroll', handleFooterVisibility);
        window.addEventListener('resize', handleFooterVisibility);
        handleFooterVisibility();
    }
});

// Globale Initialisierung für Header: Datum/Uhrzeit, Eventtitel, Menü-Hervorhebung
(function() {
    // Datum und Uhrzeit
    function updateDateTime() {
        const dateEl = document.getElementById('headerDate');
        const timeEl = document.getElementById('headerTime');
        if (!dateEl || !timeEl) return;
        const now = new Date();
        dateEl.textContent = now.toLocaleDateString('de-DE');
        timeEl.textContent = now.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
    }
    setInterval(updateDateTime, 1000);
    updateDateTime();

    // Eventtitel dynamisch setzen
    const headerTitle = document.getElementById('headerTitle');
    if (headerTitle) {
        fetch('/api/settings').then(r => r.json()).then(data => {
            headerTitle.textContent = data.event_title || 'Fotobox';
        }).catch(() => {
            headerTitle.textContent = 'Fotobox';
        });
    }

    // Aktuelle Seite im Menü hervorheben
    const menuLinks = document.querySelectorAll('#headerMenu a');
    if (menuLinks.length) {
        const current = window.location.pathname.split('/').pop() || 'capture.html';
        menuLinks.forEach(link => {
            if (link.getAttribute('href') === current) {
                link.classList.add('active');
            }
        });
    }
})();

// Dynamische Generierung des Overlay-Menüs, aktuelle Seite wird ausgeblendet
(function() {
    const menuItems = [
        { href: 'capture.html', label: 'Aufnahme' },
        { href: 'gallery.html', label: 'Galerie' },
        { href: 'contact.html', label: 'Kontakt' },
        { href: 'settings.html', label: 'Einstellungen' }
    ];
    const current = window.location.pathname.split('/').pop() || 'capture.html';
    const menu = document.getElementById('headerMenu');
    if (menu) {
        menu.innerHTML = '';
        menuItems.forEach(item => {
            if (item.href !== current) {
                const a = document.createElement('a');
                a.href = item.href;
                a.textContent = item.label;
                menu.appendChild(a);
            }
        });
    }
    // Hamburger-Menü-Logik (Öffnen/Schließen)
    const hamburger = document.getElementById('hamburgerBtn');
    if (hamburger && menu) {
        hamburger.onclick = function() {
            const expanded = hamburger.getAttribute('aria-expanded') === 'true';
            hamburger.setAttribute('aria-expanded', !expanded);
            menu.style.display = expanded ? 'none' : 'block';
        };
        document.addEventListener('click', function(e) {
            if (!menu.contains(e.target) && e.target !== hamburger) {
                menu.style.display = 'none';
                hamburger.setAttribute('aria-expanded', 'false');
            }
        });
    }
})();
