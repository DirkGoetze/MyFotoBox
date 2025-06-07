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

## Zusammenfassungen der Design Regeln für die Menüführung und den allgemeine Aufbau der Seiten

- Menübestandteile aus älteren Versionen sind nach jeder Änderung am Menü aus der Ansicht durch auskommentieren zu entfernen .
- Alle Seiten haben einen Header und einen Footer. 
-- Der Header zeigt den Eventtitel wie in der Datenbank hinterlegt zenrtiert an. Wurde noch kein Eventtitel vergeben, ist die Projektbezeichnung als Fallback zu verwenden.
-- Das Menü ist an der linken Seite des Header anzuordnen. 
-- Es besteht in der Standard Ansicht nur aus dem Hamburger Icon das immer sichtbar ist.
-- Wird das Menü durch anklicken des Hamburger geöffnet, wird ein Overlay mit allen erreichbaren Seiten (capture.html, gallery.html, contact.html und settings.html) angezeigt.
-- Diese sind untereinander angeordnet, so wie es bei Desktop Programmen üblich ist.
-- Die aktuelle Seite ist nicht im Menü enthalten.
-- Die Seite 'install.html' ist nicht über die Menü Struktur zu erreichen.
-- Sie kann über das Haus Symbol im Breadcrumb Menü oder Anklicken des Eventtitel/Projekttitel im Header erreicht werden.
-- Rechts im Header wird das Datum im Format "dd.mm.yyyy" und darunter die Uhrzeit im Format "hh:mm" angezeigt.
-- Der Footer ist am unteren Bildrand fixiert. Er zeigt nur den Projektnamen und den Copyright Hinweis.
-- Im Content Bereich wird auf allen Seiten die nicht HOME sind, ein Breadcrumb Menü angezeigt, das interaktiv sein sollte und einen schnellen Wechsel zu HOME Seite ermöglicht. 
   Dieser Link ist durch ein Haussymbol anzuzeigen, währen alle anderen Seitennamen / Routen durch ' > Seite' angezeigt werden sollten. Das Breadcrumb Menü sollte sich durch Hinterlegung in einer anderen Farbe oder eine Varianz der Hintergrundfarbe der Seite vom Rest abheben.
-- Alle HTML Elemente sollten einer durchgehenden Farbgebung folgen und Varianten für Light und Darkmodus habe.
-- Es ist auf Barriere Freiheit zu achten. Insbesonder bei der Lesbarkeit.