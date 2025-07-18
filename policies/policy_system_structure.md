# Ordnerstruktur-Policy für das Fotobox-Projekt

Diese Policy regelt die Ablage und Trennung von Skripttypen und Ressourcen im Projekt.

## Grundlegende Ordnerstruktur

- Verschiedene Skripttypen (z.B. Python, Bash) dürfen nicht im selben Ordner abgelegt werden.
- Im Backend sind für Shell-Skripte und Python-Skripte jeweils eigene Unterordner zu verwenden (z.B. backend/scripts/ für Bash, backend/ für Python).
- Diese Policy ist verbindlich und bei allen Erweiterungen, Auslagerungen oder Umstrukturierungen einzuhalten.
- Die Verzeichnisverwaltung erfolgt zentral über `manage_folders.sh` und den Python-Wrapper `manage_folders.py`.
- Verzeichnispfade müssen über die entsprechenden Funktionen wie `get_data_dir()`, `get_log_dir()` etc. abgerufen werden.
- Neue Verzeichnisse werden automatisch beim Installationsprozess oder bei Bedarf dynamisch erstellt.
- Analoges gilt für das Frontend (z.B. js/, css/, images/ etc.).
- Änderungen an der Ordnerstruktur müssen diese Policy berücksichtigen und dokumentiert werden.

## Spezielle Verzeichnisse

### `conf`-Verzeichnis

- Das `conf`-Verzeichnis dient als zentrale Ablage für alle Konfigurationsdateien und Abhängigkeitsdefinitionen.
- Folgende Dateien müssen im `conf`-Verzeichnis abgelegt werden:  - `requirements_system.inf`: Definition aller Systemabhängigkeiten
  - `requirements_python.inf`: Definition aller Python-Abhängigkeiten
  - `fotobox-backend.service`: Systemd-Service-Konfiguration
  - `nginx/template_fotobox.conf`: NGINX-Konfigurationstemplate
  - `version.inf`: Versionsinformationen der Software

- Neue Abhängigkeiten dürfen nicht direkt installiert werden, sondern müssen in den entsprechenden Requirements-Dateien definiert werden.

*Siehe auch policies/dokumentationsstandard.md und policy_system_update.md für weitere Details.*
