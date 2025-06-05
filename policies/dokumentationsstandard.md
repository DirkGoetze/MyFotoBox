# Dokumentationsstandard für das Fotobox-Projekt

Dieser Standard gilt für alle Skripttypen und Dokumentationsdateien im Projekt. Er beschreibt Kommentarstil, Review-Policy, Ordnerstruktur und Markdown-Regeln. Details siehe README im policies-Ordner.

## Kommentar- und Dokumentationsstil

## Skript Strukturierung bei größeren Skripten

- Erzeuge in umfangreichen Skripten, dazu zählen alle Skripte mit mehr als 70 Zeilen, immer einzelen Sektionen die die Aufgaben der Funktionen zusammenfassen.
- Die Rahmenlinien bestehen immer aus 71 Gleichheitszeichen.
- Standard Blöcke wären:

  - Hilfsfunktionen (Kurze Funktionen die nur eine Prüfung vornehmen ooder einen einzelnen Wert zurückgeben)
  - Einstellungen (Alle Funktionen die keine Interaktion mit dem Nutzer haben oder Systemeinstellungen ändern)
  - Eingaben oder Dialoge (Alle Funktionen die mit dem Nutzer interagieren)
  - Optional noch eine Main Sektion die das Hauptprogramm enthält

### Beispiel

```bash
# ===========================================================================
# Hilfsfunktionen
# ===========================================================================
```

## Funktionskommentare

Das folgende Schema für Funktionskommentare ist für alle Quellcodedateien im Projekt verbindlich – unabhängig von der Sprache (Bash, Python, JavaScript, HTML, CSS). Die Rahmenlinien, Einrückungen und Struktur werden jeweils mit den passenden Kommentarzeichen der jeweiligen Sprache umgesetzt. Ziel ist eine einheitliche, sofort erkennbare Dokumentation aller Funktionsblöcke.

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

Das Schema ist für alle Quellcodedateien im Projekt zu verwenden. Siehe auch Hinweise und Beispiele oben.

## Review Policy

- Prüfe Syntax und Ausführung bzw. Funktionalität für alle relevanten Modi (z.B. Installation, Update, Deinstallation, Laufzeit, Interaktion)
- Suche nach möglichen Fehlerquellen und Schwierigkeiten, die eine korrekte Ausführung oder Darstellung verhindern könnten (z.B. Rechte, Konfigurationskonsistenz, Abhängigkeiten, veraltete Software, Distributionen, Hardware, Browser-Kompatibilität)
- Liste alle gefundenen Fehler und Schwachstellen auf
- Schlage für jeden gefundenen Punkt eine Korrektur vor und begründe diese
- Nach Nutzer-Zustimmung wird jede Anpassung einzeln und nachvollziehbar vorgenommen
- Ziel: Ein robustes, auf allen aktuellen Debian- und Ubuntu-Systemen (und Derivaten) sowie gängigen Browsern funktionierendes Projekt mit minimalen Hardware-Anforderungen
- Für Shellskripte gilt: Nur Bash-Syntax und -Funktionen prüfen und verwenden, keine SH-Mischformen.

## Markdown-Formatierung (Standard für das Projekt)

- Überschriften (z.B. # Titel) müssen von einer Leerzeile oben und unten umgeben sein.
- Listen müssen von einer Leerzeile oben und unten umgeben sein.
- Es darf nur eine H1-Überschrift (# ...) pro Datei geben.
- Jede Markdown-Datei muss mit einer Leerzeile enden.
- Keine doppelten Überschriften oder Listen ohne Abstand.
- Platzhalter wie `[eventname]` sind in Markdown in eckigen Klammern zu schreiben (keine spitzen Klammern, um Lint-Fehler zu vermeiden).
- URLs sind als Markdown-Link zu formatieren: [http://...](http://...)
- Keine Inline-HTML (z.B. IP-ADRESSE statt IP-Adresse schreiben)
- Keine Bare-URLs (immer eckige Klammern verwenden)
- Siehe auch: [Markdownlint-Regeln](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)

## Policy: Nutzerrechte und Rechtevergabe

```text
-------------------------------------------------------------------------------
Alle schreibenden Operationen im Projektverzeichnis (z.B. durch Shell-, Python- oder Hilfsskripte) müssen sicherstellen, dass die betroffenen Dateien und Verzeichnisse nach Abschluss dem Anwendungsnutzer 'fotobox' gehören (`chown -R fotobox:fotobox ...`). Systemoperationen (Paketinstallation, NGINX, systemd) erfolgen weiterhin als root. Nach jedem schreibenden Schritt im Projektverzeichnis ist die Rechtevergabe zu prüfen und ggf. zu korrigieren, um spätere Zugriffsprobleme zu vermeiden.

Diese Policy ist für alle Skripte, Module und ausgelagerten Komponenten verbindlich und bei jeder Auslagerung oder Erweiterung zu beachten.
-------------------------------------------------------------------------------
```

## Ordnerstruktur-Policy: Trennung von Skripttypen

- Verschiedene Skripttypen (z.B. Python, Bash) dürfen nicht im selben Ordner abgelegt werden.
- Im Backend sind für Shell-Skripte und Python-Skripte jeweils eigene Unterordner zu verwenden (z.B. backend/scripts/ für Bash, backend/ für Python).
- Diese Policy ist verbindlich und bei allen Erweiterungen, Auslagerungen oder Umstrukturierungen einzuhalten.
- Die Struktur ist in einer `.folder.info` im jeweiligen Ordner zu dokumentieren.
- Analoges gilt für das Frontend (z.B. js/, css/, images/ etc.).
- Änderungen an der Ordnerstruktur müssen diese Policy berücksichtigen und dokumentiert werden.

## Policy: Auslagerung von TODO-Listen

TODO-Listen oder einzelne TODO-Anweisungen für Funktionen in einem Skript sind in eine separate, versteckte Datei nach dem Schema '.[skriptname].todo' (z. B. `.manage_nginx.todo`) im gleichen Verzeichnis wie das dazugehörige Skript auszulagern. Die Zuordnung zu Funktionen ist durch Angabe des Funktionsnamens sicherzustellen.

## Policy: Rückgabewerte und Fehlercodes

- 0 = OK
- 1 = Allgemeiner Fehler
- 2 = Konfigurationsfehler
- 3 = Backup-Fehler
- 4 = Reload-Fehler
- 10+ = Interaktive/sonstige Fehlerfälle
Die Rückgabewerte sind in allen Funktionskommentaren und der Implementierung konsistent zu verwenden

## Policy: Rückgabewert-Codierung nach Fehler-Schwere

Für alle Skripte und Funktionen im Projekt gilt folgende verbindliche Skala für Rückgabewerte:

| Wert | Bedeutung                                                                |
|------|--------------------------------------------------------------------------|
| 0    | OK (kein Fehler)                                                         |
| 1    | Kritischer Fehler (System nicht funktionsfähig, Datenverlust, Sicherheit)|
| 2    | Schwerer Fehler (z.B. Konfigurationsfehler, Dienst nicht startbar)       |
| 3    | Backup-Fehler (Datenintegrität gefährdet, System läuft weiter)           |
| 4    | Reload-Fehler (Konfigurationsänderung nicht aktiv, System läuft weiter)  |
| 5    | Funktionsfehler (Teilfunktion schlägt fehl, Hauptfunktion läuft)         |
| 6    | Warnung (z.B. veraltete Konfiguration, keine unmittelbare Auswirkung)    |
| 7    | Nicht-kritischer Fehler (temporäre Störung, Wiederholung möglich)        |
| 8    | Hinweis/Info (z.B. optionale Funktion nicht verfügbar)                   |
| 9    | Geringfügige Abweichung (kosmetische Fehler, keine Auswirkung)           |
| 10+  | Interaktive/Sonderfälle (z.B. Benutzerabbruch, Symlink-Fehler, Sonstiges)|

- Die Rückgabewerte sind in allen Funktionskommentaren und der Implementierung konsistent zu verwenden.
- Bei neuen Funktionen ist diese Skala strikt einzuhalten.
- Bei bestehenden Funktionen sind Abweichungen zu dokumentieren und mittelfristig zu beheben.
- Ziel ist eine eindeutige, priorisierbare Fehlerauswertung und einheitliche Fehlerbehandlung im gesamten Projekt.

_Diese Regeln gelten ab sofort als Standard für alle Markdown-Dateien im Projekt._
