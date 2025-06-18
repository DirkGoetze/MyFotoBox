# Fotobox Installation

Diese Dokumentation beschreibt die Installation der Fotobox-Software auf einem Linux-System.

## Voraussetzungen

- Linux-basiertes Betriebssystem (Debian, Ubuntu, Raspberry Pi OS)
- Root-Zugriff (sudo)
- Git installiert
- Internetverbindung

## Schnellinstallation

Für eine einfache Installation kopieren Sie den folgenden Befehl und führen ihn in einem Terminal aus:

```bash
curl -s https://raw.githubusercontent.com/DirkGoetze/MyFotoBox/main/prepare_install.sh | sudo bash
```

Oder wenn Sie die Datei bereits heruntergeladen haben:

```bash
sudo ./prepare_install.sh
```

## Installationsoptionen

Das Vorbereitungsskript `prepare_install.sh` unterstützt verschiedene Installationsoptionen:

```
Verwendung: ./prepare_install.sh [OPTIONEN]

Optionen:
  -u, --unattended       Unbeaufsichtigter Modus (keine Benutzerinteraktion)
  --http-port PORT       HTTP-Port für den Webserver (Standard: 80)
  --https-port PORT      HTTPS-Port für den Webserver (Standard: 443)
  -h, --help             Zeigt diese Hilfe an

Beispiele:
  ./prepare_install.sh --unattended --http-port 8080
  ./prepare_install.sh --help
```

### Unbeaufsichtigter Modus

Für automatisierte Installationen ohne Benutzerinteraktion:

```bash
sudo ./prepare_install.sh --unattended --http-port 8080 --https-port 4443
```

## Firewall-Konfiguration

Die Firewall wird automatisch konfiguriert, um die benötigten Ports zu öffnen:
- HTTP-Port (Standard: 80) - für den Webzugriff
- HTTPS-Port (Standard: 443) - für den sicheren Webzugriff

Unterstützte Firewall-Systeme:
- UFW (Uncomplicated Firewall)
- FirewallD
- iptables

Die Firewall-Konfiguration kann im interaktiven Modus übersprungen werden, im unbeaufsichtigten Modus wird sie automatisch angewendet.

## Nach der Installation

Nach erfolgreicher Installation können Sie auf die Weboberfläche zugreifen:
- http://localhost (oder die IP-Adresse des Servers)

Falls Sie einen benutzerdefinierten Port angegeben haben:
- http://localhost:PORT

## Fehlerbehebung

Falls bei der Installation Probleme auftreten, werfen Sie einen Blick in die Logdatei:
```bash
cat /var/log/fotobox/install.log
```

Weitere Informationen zur Fehlerbehebung finden Sie in der Datei `INSTALL_TROUBLESHOOTING.md`.
