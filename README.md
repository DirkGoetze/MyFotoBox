# Fotobox

Kurzanleitung zur Nutzung des Installationsskripts:

```sh
sudo ./fotobox.sh --install
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

Weitere Details siehe `documentation/INSTALLATION.md`, `UPDATE.md`, `REMOVE.md`.
