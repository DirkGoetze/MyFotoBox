<!--
Projekt: Fotobox
- Backend: Python (z.B. Flask) für Kamerasteuerung und Fotoverwaltung
- Frontend: HTML/JS für Weboberfläche (Fotos aufnehmen, anzeigen)
- Zielplattform: Linux (Entwicklung aktuell auf Windows)

Spezielle Hinweise:
- Backend sollte REST-API für Fotoaufnahme und -abruf bereitstellen
- Frontend kommuniziert per HTTP mit Backend
- Kameraansteuerung ggf. über Python-Module (z.B. picamera, subprocess)
- Platzhalter für Kamera-Code, falls Entwicklung ohne Hardware erfolgt

Dokumentationsstandard für alle Skripttypen (Bash, Python, HTML, CSS, JS):
- Für alle Funktionsblöcke in Skripten/Dateien ist folgender Kommentarstil zu verwenden:
-------------------------------------------------------------------------------
# funktionsname (bzw. Funktions-/Blockname, je nach Sprache)
-------------------------------------------------------------------------------
# Funktion: Kurzbeschreibung der Aufgabe der Funktion (max. 78 Zeichen)
# [Optional: weitere Details, Parameter, Rückgabewerte, Besonderheiten]
funktionsname() {
    # Funktionscode ...
}
- Die Rahmenlinien bestehen immer aus 78 Bindestrichen.
- Nach dem Funktionsnamen folgt eine Zeile mit der Beschreibung.
- Optional können weitere Details ergänzt werden.
- Dieses Schema ist für alle Bash-Skripte, Python-Skripte, HTML-, CSS- und JS-Dateien zu verwenden (Syntax an Sprache anpassen, z.B. // für JS, <!-- --> für HTML, # für Python).
- Für Shellskripte ist ausschließlich Bash-Syntax zu verwenden (keine SH-Kompatibilität oder Mischformen).

# Copilot Review Policy für Quellcodedateien (Bash, Python, HTML, CSS, JS, ...)

Bei jeder Überprüfung einer Quellcodedatei (Bash-Skripte, Python-Skripte, HTML-, CSS-, JS-Dateien etc.) in diesem Projekt sind folgende Vorgaben zwingend zu beachten:

- Prüfe Syntax und Ausführung bzw. Funktionalität für alle relevanten Modi (z.B. Installation, Update, Deinstallation, Laufzeit, Interaktion)
- Suche nach möglichen Fehlerquellen und Schwierigkeiten, die eine korrekte Ausführung oder Darstellung verhindern könnten (z.B. Rechte, Konfigurationskonsistenz, Abhängigkeiten, veraltete Software, Distributionen, Hardware, Browser-Kompatibilität)
- Liste alle gefundenen Fehler und Schwachstellen auf
- Schlage für jeden gefundenen Punkt eine Korrektur vor und begründe diese
- Nach Nutzer-Zustimmung wird jede Anpassung einzeln und nachvollziehbar vorgenommen
- Ziel: Ein robustes, auf allen aktuellen Debian- und Ubuntu-Systemen (und Derivaten) sowie gängigen Browsern funktionierendes Projekt mit minimalen Hardware-Anforderungen
- Dokumentations- und Kommentarstandard gemäß DOKUMENTATIONSSTANDARD.md
- Für Shellskripte gilt: Nur Bash-Syntax und -Funktionen prüfen und verwenden, keine SH-Mischformen.

Diese Vorgaben sind bei jeder Überprüfung und Bearbeitung durch Copilot einzuhalten.
-->
