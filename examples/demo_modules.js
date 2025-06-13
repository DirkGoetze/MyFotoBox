/**
 * @file demo_modules.js
 * @description Demonstriert die Verwendung der gemeinsamen Frontend-Module
 */

import { API_ENDPOINTS, UI_STATES, CONFIG_KEYS, EVENTS, LOCALIZED_STRINGS } from './js/constants.js';
import * as i18n from './js/i18n.js';
import * as theming from './js/theming.js';
import { createDialog, createToast, createButton } from './js/ui_components.js';
import { debounce, formatDate, validateEmail } from './js/utils.js';

// Übersetzungen initialisieren
i18n.init(LOCALIZED_STRINGS, 'de', 'en');

// Themes definieren
const themes = {
  light: {
    '--bg-color': '#ffffff',
    '--text-color': '#333333',
    '--primary-color': '#4285f4',
    '--secondary-color': '#34a853',
    '--accent-color': '#ea4335',
    '--border-color': '#dadce0',
    '--shadow-color': 'rgba(60, 64, 67, 0.3)',
    '--card-bg-color': '#ffffff',
    '--hover-bg-color': '#f8f9fa'
  },
  dark: {
    '--bg-color': '#121212',
    '--text-color': '#e0e0e0',
    '--primary-color': '#8ab4f8',
    '--secondary-color': '#81c995',
    '--accent-color': '#f28b82',
    '--border-color': '#5f6368',
    '--shadow-color': 'rgba(0, 0, 0, 0.5)',
    '--card-bg-color': '#1e1e1e',
    '--hover-bg-color': '#2d2d2d'
  },
  sepia: {
    '--bg-color': '#f8f1e3',
    '--text-color': '#5b4636',
    '--primary-color': '#8e6f47',
    '--secondary-color': '#6b8e47',
    '--accent-color': '#8e476f',
    '--border-color': '#d3c4ad',
    '--shadow-color': 'rgba(91, 70, 54, 0.3)',
    '--card-bg-color': '#f8f1e3',
    '--hover-bg-color': '#f0e9db'
  }
};

// Themes initialisieren
theming.init(themes, 'light');

/**
 * Dokument initialisieren, wenn DOM geladen ist
 */
document.addEventListener('DOMContentLoaded', () => {
  setupUI();
  setupEventListeners();
  updateUIState(UI_STATES.READY);
});

/**
 * UI-Elemente und -Struktur einrichten
 */
function setupUI() {
  // Internationalisierte Überschrift setzen
  document.querySelector('h1').textContent = i18n.t('APP_TITLE');
  
  // Theme-Umschalter registrieren
  theming.registerThemeToggle('#theme-toggle', 'light', 'dark');
  
  // Sprach-Umschalter einrichten
  const languageSelector = document.getElementById('language-selector');
  const availableLanguages = i18n.getAvailableLanguages();
  
  availableLanguages.forEach(lang => {
    const option = document.createElement('option');
    option.value = lang;
    option.textContent = lang.toUpperCase();
    languageSelector.appendChild(option);
  });
  
  languageSelector.value = i18n.getCurrentLanguage();
  
  // Buttons mit UI-Komponenten erstellen
  const photoButton = createButton({
    text: i18n.t('TAKE_PHOTO'),
    icon: 'camera',
    onClick: takePhoto,
    primary: true
  });
  
  const galleryButton = createButton({
    text: i18n.t('VIEW_GALLERY'),
    icon: 'images',
    onClick: viewGallery
  });
  
  document.getElementById('action-buttons').append(photoButton, galleryButton);
  
  // Alle Elemente mit data-i18n übersetzen
  i18n.translateElement(document);
}

/**
 * Event-Listener einrichten
 */
function setupEventListeners() {
  // Sprachänderungen überwachen
  document.getElementById('language-selector').addEventListener('change', (e) => {
    i18n.setLanguage(e.target.value);
  });
  
  // Theme-Änderungen überwachen
  document.addEventListener(EVENTS.THEME_CHANGED, (e) => {
    // Setze das Theme-Attribut für CSS-Selektoren
    document.body.dataset.theme = e.detail.theme;
    console.log(`Theme geändert zu: ${e.detail.theme}`);
  });
  
  // Sprachänderungen überwachen
  document.addEventListener(EVENTS.LANGUAGE_CHANGED, () => {
    // Aktualisiere UI-Texte
    document.querySelector('h1').textContent = i18n.t('APP_TITLE');
    
    // Alle übersetzbaren Elemente aktualisieren
    i18n.translateElement(document);
    console.log(`Sprache geändert zu: ${i18n.getCurrentLanguage()}`);
  });
}

/**
 * UI-Status aktualisieren
 * @param {string} state - Einer der UI_STATES
 */
function updateUIState(state) {
  const body = document.body;
  
  // Alte Zustände entfernen
  Object.values(UI_STATES).forEach(uiState => {
    body.classList.remove(`state-${uiState}`);
  });
  
  // Neuen Zustand setzen
  body.classList.add(`state-${state}`);
  
  console.log(`UI-Status geändert zu: ${state}`);
}

/**
 * Simuliert die Aufnahme eines Fotos
 */
async function takePhoto() {
  updateUIState(UI_STATES.LOADING);
  
  try {
    // Simuliere API-Aufruf
    console.log(`API-Aufruf: ${API_ENDPOINTS.TAKE_PHOTO}`);
    
    // Simulierte Verzögerung
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    // Erfolgsmeldung anzeigen
    createToast({
      message: i18n.t('SUCCESS'),
      type: 'success',
      duration: 3000
    });
    
    updateUIState(UI_STATES.READY);
  } catch (error) {
    console.error('Fehler bei der Fotoaufnahme:', error);
    
    createToast({
      message: i18n.t('ERROR'),
      type: 'error',
      duration: 5000
    });
    
    updateUIState(UI_STATES.ERROR);
  }
}

/**
 * Simuliert das Anzeigen der Galerie
 */
function viewGallery() {
  createDialog({
    title: i18n.t('VIEW_GALLERY'),
    content: `<p>${i18n.t('LOADING')}</p>`,
    buttons: [
      {
        text: i18n.t('BACK'),
        onClick: (dialog) => dialog.close()
      }
    ]
  });
}
