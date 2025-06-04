<!--
# Copilot/KI-Policy – Fotobox-Projekt

---

## Inhaltsverzeichnis

1. [Projektüberblick & Hinweise](#projektüberblick--hinweise)
2. [Code-Kommentar- und Dokumentationsstandard](#code-kommentar--und-dokumentationsstandard)
3. [Review- und Änderungs-Policy](#review--und-änderungs-policy)
4. [CLI-Ausgabe-Policy](#cli-ausgabe-policy)
5. [Ausnahmen & Gültigkeit](#ausnahmen--gültigkeit)

---

## Projektüberblick & Hinweise

- Backend: Python (z.B. Flask) für Kamerasteuerung und Fotoverwaltung
- Frontend: HTML/JS für Weboberfläche (Fotos aufnehmen, anzeigen)
- Zielplattform: Linux (Entwicklung aktuell auf Windows)
- Backend sollte REST-API für Fotoaufnahme und -abruf bereitstellen
- Frontend kommuniziert per HTTP mit Backend
- Kameraansteuerung ggf. über Python-Module (z.B. picamera, subprocess)
- Platzhalter für Kamera-Code, falls Entwicklung ohne Hardware erfolgt

---

## Code-Kommentar- und Dokumentationsstandard

Das folgende Schema für Funktionskommentare ist für alle Quellcodedateien im Projekt verbindlich – unabhängig von der Sprache (Bash, Python, JavaScript, HTML, CSS).

**Allgemeine Vorgaben:**

- Rahmenlinien bestehen immer aus 71 (Bash) bzw. 78 (andere Sprachen) Bindestrichen oder dem passenden Kommentarzeichen.
- Nach dem Funktionsnamen folgt eine Zeile mit der Beschreibung.
- Optional können weitere Details, Parameter, Rückgabewerte, Besonderheiten ergänzt werden.
- Die Einrückung und die Punkte/Doppelpunkte müssen im gesamten Projekt konsistent sein.
- Nach der Definition aller lokalen Variablen/Konstanten innerhalb der Funktion folgt immer eine Leerzeile, bevor der eigentliche Funktionscode beginnt.
- Für Shellskripte ist ausschließlich Bash-Syntax zu verwenden (keine SH-Kompatibilität oder Mischformen).

**Entscheidungsdokumentation:**

In Funktionsblöcken müssen alle relevanten Entscheidungen (z. B. Verzweigungen, Rückgabewerte, Fehlerbehandlung) durch strukturierte Kommentare dokumentiert werden. Die Kommentare sollen den Zweck der Entscheidung, die möglichen Alternativen und deren Auswirkungen auf den Programmablauf kurz erläutern. Dies gilt insbesondere für Kontrollstrukturen wie if/else, case, Schleifen und Fehlerbehandlungen.

**Beispiele für verschiedene Sprachen:**

_Bash:_
```bash
install_package() {
    # -----------------------------------------------------------------------
    # install_package
    # -----------------------------------------------------------------------
    # Funktion,: Installiert ein einzelnes Systempaket in gewünschter Version
    # .........  (optional, prüft Version und installiert ggf. gezielt)
    # Rückgabe.: 0 = OK
    # .........  1 = Fehler
    # .........  2 = Version installiert, aber nicht passend
    # Parameter: $1 = Paketname
    # .........  $2 = Version (optional)
    # Extras...: Nutzt apt-get, prüft nach Installation erneut
    local pkg="$1"
    local version="$2"

    # (ab hier Funktionscode)
}
```

_Python:_
```python
# ----------------------------------------------------------------------------
# def take_photo
# ----------------------------------------------------------------------------
# Funktion: Löst die Kamera aus und speichert das Foto im Zielverzeichnis
# Parameter: filename (str) – Zielpfad für das Foto
# Rückgabe: Pfad zur gespeicherten Datei oder None bei Fehler
# Extras...: Platzhalter für Hardwarezugriff, Logging integriert

def take_photo(filename):
    # ... Funktionscode ...
    pass
```

_JavaScript:_
```js
// ------------------------------------------------------------------------------
// function showGallery
// ------------------------------------------------------------------------------
// Funktion: Zeigt die Fotogalerie im Frontend an
// Parameter: images (Array) – Liste der Bildpfade
// Rückgabe: void
// Extras...: Baut das DOM dynamisch auf
function showGallery(images) {
    // ... Funktionscode ...
}
```

_HTML (für größere Funktionsblöcke/Skripte):_
```html
<!-- -------------------------------------------------------------------------- -->
<!-- gallery-section -->
<!-- -------------------------------------------------------------------------- -->
<!-- Funktion: Zeigt die Galerie mit allen aufgenommenen Fotos an
     Extras...: Wird per JavaScript dynamisch befüllt -->
<section id="gallery-section">
    <!-- ... HTML-Inhalt ... -->
</section>
```

_CSS (für größere Block-Kommentare):_
```css
/* -----------------------------------------------------------------------------
   .gallery-grid
   -----------------------------------------------------------------------------
   Funktion: Layout für die Fotogalerie im Grid-Stil
   Extras...: Responsiv, mit flex-wrap
*/
.gallery-grid {
    /* ... CSS-Regeln ... */
}
```

---

## Review- und Änderungs-Policy

### Copilot Review Policy für Quellcodedateien (Bash, Python, HTML, CSS, JS, ...)

- Prüfe Syntax und Ausführung bzw. Funktionalität für alle relevanten Modi (z.B. Installation, Update, Deinstallation, Laufzeit, Interaktion)
- Suche nach möglichen Fehlerquellen und Schwierigkeiten, die eine korrekte Ausführung oder Darstellung verhindern könnten (z.B. Rechte, Konfigurationskonsistenz, Abhängigkeiten, veraltete Software, Distributionen, Hardware, Browser-Kompatibilität)
- Liste alle gefundenen Fehler und Schwachstellen auf
- Schlage für jeden gefundenen Punkt eine Korrektur vor und begründe diese
- Nach Nutzer-Zustimmung wird jede Anpassung einzeln und nachvollziehbar vorgenommen
- Ziel: Ein robustes, auf allen aktuellen Debian- und Ubuntu-Systemen (und Derivaten) sowie gängigen Browsern funktionierendes Projekt mit minimalen Hardware-Anforderungen
- Dokumentations- und Kommentarstandard gemäß DOKUMENTATIONSSTANDARD.md
- Für Shellskripte gilt: Nur Bash-Syntax und -Funktionen prüfen und verwenden, keine SH-Mischformen.

#### Dialogorientierte Copilot-Funktionsprüfung (Review-Workflow)

1. Bei jeder Chat-Eingabe mit der Vorgabe „Prüfe jede Funktion: [Vorgabe]“ analysiert Copilot jede betroffene Funktion einzeln.
2. Für jede Funktion wird der Analyse- und Änderungsvorschlag einzeln präsentiert und mit dem Nutzer abgestimmt.
3. Nach Nutzerentscheidung wird für jede Funktion eine der folgenden Optionen umgesetzt:
   a) Änderungen werden direkt in den Code übernommen.
   b) Änderungen werden als TODO-Block in die Funktion eingetragen.
   c) Änderungen werden verworfen (keine Anpassung).
4. Dieser dialogorientierte Review-Prozess ist für alle Copilot-/KI-gestützten Funktionsprüfungen im gesamten Projekt verbindlich.

- Achte bei Markdown-Dateien auf korrekte Formatierung:
  - Überschriften (z.B. # Titel) immer mit Leerzeile davor und danach
  - Listen immer mit Leerzeile davor und danach
  - Nur eine H1-Überschrift pro Datei
  - Jede Datei muss mit einer Leerzeile enden
  - Keine doppelten Überschriften oder Listen ohne Abstand
  - Siehe DOKUMENTATIONSSTANDARD.md und https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md

---

## CLI-Ausgabe-Policy

- Bei allen Shell-, Python- und Node.js-CLI-Skripten sind die Farb- und Strukturregeln aus `policies/cli_ausgabe_policy.md` einzuhalten.
- Ampelfarben: Grün = Erfolg, Gelb = Warnung, Rot = Fehler, Blau = Benutzerinteraktion, Standard = Info.
- Benutzerinteraktionen immer neutral und abgesetzt, Defaultwerte klar angeben.
- Abschnittsweise Gliederung und Einrückung beachten.
- Barrierefreiheit: Keine reine Farbcodierung, immer Textsymbole ergänzen.
- Copilot muss bei jeder Review und Codegenerierung auf diese Policy prüfen und Verstöße melden.

---

## Ausnahmen & Gültigkeit

### Ausnahme: Keine Prüfung von Unterordnern in 'frontend/fonts/'

- Ordner und Dateien unterhalb von 'frontend/fonts/' (insbesondere 'fontawesome-free-5.15.4-web/') sind explizit von allen Policy- und Dokumentationsprüfungen ausgenommen.
- Diese stammen aus externen Quellen (z.B. FontAwesome) und sind nicht Bestandteil des eigenen Projekts.
- Änderungen, Prüfungen oder Anpassungen an diesen Dateien sind nicht zulässig und nicht erforderlich.
- Die Policy-Prüfung bezieht sich ausschließlich auf eigene Projektdateien.
- (Siehe auch dokumentationsstandard.md und JAVASCRIPT_POLICY.md)

---

# HINWEIS: Diese Datei ist die zentrale und einzig gültige Policy-Quelle für Copilot- und KI-Anweisungen im Projekt. Andere Versionen oder Kopien (z.B. im .github-Ordner oder Hauptordner) sind zu ignorieren und werden nicht mehr gepflegt.

---

## Policy: Erhalt von Funktionskommentaren und Kontrollstruktur-Kommentaren

- Bei automatischen oder KI-gestützten Codeänderungen dürfen bestehende Funktionskommentare, Blockkommentare und erläuternde Kommentare zu Kontrollstrukturen (z.B. Hinweise auf entfernte Interaktivität, Parameterübergabe, Schleifenlogik) nicht entfernt oder verkürzt werden.
- Kommentare, die die ursprüngliche oder geänderte Logik für Menschen nachvollziehbar machen (z.B. warum eine Schleife entfernt wurde, wie Parameterübergabe statt Benutzereingabe funktioniert), sind stets zu erhalten und ggf. zu aktualisieren.
- Automatisierte Refaktorierungen müssen sicherstellen, dass alle erklärenden Kommentare zu Funktionsschnittstellen, Parametern, Rückgabewerten und Besonderheiten (wie ausgelagerte Interaktivität) erhalten bleiben.
- Bei Änderungen an Funktionssignaturen oder -logik ist der Kommentarblock entsprechend zu aktualisieren, aber niemals zu entfernen oder zu verkürzen.
- Diese Regel gilt für alle Sprachen und alle Quellcodedateien im Projekt.

---

## Policy: Auslagerung von TODO-Listen

TODO-Listen oder einzelne TODO-Anweisungen für Funktionen in einem Skript sind in eine separate Datei nach dem Schema '[skriptname].todo' im gleichen Verzeichnis wie das dazugehörige Skript auszulagern. Die Zuordnung zu Funktionen ist durch Angabe des Funktionsnamens sicherzustellen.

---
