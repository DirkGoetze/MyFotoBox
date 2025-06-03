# JavaScript Policy für das Fotobox-Projekt

```text
-------------------------------------------------------------------------------
Vorgaben zur Ablage und Einbindung von JavaScript-Dateien
-------------------------------------------------------------------------------

- Alle JavaScript-Dateien müssen zentral im Verzeichnis `frontend/js/` abgelegt werden.
- Es dürfen keine Inline- oder eingebetteten Skripte in HTML-Dateien verwendet werden (außer zum Laden von Dateien per <script src=...>).
- Die Einbindung von JavaScript erfolgt ausschließlich über <script src="js/main.js"></script> (bzw. weitere zentrale Dateien bei Bedarf).
- Gemeinsame Funktionen und seitenübergreifende Logik sind in main.js zu bündeln.
- Änderungen an der Policy sind in der Datei DOKUMENTATIONSSTANDARD.md zu dokumentieren.

Ziel:
- Trennung von Struktur (HTML), Design (CSS) und Logik (JS) für bessere Wartbarkeit, Übersicht und Wiederverwendbarkeit.
-------------------------------------------------------------------------------
Hinweis: Keine Prüfung von Unterordnern in 'frontend/fonts/'
-------------------------------------------------------------------------------
Alle Unterordner und Dateien in 'frontend/fonts/' (insbesondere 'fontawesome-free-5.15.4-web/') sind von der Policy- und Review-Prüfung ausgenommen. Diese stammen aus externen Quellen und sind nicht Bestandteil des eigenen Projekts.
(Siehe auch dokumentationsstandard.md und copilot-instructions)
-------------------------------------------------------------------------------
```

## JavaScript-Policy für das Projekt

- Listen müssen immer von Leerzeilen umgeben sein.
- URLs sind als Markdown-Link zu formatieren: [http://...](http://...)
- Keine Inline-HTML (z.B. IP-ADRESSE statt IP-Adresse schreiben)
- Keine Bare-URLs (immer eckige Klammern verwenden)
- Jede Datei endet mit einer Leerzeile
- Nur eine H1-Überschrift pro Datei
- Siehe auch [Markdownlint-Regeln](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)

Letzte Änderung: 2025-06-02
