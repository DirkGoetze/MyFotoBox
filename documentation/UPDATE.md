# Fotobox: Update-Anleitung

Diese Anleitung erklärt, wie Sie die Fotobox-Software auf den neuesten Stand bringen. Sie richtet sich an Linux-Einsteiger und beschreibt alle wichtigen Funktionen des Update-Prozesses.

## Voraussetzungen

- Die Fotobox ist bereits installiert und läuft auf Ihrem System.
- Sie haben Root-Rechte (Administrator).
- Internetverbindung ist vorhanden.

## Update starten

Führen Sie das Update-Skript im Projektverzeichnis aus:

```bash
sudo bash fotobox.sh --update
```

Alternativ können Sie das Update über die Weboberfläche durchführen:

1. Öffnen Sie die Einstellungsseite (`settings.html`) 
2. Melden Sie sich als Administrator an
3. Klicken Sie im Bereich "System-Updates" auf "Auf Updates prüfen"
4. Wenn ein Update verfügbar ist, klicken Sie auf "Update installieren"

## Was passiert beim Update?

Das Skript übernimmt folgende Aufgaben (jeder Schritt wird im Terminal erklärt):

1. **Backup**: Vor dem Update werden alle wichtigen Daten und Konfigurationen gesichert (Backend, Frontend, NGINX, systemd-Service). So können Sie bei Problemen jederzeit zurückkehren.
2. **Projekt-Update**: Das Fotobox-Projekt wird aus dem Internet aktualisiert (git pull). Falls das Skript selbst aktualisiert wurde, werden Sie informiert und müssen das Update erneut starten.
3. **Systemabhängigkeiten**: Betriebssystem-Pakete, die von der Software benötigt werden, werden geprüft und bei Bedarf installiert oder aktualisiert (entsprechend der `conf/requirements_system.inf`).
4. **Python-Abhängigkeiten**: Die Python-Umgebung (venv) wird aktualisiert und alle benötigten Bibliotheken werden auf den neuesten Stand gebracht (entsprechend der `conf/requirements_python.inf`).
5. **NGINX-Konfiguration**: Die Webserver-Konfiguration wird geprüft und ggf. angepasst. Sie können einen alternativen Port wählen, falls der Standard-Port belegt ist.
6. **Systemdienst**: Der Fotobox-Backend-Dienst wird neu gestartet, damit alle Änderungen aktiv werden.
7. **Abschlusstest**: Das Skript prüft, ob die Weboberfläche nach dem Update erreichbar ist. Sie erhalten eine Erfolgsmeldung oder Hinweise zur Fehlerbehebung.

## Abhängigkeiten-Management

Das Update-System prüft und aktualisiert automatisch folgende Abhängigkeiten:

### Systemabhängigkeiten

Die Datei `conf/requirements_system.inf` im Projektverzeichnis der Fotobox definiert alle erforderlichen Betriebssystem-Pakete mit ihren Mindestversionen. Diese werden bei jedem Update überprüft und bei Bedarf aktualisiert.

Beispiel für den Inhalt der `conf/requirements_system.inf`:
```
# System-Abhängigkeiten für Fotobox2
# Format: paket>=version

# Grundlegende Pakete
nginx>=1.18.0
python3>=3.8
python3-pip>=20.0
```

### Python-Abhängigkeiten

Die Datei `conf/requirements_python.inf` im Projektverzeichnis definiert alle erforderlichen Python-Module. Diese werden bei jedem Update überprüft und bei Bedarf installiert oder aktualisiert.

## Abhängigkeiten manuell prüfen

Sie können den Status der Abhängigkeiten auch über die Weboberfläche einsehen:

1. Öffnen Sie die Einstellungsseite (`settings.html`)
2. Melden Sie sich als Administrator an
3. Im Bereich "System-Updates" werden fehlende oder veraltete Abhängigkeiten angezeigt
4. Klicken Sie auf "Abhängigkeiten installieren", um fehlende Abhängigkeiten zu installieren

## Beispiel für den Aufruf

```bash
sudo bash fotobox.sh --update
```

## Hinweise

- Das Backup des alten Stands finden Sie im Projektordner unter `backup-update-<Datum>`. Sie können daraus bei Bedarf Dateien wiederherstellen.
- Nach dem Update können Sie die Fotobox wie gewohnt im Browser aufrufen.
- Alle wichtigen Schritte und Fehler werden in der Logdatei `/var/log/fotobox_install.log` protokolliert.

## Fehlerbehebung

- Prüfen Sie, ob alle Dienste laufen:
  - `systemctl status fotobox-backend`
  - `systemctl status nginx`
- Prüfen Sie, ob der gewählte Port frei ist: `sudo lsof -i :80` oder `sudo lsof -i :8080`
- Lesen Sie die Hinweise im Terminal und in der Logdatei.

---

Mit dieser Anleitung können Sie Ihre Fotobox sicher und einfach auf dem neuesten Stand halten.
