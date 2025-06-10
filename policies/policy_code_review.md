# Code-Review-Policy

Diese Policy definiert die Standards für Code-Reviews im Fotobox-Projekt und dient als Grundlage für die weitere Entwicklung.

## Dokumentation der Reviews

* Alle durchgeführten Code-Reviews werden im `reviews/`-Ordner dokumentiert
* Der `reviews/`-Ordner wird nicht versioniert (.gitignore), um die Hauptstruktur des Repositories übersichtlich zu halten
* Jedes Review-Dokument soll detaillierte Informationen über identifizierte Probleme, durchgeführte Änderungen und deren Begründungen enthalten

## Verbindliche Code-Review-Regeln

1. **Dokumentation prüfen**: Jede Änderung muss gegen die bestehende Dokumentation geprüft werden, um Inkonsistenzen zu vermeiden.

2. **Konsistente API-Struktur**: Neue API-Endpunkte müssen den in der `policy_backend_api.md` definierten Konventionen folgen.

3. **Fehlerbehandlung**: Alle API-Endpunkte müssen die in `policy_code_errorhandling.md` beschriebenen Status-Codes und Fehlerformate verwenden.

4. **Datenbank-Zugriff**: Jeder Datenbank-Zugriff muss über die in `policy_data_model.md` definierten Funktionen erfolgen.

5. **Frontend-Routing**: Alle URL-Verweise müssen der `policy_frontend_routing.md` entsprechen.

6. **Cross-Check**: Bei jeder Änderung an einer der Komponenten muss geprüft werden, ob andere Komponenten davon betroffen sind.

7. **Code-Formatierung**: Die Formatierungsrichtlinien aus `policy_code_formatting.md` müssen eingehalten werden.

## Review-Prozess

1. **Vorbereitung**: Einarbeitung in den zu prüfenden Code und die relevanten Dokumentationen.

2. **Durchführung**: Systematische Überprüfung anhand der definierten Code-Review-Regeln.

3. **Dokumentation**: Erstellung eines Review-Dokuments im `reviews/`-Ordner.

4. **Umsetzung**: Implementierung der notwendigen Änderungen nach Freigabe.

5. **Nachbereitung**: Aktualisierung der Dokumentation und Policies bei Bedarf.

## Zuständigkeit und Häufigkeit

* Code-Reviews sind nach größeren Feature-Implementierungen und regelmäßig alle 3-6 Monate durchzuführen
* Jeder Reviewer muss mit den Projektpolicies vertraut sein
* Alle beteiligten Entwickler müssen über die Ergebnisse der Reviews informiert werden

**Stand:** 11. Juni 2025
