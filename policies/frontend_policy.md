# Frontend-Policy für das Fotobox-Projekt

Diese Policy regelt die Ablage, Trennung und Struktur aller Frontend-Bestandteile (HTML, CSS, JS, Bilder, Fonts, Dokumentation) im Projekt.

## 1. HTML-Dateien (frontend/*.html)
- Enthalten ausschließlich die Seitenstruktur und semantisches Markup.
- Keine eingebetteten Styles (<style>) oder Skripte (<script>), außer für minimale Initialisierung.

## 2. CSS-Dateien (frontend/css/*.css)
- Enthalten alle Styles, jeweils thematisch oder seitenbezogen getrennt (z.B. splash.css, gallery.css).
- Keine Inline-Styles in HTML-Attributen.

## 3. JavaScript-Dateien (frontend/js/*.js)
- Enthalten alle clientseitigen Logiken, Event-Handler und API-Kommunikation.
- Pro Seite oder Thema eigene Datei (z.B. main.js, gallery.js, config.js).

## 4. Bilder & Medien (frontend/picture/, frontend/photos/)
- Statische Bilder, Logos, Hintergründe: im Ordner picture/.
- Nutzerfotos und Galerie: im Ordner photos/ (ggf. Unterordner wie gallery/).

## 5. Fonts & Icons (frontend/fonts/)
- Externe Schriftarten und Iconsets (z.B. FontAwesome) liegen in fonts/.

## 6. Dokumentation (documentation/)
- Alle Markdown- und Dokumentationsdateien, inkl. Routing- und Strukturübersicht.

## 7. Policies (policies/)
- Alle projektweiten Regeln, Coding-Guidelines und Ausnahmen.

## 8. Keine Vermischung
- HTML, CSS, JS, Bilder, Fonts und Dokumentation sind strikt in eigenen Ordnern zu halten.
- Keine gemischten Inhalte in einem Ordner.

**Diese Policy ist verbindlich für alle künftigen Erweiterungen und Refactorings.**

*Stand: 2025-06-07*
