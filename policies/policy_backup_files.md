# Richtlinie für Backup- und temporäre Dateien

## Übersicht

Diese Policy definiert Regeln für den Umgang mit Backup-Dateien, temporären Dateien und anderen Dateien, die während der Entwicklung erstellt werden, aber nicht Teil des Produktiv-Codes sein sollen.

## Grundprinzipien

1. **Keine temporären Dateien im Haupt-Repository**: Backup-Dateien, temporäre Dateien und alte Versionen sollten nicht im Haupt-Repository auf GitHub eingecheckt werden.

2. **Zentraler Speicherort**: Alle derartigen Dateien müssen im `backup`-Ordner des Projekts abgelegt werden.

3. **Strukturierte Organisation**: Innerhalb des Backup-Ordners sollte eine sinnvolle Struktur zur besseren Auffindbarkeit beibehalten werden.

## Regeln für Dateitypen

### Backup-Dateien

- Dateien mit den Endungen `.bak`, `.old`, `.backup`, `.prev` müssen im `backup`-Ordner abgelegt werden.
- Diese Dateien sollten einen Zeitstempel im Dateinamen haben, um die Version zu identifizieren, z.B. `settings.js.bak-20250612`.

### Temporäre Dateien

- Dateien mit den Endungen `.tmp`, `.temp`, `.new` müssen im `backup`-Ordner abgelegt werden.
- Diese Dateien sollten nach dem Abschluss der Entwicklung in den `backup`-Ordner verschoben oder gelöscht werden.

### Entwicklungs-Notizen

- Dateien mit den Endungen `.todo`, `.notes`, `.ideas` sollten ebenfalls im `backup`-Ordner abgelegt werden, es sei denn, sie enthalten wichtige Dokumentation.

## Workflow für die Entwicklung

### Bei Änderungen an bestehenden Dateien

1. **Backup erstellen**: Vor umfangreichen Änderungen an einer bestehenden Datei:
   ```bash
   cp path/to/file.js backup/path/to/file.js.bak-$(date +%Y%m%d)
   ```

2. **Nach erfolgreichen Tests**: Wenn die Änderungen getestet und stabil sind, kann die Backup-Datei gelöscht oder im `backup`-Ordner belassen werden.

### Bei Erstellung neuer Versionen

1. **Temporäre Version**: Während der Entwicklung einer neuen Version einer Datei, diese als `.new` speichern.
   ```bash
   cp path/to/new_version.js path/to/file.js.new
   ```

2. **Nach abgeschlossener Entwicklung**: Die erfolgreiche `.new`-Version übernimmt den Namen der Original-Datei, die Original-Datei wird als `.bak` in den `backup`-Ordner verschoben.
   ```bash
   mv path/to/original.js backup/path/to/original.js.bak-$(date +%Y%m%d)
   mv path/to/file.js.new path/to/original.js
   ```

## Maintenance

- Regelmäßig (monatlich) sollten alte Backup-Dateien überprüft und ggf. gelöscht werden.
- Bei jedem Release sollten alle temporären Dateien (.new, .tmp) entweder finalisiert oder in den `backup`-Ordner verschoben werden.
- Die `.gitignore`-Datei sollte so konfiguriert sein, dass Dateien im `backup`-Ordner nicht eingecheckt werden.

## Ausnahmen

- Konfigurationsdateien mit der Endung `.bak`, die von externen Tools angelegt werden und für die Funktionalität wichtig sind.
- Explizit als Beispiel gekennzeichnete Dateien (z.B. `example.config.js.bak`).

---

Diese Policy wurde am 12.06.2025 erstellt und ist ab sofort für alle Entwickler verbindlich.
