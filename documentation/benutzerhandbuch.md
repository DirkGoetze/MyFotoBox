# Fotobox Benutzerhandbuch

Dieses Benutzerhandbuch enthält alle wichtigen Informationen zur Bedienung und Konfiguration der Fotobox-Software für Endanwender.

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Erste Schritte](#erste-schritte)
3. [Die Benutzeroberfläche](#die-benutzeroberfläche)
4. [Fotos aufnehmen](#fotos-aufnehmen)
5. [Galerie anzeigen](#galerie-anzeigen)
6. [Einstellungen anpassen](#einstellungen-anpassen)
7. [Kontaktinformationen](#kontaktinformationen)
8. [Fehlerbehebung](#fehlerbehebung)

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

Eine detaillierte Installationsanleitung finden Sie in der [Installationsdokumentation](installation.md).

### Erststart und Zugriff

Nach erfolgreicher Installation können Sie die Weboberfläche über einen Browser aufrufen:

* Bei lokaler Installation: `http://localhost:8080` (oder den von Ihnen konfigurierten Port)
* Bei Netzwerkinstallation: Die IP-Adresse oder den Hostnamen des Geräts, auf dem die Fotobox läuft

Beim ersten Start werden Sie durch die Ersteinrichtung geführt, bei der Sie grundlegende Einstellungen vornehmen können:

* Event-Name festlegen
* Admin-Passwort setzen
* Kamera-Einstellungen anpassen
* Speicherort für Fotos wählen

## Die Benutzeroberfläche

Die Fotobox besteht aus mehreren Seiten, die über das Menü erreichbar sind:

### Navigation

* Das **Menü** (☰) in der linken oberen Ecke öffnet die Navigation zu allen verfügbaren Seiten
* Der **Event-Titel** in der Mitte des Headers zeigt den Namen Ihrer Veranstaltung
* Das **Haus-Symbol** im Breadcrumb-Menü führt Sie zurück zur Aufnahme Seite, der Hauptseite der Fotobox
* **Uhrzeit und Datum** werden auf jeder Seite rechts im Header angezeigt

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

* Durch die Fotos blättern
* Die Vollbildansicht eines Fotos öffnen
* Nach einer gewissen Zeit der Inaktivität kehrt die Anzeige automatisch zur Home-Seite zurück

## Einstellungen anpassen

Im Einstellungsbereich (passwortgeschützt) können Sie folgende Parameter anpassen. Alle Änderungen werden automatisch gespeichert und es erscheint eine Benachrichtigung über den Status (Erfolg oder Fehler). Erfolgsbenachrichtigungen verschwinden nach kurzer Zeit automatisch, während Fehlermeldungen länger angezeigt werden:

### Event-Einstellungen

* Event-Name ändern
* Event-Datum festlegen

### Darstellungseinstellungen

* Anzeigemodus wählen (Systemabhängig/Hell/Dunkel)
* Bildschirmschoner-Timeout einstellen
* Automatische Rückkehr aus der Galerie konfigurieren

### Kamera-Einstellungen

* Kamera auswählen (Systemstandard oder spezifische Kamera)
* Blitzlicht-Modus einstellen (Automatisch/An/Aus)
* Countdown-Dauer für Fotos anpassen

### Admin-Einstellungen

* Admin-Passwort ändern

## Kontaktinformationen

Auf der Kontaktseite können Sie Informationen hinterlegen, wie Ihre Gäste die Fotos erhalten können. Diese Seite ist anpassbar und kann für jedes Event individuell gestaltet werden.

## Fehlerbehebung

### Häufige Probleme

1. **Kamera wird nicht erkannt**
   * Prüfen Sie, ob die Kamera angeschlossen und eingeschaltet ist
   * Aktualisieren Sie die Seite oder starten Sie den Browser neu

2. **Fotos werden nicht gespeichert**
   * Überprüfen Sie die Berechtigungen des Foto-Verzeichnisses
   * Stellen Sie sicher, dass ausreichend Speicherplatz vorhanden ist

3. **Einstellungen werden nicht sofort übernommen**
   * Prüfen Sie, ob die Datenbank beschreibbar ist
   * Stellen Sie sicher, dass Sie das richtige Admin-Passwort verwenden
   * Beachten Sie die Benachrichtigungen, die den Status der Einstellungsänderungen anzeigen

### Updates und Systemverwaltung

Die Fotobox bietet eine integrierte Update-Funktion, die ausschließlich über die Weboberfläche verfügbar ist:

1. Öffnen Sie die Einstellungsseite und melden Sie sich als Administrator an
2. Navigieren Sie zum Bereich "System"
3. Klicken Sie auf "Auf Updates prüfen", um nach neuen Versionen zu suchen
4. Bei verfügbaren Updates können Sie direkt "Update installieren" auswählen
5. Folgen Sie den Anweisungen auf dem Bildschirm

Während eines Updates:
* Die Fotobox ist kurzzeitig nicht verfügbar
* Alle Einstellungen und Daten bleiben erhalten
* Ein automatisches Backup wird vor dem Update erstellt

Sollte ein Update fehlschlagen, können Sie das System über die Wiederherstellungsoption in den vorherigen Zustand zurücksetzen.

### Support

Bei weiteren Problemen konsultieren Sie bitte die [Projektwebseite](https://github.com/DirkGoetze/MyFotoBox) oder erstellen Sie ein Issue im GitHub-Repository.

**Stand:** 15. Juni 2025
