# ...existing code...

---

## Ergänzung: CLI-Ausgabe-Policy (siehe policies/cli_ausgabe_policy.md)

- Bei allen Shell-, Python- und Node.js-CLI-Skripten sind die Farb- und Strukturregeln aus `policies/cli_ausgabe_policy.md` einzuhalten.
- Ampelfarben: Grün = Erfolg, Gelb = Warnung, Rot = Fehler, Blau = Benutzerinteraktion, Standard = Info.
- Benutzerinteraktionen immer neutral und abgesetzt, Defaultwerte klar angeben.
- Abschnittsweise Gliederung und Einrückung beachten.
- Barrierefreiheit: Keine reine Farbcodierung, immer Textsymbole ergänzen.
- Copilot muss bei jeder Review und Codegenerierung auf diese Policy prüfen und Verstöße melden.