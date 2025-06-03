# Fotobox: Installationsanleitung

Diese Anleitung beschreibt Schritt für Schritt, wie Sie die Fotobox-Software auf einem Ubuntu- oder Debian-System installieren. Sie richtet sich an Linux-Einsteiger und erklärt alle wichtigen Funktionen des Installationsskripts.

## Voraussetzungen

- Ein Ubuntu- oder Debian-basiertes System (z.B. Raspberry Pi OS, Ubuntu Server)
- Root-Rechte (Sie müssen das Skript als Administrator ausführen)
- Internetverbindung

## Vorbereitung

Laden Sie das Installationspaket herunter oder klonen Sie das Repository:

```bash
git clone https://github.com/DirkGoetze/fotobox2.git
cd fotobox2
```

## Installation starten

Führen Sie das Installationsskript als root aus:

```bash
sudo bash fotobox.sh --install
```

## Was passiert bei der Installation?

Das Skript übernimmt folgende Aufgaben (jeder Schritt wird im Terminal erklärt):

1. **Systemprüfung**: Das Skript prüft, ob Sie root-Rechte haben und ob das System unterstützt wird.
2. **System-Update**: Die Paketlisten werden aktualisiert, damit alle Softwarepakete auf dem neuesten Stand sind.
3. **Software-Installation**: Notwendige Programme wie nginx (Webserver), Python, pip, venv, sqlite3 und lsof werden installiert. Fehlt ein Paket, wird es automatisch nachinstalliert.
4. **Benutzer und Gruppe**: Das Skript legt automatisch den Systembenutzer und die Gruppe "fotobox" an und verwendet diese für die Ausführung der Software. Dies erhöht die Sicherheit und trennt die Fotobox von anderen Diensten.
5. **Projektdateien**: Das Fotobox-Projekt wird aus dem Internet geladen (git clone) und die Zugriffsrechte werden korrekt gesetzt.
6. **Python-Umgebung**: Eine eigene Python-Umgebung (venv) wird eingerichtet und alle benötigten Python-Bibliotheken werden installiert.
7. **Passwort setzen**: Die Zugangsdaten für die Konfigurationsseite werden nach der Installation beim ersten Aufruf der Weboberfläche festgelegt (nicht im Installationsskript).
8. **Backup & Organisation**: Wichtige Systemdateien (z.B. NGINX-Konfiguration) werden gesichert und im Projektordner organisiert.
9. **NGINX-Konfiguration**: Das Skript erkennt automatisch, ob NGINX im Default-Modus oder als Multi-Site läuft. Sie werden gefragt, ob die Fotobox in die bestehende Default-Konfiguration integriert oder als eigene Site mit eigener Konfiguration eingerichtet werden soll. Bestehende NGINX-Konfigurationen bleiben erhalten und werden nicht ohne Rückfrage deaktiviert oder gelöscht. Bei Port-Konflikten werden Sie gefragt, ob ein alternativer Port verwendet werden soll. Alle Änderungen sind reversibel (Backups werden angelegt).
10. **Systemdienst**: Das Backend (die eigentliche Fotobox-Software) wird als systemd-Dienst eingerichtet und gestartet. So läuft die Fotobox automatisch nach jedem Neustart.
11. **Abschlusstest**: Am Ende prüft das Skript, ob die Weboberfläche erreichbar ist. Sie erhalten eine Erfolgsmeldung oder Hinweise zur Fehlerbehebung.

## Beispiel für den Aufruf

```bash
sudo bash fotobox.sh --install
```

## Hinweise

- Nach der Installation können Sie die Fotobox im Browser aufrufen, z.B.:
  - [http://IP-ADRESSE:80/](http://IP-ADRESSE:80/)  (Standard)
  - [http://IP-ADRESSE:8080/](http://IP-ADRESSE:8080/) (falls Port 80 belegt war)
- Die Zugangsdaten für die Konfigurationsseite werden beim ersten Start der Weboberfläche festgelegt.
- Alle wichtigen Schritte und Fehler werden in der Logdatei `/var/log/fotobox_install.log` protokolliert.

## Fehlerbehebung

- Prüfen Sie, ob alle Dienste laufen:
  - `systemctl status fotobox-backend`
  - `systemctl status nginx`
- Prüfen Sie, ob der gewählte Port frei ist: `sudo lsof -i :80` oder `sudo lsof -i :8080`
- Lesen Sie die Hinweise im Terminal und in der Logdatei.

## Headless-/Unattended-Installation

-------------------------------------------------------------------------------

Die Fotobox-Installation unterstützt einen vollautomatischen, interaktiven und headless-tauglichen Modus. Dieser Modus ist besonders für unerfahrene Nutzer, automatisierte Deployments oder Installationen ohne Benutzerinteraktion (z.B. via SSH, Skripte, CI/CD) geeignet.

### Aktivierung des Headless-/Unattended-Modus

Der Modus wird durch das Flag `--unattended` (oder Synonyme wie `-u`, `--headless`, `headless`, `-q`) beim Aufruf des Installationsskripts aktiviert:

```bash
sudo ./install_fotobox.sh --unattended
```

### Verhalten im Unattended-Modus

- **Alle Rückfragen werden automatisch mit Standardwerten beantwortet.**
  - Portwahl: Standardport 80 wird verwendet (sofern frei).
  - NGINX-Integration: Default-Integration wird automatisch gewählt.
  - Paket-Upgrade: Upgrades werden abgelehnt (Standard: "n").
  - NGINX-Installation: Wird automatisch bestätigt (Standard: "j").
  - Bei Konflikten (z.B. Port belegt): Abbruch mit Log-Eintrag.
- **Keine Interaktion erforderlich:** Das Skript läuft ohne Benutzereingaben durch.
- **Dialog- und Statusausgaben:**
  - Nutzeraufforderungen (print_prompt) werden nicht angezeigt, sondern nur ins Log geschrieben.
  - Fehler- und Statusmeldungen werden weiterhin ins Logfile geschrieben.
  - Am Ende erfolgt ein Hinweis auf die Logdatei und die Weboberfläche auf stdout.
- **Fehlerbehandlung:**
  - Kritische Fehler führen zum Abbruch und werden im Logfile dokumentiert.
  - Für die Fehleranalyse ist das Logfile heranzuziehen (Pfad wird am Ende ausgegeben).
- **Logging:**
  - Alle wichtigen Aktionen, Status- und Fehlermeldungen werden mit Zeitstempel in eine Logdatei geschrieben (Standard: `/var/log/<datum>_install_fotobox.log` oder `/tmp/...` falls `/var/log` nicht beschreibbar).
  - Die Logdatei wird täglich rotiert und ältere Logs werden komprimiert.

### Beispiel für eine Headless-Installation

```bash
sudo ./install_fotobox.sh --unattended
```

Nach Abschluss der Installation erscheint z.B.:

```text
Installation abgeschlossen. Details siehe Logfile: /var/log/2025-06-03_install_fotobox.log
Weboberfläche: [http://192.168.1.100:80/](http://192.168.1.100:80/)
```

### Hinweise und Besonderheiten

- Für alle automatischen Entscheidungen siehe die Logdatei.
- Bei Problemen (z.B. Port belegt, fehlende Abhängigkeiten) erfolgt ein Abbruch mit Log-Hinweis.
- Die Headless-Installation ist für alle unterstützten Debian/Ubuntu-Systeme geeignet.
- Die Option ist ideal für automatisierte Setups, Testumgebungen und Remote-Installationen.

-------------------------------------------------------------------------------

Mit dieser Anleitung sollte die Installation auch für Einsteiger problemlos gelingen. Bei Fragen hilft die README.md im Projektverzeichnis weiter.
