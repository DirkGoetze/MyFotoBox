# Code-Strukturierungs-Policy für Fotobox2

## Übersicht

Diese Policy definiert eine einheitliche Struktur für die Code-Organisation im Fotobox2-Projekt. Ziel ist es, eine konsistente Strategie für die Verwaltung von Backend- und Frontend-Code zu etablieren, sodass Systemfunktionen und Seitenspezifische Funktionen klar getrennt werden.

## Grundprinzip

1. **Systemfunktionen**: Code, der für die Verwaltung und Steuerung des Systems verantwortlich ist (Updates, Installation, Datenbankverwaltung, etc.), wird in speziellen `manage_*` Modulen organisiert - sowohl im Backend als auch im Frontend.

2. **Seitenspezifischer Code**: Code, der nur für die Darstellung und Interaktion auf einer bestimmten Seite relevant ist, wird in nach den Seiten benannten Dateien (`seite.js`) organisiert.

## Zuordnung von Funktionen zu Modulen

Die folgende Tabelle zeigt die geplante Organisation von Funktionen in entsprechenden Modulen:

| Funktion                    | Backend-Modul              | Frontend-Modul               |
|-----------------------------|----------------------------|------------------------------|
| Systemupdates               | `manage_update.py`         | `manage_update.js`           |
| Installation/Deinstallation | `manage_install.py`        | `manage_install.js`          |
| Datenbankverwaltung         | `manage_database.py`       | `manage_database.js`         |
| Einstellungen               | `manage_settings.py`       | `manage_settings.js`         |
| Authentifizierung/Passwörter| `manage_auth.py`           | `manage_auth.js`             |
| Logging                     | `manage_logging.py`        | `manage_logging.js`          |
| Dateisystem-Zugriff         | `manage_filesystem.py`     | `manage_filesystem.js`       |
| API-Kommunikation           | `manage_api.py`            | `manage_api.js`              |
| Kamera-Steuerung            | `manage_camera.py`         | `manage_camera.js`           |

## Seitenspezifische JavaScript-Dateien

Diese Dateien enthalten ausschließlich Code für DOM-Manipulation, Event-Handling und seitenspezifische Logik, die nicht mit dem Backend kommuniziert oder globale Systemfunktionen übernimmt.

| HTML-Seite       | JavaScript-Datei | Verantwortlichkeiten                                     |
|------------------|------------------|----------------------------------------------------------|
| `index.html`     | `index.js`       | Startseite-Darstellung, Animation                        |
| `capture.html`   | `capture.js`     | Kamera-UI, Aufnahme-Buttons, Effekte                     |
| `gallery.html`   | `gallery.js`     | Galerie-Navigation, Bildanzeige, Scroll-Effekte          |
| `settings.html`  | `settings.js`    | UI-Interaktion, Formularvalidierung, Anzeigeoptionen     |
| `install.html`   | `install.js`     | UI für Installation, Fortschrittsanzeige                 |

## Gemeinsame Funktionalität

Für gemeinsame Funktionalitäten, die auf mehreren Seiten verwendet werden, gibt es gemeinsam genutzte Module:

| Funktion                     | Gemeinsames Modul      | Status                      |
|------------------------------|------------------------|----------------------------|
| UI-Komponenten               | `ui_components.js`     | 🟢 Vollständig implementiert |
| Hilfsfunktionen              | `utils.js`             | 🟢 Vollständig implementiert |
| Konstanten                   | `constants.js`         | 🟢 Vollständig implementiert |
| Mehrsprachigkeit             | `i18n.js`              | 🟢 Vollständig implementiert |
| Themes/Darstellung           | `theming.js`           | 🟢 Vollständig implementiert |

## Migration-Strategie

Die Migration des bestehenden Codes wird schrittweise erfolgen:

1. **Identifikation**: ✅ Bestehenden Code analysieren und kategorisieren
2. **Refactoring-Plan**: ✅ Detaillierten Plan für jedes Modul erstellen
3. **Migration**: ✅ Schrittweise Überführung, beginnend mit den am wenigsten abhängigen Modulen
4. **Tests**: ✅ Prüfung der migrierten Funktionalität
5. **Dokumentation**: ⏳ Aktualisieren der Dokumentation für jeden abgeschlossenen Migrationsschritt

## Vorteile

- **Konsistenz**: Einheitliche Strukturierung im gesamten Projekt
- **Trennung der Zuständigkeiten**: Klare Abgrenzung zwischen System- und UI-Funktionen
- **Wiederverwendbarkeit**: Leichtere Identifizierung und Nutzung gemeinsamer Funktionalität
- **Wartbarkeit**: Verbesserung der Lesbarkeit und Wartbarkeit des Codes
- **Erweiterbarkeit**: Einfachere Erweiterung um neue Funktionen durch klare Strukturierung

---

**Hinweis**: Diese Policy ist ein Vorschlag für die zukünftige Strukturierung des Fotobox2-Codes. Die tatsächliche Implementierung erfordert eine sorgfältige Planung und schrittweise Migration, um die Funktionalität des Systems während der Umstellung zu gewährleisten.
