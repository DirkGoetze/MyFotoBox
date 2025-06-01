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
4. **Benutzer und Gruppe**: Sie werden gefragt, unter welchem Systembenutzer und welcher Gruppe die Fotobox laufen soll (Standard: www-data). Das erhöht die Sicherheit.
5. **Projektdateien**: Das Fotobox-Projekt wird aus dem Internet geladen (git clone) und die Zugriffsrechte werden korrekt gesetzt.
6. **Python-Umgebung**: Eine eigene Python-Umgebung (venv) wird eingerichtet und alle benötigten Python-Bibliotheken werden installiert.
7. **Passwort setzen**: Sie legen ein Passwort für die Konfigurationsseite der Fotobox fest. Dieses wird sicher (verschlüsselt) gespeichert.
8. **Backup & Organisation**: Wichtige Systemdateien (z.B. NGINX-Konfiguration) werden gesichert und im Projektordner organisiert.
9. **NGINX-Konfiguration**: Das Skript prüft, ob der Standard-Webserver-Port (80) frei ist. Falls nicht, können Sie einen alternativen Port wählen (z.B. 8080). Die Konfiguration wird automatisch angepasst.
10. **Systemdienst**: Das Backend (die eigentliche Fotobox-Software) wird als systemd-Dienst eingerichtet und gestartet. So läuft die Fotobox automatisch nach jedem Neustart.
11. **Abschlusstest**: Am Ende prüft das Skript, ob die Weboberfläche erreichbar ist. Sie erhalten eine Erfolgsmeldung oder Hinweise zur Fehlerbehebung.

## Beispiel für den Aufruf
```bash
sudo bash fotobox.sh --install
```

## Hinweise
- Nach der Installation können Sie die Fotobox im Browser aufrufen, z.B.:
  - http://<IP-Adresse>:80/  (Standard)
  - http://<IP-Adresse>:8080/ (falls Port 80 belegt war)
- Das Passwort für die Konfigurationsseite wird beim ersten Start gesetzt.
- Alle wichtigen Schritte und Fehler werden in der Logdatei `/var/log/fotobox_install.log` protokolliert.

## Fehlerbehebung
- Prüfen Sie, ob alle Dienste laufen:
  - `systemctl status fotobox-backend`
  - `systemctl status nginx`
- Prüfen Sie, ob der gewählte Port frei ist: `sudo lsof -i :80` oder `sudo lsof -i :8080`
- Lesen Sie die Hinweise im Terminal und in der Logdatei.

---

Mit dieser Anleitung sollte die Installation auch für Einsteiger problemlos gelingen. Bei Fragen hilft die README.md im Projektverzeichnis weiter.
