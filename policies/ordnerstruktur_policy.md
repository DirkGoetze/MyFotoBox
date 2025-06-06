# Ordnerstruktur-Policy für das Fotobox-Projekt

Diese Policy regelt die Ablage und Trennung von Skripttypen und Ressourcen im Projekt.

- Verschiedene Skripttypen (z.B. Python, Bash) dürfen nicht im selben Ordner abgelegt werden.
- Im Backend sind für Shell-Skripte und Python-Skripte jeweils eigene Unterordner zu verwenden (z.B. backend/scripts/ für Bash, backend/ für Python).
- Diese Policy ist verbindlich und bei allen Erweiterungen, Auslagerungen oder Umstrukturierungen einzuhalten.
- Die Struktur ist in einer `.folder.info` im jeweiligen Ordner zu dokumentieren.
- Analoges gilt für das Frontend (z.B. js/, css/, images/ etc.).
- Änderungen an der Ordnerstruktur müssen diese Policy berücksichtigen und dokumentiert werden.
- Für Details zur Frontend-Struktur und Trennung siehe policies/frontend_policy.md.

*Siehe auch policies/dokumentationsstandard.md für weitere Details.*
