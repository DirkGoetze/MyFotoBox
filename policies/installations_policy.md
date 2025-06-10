# Installations-Policy

Diese Policy definiert den verbindlichen Ablauf und die technischen Anforderungen für die Installation der Fotobox-Software und dient als technische Vorgabe für Entwickler.

## Installationsablauf

Der Installationsprozess ist in folgenden Schritten zu implementieren:

```
+-------------------------------------------------------------------------------+
| Start: Aufruf install_fotobox.sh                                              |
+-------------------------------------------------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Prüfe Skriptstandort                                                          |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | Skript im Zielverzeichnis            |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Prüfe Root-Rechte                                                             |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | Root-Rechte erforderlich             |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Prüfe Betriebssystem und Versionen (Distribution, Python usw.)                |
+-------------------------------------------------------------------------------+
| OK                                     | Warnung                              |
+----------------------------------------+--------------------------------------+
|                                        | Fortfahren mit Warnung               |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Installation der Systempakete (git, nginx, python3-venv, sqlite3 usw.)        |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | Systempakete konnten nicht           |
|                                        | installiert werden                   |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Python-Abhängigkeiten installieren (venv erstellen, requirements.txt)         |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | Python-Abhängigkeiten                |
|                                        | konnten nicht installiert werden     |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Konfiguration NGINX (manage_nginx.sh ausführen)                               |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | NGINX konnte nicht                   |
|                                        | konfiguriert werden                  |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Backend als Systemdienst einrichten (manage_backend_service.sh)               |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | Backend-Dienst konnte nicht          |
|                                        | eingerichtet werden                  |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Prüfe Konfiguration                                                           |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | Konfiguration nicht vollständig      |
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Backend-Service starten                                                       |
+-------------------------------------------------------------------------------+
| OK                                     | Fehler                               |
+----------------------------------------+--------------------------------------+
|                                        | Abbruch:                             |
|                                        | Backend konnte nicht gestartet werden|
+----------------------------------------+--------------------------------------+
            |
+-------------------------------------------------------------------------------+
| Installationslog ausgeben und URL für Webzugriff anzeigen                     |
+-------------------------------------------------------------------------------+
```

## Technische Anforderungen

### Systemvoraussetzungen

- **Unterstützte Systeme:** Debian/Ubuntu (prioritär) oder andere Linux-Systeme mit systemd
- **Python-Version:** 3.8 oder höher
- **Speicherplatz:** Mindestens 500 MB freier Speicher
- **RAM:** Mindestens 1 GB freier Arbeitsspeicher
- **Benutzerrechte:** Root-Rechte für die Installation erforderlich

### Zu installierende Systemkomponenten

```bash
apt-get update && apt-get install -y \
  git \
  lsof \
  nginx \
  python3-venv \
  python3-pip \
  sqlite3
```

### Python-Abhängigkeiten

Alle Python-Abhängigkeiten müssen in der Datei `backend/requirements.txt` definiert und in einer virtuellen Umgebung installiert werden.

```bash
# Virtual Environment erstellen
python3 -m venv /opt/fotobox/venv

# Abhängigkeiten installieren
/opt/fotobox/venv/bin/pip install -r backend/requirements.txt
```

### Systemdienst-Konfiguration

Der Backend-Dienst muss über systemd verwaltet werden. Die Konfigurationsdatei `conf/fotobox-backend.service` wird nach `/etc/systemd/system/` kopiert.

```bash
cp conf/fotobox-backend.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable fotobox-backend.service
systemctl start fotobox-backend.service
```

### NGINX-Konfiguration

Die Webserver-Konfiguration erfolgt über das Skript `backend/scripts/manage_nginx.sh`. Die Standardkonfiguration wird aus `conf/nginx-fotobox.conf` geladen.

```bash
bash backend/scripts/manage_nginx.sh setup
```

## Überprüfung der Installation

Nach der Installation müssen folgende Elemente überprüft werden:

1. Backend-Dienst läuft: `systemctl status fotobox-backend.service`
2. NGINX-Dienst läuft: `systemctl status nginx`
3. Port ist erreichbar: `curl http://localhost:8080/` (oder konfigurierter Port)
4. Datenbank wurde erstellt: `test -f /opt/fotobox/data/fotobox_settings.db`

## Logs und Fehlerbehandlung

- Alle Installationsschritte werden in einer Log-Datei protokolliert: `/opt/fotobox/logs/install.log`
- Bei jedem Fehler wird eine eindeutige Fehlermeldung ausgegeben und der Fehlercode im Log vermerkt
- Das Installationsskript enthält Wiederherstellungsfunktionen für fehlgeschlagene Installationen

**Stand:** 10. Juni 2025

Diese Installations-Policy ist verbindlich für alle Entwicklungen am Fotobox-Projekt, die den Installationsprozess betreffen.
