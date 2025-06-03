# Policy: Farbgebung und Struktur von CLI-Ausgaben

## Ziel

Diese Policy legt verbindliche Regeln für die Gestaltung von Ausgaben in allen Shellskripten und CLI-Tools des Projekts fest. Ziel ist eine international verständliche, barrierearme und übersichtliche Benutzerführung.

## Farbgebung (Ampelprinzip)

- **Grün** (`\033[1;32m`): Erfolgsmeldungen (z.B. "OK", "Fertig", "Erfolgreich abgeschlossen")
- **Gelb** (`\033[1;33m`): Warnungen und Hinweise (z.B. "Achtung", "Warnung", "Nicht kritisch, aber zu beachten")
- **Rot** (`\033[1;31m`): Fehler und kritische Probleme (z.B. "Fehler", "Abbruch", "Nicht erfolgreich")
- **Standardfarbe** (`\033[0m`): Allgemeine Informationen, Statusmeldungen, Zusatzinfos
- **Blau** (`\033[1;34m`): Benutzerinteraktionen (z.B. Fragen, Eingabeaufforderungen) – keine Ampelfarbe, um Neutralität zu wahren

## Struktur und Layout

- **Schrittbezeichnungen** stehen fett (sofern möglich) und am Zeilenanfang, um die Orientierung zu erleichtern.
- **Informationen, Warnungen, Fehler** werden eingerückt dargestellt.
- **Benutzereingaben** werden durch Leerzeilen davor und danach vom übrigen Text getrennt und farblich (blau oder invertiert) hervorgehoben. Die Lesbarkeit (Kontrast) ist stets zu gewährleisten.
- **Interaktive Fragen** erklären immer den Sinn der Eingabe und geben zulässige Antworten explizit an (z.B. `[J/n]`).
- **Defaultwerte** werden bei keiner Eingabe automatisch verwendet und sind so gewählt, dass sie die wahrscheinlichste und sicherste Option darstellen.
- **Abschnittsweise Gliederung** (z.B. durch Leerzeilen, Überschriften, Einrückungen) ist bei längeren Ausgaben Pflicht.

## Einheitliches Schema für Warnungen und Fehler

Warnungen und Fehler werden immer nach folgendem Muster ausgegeben:

- Zwei Leerzeichen Einrückung
- Pfeil (→)
- Tag [WARN] (gelb) bzw. [ERROR] (rot)
- Danach der eigentliche Text

Beispiel Warnung:

```bash
  \033[1;33m→ [WARN]\033[0m Dies ist eine Warnung.
```

Beispiel Fehler:

```bash
  \033[1;31m→ [ERROR]\033[0m Ein Fehler ist aufgetreten!
```

Keine unterschiedlichen Formate wie [WARN] vs. Fehler: oder uneinheitliche Einrückung verwenden. Die Farbcodierung wird immer durch das Tag ergänzt, reine Farbe ist nicht ausreichend.

## Beispiele

- Erfolg:   `\033[1;32m[OK]\033[0m   → Alles erledigt.`
- Warnung:  `\033[1;33m[WARN]\033[0m → Achtung, dies ist nur ein Hinweis.`
- Fehler:   `\033[1;31m[ERROR]\033[0m → Ein Fehler ist aufgetreten!`
- Prompt:   `\033[1;34mBitte bestätigen Sie mit [J/n]:\033[0m`

## Barrierefreiheit

- Es ist auf ausreichenden Kontrast und Lesbarkeit zu achten.
- Farbcodierung wird immer durch Textsymbole (z.B. [OK], [WARN], [ERROR]) ergänzt.
- Keine Information darf ausschließlich durch Farbe vermittelt werden.

## Gültigkeit

Diese Policy ist für alle eigenen Shellskripte, Python- und Node.js-CLI-Tools im Projekt verbindlich. Sie ergänzt die Vorgaben aus `dokumentationsstandard.md` und `review_policy.md`.

---

# Copilot Review Policy – Ergänzung

- Bei jeder Prüfung von CLI-Ausgaben ist die Einhaltung der Farb- und Strukturregeln aus `cli_ausgabe_policy.md` zu kontrollieren.
- Abweichungen sind zu dokumentieren und zu begründen.
- Vorschläge zur Verbesserung der CLI-Usability sind explizit zu machen.
- Die Policy ist auch bei der Generierung von Funktionskommentaren und Beispielen zu beachten.
