# Fotobox Benutzerhandbuch

Dieses Benutzerhandbuch enthält alle wichtigen Informationen zur Bedienung und Konfiguration der Fotobox-Software für Endanwend- Einstellungen**: Alle Konfigurationen wie Event-Name, Darstellungsoptionen etc.
2. **Bildmetadaten**: Informationen zu aufgenommenen Fotos (Zeitstempel, Tags, etc.)
3. **Benutzerinformationen**: Admin-Zugangsdaten für die Einstellungsseite

Diese Dokumentation richtet sich an Endbenutzer der Fotobox-Software und Administratoren, die die Software installieren und konfigurieren. Sie enthält praktische Anleitungen und Erklärungen in verständlicher Sprache.

Alle Dokumentationsdateien sind im Markdown-Format geschrieben und werden regelmäßig aktualisiert, um Änderungen an der Software zu berücksichtigen. Das am Ende des Dokuments angegebene Datum zeigt den aktuellen Stand der Dokumentation.

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Erste Schritte](#erste-schritte)
3. [Die Benutzeroberfläche](#die-benutzeroberfläche)
4. [Fotos aufnehmen](#fotos-aufnehmen)
5. [Galerie anzeigen](#galerie-anzeigen)
6. [Einstellungen anpassen](#einstellungen-anpassen)
7. [Datenverwaltung](#datenverwaltung)
8. [Kontaktinformationen](#kontaktinformationen)
9. [Netzwerkkonfiguration](#netzwerkkonfiguration)
10. [Fehlerbehebung](#fehlerbehebung)
    - [Häufige Probleme](#häufige-probleme)
    - [Updates und Systemverwaltung](#updates-und-systemverwaltung)
    - [Installationsprobleme](#installationsprobleme)
    - [System-Logs](#system-logs)
    - [Datenbank-Fehlerbehebung](#datenbank-fehlerbehebung)
11. [Deinstallation](#deinstallation)

## Übersicht

Die Fotobox ist ein flexibles, webbasiertes System für Events, Partys und Feiern. Sie können direkt Fotos aufnehmen, diese in einer Galerie betrachten und für Ihre Gäste bereitstellen. Gäste können direkt Fotos aufnehmen, diese in einer Galerie ansehen und – sofern ein geeigneter Drucker vorhanden ist – direkt ausdrucken. Die Oberfläche bietet einen Aufnahmemodus und eine Galerieansicht. Optional können Gäste auch Fotos von ihrem eigenen Handy hochladen; diese werden in der Galerie in einem separaten Ordner unter dem vom Nutzer gewählten Namen angezeigt. Alle Bilder und Uploads werden zentral in einer Datenbank verwaltet.

## Erste Schritte

### Installation und Einrichtung

Vor der Nutzung muss die Fotobox auf einem Linux-System (Debian/Ubuntu) installiert werden:

1. Klonen Sie das Repository in ein Verzeichnis Ihrer Wahl:

   ```bash
   sudo git clone https://github.com/DirkGoetze/MyFotoBox.git /opt/fotobox
   ```

2. Wechseln Sie in das Projektverzeichnis und machen Sie das Installationsskript ausführbar:

   ```bash
   cd /opt/fotobox
   sudo chmod +x install.sh
   ```

3. Führen Sie die Installation aus:

   ```bash
   sudo ./install.sh
   ```

> **Hinweis (Aktualisierung vom 14. Juni 2025)**: Das Installationsskript wurde grundlegend überarbeitet, um die Zuverlässigkeit und Robustheit zu verbessern. Es führt nun umfassendere Prüfungen der Systemumgebung durch und bietet bessere Fehlermeldungen bei Problemen. Bei älteren Systemen kann es zu Kompatibilitätsproblemen kommen, insbesondere mit Python-Paketen, die native Erweiterungen kompilieren. In solchen Fällen sollten Sie die entsprechenden Systempakete manuell installieren. Für Intel RealSense-Kameras müssen die spezifischen Pakete manuell aus den Intel-Repositories installiert werden.

#### Headless-/Unattended-Installation

Für eine unbeaufsichtigte Installation ohne Benutzerinteraktion können Sie den Unattended-Modus verwenden:

```bash
sudo ./install.sh --unattended
```

In diesem Modus werden alle Rückfragen automatisch mit Standardwerten beantwortet:

- Standardport 80 wird verwendet (sofern frei)
- NGINX-Integration wird automatisch gewählt
- Bei Konflikten (z.B. Port belegt) erfolgt ein Abbruch mit Log-Eintrag

Die Ausgaben werden nur ins Log geschrieben und am Ende erhalten Sie einen Hinweis auf die Logdatei und die Weboberfläche.

### Erststart und Zugriff

Nach erfolgreicher Installation können Sie die Weboberfläche über einen Browser aufrufen:

- Bei lokaler Installation: `http://localhost:8080` (oder den von Ihnen konfigurierten Port)
- Bei Netzwerkinstallation: Die IP-Adresse oder den Hostnamen des Geräts, auf dem die Fotobox läuft

Beim ersten Start werden Sie durch die Ersteinrichtung geführt, bei der Sie grundlegende Einstellungen vornehmen können:

- Event-Name festlegen
- Admin-Passwort setzen
- Kamera-Einstellungen anpassen
- Speicherort für Fotos wählen

## Die Benutzeroberfläche

Die Fotobox besteht aus mehreren Seiten, die über das Menü erreichbar sind:

### Navigation

- Das **Menü** (☰) in der linken oberen Ecke öffnet die Navigation zu allen verfügbaren Seiten
- Der **Event-Titel** in der Mitte des Headers zeigt den Namen Ihrer Veranstaltung
- Das **Haus-Symbol** im Breadcrumb-Menü führt Sie zurück zur Aufnahme Seite, der Hauptseite der Fotobox
- **Uhrzeit und Datum** werden auf jeder Seite rechts im Header angezeigt

### Verfügbare Seiten

1. **Home** (capture.html): Die Hauptseite für die Fotoaufnahme
2. **Galerie** (gallery.html): Zeigt alle aufgenommenen Fotos an
3. **Kontakt** (contact.html): Enthält Informationen, wie Gäste an die Fotos kommen
4. **Einstellungen** (settings.html): Passwortgeschützter Bereich für die Konfiguration

## Fotos aufnehmen

Auf der Home-Seite können Sie:

1. Die Kamera-Vorschau sehen
2. Den "Foto aufnehmen"-Button drücken, um ein Bild zu erstellen
3. Optional einen Countdown vor der Aufnahme nutzen

Die aufgenommenen Fotos werden automatisch gespeichert und sind sofort in der Galerie verfügbar.

## Galerie anzeigen

In der Galerie-Ansicht werden alle Fotos chronologisch angezeigt (neueste zuerst). Sie können:

- Durch die Fotos blättern
- Die Vollbildansicht eines Fotos öffnen
- Nach einer gewissen Zeit der Inaktivität kehrt die Anzeige automatisch zur Home-Seite zurück

## Einstellungen anpassen

Im Einstellungsbereich (passwortgeschützt) können Sie folgende Parameter anpassen. Alle Änderungen werden automatisch gespeichert und es erscheint eine Benachrichtigung über den Status (Erfolg oder Fehler). Erfolgsbenachrichtigungen verschwinden nach kurzer Zeit automatisch, während Fehlermeldungen länger angezeigt werden:

### Event-Einstellungen

- Event-Name ändern
- Event-Datum festlegen

### Darstellungseinstellungen

- Anzeigemodus wählen (Systemabhängig/Hell/Dunkel)
- Bildschirmschoner-Timeout einstellen
- Automatische Rückkehr aus der Galerie konfigurieren

### Kamera-Einstellungen

- Kamera auswählen (Systemstandard oder spezifische Kamera)
- Blitzlicht-Modus einstellen (Automatisch/An/Aus)
- Countdown-Dauer für Fotos anpassen

### Admin-Einstellungen

- Admin-Passwort ändern

## Datenverwaltung

Die Fotobox speichert alle Einstellungen und Bildinformationen in einer Datenbank, die automatisch verwaltet wird. Als Benutzer müssen Sie sich um die Datenbankverwaltung nicht kümmern, sollten aber einige grundlegende Aspekte kennen:

### Gespeicherte Daten

Die Fotobox speichert folgende Informationen in der Datenbank:

1. **Einstellungen**: Alle Konfigurationen wie Event-Name, Darstellungsoptionen etc.
2. **Bildmetadaten**: Informationen zu aufgenommenen Fotos (Zeitstempel, Tags, etc.)
3. **Benutzerinformationen**: Admin-Zugangsdaten für die Einstellungsseite

### Datensicherheit

- Alle Daten werden lokal auf dem Fotobox-Gerät gespeichert
- Passwörter werden sicher gehasht gespeichert
- Es werden keine Daten ohne Ihre Zustimmung an externe Dienste übertragen

### Datenintegrität

Die Datenbank überprüft regelmäßig ihre Integrität und führt Optimierungen durch. Falls Sie dennoch Probleme mit den gespeicherten Daten bemerken (falsche Einstellungen, fehlende Bilder in der Galerie), können Sie folgende Schritte unternehmen:

1. Öffnen Sie die Einstellungsseite und melden Sie sich als Administrator an
2. Navigieren Sie zum Bereich "System"
3. Wählen Sie "Datenbank-Integrität prüfen"
4. Bei Problemen nutzen Sie die Option "Datenbank optimieren"

## Kontaktinformationen

Auf der Kontaktseite können Sie Informationen hinterlegen, wie Ihre Gäste die Fotos erhalten können. Diese Seite ist anpassbar und kann für jedes Event individuell gestaltet werden.

## Netzwerkkonfiguration

Die Fotobox kann flexibel in verschiedenen Netzwerksituationen betrieben werden. Je nach Einsatzzweck und geplanter Nutzung empfehlen sich unterschiedliche Konfigurationen.

### Einsatzszenarien

#### Standalone-Betrieb (ohne Netzwerk)

Wenn Sie die Fotobox ausschließlich auf einem einzelnen Gerät nutzen möchten:

- **Vorteile**: Einfache Einrichtung, hohe Sicherheit, keine Netzwerkabhängigkeit
- **Zugriff**: nur am Gerät selbst möglich
- **Empfohlene Einstellungen**:
  - Bind-Adresse: `127.0.0.1` (nur lokaler Zugriff)
  - Port: beliebig (z.B. 8080, 8888)
  - HTTPS/SSL: nicht erforderlich

#### Lokales Netzwerk

Für den Betrieb in einem lokalen Netzwerk, in dem mehrere Geräte auf die Fotobox zugreifen sollen:

- **Vorteile**: Mehrere Nutzer können gleichzeitig zugreifen, Mobile Upload-Funktion nutzbar
- **Zugriff**: von allen Geräten im selben Netzwerk
- **Empfohlene Einstellungen**:
  - Bind-Adresse: `0.0.0.0` (alle Netzwerkschnittstellen) oder spezifische lokale IP (z.B. `192.168.x.x`)
  - Port: anpassbar (z.B. 80, 8080)
  - Servername: optional, z.B. `fotobox.local` für einfacheren Zugriff
  - HTTPS/SSL: optional, aber empfohlen für mobilen Upload

#### Externer Zugriff (Internet)

Für den Betrieb mit Zugriff über das Internet:

- **Vorteile**: Globaler Zugriff, ideal für verteilte Events oder Cloud-Speicherung
- **Zugriff**: von überall im Internet möglich
- **Empfohlene Einstellungen**:
  - Bind-Adresse: `0.0.0.0` oder spezifische öffentliche IP
  - Port: anpassbar (empfohlen: 443 für HTTPS)
  - Servername: erforderlich (z.B. DNS-Name oder DynDNS)
  - HTTPS/SSL: dringend empfohlen (z.B. Let's Encrypt)

### Übersichtstabelle

| Einstellung        | Standalone | Lokales Netzwerk | Internet/Cloud |
|--------------------|------------|------------------|---------------|
| Bind-Adresse       | 127.0.0.1  | 0.0.0.0 / lokale IP | 0.0.0.0 / öffentl. IP |
| Port               | beliebig   | anpassbar        | 443 (HTTPS)   |
| Servername         | optional   | sinnvoll         | erforderlich  |
| URL-Pfad           | optional   | optional         | optional      |
| HTTPS/SSL          | unwichtig  | empfohlen        | erforderlich  |

> **Hinweis zur Sicherheit**: Bei externem Zugriff sollten Sie immer HTTPS/SSL verwenden und die empfohlenen Sicherheitseinstellungen beachten. Denken Sie auch an die Konfiguration von Firewall und Portfreigaben in Ihrem Router.

### Konfiguration ändern

Um die Netzwerkeinstellungen der Fotobox anzupassen:

1. Öffnen Sie die Einstellungsseite und melden Sie sich als Administrator an
2. Navigieren Sie zum Bereich "System" > "Netzwerk"
3. Passen Sie die Einstellungen entsprechend Ihrem gewünschten Szenario an
4. Speichern Sie die Änderungen und starten Sie den Server neu, wenn aufgefordert

## Fehlerbehebung

### Häufige Probleme

1. **Kamera wird nicht erkannt**   - Prüfen Sie, ob die Kamera angeschlossen und eingeschaltet ist
   - Aktualisieren Sie die Seite oder starten Sie den Browser neu

2. **Fotos werden nicht gespeichert**   - Überprüfen Sie die Berechtigungen des Foto-Verzeichnisses
   - Stellen Sie sicher, dass ausreichend Speicherplatz vorhanden ist

3. **Einstellungen werden nicht sofort übernommen**   - Prüfen Sie, ob die Datenbank beschreibbar ist
   - Stellen Sie sicher, dass Sie das richtige Admin-Passwort verwenden
   - Beachten Sie die Benachrichtigungen, die den Status der Einstellungsänderungen anzeigen

### Updates und Systemverwaltung

Die Fotobox bietet eine integrierte Update-Funktion, die ausschließlich über die Weboberfläche verfügbar ist:

1. Öffnen Sie die Einstellungsseite und melden Sie sich als Administrator an
2. Navigieren Sie zum Bereich "System" > "System-Updates"
3. Klicken Sie auf "Auf Updates prüfen", um nach neuen Versionen zu suchen
4. Bei verfügbaren Updates können Sie direkt "Update installieren" auswählen
5. Folgen Sie den Anweisungen auf dem Bildschirm

#### Update-Prozess im Detail

Der Update-Prozess führt automatisch folgende Schritte aus:

1. **Backup**: Vor dem Update werden alle wichtigen Daten und Konfigurationen gesichert (Backend, Frontend, NGINX, systemd-Service). Das Backup wird im Ordner `backup-update-<Datum>` gespeichert.
2. **Projekt-Update**: Die Fotobox-Software wird aus dem Internet aktualisiert.
3. **Systemabhängigkeiten**: Betriebssystem-Pakete werden geprüft und bei Bedarf installiert oder aktualisiert.
4. **Python-Abhängigkeiten**: Die Python-Umgebung wird aktualisiert und alle benötigten Bibliotheken werden auf den neuesten Stand gebracht.
5. **NGINX-Konfiguration**: Die Webserver-Konfiguration wird geprüft und bei Bedarf angepasst.
6. **Systemdienst**: Der Fotobox-Backend-Dienst wird neu gestartet, damit alle Änderungen aktiv werden.
7. **Abschlusstest**: Das System prüft, ob die Weboberfläche nach dem Update erreichbar ist.

Während eines Updates:

- Die Fotobox ist kurzzeitig nicht verfügbar
- Alle Einstellungen und Daten bleiben erhalten
- Der Fortschritt wird auf dem Bildschirm angezeigt

#### Abhängigkeiten-Management

Das Update-System prüft und aktualisiert automatisch zwei Arten von Abhängigkeiten:

1. **Systemabhängigkeiten**: Betriebssystem-Pakete wie NGINX, Python usw. (definiert in `conf/requirements_system.inf`)
2. **Python-Abhängigkeiten**: Python-Module, die für die Fotobox-Software benötigt werden (definiert in `conf/requirements_python.inf`)

Sie können den Status der Abhängigkeiten auch manuell überprüfen:

1. Öffnen Sie die Einstellungsseite und melden Sie sich als Administrator an
2. Im Bereich "System-Updates" werden fehlende oder veraltete Abhängigkeiten angezeigt
3. Klicken Sie auf "Abhängigkeiten installieren", um fehlende Abhängigkeiten zu installieren

#### Wiederherstellung nach fehlgeschlagenem Update

Sollte ein Update fehlschlagen, können Sie das System wie folgt wiederherstellen:

1. Das automatische Backup finden Sie im Projektordner unter `backup-update-<Datum>`
2. In der Weboberfläche gibt es eine Wiederherstellungsoption, falls das Update fehlschlägt
3. Alternativ können Sie über die Kommandozeile das Backup manuell wiederherstellen

### Installationsprobleme

Falls Sie Probleme bei der Installation haben, beachten Sie folgende Punkte:

1. **Systemkompatibilität**: Das Installationsskript prüft automatisch die Kompatibilität Ihrer Distribution. Offizielle Unterstützung besteht für Debian 10/11/12 und Ubuntu 20.04/22.04. Auf anderen Versionen wird eine Warnung angezeigt, die Installation aber fortgesetzt.

2. **Python-Abhängigkeiten**: Einige Python-Pakete können Probleme bereiten, wenn sie native Erweiterungen kompilieren müssen. In solchen Fällen kann es helfen, die entsprechenden Systempakete manuell zu installieren.

3. **Kamera-Unterstützung**: Für Intel RealSense-Kameras müssen die spezifischen Pakete manuell aus den Intel-Repositories installiert werden. Diese Pakete sind in der `conf/requirements_system.inf` als Kommentare markiert.

4. **Logging-Probleme**: Das Installationsskript versucht, Logs in `/var/log` zu schreiben. Falls keine Schreibrechte bestehen, werden Logs im aktuellen Verzeichnis oder `/tmp` gespeichert. Der genaue Pfad wird am Ende der Installation angezeigt.

5. **Fehlerbehebung**: Falls die Installation fehlschlägt:
   - Prüfen Sie, ob alle Dienste laufen: `systemctl status fotobox-backend` und `systemctl status nginx`
   - Prüfen Sie, ob der gewählte Port frei ist: `sudo lsof -i :80` oder `sudo lsof -i :8080`
   - Lesen Sie die Hinweise im Terminal und in der Logdatei

6. **Systembenutzer**: Das System erstellt einen Benutzer `fotobox` ohne Home-Verzeichnis und ohne Login-Shell, was aus Sicherheitsgründen Best Practice für Systemdienste ist.

### Datenbank-Fehlerbehebung

Falls Sie Probleme mit der Datenbank haben:

1. **Einstellungen werden nicht gespeichert**
   - Prüfen Sie die Schreibrechte des `data/`-Verzeichnisses
   - Starten Sie die Fotobox-Anwendung neu

2. **Bilder erscheinen nicht in der Galerie**
   - Überprüfen Sie die Datenbank-Integrität wie oben beschrieben
   - Prüfen Sie, ob die Bilddateien im `frontend/photos/`-Verzeichnis vorhanden sind

3. **Fehlermeldung "Datenbank-Fehler"**
   - Notieren Sie die genaue Fehlermeldung
   - Überprüfen Sie den freien Speicherplatz auf dem Gerät
   - Wenden Sie sich bei anhaltenden Problemen an den Support

### System-Logs

Die Fotobox verwendet ein umfassendes Logging-System, das bei der Fehlerbehebung helfen kann. Alle wichtigen Ereignisse, Warnungen und Fehler werden automatisch protokolliert.

#### Zugriff auf Log-Dateien

Die Log-Dateien befinden sich standardmäßig in den folgenden Verzeichnissen:

- Hauptverzeichnis: `/opt/fotobox/log`
- Alternativ: `/var/log/fotobox` (falls das Hauptverzeichnis nicht beschreibbar ist)

Sie finden dort folgende Log-Dateien:

- `YYYY-MM-DD_fotobox.log`: Allgemeine Logs des aktuellen Tages
- `fotobox_debug.log`: Detaillierte technische Informationen

#### Analyse der Log-Dateien

Wenn Sie technische Probleme mit der Fotobox haben, können diese Log-Dateien wertvolle Hinweise geben. IT-Fachpersonal kann zur Problemanalyse folgende Befehle verwenden:

```bash
# Aktuelle Logs ansehen
tail -f /opt/fotobox/log/$(date +%Y-%m-%d)_fotobox.log

# Fehler in den Logs suchen
grep ERROR /opt/fotobox/log/$(date +%Y-%m-%d)_fotobox.log
```

#### Automatische Log-Rotation

Um Speicherplatz zu sparen, werden die Log-Dateien täglich rotiert und komprimiert:

- Aktuelle Logs: `YYYY-MM-DD_fotobox.log`
- Ältere Logs: `YYYY-MM-DD_fotobox.log.1`, `YYYY-MM-DD_fotobox.log.2.gz`, usw.

Es werden höchstens 5 ältere Log-Dateien aufbewahrt, um die Festplatte nicht zu überfüllen.

> **Tipp**: Falls Sie Speicherplatzprobleme haben, können Sie ältere Log-Dateien manuell löschen.

### Support

Bei weiteren Problemen konsultieren Sie bitte die [Projektwebseite](https://github.com/DirkGoetze/MyFotoBox) oder erstellen Sie ein Issue im GitHub-Repository.

### Deinstallation

Wenn Sie die Fotobox von Ihrem System entfernen möchten, stellt die Software eine einfache Deinstallationsfunktion bereit:

#### Deinstallation starten

Die Deinstallation erfolgt ausschließlich über die Weboberfläche:

1. Öffnen Sie die Einstellungsseite (`settings.html`)
2. Melden Sie sich als Administrator an
3. Navigieren Sie zum Bereich "System"
4. Klicken Sie auf "Fotobox deinstallieren" und folgen Sie den Anweisungen

#### Deinstallationsprozess

Der Deinstallationsprozess führt folgende Aufgaben aus:

1. **Backup erstellen**: Vor der Deinstallation wird ein Sicherungsarchiv Ihrer Daten und Einstellungen erstellt.
2. **Dienste stoppen**: Der Fotobox-Backend-Dienst und NGINX werden gestoppt.
3. **Systemdienste entfernen**: Die systemd-Unit für das Backend wird entfernt.
4. **NGINX-Konfiguration entfernen**: Die Fotobox-Konfiguration wird aus NGINX entfernt.
5. **Projektdateien löschen**: Das gesamte Projektverzeichnis wird entfernt (nach Bestätigung).
6. **Benutzer und Gruppe entfernen**: Der Systembenutzer und die Gruppe "fotobox" werden gelöscht (optional).
7. **Abschlussbestätigung**: Sie erhalten eine Bestätigung über die erfolgreiche Deinstallation.

> **Wichtig**: Die Deinstallation ist ein endgültiger Vorgang! Alle lokalen Fotos und Uploads werden während des Deinstallationsprozesses gelöscht, sofern Sie diese nicht vorher manuell sichern. Ein Backup aller wichtigen Daten wird jedoch automatisch erstellt und kann bei Bedarf heruntergeladen werden.

**Stand:** 16. Juni 2025
