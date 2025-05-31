<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

Projekt: Fotobox
- Backend: Python (z.B. Flask) für Kamerasteuerung und Fotoverwaltung
- Frontend: HTML/JS für Weboberfläche (Fotos aufnehmen, anzeigen)
- Zielplattform: Linux (Entwicklung aktuell auf Windows)

Spezielle Hinweise:
- Backend sollte REST-API für Fotoaufnahme und -abruf bereitstellen
- Frontend kommuniziert per HTTP mit Backend
- Kameraansteuerung ggf. über Python-Module (z.B. picamera, subprocess)
- Platzhalter für Kamera-Code, falls Entwicklung ohne Hardware erfolgt

Dokumentationsstandard für Shell-Skripte:
- Für alle Funktionsblöcke im Skript ist folgender Kommentarstil zu verwenden:
-------------------------------------------------------------------------------
# funktionsname
-------------------------------------------------------------------------------
# Funktion: Kurzbeschreibung der Aufgabe der Funktion (max. 78 Zeichen)
# [Optional: weitere Details, Parameter, Rückgabewerte, Besonderheiten]
funktionsname() {
    # Funktionscode ...
}
- Die Rahmenlinien bestehen immer aus 78 Bindestrichen.
- Nach dem Funktionsnamen folgt eine Zeile mit der Beschreibung.
- Optional können weitere Details ergänzt werden.
- Dieses Schema ist für alle Shell-Skripte und bash-Funktionen zu verwenden.
