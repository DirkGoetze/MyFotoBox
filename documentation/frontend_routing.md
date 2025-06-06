# Frontend Routing- und Dateinamen-Übersicht

Diese Datei beschreibt die Zuordnung der HTML-Dateien zu den jeweiligen Routen (URLs) im Fotobox-Frontend.

| Dateiname      | Route (URL)      | Funktion/Beschreibung                                                        |
|---------------|------------------|-------------------------------------------------------------------------------|
| index.html    | /                | Einstiegspunkt, zeigt Splash & prüft Weiterleitung (Installation/Hauptseite)  |
| install.html  | /installation    | Einmalige Ersteinrichtung, initiale Einstellungen setzen, dann Weiterleitung  |
| capture.html  | /capture         | Hauptseite für Fotoaufnahme („Home“), von überall erreichbar                  |
| gallery.html  | /gallery         | Galerie aller aufgenommenen Fotos                                             |
| settings.html | /settings        | Einstellungen, passwortgeschützt                                              |
| contact.html  | /contact         | Kontaktinfos, wie Gäste an die Fotos kommen                                   |

**Stand:** 2025-06-07

Für Details zur technischen Struktur und Trennung siehe policies/frontend_policy.md.

Diese Tabelle ist verbindlich für die Projektstruktur und alle Policies.

## Zusammenfassung des aktuellen Stands und der wichtigsten Punkte für die weitere Implementierung des Routingprozesses:

** 1. Frontend-Refaktorierung & Modularisierung

Alle HTML-, CSS- und JS-Dateien sind thematisch/seitenbezogen getrennt (z.B. capture.html, gallery.html, settings.html, install.html, index.html als Splash).
Interne Links und Imports wurden auf die neuen Dateinamen/Routen angepasst.
Splash-Screen (index.html) übernimmt die Routing-Logik und leitet je nach Setup-Status weiter (Progressbar, Weiterleitung zu install.html oder capture.html).
CSS ist nach Seiten/Funktionen getrennt (z.B. splash.css).

** 2. Projektstruktur & Policies

Klare Trennung und Dokumentation der Ordnerstruktur (HTML, CSS, JS, Bilder, Fonts, Dokumentation etc.).
frontend_policy.md enthält verbindliche Regeln zur Trennung und Struktur.
frontend_routing.md beschreibt die Zuordnung von Dateien zu Routen.
ordnerstruktur_policy.md verweist auf frontend_policy.md.

** 3. NGINX/Webserver

Die Verwaltung der NGINX-Konfiguration erfolgt zentral über manage_nginx.sh (Port, URL, Reload, Backup etc.).
Das Skript ist für seltene Änderungen und Updates ausreichend und empfohlen.
Workflow: Änderungen an Routing/NGINX → manage_nginx.sh ausführen → Webserver wird aktualisiert.

** 4. Best Practices

Modularisierung, klare Trennung der Ressourcen, konsistente Benennung und Dokumentation sind umgesetzt und dokumentiert.
Policies und Dokumentation sind aktuell und werden als Referenz genutzt.

** 5. Nächster Schritt

Die eigentliche Implementierung des Routingprozesses (z.B. Splash-Logik, Weiterleitungen, Backend-Anpassungen) kann jetzt auf Basis dieser Struktur und Policies erfolgen.