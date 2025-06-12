# Leitfaden zur Migration von Modulen

Dieser Leitfaden hilft Entwicklern dabei, bestehenden Code gemäß der neuen Code-Strukturierungs-Policy zu migrieren. Er enthält eine schrittweise Anleitung und bewährte Praktiken für die Umstrukturierung.

## Vorbereitung

Bevor Sie mit der Migration eines Moduls beginnen, sollten Sie folgende Schritte durchführen:

1. **Analysieren Sie den bestehenden Code**:
   - Identifizieren Sie Funktionen, die zu Systemmodulen (`manage_*`) gehören
   - Identifizieren Sie seitenspezifischen Code, der in der ursprünglichen Datei verbleiben sollte
   - Markieren Sie gemeinsam genutzte Komponenten für die spätere Extraktion

2. **Erstellen Sie einen Migrationsplan**:
   - Notieren Sie, welche Funktionen wohin verschoben werden
   - Berücksichtigen Sie Abhängigkeiten zwischen Funktionen
   - Planen Sie die Reihenfolge der Migration

3. **Erstellen Sie Testfälle**:
   - Dokumentieren Sie das erwartete Verhalten vor und nach der Migration
   - Erstellen Sie Tests, um sicherzustellen, dass die Funktionalität erhalten bleibt

## Migrations-Schrittfolge

### 1. Modul-Gerüst erstellen

Beginnen Sie mit der Erstellung eines Grundgerüsts für das neue Systemmodul:

```javascript
/**
 * @file manage_module.js
 * @description Beschreibung des Moduls
 * @module manage_module
 */

// Abhängigkeiten importieren

// Typdefinitionen

// Private Variablen und Funktionen

// Öffentliche API-Funktionen
export function functionName() {
    // Implementierung
}

// Initialisierung
```

### 2. Funktionen migrieren

Migrieren Sie für jede identifizierte Funktion:

1. **Kopieren** Sie den Funktionscode in das neue Modul
2. **Passen Sie** Abhängigkeiten und Imports an
3. **Refactoren** Sie den Code, um den neuen Modulstandards zu entsprechen:
   - Klare Trennung zwischen Geschäftslogik und UI
   - Verwendung von Promises für asynchrone Operationen
   - Ordentliche Fehlerbehandlung
4. **Exportieren** Sie die Funktion in der öffentlichen API

### 3. Ursprüngliche Datei anpassen

Nachdem die Funktionen in das neue Modul migriert wurden:

1. **Importieren** Sie die migrierten Funktionen aus dem neuen Modul
2. **Entfernen** Sie den alten Funktionscode
3. **Passen Sie** Funktionsaufrufe an
4. **Testen** Sie die Funktionalität

### 4. Gemeinsame Komponenten extrahieren

Für gemeinsam genutzte UI-Komponenten oder Hilfsfunktionen:

1. Identifizieren Sie Code, der auf mehreren Seiten verwendet wird
2. Extrahieren Sie diesen Code in geeignete Module (z.B. `ui_components.js`, `utils.js`)
3. Importieren Sie diese Module in den Dateien, die sie verwenden

## Beispiel: Migration einer Settings-bezogenen Funktion

### Vor der Migration (in `settings.js`):

```javascript
// Alte Implementierung in settings.js
function loadSettings() {
    return fetch('/api/settings')
        .then(response => response.json())
        .then(data => {
            // Einstellungen verarbeiten
            populateSettingsForm(data);
            return data;
        })
        .catch(error => {
            console.error('Fehler beim Laden der Einstellungen:', error);
            showError('Einstellungen konnten nicht geladen werden');
        });
}
```

### Nach der Migration:

In `manage_settings.js`:

```javascript
// Neue Implementierung in manage_settings.js
import { apiGet } from './manage_api.js';
import { log, error } from './manage_logging.js';

export async function loadSettings() {
    try {
        const data = await apiGet('/api/settings');
        log('Einstellungen erfolgreich geladen');
        return data;
    } catch (err) {
        error('Fehler beim Laden der Einstellungen', err);
        throw err;
    }
}
```

In `settings.js`:

```javascript
// Angepasster Code in settings.js
import { loadSettings } from './manage_settings.js';
import { showNotification } from './ui_components.js';

async function initSettingsUI() {
    try {
        const settings = await loadSettings();
        populateSettingsForm(settings);
    } catch (err) {
        showNotification('Einstellungen konnten nicht geladen werden', 'error');
    }
}
```

## Best Practices für die Migration

### Modulstruktur

- **Eine Verantwortlichkeit pro Modul**: Jedes Modul sollte eine klare, einzige Verantwortlichkeit haben
- **Klare Abhängigkeiten**: Importieren Sie nur Module, die wirklich benötigt werden
- **Minimale öffentliche API**: Exportieren Sie nur Funktionen, die von außen benötigt werden

### Code-Qualität

- **Konsistenter Stil**: Verwenden Sie ESLint und folgen Sie dem Projektstil
- **Fehlerbehandlung**: Implementieren Sie angemessene Fehlerbehandlung mit try/catch
- **Typisierung**: Verwenden Sie JSDoc für die Dokumentation von Typen
- **Logging**: Implementieren Sie angemessenes Logging für wichtige Operationen

### Versionskompatibilität

- **Schrittweise Migration**: Ändern Sie nicht alles auf einmal
- **Rückwärtskompatibilität**: Stellen Sie sicher, dass alte Funktionen weiterhin funktionieren
- **Feature-Flags**: Verwenden Sie Feature-Flags für größere Änderungen

## Testprozess

Nach jeder Migration:

1. **Unit-Tests**: Testen Sie das migrierte Modul
2. **Integrationstests**: Testen Sie die Integration mit anderen Modulen
3. **UI-Tests**: Stellen Sie sicher, dass die Benutzeroberfläche weiterhin funktioniert
4. **Regression-Tests**: Führen Sie Tests auf bereits migrierten Code durch

## Häufige Probleme und Lösungen

### Problem: Zirkuläre Abhängigkeiten

**Lösung**: Extrahieren Sie gemeinsam genutzte Funktionen in ein separates Modul oder verwenden Sie Dependency Injection.

### Problem: Globale Variablen

**Lösung**: Wandeln Sie globale Variablen in Modulvariablen um und bieten Sie Zugriffsmethoden an.

### Problem: Eng gekoppelter Code

**Lösung**: Trennen Sie Geschäftslogik von der UI und definieren Sie klare Schnittstellen.

### Problem: Asynchrone Funktionen

**Lösung**: Verwenden Sie Promises oder async/await konsistent, um asynchrone Funktionen zu verwalten.

## Abschluss der Migration

Nachdem Sie ein Modul migriert haben:

1. **Dokumentieren** Sie die Änderungen
2. **Aktualisieren** Sie den Migrations-Status im `migration_status_tracking.md`
3. **Überprüfen** Sie, ob alle Abhängigkeiten korrekt behandelt wurden
4. **Commit** und Pull Request für Code-Review

---

## Anhang: Checkliste für die Migration

- [ ] Bestehenden Code analysiert
- [ ] Funktionen für Migration identifiziert
- [ ] Modul-Gerüst erstellt
- [ ] Funktionen migriert und angepasst
- [ ] Ursprüngliche Datei aktualisiert
- [ ] Gemeinsame Komponenten extrahiert
- [ ] Tests geschrieben und ausgeführt
- [ ] Dokumentation aktualisiert
- [ ] Migrations-Status aktualisiert
- [ ] Code-Review durchgeführt
