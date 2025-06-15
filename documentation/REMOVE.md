# Fotobox: Entfernen/Deinstallation

Diese Anleitung beschreibt, wie Sie die Fotobox-Software vollständig von Ihrem System entfernen. Sie richtet sich an Linux-Einsteiger und erklärt alle wichtigen Schritte.

## Voraussetzungen

- Die Fotobox ist auf Ihrem System installiert.
- Sie haben Root-Rechte (Administrator).

## Deinstallation starten

Die Deinstallation erfolgt ausschließlich über die Weboberfläche:

1. Öffnen Sie die Einstellungsseite (`settings.html`)
2. Melden Sie sich als Administrator an
3. Navigieren Sie zum Bereich "System"
4. Klicken Sie auf "Fotobox deinstallieren" und folgen Sie den Anweisungen

## Was passiert bei der Deinstallation?

Der Deinstallationsprozess über die Weboberfläche führt folgende Aufgaben aus:

1. **Backup erstellen**: Vor der Deinstallation wird ein Sicherungsarchiv Ihrer Daten und Einstellungen erstellt.
2. **Dienste stoppen**: Der Fotobox-Backend-Dienst und NGINX werden gestoppt.
3. **Systemdienste entfernen**: Die systemd-Unit für das Backend wird entfernt.
4. **NGINX-Konfiguration entfernen**: Die Fotobox-Konfiguration wird aus NGINX entfernt (Symlinks und Konfigurationsdateien werden gelöscht, Backups bleiben erhalten).
5. **Projektdateien löschen**: Das gesamte Projektverzeichnis wird entfernt (nach Bestätigung).
6. **Benutzer und Gruppe entfernen**: Der Systembenutzer und die Gruppe "fotobox" werden gelöscht (optional, nach Bestätigung).
7. **Abschlussbestätigung**: Sie erhalten eine Bestätigung über die erfolgreiche Deinstallation.

## Hinweise

- Backups der Konfiguration und Daten werden vor der Deinstallation automatisch erstellt und können bei Bedarf heruntergeladen werden.
- Die Deinstallation ist ein endgültiger Vorgang, der nicht rückgängig gemacht werden kann.
- Alle lokalen Fotos und Uploads werden während des Deinstallationsprozesses gelöscht, sofern Sie diese nicht vorher manuell sichern.
- Prüfen Sie nach der Deinstallation, ob alle gewünschten Komponenten entfernt wurden.
- Alle wichtigen Schritte und Fehler werden in der Logdatei `/var/log/install.log` protokolliert.

## Fehlerbehebung

- Prüfen Sie, ob alle Dienste gestoppt wurden:
  - `systemctl status fotobox-backend`
  - `systemctl status nginx`
- Lesen Sie die Hinweise im Terminal und in der Logdatei.

---

Mit dieser Anleitung können Sie die Fotobox sicher und vollständig von Ihrem System entfernen.
