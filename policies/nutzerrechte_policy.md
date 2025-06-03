# Policy: Nutzerrechte und Rechtevergabe

Alle schreibenden Operationen im Projektverzeichnis (z.B. durch Shell-, Python- oder Hilfsskripte) müssen sicherstellen, dass die betroffenen Dateien und Verzeichnisse nach Abschluss dem Anwendungsnutzer 'fotobox' gehören (`chown -R fotobox:fotobox ...`).

- Systemoperationen (Paketinstallation, NGINX, systemd) erfolgen weiterhin als root.
- Nach jedem schreibenden Schritt im Projektverzeichnis ist die Rechtevergabe zu prüfen und ggf. zu korrigieren, um spätere Zugriffsprobleme zu vermeiden.
- Diese Policy ist für alle Skripte, Module und ausgelagerten Komponenten verbindlich und bei jeder Auslagerung oder Erweiterung zu beachten.
