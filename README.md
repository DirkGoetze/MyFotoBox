# Fotobox

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Lizenz: MIT](https://img.shields.io/badge/license-MIT-blue)
![Version 0.3.1](https://img.shields.io/badge/version-0.3.1-orange)

> **Achtung: Diese Version ist eine Vorab-/Testversion (Pre-Release) und nicht für den Produktiveinsatz geeignet!**

## Kurzbeschreibung

Die Fotobox ist ein flexibles, webbasiertes System für Events, Partys und Feiern. Nutzer können direkt Fotos aufnehmen, diese in einer Galerie ansehen und – sofern ein geeigneter Drucker vorhanden ist – direkt ausdrucken. Die Oberfläche bietet einen Aufnahmemodus und eine Galerieansicht. Optional können Gäste auch Fotos von ihrem eigenen Handy hochladen; diese werden in der Galerie in einem separaten Ordner unter dem vom Nutzer gewählten Namen angezeigt. Alle Bilder und Uploads werden zentral in einer Datenbank verwaltet. Die detaillierte Beschreibung der Funktionen und Konfigurationsmöglichkeiten findet sich in der Projektdokumentation.

## Inhaltsverzeichnis

- [Features](#features)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Schnellstart](#schnellstart)
- [Konfiguration](#konfiguration)
- [Update und Deinstallation](#update-und-deinstallation)
- [Dokumentation](#dokumentation)
- [Beitrag](#beitrag)
- [Lizenz](#lizenz)
- [Kontakt](#kontakt)

## Features

- Fotos direkt über die Fotobox aufnehmen
- Galerieansicht für alle aufgenommenen und hochgeladenen Fotos
- Fotos direkt ausdrucken (sofern Drucker vorhanden)
- Aufnahmebildschirm (Kamera-Modus) und Galerie-Modus
- Optional: Upload von Fotos über das Handy (mit Username-Abfrage)
- Hochgeladene Fotos werden in separatem Ordner mit Geräte-ID gespeichert
- In der Galerie werden Uploads als 'Bilder von [Username]' angezeigt
- Zentrale Verwaltung aller Bilder und Uploads über eine Datenbank
- Trennung und Kennzeichnung von lokalen Aufnahmen und Uploads in der Galerie
- Verwaltung, Update und Deinstallation bequem über die Weboberfläche (WebUI)

## Voraussetzungen

- Unterstützte Betriebssysteme: Debian/Ubuntu (getestet), andere Linux-Distributionen mit Anpassung möglich
- Python 3.8 oder neuer
- Systempakete: git, lsof, nginx, python3-venv, python3-pip, sqlite3 (Hinweis: Die notwendigen Systempakete werden bei der Installation über das Installationsskript automatisch mit installiert)
- Optional: Drucker mit Linux-Unterstützung für Druckfunktion
- Webbrowser für die Nutzung der Weboberfläche
- Netzwerkzugang für Upload-Funktion (optional)

## Installation

1. Repository klonen (Zielverzeichnis frei wählbar, z.B. /opt/fotobox):

   ```sh
   sudo git clone https://github.com/DirkGoetze/MyFotoBox.git /opt/fotobox
   ```

2. In das Projektverzeichnis wechseln und das Installationsskript ausführbar machen:

   ```sh
   cd /opt/fotobox
   sudo chmod +x install_fotobox.sh
   ```

3. Installationsskript als root/Admin ausführen:

   ```sh
   sudo ./install_fotobox.sh
   ```

4. Weitere Hinweise siehe [INSTALLATION](documentation/installation.md)

## Schnellstart

- [ ] Platzhalter: Kurzanleitung für den ersten Start und Zugriff auf die Weboberfläche

## Konfiguration

- [ ] Platzhalter: Hinweise zur Anpassung von Einstellungen, Ports, Benutzerrechten etc.

## Update und Deinstallation

Die Verwaltung, das Update und die Deinstallation der Fotobox können einfach und komfortabel über die Weboberfläche (WebUI) durchgeführt werden. Technische Kenntnisse sind dafür nicht erforderlich.

## Dokumentation

- [INSTALLATION](documentation/installation.md): Ausführliche Installationsanleitung
- [UPDATE](documentation/update.md): Update-Anleitung
- [REMOVE](documentation/remove.md): Deinstallationsanleitung

## Beitrag

Beiträge, Fehlerberichte und Feature-Vorschläge sind willkommen! Bitte nutze dazu das Issue-Management von GitHub. Pull Requests werden gerne entgegengenommen, sofern sie klar dokumentiert sind und das Projekt sinnvoll erweitern.

Bitte beachte: Dies ist ein Hobby-Projekt ohne Anspruch auf Support oder regelmäßige Weiterentwicklung. Es besteht kein Anspruch auf Fehlerbehebung oder Unterstützung. Für Fragen und Diskussionen steht ausschließlich das Issue-System zur Verfügung.

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.

*Hinweis: Für den Betrieb werden weitere Open-Source-Komponenten (z. B. NGINX, Python) benötigt. Bitte beachten Sie die jeweiligen Lizenzbedingungen der eingesetzten Fremdsoftware (in der Regel Open Source, siehe Distribution/Paketquelle).*

## Kontakt

Bei Fragen oder Problemen bitte ein Issue auf GitHub eröffnen.
Persönlicher Support oder E-Mail-Kontakt ist nicht möglich.

## Danksagung

Danke an alle Open-Source-Entwickler, deren Tools und Software dieses Projekt ermöglichen.
