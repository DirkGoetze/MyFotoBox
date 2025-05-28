# Fotobox

Dieses Projekt ist eine Fotobox-Anwendung mit Python-Backend und HTML/JS-Frontend.

## Installation von GitHub

1. Repository klonen:

   ```sh
   git clone https://github.com/DirkGoetze/fotobox2.git
   cd fotobox2
   ```

2. Installationsskript als root ausführen:

   ```sh
   sudo bash install_fotobox.sh
   ```

Das Skript installiert alle Abhängigkeiten, richtet NGINX ein und startet das Backend als Service.

### Sicherheit

- Die Konfigurationsseite ist passwortgeschützt, das Passwort sollte regelmäßig geändert werden.
- Für den Produktivbetrieb HTTPS aktivieren (z. B. mit Let's Encrypt).

## Update des Projekts

Um das Projekt auf die neueste Version zu aktualisieren, führen Sie das Update-Skript als root aus:

```sh
sudo bash update_fotobox.sh
```

Das Skript legt automatisch ein Backup der aktuellen Installation an, aktualisiert den Code aus GitHub, installiert ggf. neue Abhängigkeiten und startet die Dienste neu.

## Deinstallation

Um das Projekt vollständig zu entfernen und alle Systemänderungen rückgängig zu machen, führen Sie das Deinstallationsskript als root aus:

```sh
sudo bash uninstall_fotobox.sh
```

Das Skript stellt vorherige Systemdateien aus dem Backup wieder her und entfernt alle Projektdateien sowie die zugehörigen Dienste.

---

# Dokumentation zur MyFotoBox-Installation

Die vollständige Anleitung zur Installation, Update und Deinstallation finden Sie in dieser README.md.

(Die Inhalte entsprechen der bisherigen README im Projektroot.)
