// ------------------------------------------------------------------------------
// main.js
// ------------------------------------------------------------------------------
// Funktion: Steuert die Interaktion der Fotobox-Weboberfläche (z.B. Fotoaufnahme,
// Galerieanzeige, Kommunikation mit Backend per HTTP).
// ------------------------------------------------------------------------------

// Hauptinitialisierung - wird ausgeführt, wenn das DOM geladen ist
document.addEventListener('DOMContentLoaded', function() {
    // Datum und Uhrzeit initialisieren
    updateDateTime();
    setInterval(updateDateTime, 60000); // Aktualisiere jede Minute
    
    // Menü initialisieren
    initMenu();
    
    // Farbschema anwenden
    applyColorMode(getColorMode());
    
    // Footer-Logik für kleine Bildschirme (nur auf Seiten mit Footer)
    handleFooterVisibility();
    
    // Weitere Initialisierungen je nach Seite
    initPageSpecificFeatures();
});

// ------------------------------------------------------------------------------
// Funktionsblock: Menüführung
// ------------------------------------------------------------------------------
// Funktion: Verwaltet das Hamburger-Menü und die Navigation
// ------------------------------------------------------------------------------

// Funktion zum Initialisieren des Menüs
function initMenu() {
    // Menü-Elemente definieren - ohne install.html gemäß Anforderungen
    const menuItems = [
        { text: 'Home', href: 'capture.html' }, // Geändert: "Home" statt "Startseite"
        { text: 'Galerie', href: 'gallery.html' },
        { text: 'Kontakt', href: 'contact.html' },
        { text: 'Einstellungen', href: 'settings.html' }
    ];
      // Aktuelle Seite ermitteln
    const currentPage = window.location.pathname.split('/').pop() || 'capture.html';
    
    // Menü-Container und Button holen
    const menuOverlay = document.getElementById('menuOverlay');
    const hamburgerBtn = document.getElementById('hamburgerBtn');
    
    if (menuOverlay && hamburgerBtn) {
        // Existierende Menüpunkte entfernen
        menuOverlay.innerHTML = '';
        
        // Menüpunkte erstellen (ohne die aktuelle Seite)
        menuItems.forEach(item => {
            if (item.href !== currentPage) {
                const link = document.createElement('a');
                link.href = item.href;
                link.textContent = item.text;
                menuOverlay.appendChild(link);
            }
        });
          // Klick-Handler für den Hamburger-Button
        hamburgerBtn.addEventListener('click', function(event) {
            event.stopPropagation(); // Stoppt das Event von der Weiterleitung
            menuOverlay.classList.toggle('visible');
            
            // Toggle body overflow, um Scrollbars zu verhindern, wenn das Menü offen ist
            if (menuOverlay.classList.contains('visible')) {
                document.body.style.overflow = 'hidden'; // Verhindert Scrollen, wenn Menü geöffnet
            } else {
                document.body.style.overflow = ''; // Stellt Standard wieder her
            }
        });
        
        // Klick außerhalb des Menüs schließt es
        document.addEventListener('click', function(event) {
            if (menuOverlay.classList.contains('visible') && 
                !menuOverlay.contains(event.target) && 
                event.target !== hamburgerBtn) {
                menuOverlay.classList.remove('visible');
                document.body.style.overflow = ''; // Stellt Scrolling wieder her
            }
        });
          // Stoppe Bubbling, wenn auf ein Menüelement geklickt wird
        menuOverlay.addEventListener('click', function(event) {
            event.stopPropagation();
        });
        
        // Escape-Taste schließt das Menü
        document.addEventListener('keydown', function(event) {
            if (event.key === 'Escape' && menuOverlay.classList.contains('visible')) {
                menuOverlay.classList.remove('visible');
                document.body.style.overflow = ''; // Stellt Scrolling wieder her
            }
        });
    }
}

// ------------------------------------------------------------------------------
// Funktionsblock: Header/Footer Dynamik
// ------------------------------------------------------------------------------
// Funktion: Steuert die Header- und Footer-Elemente
// ------------------------------------------------------------------------------

// Funktion zur Aktualisierung von Datum und Uhrzeit
function updateDateTime() {
    const now = new Date();
    
    // Formatiere Datum als DD.MM.YYYY
    const date = now.getDate().toString().padStart(2, '0') + '.' +
                (now.getMonth() + 1).toString().padStart(2, '0') + '.' +
                now.getFullYear();
    
    // Formatiere Uhrzeit als HH:MM
    const time = now.getHours().toString().padStart(2, '0') + ':' +
                now.getMinutes().toString().padStart(2, '0');
    
    // Aktualisiere die Anzeige, falls die Elemente existieren
    if (document.getElementById('headerDate')) {
        document.getElementById('headerDate').textContent = date;
    }
    if (document.getElementById('headerTime')) {
        document.getElementById('headerTime').textContent = time;
    }
}

// Footer-Sichtbarkeit je nach Bildschirmgröße
function handleFooterVisibility() {
    const footer = document.getElementById('mainFooter');
    if (footer) {
        const checkVisibility = function() {
            if (window.innerWidth <= 900) {
                const scrollBottom = window.innerHeight + window.scrollY >= document.body.offsetHeight - 2;
                footer.style.display = scrollBottom ? 'block' : 'none';
            } else {
                footer.style.display = 'block';
            }
        };
        
        window.addEventListener('scroll', checkVisibility);
        window.addEventListener('resize', checkVisibility);
        checkVisibility();
    }
}

// Header-Titel dynamisch setzen
function setHeaderTitle(title) {
    // Fallback-Titel, wenn kein Titel übergeben wurde
    const displayTitle = title && title.trim() ? title : 'Fotobox';
    
    // Titel im Header setzen
    const headerTitle = document.getElementById('headerTitle');
    if (headerTitle) {
        headerTitle.textContent = displayTitle;
    }
    
    // Korrekte Verlinkung des Header-Titels entsprechend der Doku
    // Header-Titel verlinkt auf install.html (Einstellungen) gemäß frontend_routing.md
    const headerTitleLink = document.getElementById('headerTitleLink');
    if (headerTitleLink) {
        headerTitleLink.href = 'install.html';
    }
    
    // Zusätzlich den Titel im Browser-Tab aktualisieren
    document.title = displayTitle;
    
    // Im Footer den Copyright-Text aktualisieren, falls vorhanden
    const footerText = document.getElementById('footerText');
    if (footerText) {
        const currentYear = new Date().getFullYear();
        footerText.textContent = `© ${currentYear} ${displayTitle}`;
    }
}

// ------------------------------------------------------------------------------
// Funktionsblock: Farbschema-Umschaltung
// ------------------------------------------------------------------------------
// Funktion: Setzt und speichert das Farbschema (Light/Dark/Auto)
// ------------------------------------------------------------------------------

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

// ------------------------------------------------------------------------------
// Funktionsblock: Seitenspezifische Funktionen
// ------------------------------------------------------------------------------
// Funktion: Führt je nach aktueller Seite spezifische Initialisierungen durch
// ------------------------------------------------------------------------------

function initPageSpecificFeatures() {    // Erfasse den Seitentyp basierend auf URL oder DOM-Elementen
    const path = window.location.pathname;
    const isCapturePage = path.includes('capture.html') || document.getElementById('captureView');
    const isGalleryPage = path.includes('gallery.html') || document.getElementById('galleryView');
    const isSettingsPage = path.includes('settings.html') || document.getElementById('configForm');
    const isSplashPage = path.endsWith('/') || path.endsWith('index.html') || document.getElementById('splashOverlay');
    
    // Lade Event-Titel aus API für alle Seiten außer Splash und Install
    if (!isSplashPage && !path.includes('install.html')) {
        fetch('/api/settings').then(r => r.json()).then(config => {
            // Setze den Event-Titel im Header
            setHeaderTitle(config.event_name || 'Fotobox');
            
            // Nur für capture.html: Zeige Event-Name im Content-Bereich
            if (isCapturePage && config.event_name && document.getElementById('eventName')) {
                document.getElementById('eventName').textContent = config.event_name;
            }
        }).catch(() => {
            setHeaderTitle('Fotobox');
        });
    }
    
    // Initialisiere Features für die Galerieseite
    if (isGalleryPage) {
        // Hier könnte die Galerie-Logik implementiert werden
    }
    
    // Initialisiere Features für die Einstellungsseite
    if (isSettingsPage) {
        // Farbschema-Einstellungen synchronisieren
        const colorModeSelect = document.getElementById('color_mode');
        if (colorModeSelect) {
            colorModeSelect.value = getColorMode();
            colorModeSelect.onchange = function() {
                setColorMode(this.value);
            };
        }
    }
}

// ------------------------------------------------------------------------------
// Ende der bereinigten main.js
// ------------------------------------------------------------------------------