/**
 * @file constants.js
 * @description Gemeinsame Konstanten für die Fotobox2-Anwendung
 * @module constants
 */

/**
 * API-Endpunkte für die Backend-Kommunikation
 * @constant {Object}
 */
export const API_ENDPOINTS = Object.freeze({
    /**
     * Authentifizierungs-Endpunkt
     */
    LOGIN: '/api/login',
    
    /**
     * Prüfung, ob ein Passwort gesetzt ist
     */
    CHECK_PASSWORD: '/api/check_password_set',
    
    /**
     * Session-Status-Prüfung
     */
    SESSION_CHECK: '/api/session-check',
    
    /**
     * Einstellungen-Endpunkt
     */
    SETTINGS: '/api/settings',
    
    /**
     * Logs-Endpunkt
     */
    LOGS: '/api/logs',
    
    /**
     * Logs-Batch-Endpunkt für mehrere Log-Einträge
     */
    LOGS_BATCH: '/api/logs/batch',
    
    /**
     * Logs löschen
     */
    LOGS_CLEAR: '/api/logs/clear',
    
    /**
     * Dateisystem-Endpunkt
     */
    FILESYSTEM: '/api/filesystem',
    
    /**
     * Dateiliste abrufen
     */
    LIST_FILES: '/api/filesystem/list',
    
    /**
     * Datei hochladen
     */
    UPLOAD_FILE: '/api/filesystem/upload',
    
    /**
     * Datei löschen
     */
    DELETE_FILE: '/api/filesystem/delete',
    
    /**
     * Verzeichnis erstellen
     */
    CREATE_DIRECTORY: '/api/filesystem/mkdir',
    
    /**
     * Speicherplatz-Informationen
     */
    DISK_SPACE: '/api/filesystem/disk-space',
    
    /**
     * Kamera-Endpunkt
     */
    CAMERA: '/api/camera',
    
    /**
     * Konfiguration der Kamera abrufen
     */
    CAMERA_CONFIG: '/api/camera/config',
    
    /**
     * Foto aufnehmen
     */
    TAKE_PHOTO: '/api/camera/capture',
    
    /**
     * Kamera-Vorschau starten
     */
    START_PREVIEW: '/api/camera/preview/start',
    
    /**
     * Kamera-Vorschau stoppen
     */
    STOP_PREVIEW: '/api/camera/preview/stop',
    
    /**
     * Datenbank-Einstellungen abrufen
     */
    DB_SETTINGS: '/api/database/settings',
    
    /**
     * Datenbank-Integrität prüfen
     */
    DB_CHECK_INTEGRITY: '/api/database/check-integrity',
    
    /**
     * Datenbank-Statistiken abrufen
     */
    DB_STATS: '/api/database/stats',
    
    /**
     * Datenbank-Abfrage ausführen
     */
    DB_QUERY: '/api/database/query',
    
    /**
     * Update-Status abrufen
     */
    UPDATE_STATUS: '/api/update/status',
    
    /**
     * Update durchführen
     */
    UPDATE_START: '/api/update/start'
});

/**
 * UI-Zustände für die Benutzeroberfläche
 * @constant {Object}
 */
export const UI_STATES = Object.freeze({
    /**
     * Lade-Zustand (Daten werden abgerufen oder verarbeitet)
     */
    LOADING: 'loading',
    
    /**
     * Bereit-Zustand (Daten wurden geladen und UI ist interaktionsbereit)
     */
    READY: 'ready',
    
    /**
     * Fehler-Zustand (Ein Fehler ist aufgetreten)
     */
    ERROR: 'error',
    
    /**
     * Leerlauf-Zustand (Warten auf Benutzerinteraktion)
     */
    IDLE: 'idle',
    
    /**
     * Übertragen-Zustand (Daten werden an den Server gesendet)
     */
    SUBMITTING: 'submitting'
});

/**
 * Konfigurationsschlüssel für die Einstellungen
 * @constant {Object}
 */
export const CONFIG_KEYS = Object.freeze({
    /**
     * Breite der Kamera-Auflösung
     */
    RESOLUTION_WIDTH: 'resolution_width',
    
    /**
     * Höhe der Kamera-Auflösung
     */
    RESOLUTION_HEIGHT: 'resolution_height',
    
    /**
     * Farbmodus (color, bw, sepia, etc.)
     */
    COLOR_MODE: 'color_mode',
    
    /**
     * Kamera-Modus (photo, video)
     */
    CAMERA_MODE: 'camera_mode',
    
    /**
     * Countdown-Dauer für Fotos
     */
    COUNTDOWN_DURATION: 'countdown_duration',
    
    /**
     * Zeige Splash-Screen beim Start
     */
    SHOW_SPLASH: 'show_splash',
    
    /**
     * Timeout für den Bildschirmschoner
     */
    SCREENSAVER_TIMEOUT: 'screensaver_timeout',
    
    /**
     * Timeout für die Galerie-Anzeige
     */
    GALLERY_TIMEOUT: 'gallery_timeout',
    
    /**
     * Timer für die Foto-Aufnahme
     */
    PHOTO_TIMER: 'photo_timer',
    
    /**
     * Name des Events
     */
    EVENT_NAME: 'event_name',
    
    /**
     * Datum des Events
     */
    EVENT_DATE: 'event_date',
    
    /**
     * Speicherpfad für Fotos
     */
    STORAGE_PATH: 'storage_path',
    
    /**
     * Blitzmodus (auto, on, off)
     */
    FLASH_MODE: 'flash_mode',
    
    /**
     * Kamera-ID
     */
    CAMERA_ID: 'camera_id'
});

/**
 * Fehlercodes für die Anwendung
 * @constant {Object}
 */
export const ERROR_CODES = Object.freeze({
    /**
     * Authentifizierung erforderlich
     */
    AUTH_REQUIRED: 'auth_required',
    
    /**
     * Verbindungsfehler
     */
    CONNECTION_ERROR: 'connection_error',
    
    /**
     * Serverfehler
     */
    SERVER_ERROR: 'server_error',
    
    /**
     * Kamerafehler
     */
    CAMERA_ERROR: 'camera_error',
    
    /**
     * Dateisystemfehler
     */
    FILESYSTEM_ERROR: 'filesystem_error',
    
    /**
     * Validierungsfehler
     */
    VALIDATION_ERROR: 'validation_error',
    
    /**
     * Nicht gefunden
     */
    NOT_FOUND: 'not_found',
    
    /**
     * Unbekannter Fehler
     */
    UNKNOWN_ERROR: 'unknown_error'
});

/**
 * Standardeinstellungen für die Anwendung
 * @constant {Object}
 */
export const DEFAULT_SETTINGS = Object.freeze({
    /**
     * Timer für die Foto-Aufnahme (Sekunden)
     */
    PHOTO_TIMER: 5,
    
    /**
     * Zeige Splash-Screen beim Start
     */
    SHOW_SPLASH: true,
    
    /**
     * Timeout für die Galerie-Anzeige (Sekunden)
     */
    GALLERY_TIMEOUT: 60,
    
    /**
     * Timeout für den Bildschirmschoner (Sekunden)
     */
    SCREENSAVER_TIMEOUT: 300,
    
    /**
     * Kamera-Modus
     */
    CAMERA_MODE: 'photo',
    
    /**
     * Farbmodus
     */
    COLOR_MODE: 'color',
    
    /**
     * Blitzmodus
     */
    FLASH_MODE: 'auto',
    
    /**
     * Countdown-Dauer für Fotos (Sekunden)
     */
    COUNTDOWN_DURATION: 3,
    
    /**
     * Standard-Auflösung (Breite)
     */
    RESOLUTION_WIDTH: 1920,
    
    /**
     * Standard-Auflösung (Höhe)
     */
    RESOLUTION_HEIGHT: 1080
});

/**
 * Lokalisierte Texte für die Anwendung
 * @constant {Object}
 */
export const LOCALIZED_STRINGS = Object.freeze({
    /**
     * Titel der Anwendung
     */
    APP_TITLE: {
        de: 'Fotobox',
        en: 'Photo Booth'
    },
    
    /**
     * Willkommensnachricht
     */
    WELCOME: {
        de: 'Willkommen zur Fotobox!',
        en: 'Welcome to the Photo Booth!'
    },
    
    /**
     * Foto aufnehmen
     */
    TAKE_PHOTO: {
        de: 'Foto aufnehmen',
        en: 'Take Photo'
    },
    
    /**
     * Galerie anzeigen
     */
    VIEW_GALLERY: {
        de: 'Galerie anzeigen',
        en: 'View Gallery'
    },
    
    /**
     * Einstellungen
     */
    SETTINGS: {
        de: 'Einstellungen',
        en: 'Settings'
    },
    
    /**
     * Login
     */
    LOGIN: {
        de: 'Anmelden',
        en: 'Login'
    },
    
    /**
     * Logout
     */
    LOGOUT: {
        de: 'Abmelden',
        en: 'Logout'
    },
    
    /**
     * Passwort
     */
    PASSWORD: {
        de: 'Passwort',
        en: 'Password'
    },
    
    /**
     * Fehler
     */
    ERROR: {
        de: 'Fehler',
        en: 'Error'
    },
    
    /**
     * Erfolg
     */
    SUCCESS: {
        de: 'Erfolg',
        en: 'Success'
    },
    
    /**
     * Speichern
     */
    SAVE: {
        de: 'Speichern',
        en: 'Save'
    },
    
    /**
     * Abbrechen
     */
    CANCEL: {
        de: 'Abbrechen',
        en: 'Cancel'
    },
    
    /**
     * Löschen
     */
    DELETE: {
        de: 'Löschen',
        en: 'Delete'
    },
    
    /**
     * Laden
     */
    LOADING: {
        de: 'Laden...',
        en: 'Loading...'
    },
    
    /**
     * Zurück
     */
    BACK: {
        de: 'Zurück',
        en: 'Back'
    },
    
    /**
     * Weiter
     */
    NEXT: {
        de: 'Weiter',
        en: 'Next'
    },
    
    /**
     * Lächeln
     */
    SMILE: {
        de: 'Lächeln!',
        en: 'Smile!'
    },
    
    /**
     * Fertig
     */
    DONE: {
        de: 'Fertig',
        en: 'Done'
    }
});

/**
 * Event-Namen für die Anwendung
 * @constant {Object}
 */
export const EVENTS = Object.freeze({
    /**
     * Theme geändert
     */
    THEME_CHANGED: 'themeChanged',
    
    /**
     * Sprache geändert
     */
    LANGUAGE_CHANGED: 'languageChanged',
    
    /**
     * Einstellungen geändert
     */
    SETTINGS_CHANGED: 'settingsChanged',
    
    /**
     * Login-Status geändert
     */
    AUTH_STATE_CHANGED: 'authStateChanged',
    
    /**
     * Kameraaufnahme abgeschlossen
     */
    CAPTURE_COMPLETE: 'captureComplete',
    
    /**
     * Fehler aufgetreten
     */
    ERROR_OCCURRED: 'errorOccurred'
});
