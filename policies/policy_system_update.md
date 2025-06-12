# Update-Policy für Fotobox2

## Übersicht

Diese Policy definiert den Update-Prozess für die Fotobox2-Software und stellt sicher, dass alle Systemkomponenten, einschließlich OS-Abhängigkeiten und Python-Module, konsistent und aktuell gehalten werden.

## Grundprinzipien

1. **Vollständige Update-Prüfung**: Updates prüfen nicht nur die Codeversion, sondern auch Systemabhängigkeiten und Python-Module.
2. **Automatische Installation von Abhängigkeiten**: Fehlende oder veraltete Abhängigkeiten werden automatisch beim Update installiert.
3. **Transparenz**: Der Update-Status und fehlende Abhängigkeiten werden dem Benutzer klar angezeigt.
4. **Konsistenz**: Es wird sichergestellt, dass alle Abhängigkeiten in den erforderlichen Versionen verfügbar sind.

## Update-Ablauf

### 1. Update-Überprüfung

Bei einer Update-Überprüfung werden folgende Schritte durchgeführt:

1. Prüfung der aktuellen Version gegenüber der neuesten verfügbaren Version
2. Prüfung aller OS-Abhängigkeiten gemäß `conf/requirements_system.inf`
3. Prüfung aller Python-Abhängigkeiten gemäß `conf/requirements_python.inf`

### 2. Update-Installation

Ein Update wird in folgenden Schritten durchgeführt:

1. Erstellung eines Backups der wichtigen Konfigurationsdateien
2. Aktualisierung des Code-Repositories (git pull)
3. Installation fehlender oder aktualisierter OS-Abhängigkeiten
4. Aktualisierung der Python-Umgebung mit aktuellen Paketen
5. Neustart der relevanten Dienste (Backend, Webserver)

## Dateistruktur für Abhängigkeiten

### requirements_system.inf

Die Datei `conf/requirements_system.inf` im Projektverzeichnis enthält alle erforderlichen OS-Pakete im folgenden Format:

```plaintext
paketname>=mindestversion
```

Beispiel:

```plaintext
# System-Abhängigkeiten für Fotobox2
# Format: paket>=version

# Grundlegende Pakete
nginx>=1.18.0
python3>=3.8
python3-pip>=20.0
```

### requirements_python.inf

Die Python-Abhängigkeitsdatei `conf/requirements_python.inf` enthält alle erforderlichen Python-Pakete:

```plaintext
# Python-Abhängigkeiten für Fotobox2
# Format: paket>=version

Flask>=2.0.0
Pillow>=9.0.0
psutil>=5.9.0
```

## Verwaltung von Abhängigkeiten

- **Zentrale Definition**: Alle Software- und Paketabhängigkeiten müssen zentral in den entsprechenden Dateien im `conf`-Verzeichnis definiert werden.
  - Systemabhängigkeiten in `conf/requirements_system.inf`
  - Python-Abhängigkeiten in `conf/requirements_python.inf`

- **Keine direkte Installation**: Neue Abhängigkeiten dürfen nicht direkt mit Befehlen wie `pip install` oder `apt install` installiert werden. Stattdessen muss die entsprechende Requirements-Datei aktualisiert werden.

- **Versionsspezifikation**: Bei Hinzufügen neuer Abhängigkeiten sollte immer eine Mindestversion angegeben werden, um Kompatibilität sicherzustellen, z.B. `package>=1.2.3`.

- **Dokumentation**: Jede neue Abhängigkeit sollte mit einem kurzen Kommentar in der Requirements-Datei versehen werden, der den Zweck erklärt.

## Zuständigkeiten im Code

### Backend

- `manage_update.py`: Implementiert die Hauptlogik für das System-Update, einschließlich der Abhängigkeitsprüfung und -installation
- `update_api.py`: Stellt REST-API-Endpunkte für Update-Operationen bereit

### Frontend

- `manage_update.js`: Bietet JavaScript-Funktionen für das Update-Management
- `settings.html`: Enthält UI-Elemente zur Anzeige von Update- und Abhängigkeitsstatus

## Berechtigungsanforderungen

Die Installation von OS-Abhängigkeiten erfordert Root-Berechtigungen. Der Update-Prozess verwendet sudo für Operationen, die Root-Rechte benötigen.

## Update-Fehlerbehandlung

Bei Fehlern während des Updates wird wie folgt vorgegangen:

1. Der Fehler wird im Systemlog dokumentiert
2. Der Update-Status wird auf "Fehler" gesetzt
3. Der Benutzer wird über die Benutzeroberfläche informiert
4. Bei kritischen Fehlern kann ein Rollback durchgeführt werden

## Rollback-Strategie

Im Falle eines fehlgeschlagenen Updates kann ein Rollback in folgenden Schritten durchgeführt werden:

1. Wiederherstellung der gesicherten Konfigurationsdateien
2. Zurücksetzen des Repository-Status (git reset)
3. Neustart der Dienste mit der vorherigen Konfiguration

---

Diese Policy ist verbindlich für alle Entwicklungsbeiträge zum Fotobox2-Projekt und sollte bei Änderungen am Update-Prozess berücksichtigt werden.
