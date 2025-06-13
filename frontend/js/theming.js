/**
 * @file theming.js
 * @description Theme-Management für die Fotobox2-Anwendung
 * @module theming
 */

import { EVENTS } from './constants.js';

/**
 * Speichert die verfügbaren Themes
 * @private
 * @type {Object}
 */
let _themes = {};

/**
 * Speichert das aktuelle Theme
 * @private
 * @type {string}
 */
let _currentTheme = '';

/**
 * Speichert das Standard-Theme
 * @private
 * @type {string}
 */
let _defaultTheme = '';

/**
 * Initialisiert das Theming-Modul mit verfügbaren Themes und Standardeinstellung
 * @param {Object} themes - Objekt mit Theme-Definitionen
 * @param {string} defaultTheme - Standard-Theme, das verwendet wird, wenn kein Theme gespeichert ist
 */
export function init(themes, defaultTheme) {
    _themes = themes || {};
    _defaultTheme = defaultTheme;
    
    // Versuche, das gespeicherte Theme zu laden
    const storedTheme = localStorage.getItem('theme');
    const themeToApply = storedTheme && _themes[storedTheme] ? storedTheme : defaultTheme;
    
    // Theme anwenden
    setTheme(themeToApply);
    
    console.log(`Theming initialisiert mit Theme: ${_currentTheme}`);
    
    // Event-Listener für Medien-Anfragen (automatischer Dark/Light Mode)
    const darkModeMediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    
    darkModeMediaQuery.addEventListener('change', (e) => {
        // Nur automatisch umschalten, wenn kein Theme gespeichert wurde
        if (!localStorage.getItem('theme')) {
            const newTheme = e.matches ? 'dark' : 'light';
            if (_themes[newTheme]) {
                setTheme(newTheme);
            }
        }
    });
}

/**
 * Setzt das aktuelle Theme und wendet die entsprechenden CSS-Variablen an
 * @param {string} themeName - Der Name des anzuwendenden Themes
 * @returns {boolean} True, wenn das Theme erfolgreich gesetzt wurde
 */
export function setTheme(themeName) {
    // Prüfe, ob das Theme existiert
    if (!_themes[themeName]) {
        console.warn(`Theme nicht gefunden: ${themeName}`);
        return false;
    }
    
    // Alte Theme-Klasse entfernen, falls vorhanden
    if (_currentTheme) {
        document.body.classList.remove(`theme-${_currentTheme}`);
    }
    
    // Theme in der Dokumentenwurzel setzen
    const themeVars = _themes[themeName];
    Object.entries(themeVars).forEach(([property, value]) => {
        document.documentElement.style.setProperty(property, value);
    });
    
    // Neue Theme-Klasse hinzufügen
    document.body.classList.add(`theme-${themeName}`);
    
    // Theme als aktuell markieren
    _currentTheme = themeName;
    
    // Theme im localStorage speichern
    localStorage.setItem('theme', themeName);
    
    // Informiere andere Komponenten über die Theme-Änderung
    document.dispatchEvent(new CustomEvent(EVENTS.THEME_CHANGED, { 
        detail: { theme: themeName } 
    }));
    
    console.log(`Theme geändert auf: ${themeName}`);
    return true;
}

/**
 * Gibt das aktuelle Theme zurück
 * @returns {string} Der Name des aktuellen Themes
 */
export function getCurrentTheme() {
    return _currentTheme;
}

/**
 * Gibt alle verfügbaren Themes zurück
 * @returns {string[]} Liste der verfügbaren Theme-Namen
 */
export function getAvailableThemes() {
    return Object.keys(_themes);
}

/**
 * Gibt die CSS-Variablen eines bestimmten Themes zurück
 * @param {string} themeName - Der Name des Themes
 * @returns {Object|null} Die CSS-Variablen des Themes oder null, wenn das Theme nicht existiert
 */
export function getThemeVariables(themeName) {
    return _themes[themeName] || null;
}

/**
 * Gibt zurück, ob das aktuelle Theme ein dunkles Theme ist
 * @returns {boolean} True, wenn es sich um ein dunkles Theme handelt
 */
export function isDarkTheme() {
    return _currentTheme.includes('dark');
}

/**
 * Wechselt zwischen hellem und dunklem Theme
 * @returns {string} Der Name des neu gesetzten Themes
 */
export function toggleDarkMode() {
    const isDark = isDarkTheme();
    let newTheme = '';
    
    if (isDark) {
        // Versuche 'light'-Variante des aktuellen Themes zu finden
        newTheme = _currentTheme.replace('dark', 'light');
        if (!_themes[newTheme]) {
            newTheme = 'light'; // Fallback auf Standard-Light-Theme
        }
    } else {
        // Versuche 'dark'-Variante des aktuellen Themes zu finden
        newTheme = _currentTheme.replace('light', 'dark');
        if (!_themes[newTheme]) {
            newTheme = 'dark'; // Fallback auf Standard-Dark-Theme
        }
    }
    
    // Prüfe, ob das neue Theme existiert, setze ansonsten auf Standard-Theme
    if (!_themes[newTheme]) {
        newTheme = _defaultTheme;
    }
    
    setTheme(newTheme);
    return newTheme;
}

/**
 * Erstellt ein neues Theme basierend auf einem existierenden Theme
 * @param {string} basedOn - Name des Basis-Themes
 * @param {string} newThemeName - Name des neuen Themes
 * @param {Object} overrides - Überschreibungen für das neue Theme
 * @returns {boolean} True, wenn das Theme erfolgreich erstellt wurde
 */
export function createTheme(basedOn, newThemeName, overrides = {}) {
    if (!_themes[basedOn]) {
        console.warn(`Basis-Theme nicht gefunden: ${basedOn}`);
        return false;
    }
    
    if (_themes[newThemeName]) {
        console.warn(`Theme existiert bereits: ${newThemeName}`);
        return false;
    }
    
    // Neues Theme erstellen basierend auf dem Basis-Theme
    _themes[newThemeName] = { ..._themes[basedOn], ...overrides };
    
    console.log(`Neues Theme erstellt: ${newThemeName}`);
    return true;
}

/**
 * Registriert einen Theme-Switch-Button
 * @param {string|Element} elementOrSelector - DOM-Element oder CSS-Selektor
 * @param {string} lightTheme - Name des hellen Themes
 * @param {string} darkTheme - Name des dunklen Themes
 */
export function registerThemeToggle(elementOrSelector, lightTheme = 'light', darkTheme = 'dark') {
    const element = typeof elementOrSelector === 'string' 
        ? document.querySelector(elementOrSelector)
        : elementOrSelector;
    
    if (!element) {
        console.warn(`Element für Theme-Toggle nicht gefunden: ${elementOrSelector}`);
        return;
    }
    
    // Initialen Zustand setzen
    updateToggleState(element, isDarkTheme());
    
    // Click-Handler registrieren
    element.addEventListener('click', () => {
        const newTheme = isDarkTheme() ? lightTheme : darkTheme;
        setTheme(newTheme);
        updateToggleState(element, isDarkTheme());
    });
    
    // Theme-Änderung überwachen
    document.addEventListener(EVENTS.THEME_CHANGED, () => {
        updateToggleState(element, isDarkTheme());
    });
}

/**
 * Aktualisiert den Zustand eines Theme-Toggle-Elements
 * @private
 * @param {Element} element - Das zu aktualisierende DOM-Element
 * @param {boolean} isDark - Ist das aktuelle Theme dunkel?
 */
function updateToggleState(element, isDark) {
    if (isDark) {
        element.classList.add('theme-dark');
        element.classList.remove('theme-light');
        element.setAttribute('aria-pressed', 'true');
    } else {
        element.classList.add('theme-light');
        element.classList.remove('theme-dark');
        element.setAttribute('aria-pressed', 'false');
    }
}
