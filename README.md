# Fotobox

Dieses Projekt ist eine Fotobox-Anwendung mit Python-Backend und HTML/JS-Frontend.

## Projektstruktur
- **/opt/fotobox/frontend/** – Statische Webdateien (HTML, JS, CSS)
- **/opt/fotobox/backend/** – Python-Backend (Flask)

## Starten des Projekts
1. Python-Backend starten:
   - Wechsle in das Verzeichnis `/opt/fotobox/backend` und führe `python3 app.py` aus (bzw. als systemd-Service, siehe unten).
2. Frontend öffnen:
   - Das Frontend ist nach NGINX-Installation über Port 80 erreichbar (z. B. http://localhost/start.html).

## Hinweise
- Die Kameraansteuerung ist als Platzhalter implementiert und kann auf Linux mit z.B. `fswebcam` oder `raspistill` erweitert werden.
- Die Entwicklung erfolgt aktuell auf Windows, Zielplattform ist Linux.

---

## Hinweise zur NGINX-Nutzung und Projektstruktur

### Einrichtung

1. Führen Sie das Skript `install_nginx_fotobox.sh` als root auf Ihrem Linux-System aus.
2. Die NGINX-Konfiguration wird automatisch eingerichtet und das Frontend ist über Port 80 erreichbar.
3. Das Backend (Flask) muss weiterhin separat gestartet werden (z. B. per systemd-Service).

### Beispiel für Backend-Start (systemd)

```ini
[Unit]
Description=Fotobox Backend (Flask)
After=network.target

[Service]
User=www-data
WorkingDirectory=/opt/fotobox/backend
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Dann aktivieren mit:

```sh
sudo systemctl enable --now fotobox-backend
```

### Sicherheit

- Die Konfigurationsseite ist passwortgeschützt, das Passwort sollte regelmäßig geändert werden.
- Für den Produktivbetrieb HTTPS aktivieren (z. B. mit Let's Encrypt).
