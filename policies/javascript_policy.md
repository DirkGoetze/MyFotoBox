# JavaScript Policy für das Fotobox-Projekt

- Alle JavaScript-Dateien müssen zentral im Verzeichnis `frontend/js/` abgelegt werden.
- Es dürfen keine Inline- oder eingebetteten Skripte in HTML-Dateien verwendet werden (außer zum Laden von Dateien per `<script src=...>`).
- Die Einbindung von JavaScript erfolgt ausschließlich über `<script src="js/main.js"></script>` (bzw. weitere zentrale Dateien bei Bedarf).
- Gemeinsame Funktionen und seitenübergreifende Logik sind in `main.js` zu bündeln.
- Änderungen an der Policy sind in der Datei `policies/dokumentationsstandard.md` zu dokumentieren.
- Trennung von Struktur (HTML), Design (CSS) und Logik (JS) für bessere Wartbarkeit, Übersicht und Wiederverwendbarkeit.

*Siehe auch policies/dokumentationsstandard.md für allgemeine Formatierungsregeln.*
