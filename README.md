# Fotobox

Dieses Projekt ist eine Fotobox-Anwendung mit Python-Backend (Flask), HTML/JS-Frontend und SQLite für Einstellungen. Die Software ist für den Einsatz auf Linux-Systemen (z.B. Raspberry Pi, Ubuntu/Debian) konzipiert und kann per Skript installiert, aktualisiert und deinstalliert werden.

## Installation

1. Installationsskript herunterladen:

   ```sh
   wget https://raw.githubusercontent.com/DirkGoetze/fotobox2/main/fotobox.sh
   sudo chmod +x fotobox.sh
   sudo ./fotobox.sh --install
   ```

   Das Skript lädt automatisch das gesamte Repository, installiert alle Abhängigkeiten, richtet NGINX ein, konfiguriert das Backend als systemd-Service und übernimmt die gesamte Systemintegration. Während der Installation werden Sie nach User/Gruppe für den Betrieb gefragt.

## Update

Um die Fotobox-Software auf die neueste Version zu aktualisieren, führen Sie das Skript mit dem Update-Parameter aus:

```sh
sudo ./fotobox.sh --update
```

Das Skript legt automatisch ein Backup der aktuellen Installation an, aktualisiert den Code aus GitHub, installiert ggf. neue Abhängigkeiten und startet die Dienste neu.

## Deinstallation

Um die Fotobox-Software vollständig zu entfernen und alle Systemänderungen rückgängig zu machen, führen Sie das Skript mit dem Remove-Parameter aus:

```sh
sudo ./fotobox.sh --remove
```

Das Skript stellt vorherige Systemdateien aus dem Backup wieder her und entfernt alle Projektdateien sowie die zugehörigen Dienste.

## Hinweise

- Die Konfigurationsseite ist passwortgeschützt, das Passwort sollte regelmäßig geändert werden.
- Für den Produktivbetrieb wird empfohlen, HTTPS (z. B. mit Let's Encrypt) zu aktivieren.
- Alle Systemdateien (NGINX, systemd, Datenbank) werden bei Installation, Update und Deinstallation automatisch gesichert und können wiederhergestellt werden.

---

Weitere Details und technische Dokumentation finden Sie im Ordner `documentation/`.
