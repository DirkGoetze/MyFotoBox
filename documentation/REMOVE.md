# Fotobox: Entfernen/Deinstallation

Diese Anleitung beschreibt, wie Sie die Fotobox-Software vollständig von Ihrem System entfernen. Sie richtet sich an Linux-Einsteiger und erklärt alle wichtigen Schritte.

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

1. **Dienste stoppen**: Der Fotobox-Backend-Dienst und NGINX werden gestoppt.
2. **Systemdienste entfernen**: Die systemd-Unit für das Backend wird entfernt.
3. **NGINX-Konfiguration entfernen**: Die Fotobox-Konfiguration wird aus NGINX entfernt (Symlinks und Konfigurationsdateien werden gelöscht, Backups bleiben erhalten).
4. **Projektdateien löschen**: Das gesamte Projektverzeichnis wird entfernt (nach Rückfrage).
5. **Benutzer und Gruppe entfernen**: Der Systembenutzer und die Gruppe "fotobox" werden gelöscht (optional, nach Rückfrage).
6. **Abschlusstest**: Das Skript prüft, ob alle Komponenten entfernt wurden.

## Hinweise

- Backups der Konfiguration und Daten bleiben im Backup-Ordner erhalten, sofern nicht explizit gelöscht.
- Prüfen Sie nach der Deinstallation, ob alle gewünschten Komponenten entfernt wurden.
- Alle wichtigen Schritte und Fehler werden in der Logdatei `/var/log/fotobox_install.log` protokolliert.

## Fehlerbehebung

- Prüfen Sie, ob alle Dienste gestoppt wurden:
  - `systemctl status fotobox-backend`
  - `systemctl status nginx`
- Lesen Sie die Hinweise im Terminal und in der Logdatei.

---

Mit dieser Anleitung können Sie die Fotobox sicher und vollständig von Ihrem System entfernen.
