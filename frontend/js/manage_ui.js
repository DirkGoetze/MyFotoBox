/**
 * @file manage_ui.js
 * @description UI-Management-Modul für Fotobox2
 * @module manage_ui
 */

import { log, error } from './manage_logging.js';
import { getSetting, setSetting } from './manage_database.js';

// ------------------------------------------------------------------------------
// Funktionsblock: Menüführung
// ------------------------------------------------------------------------------

/**
 * Initialisiert das Navigationsmenü
 */
export function initMenu() {
    // Menü-Elemente definieren (ohne install.html)
    const menuItems = [
        { text: 'Home', href: 'capture.html' },
        { text: 'Galerie', href: 'gallery.html' },
        { text: 'Kontakt', href: 'contact.html' },
        { text: 'Einstellungen', href: 'settings.html' },
        { text: 'Test-Tools', href: 'tests/index.html' }
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

/**
 * Aktualisiert das Datum und die Uhrzeit im Header
 */
export function updateDateTime() {
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

/**
 * Footer-Sichtbarkeit je nach Bildschirmgröße anpassen
 */
export function handleFooterVisibility() {
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

/**
 * Header-Titel dynamisch setzen
 * @param {string} title - Der zu setzende Titel
 */
export function setHeaderTitle(title) {
    // Fallback-Titel, wenn kein Titel übergeben wurde
    const displayTitle = title && title.trim() ? title : 'Fotobox';
    
    // Titel im Header setzen
    const headerTitle = document.getElementById('headerTitle');
    if (headerTitle) {
        headerTitle.textContent = displayTitle;
    }
      
    // Korrekte Verlinkung des Header-Titels
    const headerTitleLink = document.getElementById('headerTitleLink');
    if (headerTitleLink) {
        headerTitleLink.href = 'capture.html';
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
// Funktionsblock: Anzeigemodus-Umschaltung
// ------------------------------------------------------------------------------

/**
 * Wendet den ausgewählten Farbmodus an
 * @param {string} mode - Der anzuwendende Farbmodus ('light', 'dark', 'system')
 */
export function applyColorMode(mode) {
    if (mode === 'system') {
        // Nutze die Systemeinstellung über prefers-color-scheme, falls verfügbar
        if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
            document.body.classList.add('dark');
        } else {
            document.body.classList.remove('dark');
        }
        
        // Event-Listener für Änderungen der Systemeinstellung
        if (window.matchMedia) {
            window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
                if (getColorMode() === 'system') {
                    document.body.classList.toggle('dark', e.matches);
                }
            });
        }
    } else if (mode === 'dark') {
        document.body.classList.add('dark');
    } else {
        document.body.classList.remove('dark');
    }
}

/**
 * Gibt den aktuellen Farbmodus zurück
 * @returns {Promise<string>} Der aktuelle Farbmodus
 */
export async function getColorMode() {
    // Versuche zuerst DB, dann localStorage als Fallback
    const dbValue = await getSetting('color_mode', null);
    if (dbValue !== null) {
        return dbValue;
    }
    return localStorage.getItem('color_mode') || 'system';
}

/**
 * Setzt den Farbmodus
 * @param {string} mode - Der zu setzende Farbmodus
 * @returns {Promise<boolean>} Erfolg der Operation
 */
export async function setColorMode(mode) {
    // In DB speichern und als Fallback auch im localStorage
    await setSetting('color_mode', mode);
    localStorage.setItem('color_mode', mode); // Fallback
    applyColorMode(mode);
    return true;
}

// ------------------------------------------------------------------------------
// Funktionsblock: Seitenspezifische Funktionen
// ------------------------------------------------------------------------------

/**
 * Initialisierung der seitenspezifischen Features
 */
export function initPageSpecificFeatures() {
    // Erfasse den Seitentyp basierend auf URL oder DOM-Elementen
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
    
    // Initialisiere Features für die Einstellungsseite
    if (isSettingsPage) {
        // Farbschema-Einstellungen synchronisieren
        const colorModeSelect = document.getElementById('color_mode');
        if (colorModeSelect) {
            getColorMode().then(mode => {
                colorModeSelect.value = mode;
                colorModeSelect.onchange = function() {
                    setColorMode(this.value);
                };
            });
        }
    }
}

/**
 * Initialisiert die Basis-UI-Elemente der Seite
 * Diese Funktion sollte nach dem DOMContentLoaded Event aufgerufen werden
 */
export function initBaseUI() {
    // Anti-Cache für die Testphase
    initAntiCache();
    
    // Datum und Uhrzeit initialisieren
    updateDateTime();
    setInterval(updateDateTime, 60000); // Aktualisiere jede Minute
    
    // Menü initialisieren
    initMenu();
    
    // Farbschema anwenden
    getColorMode().then(mode => {
        applyColorMode(mode);
    });
    
    // Footer-Logik für kleine Bildschirme
    handleFooterVisibility();
    
    // Weitere Initialisierungen je nach Seite
    initPageSpecificFeatures();
    
    log('UI-Basisfunktionen initialisiert');
}

/**
 * Anti-Cache-Funktion für die Testphase
 * Fügt zu allen CSS und JS Dateien einen Timestamp als Query-Parameter hinzu,
 * um das Caching des Browsers zu umgehen
 */
function initAntiCache() {
    // Nur im Testmodus ausführen
    const isTestMode = true;
    
    if (isTestMode) {
        // Funktionalität, um dynamischen Timestamp zu CSS-Links hinzuzufügen
        function addTimestampToResources() {
            // Alle Link-Elemente (CSS) mit Timestamp versehen
            document.querySelectorAll('link[rel="stylesheet"]').forEach(link => {
                if (!link.href.includes('?v=')) {
                    link.href = link.href + '?v=' + new Date().getTime();
                }
            });
            
            // Alle Script-Elemente mit Timestamp versehen
            document.querySelectorAll('script[src]').forEach(script => {
                if (!script.src.includes('?v=')) {
                    script.src = script.src + '?v=' + new Date().getTime();
                }
            });
        }
        
        // Ausführen sobald das Skript geladen wird
        addTimestampToResources();
        
        // Zusätzlich ein Hotkey zum manuellen Neuladen ohne Cache (Strg+Shift+R)
        document.addEventListener('keydown', function(e) {
            if (e.ctrlKey && e.shiftKey && e.key === 'R') {
                e.preventDefault();
                window.location.reload(true); // True erzwingt Neuladen ohne Cache
            }
        });
        
        log('Anti-Cache-Maßnahmen für Testphase aktiviert');
    }
}

// Automatische Initialisierung
log('UI-Management-Modul geladen');
