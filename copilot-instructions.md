# Policy: Nutzerrechte und Rechtevergabe
-------------------------------------------------------------------------------
Alle schreibenden Operationen im Projektverzeichnis (z.B. durch Shell-, Python- oder Hilfsskripte) müssen sicherstellen, dass die betroffenen Dateien und Verzeichnisse nach Abschluss dem Anwendungsnutzer 'fotobox' gehören (chown -R fotobox:fotobox ...). Systemoperationen (Paketinstallation, NGINX, systemd) erfolgen weiterhin als root. Nach jedem schreibenden Schritt im Projektverzeichnis ist die Rechtevergabe zu prüfen und ggf. zu korrigieren, um spätere Zugriffsprobleme zu vermeiden.

Diese Policy ist für alle automatisierten Änderungen, Auslagerungen und Erweiterungen durch Copilot verbindlich und bei jeder Codegenerierung zu beachten.
-------------------------------------------------------------------------------

# Allgemeine Vorgaben
-------------------------------------------------------------------------------
## 1. Verzeichnisse
- Alle Verzeichnisse sind so zu wählen, dass sie den Namenskonventionen des Projekts entsprechen.
- Verzeichnisse für temporäre Dateien sind zu vermeiden; stattdessen sind geeignete Mechanismen zur Handhabung temporärer Daten nutzen.

## 2. Dateinamen
- Dateinamen müssen aussagekräftig sein und den Inhalt der Datei widerspiegeln.
- Vermeiden Sie die Verwendung von Leerzeichen in Dateinamen. Nutzen Sie stattdessen Unterstriche (_) oder Bindestriche (-).
- Alle Dateinamen sind in Kleinbuchstaben zu halten.

## 3. Code-Struktur
- Der Code ist klar zu strukturieren und zu kommentieren, um die Lesbarkeit und Wartbarkeit zu gewährleisten.
- Funktionen und Klassen sind sinnvoll zu benennen und sollten jeweils eine klar umrissene Aufgabe haben.

## 4. Abhängigkeiten
- Externe Bibliotheken und Abhängigkeiten sind nur einzubinden, wenn es unbedingt erforderlich ist.
- Die verwendeten Versionen von Bibliotheken sind zu dokumentieren.

## 5. Sicherheit
- Alle sicherheitsrelevanten Aspekte sind besonders zu beachten. Dazu gehört die Validierung von Eingaben, die Absicherung von Schnittstellen und die sichere Handhabung von Benutzerdaten.
- Vermeiden Sie die Speicherung von sensiblen Daten im Quellcode. Nutzen Sie stattdessen Umgebungsvariablen oder sichere Geheimnisverwaltungsdienste.

## 6. Logging und Monitoring
- Integrieren Sie umfassende Logging- und Monitoring-Möglichkeiten, um den Betrieb und die Fehlerbehebung zu erleichtern.
- Logs sind so zu gestalten, dass sie keine sensiblen Daten enthalten.

## 7. Dokumentation
- Jede Codeänderung ist angemessen zu dokumentieren.
- Die Dokumentation muss klar, präzise und für den beabsichtigten Benutzerkreis verständlich sein.

## 8. Testing
- Für jede Codeänderung sind entsprechende Tests zu erstellen und durchzuführen.
- Die Tests sind so zu gestalten, dass sie automatisch ausgeführt werden können und eine hohe Testabdeckung gewährleisten.

## 9. Performance
- Achten Sie auf eine effiziente Nutzung von Ressourcen.
- Vermeiden Sie unnötige Berechnungen und Datenbankabfragen.

## 10. Backup und Recovery
- Stellen Sie sicher, dass angemessene Backup- und Wiederherstellungsverfahren vorhanden sind.
- Testen Sie regelmäßig die Wiederherstellbarkeit der gesicherten Daten.

Diese allgemeinen Vorgaben sind bei allen Entwicklungen und Änderungen zu beachten und bilden die Grundlage für eine erfolgreiche und sichere Projektdurchführung.
-------------------------------------------------------------------------------

# Policy: Trennung von Skripttypen und Ordnerstruktur im Backend
-------------------------------------------------------------------------------
Für das gesamte Projekt gilt:
- Verschiedene Skripttypen (z.B. Python, Bash) dürfen nicht im selben Ordner abgelegt werden.
- Im Backend sind für Shell-Skripte und Python-Skripte jeweils eigene Unterordner zu verwenden (z.B. backend/scripts/ für Bash, backend/ für Python).
- Diese Policy ist verbindlich und bei allen Erweiterungen, Auslagerungen oder Umstrukturierungen einzuhalten.
- Die Struktur ist in einer readme.md im jeweiligen Ordner zu dokumentieren.
- Analoges gilt für das Frontend (z.B. js/, css/, images/ etc.).
- Änderungen an der Ordnerstruktur müssen diese Policy berücksichtigen und dokumentiert werden.
-------------------------------------------------------------------------------