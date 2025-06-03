# Fotobox

Kurzanleitung zum Herunterladen und Starten des Installationsskripts:

```sh
wget https://raw.githubusercontent.com/DirkGoetze/fotobox2/main/install_fotobox.sh
chmod +x install_fotobox.sh
sudo ./install_fotobox.sh
```

Für ausführliche Informationen zu Installation, Update und Deinstallation siehe:

- [INSTALLATION](documentation/INSTALLATION.md): Ausführliche Installationsanleitung
- [UPDATE](documentation/UPDATE.md): Update-Anleitung
- [REMOVE](documentation/REMOVE.md): Deinstallationsanleitung
- [DOKUMENTATIONSSTANDARD](DOKUMENTATIONSSTANDARD.md): Kommentar- und Review-Standards
- [BACKUP_STRATEGIE](BACKUP_STRATEGIE.md): Verbindliche Backup-/Restore-Strategie für alle Features

Weitere technische Details und Hinweise finden Sie im Ordner `documentation/`.

## Verwaltung und Wartung ab Version 2.0

- **Erstinstallation:**
  - Führe als root das Skript `install_fotobox.sh` aus.
- **Update und Deinstallation:**
  - Nutze die Weboberfläche (WebUI) oder die Python-Skripte im Ordner `backend/`:
    - `backend/manage_update.py` für Updates
    - `backend/manage_uninstall.py` für Deinstallation/Restore
- **Backups und Logs:**
  - Alle Backups und Logs werden im Ordner `backup/` abgelegt.

Weitere Details siehe `documentation/installation.md`, `UPDATE.md`, `REMOVE.md`.

## Headless-/Unattended-Installation

Die Fotobox kann vollständig ohne Benutzerinteraktion installiert werden (headless/unattended). Hierzu das Installationsskript mit dem Flag `--unattended` aufrufen:

```bash
sudo ./install_fotobox.sh --unattended
```

Weitere Details und Hinweise siehe `documentation/installation.md`.

## Projektbezogne Benutzer und Gruppen  

Das Installationsskript legt den Systembenutzer und die Gruppe `fotobox` **ohne Home-Verzeichnis** und **ohne Login-Shell** an. Dies dient der Sicherheit des Gastsystem.

Weitere Details und Hintergründe siehe `documentation/installation.md`.
