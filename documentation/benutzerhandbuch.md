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

Nach der [Installation](installation.md) der Fotobox können Sie die Weboberfläche über einen Browser aufrufen:

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

Im Einstellungsbereich (passwortgeschützt) können Sie folgende Parameter anpassen:

### Event-Einstellungen

* Event-Name ändern
* Event-Datum festlegen

### Anzeige-Einstellungen

* Farbschema wählen (Hell/Dunkel/Auto)
* Countdown-Dauer für Fotos anpassen

### Kamera-Einstellungen

* Kamera auswählen (falls mehrere vorhanden)
* Blitzlicht-Modus einstellen

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

3. **Einstellungen können nicht gespeichert werden**
   * Prüfen Sie, ob die Datenbank beschreibbar ist
   * Stellen Sie sicher, dass Sie das richtige Admin-Passwort verwenden

### Support

Bei weiteren Problemen konsultieren Sie bitte die [Projektwebseite](https://github.com/DirkGoetze/fotobox2) oder erstellen Sie ein Issue im GitHub-Repository.

**Stand:** 11. Juni 2025
