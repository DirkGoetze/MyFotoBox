# Policy für die Entwicklung mit Remote-Datenbank

## Problemstellung

Bei der Entwicklung der Fotobox-Anwendung treten häufig Probleme auf, wenn die Datenbank nicht auf dem lokalen Entwicklungssystem, sondern auf einem entfernten Server läuft. Dies führt unter anderem zu:

1. Fehlgeschlagenen Tests von Datenbank-bezogenen Funktionen
2. Zeichenkodierungsproblemen bei der Übertragung von Daten
3. Inkonsistenzen zwischen Entwicklungs- und Produktionsumgebung

## Umgebungskonfiguration

Die aktuelle Entwicklungsumgebung ist wie folgt konfiguriert:

- **Entwicklungssystem**: Windows-PC
- **Datenbank-Server**: LXC-Container auf IP 192.168.20.25
- **Frontend-Port**: 8080
- **Backend-API**: Läuft auf demselben LXC-Container

## Richtlinien

### 1. API-Endpunkte-Konfiguration

Alle API-Endpunkte in den JavaScript-Dateien sollten konfigurierbar sein:

```javascript
// Konfigurierbare API-Basis-URL
const API_BASE_URL = window.location.hostname === 'localhost' 
    ? 'http://192.168.20.25:8080/api' 
    : '/api';
```

### 2. Entwicklung ohne Live-Datenbankzugriff

**WICHTIG: Während der Entwicklung ist KEIN Zugriff auf eine Live-Datenbank möglich.** 
Alle Entwicklung muss unter der Annahme erfolgen, dass keine laufende Instanz oder Remote-Datenbank verfügbar ist.

Für die Entwicklung ohne Datenbankzugriff MÜSSEN Mock-Daten verwendet werden:

- Erstelle JSON-Beispieldateien für typische API-Antworten
- Implementiere eine Testumgebungsvariable, die standardmäßig auf Mock-Daten konfiguriert ist

```javascript
// Für die Entwicklung IMMER true, keine Verbindung zu echter Datenbank!
const USE_MOCK_DATA = true; 

function fetchData() {
    if (USE_MOCK_DATA) {
        return Promise.resolve(MOCK_DATA);
    } else {
        // Diese Alternative ist NUR für die Produktivumgebung relevant!
        return fetch('/api/data').then(response => response.json());
    }
}
```

### 3. Zeichenkodierungsstandard

Um Probleme mit Umlauten und Sonderzeichen zu vermeiden:

- Alle HTML-Dateien müssen UTF-8 als Zeichensatz verwenden
- Bei PowerShell-Skripten auf UTF-8-Kodierung achten:
  ```powershell
  $content = Get-Content -Path "file.html" -Encoding UTF8
  Set-Content -Path "file.html" -Value $content -Encoding UTF8
  ```

### 4. Fehlerbehandlung für nicht erreichbare APIs

Implementiere eine robuste Fehlerbehandlung, die dem Benutzer sinnvolle Fehlermeldungen anzeigt:

```javascript
fetch('/api/settings')
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP-Fehler: ${response.status}`);
        }
        return response.json();
    })
    .catch(error => {
        console.error('API nicht erreichbar:', error);
        displayConnectionError('Datenbank-Server nicht erreichbar unter 192.168.20.25:8080');
    });
```

### 5. Testmodus-Indikator

Füge einen visuellen Indikator hinzu, der anzeigt, ob die Anwendung im Test-Modus läuft:

```html
<div id="test-mode-indicator" class="test-mode">Test-Modus: Lokale Daten</div>
```

Mit entsprechendem CSS:

```css
.test-mode {
    background-color: #ffcc00;
    color: #333;
    text-align: center;
    padding: 5px;
    position: fixed;
    bottom: 0;
    width: 100%;
    font-weight: bold;
    display: none; /* Standardmäßig ausgeblendet */
}
```

## Implementierungsvorschläge

1. **Frontend-Proxy konfigurieren**:
   Konfiguriere einen lokalen Entwicklungsserver, der API-Anfragen an den entfernten Server weiterleitet.

2. **Lokale Testdatenbank**:
   Erstelle eine SQLite-Testdatenbank für die lokale Entwicklung, die bei Bedarf mit Testdaten gefüllt wird.

3. **Automatisierte Tests**:
   Implementiere automatisierte Tests, die gegen Mock-Daten laufen, um unabhängig von der Remote-Datenbank entwickeln zu können.

## Anwendungsbeispiel für die DB-Status-Seite

Für die `db-status.html`-Testseite empfehlen wir:

```javascript
// Konfigurierbare API-URL
const API_URL = {
    production: '/api/settings-details', // Relativer Pfad für Produktionsumgebung
    development: 'http://192.168.20.25:8080/api/settings-details' // Explizite IP für Entwicklung
};

// Testmodus aktivieren, wenn lokale Entwicklung erkannt wird
const isLocalDev = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
const currentApiUrl = isLocalDev ? API_URL.development : API_URL.production;

// Test-Modus-Indikator anzeigen wenn nötig
document.getElementById('test-mode-indicator').style.display = isLocalDev ? 'block' : 'none';

// API-Aufruf mit konfigurierbarer URL
fetch(currentApiUrl)
    .then(/* ... */)
    .catch(error => {
        console.error(`Fehler beim Zugriff auf ${currentApiUrl}:`, error);
        // Sinnvolle Fehlermeldung anzeigen
    });
```

## Verantwortlichkeiten

- **Frontend-Entwickler**: Implementierung der konfigurierbaren API-Endpunkte und Mock-Daten
- **Backend-Entwickler**: Bereitstellung von Test-APIs und Dokumentation der API-Struktur
- **DevOps**: Sicherstellung der Netzwerkkonnektivität und Konfiguration der Entwicklungsumgebung

## Fazit

Diese Policy soll sicherstellen, dass die Entwicklung der Fotobox-Anwendung auch dann effizient fortgesetzt werden kann, wenn die primäre Datenbank auf einem entfernten System läuft. Durch die Verwendung von Mock-Daten, konfigurierbaren API-Endpunkten und robusten Fehlerbehandlungen können viele der häufig auftretenden Probleme vermieden werden.
