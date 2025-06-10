# Policy: Nutzerrechte und Rechtevergabe

Alle schreibenden Operationen im Projektverzeichnis (z.B. durch Shell-, Python- oder Hilfsskripte) müssen sicherstellen, dass die betroffenen Dateien und Verzeichnisse nach Abschluss dem Anwendungsnutzer 'fotobox' gehören (`chown -R fotobox:fotobox ...`).

- Systemoperationen (Paketinstallation, NGINX, systemd) erfolgen weiterhin als root.
- Nach jedem schreibenden Schritt im Projektverzeichnis ist die Rechtevergabe zu prüfen und ggf. zu korrigieren, um spätere Zugriffsprobleme zu vermeiden.
- Diese Policy ist für alle Skripte, Module und ausgelagerten Komponenten verbindlich und bei jeder Auslagerung oder Erweiterung zu beachten.

> **Hinweis für Python- und Shell-Skripte:**
>
> Wenn ein Update- oder Installationsprozess als root ausgeführt wird (z.B. `manage_update.py`), müssen nach jedem schreibenden Schritt im Projektverzeichnis die Rechte explizit auf `fotobox:fotobox` gesetzt werden, z.B. mit `chown -R fotobox:fotobox /opt/fotobox`. Andernfalls kann es zu Zugriffsproblemen kommen, wenn nachfolgende Prozesse als Nutzer `fotobox` laufen.
>
> **Beispiel für Python:**
>
> ```python
> import subprocess
> subprocess.run(["chown", "-R", "fotobox:fotobox", "/opt/fotobox"])
> ```
>
> **Beispiel für Shell:**
>
> ```bash
> chown -R fotobox:fotobox /opt/fotobox
> ```
>
> Diese Rechtekorrektur ist nach jedem schreibenden Schritt im Projektverzeichnis durchzuführen, wenn das Skript als root läuft.
