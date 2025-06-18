# Fehlerbehebung für das Fotobox Installationsskript

Diese Anleitung hilft bei der Behebung von häufigen Problemen mit dem Fotobox-Installationsskript.

## Häufige Probleme und Lösungen

### Das Skript bleibt bei "Log-Hilfsskript erfolgreich geladen, verwende zentrales Logging" stehen

Dieses Problem tritt auf, wenn das Skript nach dem Laden der Ressourcen nicht korrekt weiterläuft. Es wurden folgende Verbesserungen implementiert:

1. Verbesserte Fehlerbehandlung beim Laden der Ressourcen
2. Optimierte Berechnung der Dialog-Schritte
3. Robustere Fehlerbehandlung innerhalb der Dialog-Funktionen
4. Debugging-Ausgaben zur besseren Nachverfolgung des Installationsablaufs

### Seltsame Verzeichnisse mit ANSI-Farbcodes werden erstellt

Wenn während der Installation Verzeichnisse mit seltsamen Namen wie `[1;36mVerwende` erstellt werden, handelt es sich um ein Problem mit Debug-Ausgaben in der Funktion `get_log_dir()`. Dieses Problem wurde in neueren Versionen gelöst, indem Debug-Ausgaben nach `/dev/null` umgeleitet werden.

Wenn auf Ihrem System bereits solche Verzeichnisse erstellt wurden, können Sie das Reparaturskript `fix_logging_issues.sh` verwenden:

```bash
sudo bash fix_logging_issues.sh
```

### Separate Log-Dateien statt zentraler Logging-Lösung

In früheren Versionen wurden bei der Installation separate Log-Dateien für verschiedene Prozesse erstellt (z.B. `apt_update.log`, `venv_create.log`), was die zentrale Logging-Lösung umging. Dieses Problem wurde behoben, und alle Ausgaben werden nun in die zentrale Logdatei geschrieben.

Detaillierte Informationen zu Logging-Problemen und deren Lösungen finden Sie in der Dokumentation unter `documentation/logging_probleme_und_loesungen.md`.

### Verwendung des Debug-Installationsskripts

Für eine detailliertere Fehlerbehebung wurde ein Debug-Installationsskript erstellt. Dieses kann anstelle des normalen Installationsskripts verwendet werden:

```bash
sudo bash debug_install.sh
```

Das Debug-Skript erzeugt zwei Protokolldateien:

- `/tmp/fotobox_install_debug.log`: Enthält detaillierte Informationen zum Installationsablauf
- `/tmp/fotobox_install_errors.log`: Enthält nur die Fehlermeldungen

### Manuelle Prüfung kritischer Komponenten

Falls die Installation weiterhin fehlschlägt, können Sie folgende Komponenten manuell prüfen:

1. **Ressourcen-Ladesystem:**

   ```bash
   source backend/scripts/lib_core.sh && echo "Core-Bibliothek erfolgreich geladen"
   ```

2. **NGINX-Konfiguration:**

   ```bash
   bash backend/scripts/manage_nginx.sh status
   ```

3. **Benutzerrechte:**

   ```bash
   ls -la /var/www/fotobox
   id fotobox
   ```

## Aktualisierung nach fehlgeschlagener Installation

Wenn die Installation unvollständig ist und Sie sie neu starten möchten:

```bash
# Räume eventuell unvollständige Installationsdateien auf
sudo bash backend/scripts/manage_uninstall.sh --partial-clean

# Starte die Installation neu mit dem Debug-Skript
sudo bash debug_install.sh
```

## Bekannte Fehler

1. **Fehler bei der Zählung der Installationsschritte:**
   Das Problem mit der Zählung der Installationsschritte wurde behoben, indem eine robustere Methode zur Berechnung der Schrittanzahl implementiert wurde.

2. **Skript bricht bei kleinen Fehlern ab:**
   Die `exit`-Befehle in den Dialog-Funktionen wurden durch `return`-Befehle ersetzt, sodass das Skript bei kleinen Fehlern nicht komplett abbricht.

3. **Fehlende Abhängigkeiten:**
   Das Skript prüft nun besser, ob alle benötigten Abhängigkeiten vorhanden sind, und bietet Fallback-Funktionen an, wenn bestimmte Komponenten nicht verfügbar sind.
