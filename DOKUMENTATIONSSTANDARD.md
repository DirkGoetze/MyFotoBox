# dokumentationsstandard.md

## Geltungsbereich

Dieser Standard gilt für **alle Skripttypen** im Projekt:

- Bash-Skripte (nur Bash, keine SH-Mischformen)
- Python-Skripte
- HTML-Dateien
- CSS-Dateien
- JavaScript-Dateien

## Kommentar- und Dokumentationsstil

Für alle Funktionsblöcke in Skripten/Dateien ist folgender Kommentarstil zu verwenden (Syntax je nach Sprache anpassen, z.B. # für Python/Bash, // für JS, <!-- --> für HTML):

-------------------------------------------------------------------------------
# funktionsname (bzw. Funktions-/Blockname, je nach Sprache)
-------------------------------------------------------------------------------
# Funktion: Kurzbeschreibung der Aufgabe der Funktion (max. 78 Zeichen)
# [Optional: weitere Details, Parameter, Rückgabewerte, Besonderheiten]
funktionsname() {
    # Funktionscode ...
}
-------------------------------------------------------------------------------

- Die Rahmenlinien bestehen immer aus 78 Bindestrichen.
- Nach dem Funktionsnamen folgt eine Zeile mit der Beschreibung.
- Optional können weitere Details ergänzt werden.
- Dieses Schema ist für alle Bash-, Python-, HTML-, CSS- und JS-Dateien zu verwenden.
- Für Shellskripte ist ausschließlich Bash-Syntax zu verwenden (keine SH-Kompatibilität oder Mischformen).

## Review Policy

- Prüfe Syntax und Ausführung bzw. Funktionalität für alle relevanten Modi (z.B. Installation, Update, Deinstallation, Laufzeit, Interaktion)
- Suche nach möglichen Fehlerquellen und Schwierigkeiten, die eine korrekte Ausführung oder Darstellung verhindern könnten (z.B. Rechte, Konfigurationskonsistenz, Abhängigkeiten, veraltete Software, Distributionen, Hardware, Browser-Kompatibilität)
- Liste alle gefundenen Fehler und Schwachstellen auf
- Schlage für jeden gefundenen Punkt eine Korrektur vor und begründe diese
- Nach Nutzer-Zustimmung wird jede Anpassung einzeln und nachvollziehbar vorgenommen
- Ziel: Ein robustes, auf allen aktuellen Debian- und Ubuntu-Systemen (und Derivaten) sowie gängigen Browsern funktionierendes Projekt mit minimalen Hardware-Anforderungen
- Für Shellskripte gilt: Nur Bash-Syntax und -Funktionen prüfen und verwenden, keine SH-Mischformen.

Diese Vorgaben sind bei jeder Überprüfung und Bearbeitung einzuhalten.

## Shellskript-Ausgabe-Farben

- Fehlerausgaben immer in Rot
- Ausgaben zu auszuführenden Schritten in Gelb
- Erfolgsmeldungen in Dunkelgrün
- Aufforderungen zur Nutzeraktion in Blau
- Alle anderen Ausgaben nach Systemstandard

Beispiel-Funktionen siehe install_fotobox.sh.

## Markdown-Formatierung

- Überschriften (z.B. # Titel) müssen von einer Leerzeile oben und unten umgeben sein.
- Listen müssen von einer Leerzeile oben und unten umgeben sein.
- Es darf nur eine H1-Überschrift (# ...) pro Datei geben.
- Jede Markdown-Datei muss mit einer Leerzeile enden.
- Keine doppelten Überschriften oder Listen ohne Abstand.
- Platzhalter wie `[eventname]` sind in Markdown in eckigen Klammern zu schreiben (keine spitzen Klammern, um Lint-Fehler zu vermeiden).
- Siehe auch: [Markdownlint-Regeln](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)
