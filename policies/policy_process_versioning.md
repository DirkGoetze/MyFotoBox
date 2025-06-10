# Versionsstandard-Policy

Dieser Standard definiert die verbindlichen Regeln für die Versionierung der Fotobox-Software und dient als technische Vorgabe für Entwickler.

## Semantische Versionierung (SemVer)

Für die Fotobox-Software wird das semantische Versionierungsschema (SemVer) verwendet:

    MAJOR.MINOR.PATCH

Beispiel: 1.2.3

- **MAJOR**: Hauptversion, wird erhöht bei inkompatiblen Änderungen oder großen neuen Funktionen.
- **MINOR**: Nebenversion, wird erhöht bei neuen, abwärtskompatiblen Features.
- **PATCH**: Fehlerbehebungen oder minimale, abwärtskompatible Änderungen (z.B. UI-Feinschliff).

## Speicherort der Version

Die aktuelle Version ist in der Datei `conf/version.inf` hinterlegt und wird bei jedem Update automatisch aktualisiert. Diese Datei ist die EINZIGE und OFFIZIELLE Quelle für die Versionsinformation im gesamten Projekt. Die `VERSION`-Datei im Hauptverzeichnis dient nur als Verweis auf diese offizielle Quelle und das `sync_version.ps1`-Skript stellt sicher, dass README.md und andere Referenzen aktualisiert werden.

## Versionspflege und -aktualisierung

### Änderung der Version

1. Bei jeder Änderung am Code, die veröffentlicht wird, muss die Version in `conf/version.inf` angepasst werden.
2. Die Version muss im Format `X.Y.Z` ohne weitere Zeichen oder Kommentare in der Datei stehen.
3. Das Skript `backend/manage_update.py` muss die Version aktualisieren können.

### Pre-Release Kennzeichnungen

Für Vorab-Versionen werden folgende Konventionen verwendet:

- **Alpha**: Sehr frühe Versionen, z.B. `1.2.3-alpha.1`
- **Beta**: Testversionen mit vollständigen Features, z.B. `1.2.3-beta.2`
- **RC**: Release Candidates, z.B. `1.2.3-rc.1`

## Version in der Benutzeroberfläche

Die aktuelle Version muss in der Benutzeroberfläche unter Einstellungen angezeigt werden.

## Versionsprüfung bei Updates

Das Update-System muss die lokale Version mit der Remote-Version vergleichen und dementsprechend handeln:

```python
def check_update_available():
    """Prüft, ob ein Update verfügbar ist"""
    local_version = None
    remote_version = None
    
    # Lokale Version lesen
    try:
        with open(os.path.join('conf', 'version.inf'), 'r') as f:
            local_version = f.read().strip()
    except Exception:
        return False, "Lokale Version konnte nicht gelesen werden"
    
    # Remote-Version lesen
    try:
        url = 'https://raw.githubusercontent.com/DirkGoetze/MyFotoBox/main/conf/version.inf'
        with urllib.request.urlopen(url, timeout=5) as response:
            remote_version = response.read().decode('utf-8').strip()
    except Exception:
        return False, "Remote-Version konnte nicht abgerufen werden"
    
    # Versionen vergleichen
    if local_version and remote_version:
        update_available = (local_version != remote_version)
        return update_available, {
            'update_available': update_available,
            'local_version': local_version,
            'remote_version': remote_version
        }
    
    return False, "Versionsvergleich nicht möglich"
```

## Changelog

Bei jeder Versionsänderung muss der Changelog in der Datei `CHANGELOG.md` aktualisiert werden.

Das Format für Changelog-Einträge folgt dem Keep a Changelog-Standard:

```markdown
## [1.2.3] - 2025-06-10

### Added
- Neue Funktion X hinzugefügt

### Changed
- Funktion Y verbessert

### Fixed
- Bug Z behoben
```

**Stand:** 10. Juni 2025

Diese Versionsstandard-Policy ist verbindlich für alle Entwicklungen am Fotobox-Projekt.
