# Fotobox: Deinstallationsanleitung

Diese Anleitung beschreibt, wie Sie die Fotobox-Software vollständig von Ihrem System entfernen. Sie richtet sich an Linux-Einsteiger und erklärt die einzelnen Schritte des Deinstallationsprozesses.

## Voraussetzungen
- Die Fotobox ist auf Ihrem System installiert.
- Sie haben Root-Rechte (Administrator).

## Deinstallation starten
Führen Sie das Deinstallationsskript im Projektverzeichnis aus:

```bash
sudo bash fotobox.sh --remove
```

## Was passiert bei der Deinstallation?
Das Skript übernimmt folgende Aufgaben (jeder Schritt wird im Terminal erklärt):

1. **Backup und Wiederherstellung**: Das Skript sucht nach dem letzten Backup und stellt wichtige Systemdateien (NGINX-Konfiguration, systemd-Service) daraus wieder her. So bleibt Ihr System stabil.
2. **Port-Prüfung**: Falls der Standard-Webserver-Port (80) belegt ist, werden Sie nach einem alternativen Port gefragt. Die Konfiguration wird automatisch angepasst.
3. **Dienste stoppen**: Der Fotobox-Backend-Dienst wird gestoppt und deaktiviert. Die zugehörige systemd-Service-Datei wird entfernt.
4. **Konfigurationsdateien entfernen**: Die NGINX-Konfiguration und alle Links zur Fotobox werden gelöscht. Die Standard-NGINX-Seite bleibt erhalten.
5. **Projektdateien löschen**: Das gesamte Projektverzeichnis `/opt/fotobox` und die Datenbank werden entfernt.
6. **Backup der entfernten Dateien**: Alle entfernten Systemdateien werden in einem Backup-Ordner gespeichert (`/opt/fotobox-backup-<Datum>`). So können Sie bei Bedarf einzelne Dateien wiederherstellen.
7. **Abschlussmeldung**: Am Ende erhalten Sie eine Übersicht, was entfernt wurde und wo Sie das Backup finden.

## Beispiel für den Aufruf
```bash
sudo bash fotobox.sh --remove
```

## Hinweise
- Nach der Deinstallation ist die Fotobox nicht mehr erreichbar.
- Prüfen Sie ggf. manuell, ob weitere benutzerdefinierte Einstellungen entfernt werden müssen.
- Das Backup der entfernten Dateien finden Sie unter `/opt/fotobox-backup-<Datum>`.

## Fehlerbehebung
- Sollte die Deinstallation fehlschlagen, prüfen Sie die Hinweise im Terminal und die Logdatei `/var/log/fotobox_install.log`.
- Sie können Systemdateien aus dem Backup-Ordner manuell wiederherstellen.

---

Mit dieser Anleitung können Sie die Fotobox sicher und vollständig von Ihrem System entfernen.
