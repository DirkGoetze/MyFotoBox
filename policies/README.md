# Policies für das Fotobox-Projekt

Dieser Ordner enthält alle technischen Vorgaben und Entwicklungsrichtlinien für das Fotobox-Projekt. Die hier hinterlegten Policies sind verbindlich für alle Entwickler und dienen als Grundlage für die Projektstruktur und -entwicklung.

## Namenskonvention

Alle Policy-Dateien folgen dem Namensschema `policy_[bereich]_[unterbereich].md`, wodurch eine thematische Gruppierung im Dateisystem erreicht wird. Diese Konvention bietet folgende Vorteile:

* Verbesserte Übersichtlichkeit durch Gruppierung verwandter Policies
* Intuitive Zuordnung durch konsistente Benennung
* Einfache Filterung nach Bereichen in der Dateisuche

## Zweck der Policies

* Festlegen von verbindlichen technischen Standards und Konventionen
* Dokumentation der Architekturentscheidungen
* Sicherstellung der Codequalität und -konsistenz
* Erleichterung der Einarbeitung neuer Entwickler
* Vermeidung von Konflikten und Inkonsistenzen im Code

## Übersicht der Policies

### Frontend-Policies

* [Frontend Structure](policy_frontend_structure.md) - Struktur und Trennung von HTML, CSS und JS
* [Frontend Routing](policy_frontend_routing.md) - Zuordnung von Dateien zu Routen
* [Frontend JavaScript](policy_frontend_javascript.md) - Standards für JavaScript-Code
* [Frontend Fonts](policy_frontend_fonts.md) - Ausnahmen für Font-Dateien

### Backend-Policies

* [Backend API](policy_backend_api.md) - Definition der API-Schnittstellen
* [Backend CLI](policy_backend_cli.md) - Standards für Konsolenausgaben

### Code-Policies

* [Code Formatting](policy_code_formatting.md) - Verbindliche Formatierungsregeln für alle Dateitypen
* [Code Error Handling](policy_code_errorhandling.md) - Standards für Fehlerbehandlung
* [Code Review](policy_code_review.md) - Standards für Code-Reviews
* [Python Coding](policy_python_coding.md) - Python-spezifische Coding-Standards

### System-Policies

* [System Installation](policy_system_installation.md) - Ablauf und Anforderungen der Installation
* [System Backup](policy_system_backup.md) - Sicherungskonzept
* [System Permissions](policy_system_permissions.md) - Berechtigungskonzept
* [System Structure](policy_system_structure.md) - Ordnerstruktur und Dateisystem

### Prozess-Policies

* [Process Review](policy_process_review.md) - Prozess für Code-Reviews
* [Process Versioning](policy_process_versioning.md) - Versionierungsschema

### Dokumentations-Policies

* [Docs Standards](policy_docs_standards.md) - Standards für Kommentare und Dokumentation
* [Docs Diagrams](policy_docs_diagrams.md) - Standards für Diagramme und visuelle Dokumentation

### Daten-Policies

* [Data Model](policy_data_model.md) - Struktur der Datenbank

## Reviews und Aktualisierungen

Die Policies in diesem Ordner sind verbindlich für alle Entwickler. Anpassungen und Ergänzungen sind nur nach einem Review-Prozess möglich und müssen dokumentiert werden. Der in jeder Policy angegebene Stand zeigt das letzte Aktualisierungsdatum.

* Ergebnisse durchgeführter Code-Reviews werden im separaten `reviews/`-Ordner dokumentiert
* Der `reviews/`-Ordner wird nicht versioniert (.gitignore) und enthält Dokumente zu durchgeführten Reviews, identifizierten Abweichungen und deren Behebung

## Verhältnis zur Dokumentation

Im Gegensatz zur Endbenutzer-Dokumentation im Ordner "documentation" richten sich die Policies in diesem Ordner an Entwickler und definieren technische Standards und Anforderungen. Die Endbenutzer-Dokumentation erklärt die Nutzung der Software, während die Policies die Entwicklung der Software regeln.

## Stand

Stand: 20. Juni 2025
