# BACKUP_STRATEGIE.md
-------------------------------------------------------------------------------
Backup- und Restore-Strategie für das Fotobox-Projekt
-------------------------------------------------------------------------------

## Ziel
Alle Funktionen und Erweiterungen des Projekts müssen eine nachvollziehbare, versionierte und platzsparende Backup-/Restore-Strategie berücksichtigen. Diese Vorgabe ist verbindlich und dauerhaft für alle neuen Features und Systemintegrationen einzuhalten.

## Grundprinzipien
- **Inkrementelle, dateibasierte Sicherung**: Es werden nur geänderte oder neue Dateien gesichert.
- **Metadaten-Log**: Jede Sicherung wird mit Metadaten (Zeitpunkt, Version, Dateiliste, Prüfsummen) dokumentiert.
- **Versionierung**: Backups sind eindeutig versioniert und nachvollziehbar.
- **Platzsparend**: Alte, nicht mehr benötigte Backups können automatisiert gelöscht werden.
- **Wiederherstellbarkeit**: Restore-Prozesse sind dokumentiert und getestet.

## Umsetzung
- Die Python-Utility-Skripte (`manage_update.py`, `manage_uninstall.py`) implementieren diese Strategie und dienen als Referenz.
- Neue API-Endpunkte, Systemintegrationen oder Features müssen diese Strategie berücksichtigen und dokumentieren.
- Änderungen an der Backup-/Restore-Logik sind in der Dokumentation zu vermerken.

## Geltungsbereich und Verpflichtung

Die Backup-/Restore-Regeln gelten für **jede Änderung am System**, unabhängig davon, ob diese durch ein Shellskript, ein Python-Skript, die Weboberfläche, ein API-Endpunkt oder ein anderes Modul/Funktion ausgelöst wird.

- Jede neue Funktion, die Änderungen am System (Dateien, Konfiguration, Datenbank, Systemdienste etc.) vornimmt, muss die Backup-Regeln direkt mit implementieren.
- Die Sicherung der betroffenen Daten/Dateien/Konfigurationen muss **vor** der Änderung erfolgen.
- Die Wiederherstellung muss dokumentiert und getestet sein.
- Bei Code-Reviews und vor dem Merge ist zu prüfen, ob die Backup-/Restore-Strategie für alle systemverändernden Funktionen eingehalten wird.
- Abweichungen sind zu begründen und zu dokumentieren.

**Ziel:** Jede Änderung am System ist nachvollziehbar, rücksetzbar und sicher – unabhängig vom Verursacher oder der Art der Änderung.

## Entwicklerhinweis

Vor Merge neuer Features ist zu prüfen, ob die Backup-/Restore-Strategie eingehalten wird. Bei Abweichungen ist eine Begründung und Dokumentation erforderlich.

-------------------------------------------------------------------------------
