# JavaScript Policy für das Fotobox-Projekt

## Allgemeine Regeln

- Alle JavaScript-Dateien müssen zentral im Verzeichnis `frontend/js/` abgelegt werden.
- Es dürfen keine Inline- oder eingebetteten Skripte in HTML-Dateien verwendet werden (außer zum Laden von Dateien per `<script src=...>`).
- Die Einbindung von JavaScript erfolgt ausschließlich über `<script src="js/main.js"></script>` (bzw. weitere zentrale Dateien bei Bedarf).
- Gemeinsame Funktionen und seitenübergreifende Logik sind in `main.js` zu bündeln.
- Änderungen an der Policy sind in der Datei `policies/dokumentationsstandard.md` zu dokumentieren.
- Trennung von Struktur (HTML), Design (CSS) und Logik (JS) für bessere Wartbarkeit, Übersicht und Wiederverwendbarkeit.

## Spezifische Funktionalitäten

### Einstellungen

- Änderungen an Einstellungen werden automatisch beim Verlassen eines Feldes gespeichert (Blur-Event)
- Jede Änderung wird einzeln verarbeitet und an die API übermittelt
- Nutzer werden über Erfolg oder Fehler beim Speichern durch Benachrichtigungen informiert

### Benachrichtigungssystem

- Benachrichtigungen werden dynamisch im DOM erzeugt und gestapelt angezeigt
- Erfolgsbenachrichtigungen werden automatisch nach 3 Sekunden ausgeblendet
- Fehlermeldungen werden mit längerer Anzeigedauer (6 Sekunden) angezeigt
- Nutzer können Benachrichtigungen manuell schließen
- Das Benachrichtigungssystem unterstützt verschiedene Meldungstypen (Erfolg, Fehler, Warnung)

*Siehe auch policies/dokumentationsstandard.md für allgemeine Formatierungsregeln.*
