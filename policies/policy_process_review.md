# Review Policy für das Fotobox-Projekt

Diese Policy beschreibt die verbindlichen Regeln für die Überprüfung und Bearbeitung aller Quellcodedateien und Dokumente im Projekt.

## Review-Prozess

* Syntax und Funktionalität müssen für alle relevanten Modi geprüft werden (z.B. Installation, Update, Deinstallation, Laufzeit, Interaktion).
* Mögliche Fehlerquellen und Schwierigkeiten (z.B. Rechte, Abhängigkeiten, veraltete Software, Distributionen, Hardware, Browser-Kompatibilität) sind zu identifizieren.
* Alle gefundenen Fehler und Schwachstellen sind aufzulisten.
* Für jeden Punkt ist eine Korrektur vorzuschlagen und zu begründen.
* Nach Nutzer-Zustimmung werden Anpassungen einzeln und nachvollziehbar vorgenommen.
* Ziel: Ein robustes, auf allen aktuellen Debian- und Ubuntu-Systemen (und Derivaten) sowie gängigen Browsern funktionierendes Projekt mit minimalen Hardware-Anforderungen.
* Für Shellskripte gilt: Nur Bash-Syntax und -Funktionen prüfen und verwenden, keine SH-Mischformen.

## Review-Dokumentation

* Alle durchgeführten Reviews werden im Ordner `reviews/` dokumentiert.
* Die Review-Dokumente enthalten Informationen über identifizierte Probleme, durchgeführte Änderungen und Begründungen.
* Der `reviews/`-Ordner wird nicht versioniert (.gitignore), um die Hauptstruktur des Repositories übersichtlich zu halten.

*Diese Policy ist bei jeder Überprüfung und Bearbeitung einzuhalten.*
