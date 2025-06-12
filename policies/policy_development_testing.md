# Policy für Tests und Entwicklungsumgebungen

## Übersicht

Diese Policy definiert verbindliche Regeln für Tests und Entwicklungsprozesse im Fotobox2-Projekt und dient als klare Richtlinie für alle Entwicklungsarbeiten.

## Grundprinzipien

1. **Keine Live-Tests**: Im regulären Entwicklungsprozess steht **keine** Live-Testumgebung zur Verfügung. Alle Entwicklungsarbeit muss ohne direkten Zugriff auf die Produktiv- oder Test-Instanz erfolgen.

2. **Code-zentrierte Entwicklung**: Die gesamte Entwicklung konzentriert sich auf die Codebasis. Funktionalitätstests erfolgen erst nach der Integration in den Hauptzweig durch das Build-Team.

3. **Mock-First-Ansatz**: Alle externen Abhängigkeiten müssen soweit möglich durch Mock-Objekte simuliert werden.

## Detaillierte Richtlinien

### 1. Entwicklung ohne Live-System

- **Kein Zugriff auf laufende Instanzen** bei der Entwicklung neuer Features oder Bugfixes
- **Keine Abhängigkeit von externer Hardware** (Kameras, Drucker, etc.) während der Entwicklung
- **Offline-First**: Code muss so entwickelt werden, dass er ohne externe Dienste funktionieren kann

### 2. Mock-Daten und Mock-Services

- Für jede API muss ein **entsprechendes Mock-Interface** erstellt werden
- **Standardisierte Test-Datensätze** müssen in der Codebasis enthalten sein
- Für Tests der Frontend-Backend-Kommunikation sind **simulierte API-Antworten** zu verwenden

### 3. Testdateien und -struktur

- Unit-Tests müssen im entsprechenden `tests/`-Verzeichnis der jeweiligen Komponente abgelegt werden
- Jedes Modul benötigt wenigstens grundlegende Tests der öffentlichen API
- Als Benennungskonvention gilt: `test_[modulname].js` bzw. `test_[modulname].py`

### 4. Umgang mit Abhängigkeiten

- **Zentrale Definition**: Alle Abhängigkeiten (System und Python) müssen in den zentralen Dateien im `conf`-Verzeichnis definiert werden:
  - `conf/requirements_system.inf` für Systemabhängigkeiten
  - `conf/requirements_python.inf` für Python-Abhängigkeiten

- **Keine Ad-hoc-Installationen**: Entwickler dürfen keine Abhängigkeiten direkt installieren (`pip install`, `apt install` etc.). Stattdessen müssen alle Abhängigkeiten zuerst in den entsprechenden Requirements-Dateien definiert werden.

- **Versionierung**: Bei neuen Abhängigkeiten muss eine Mindestversion angegeben werden (z.B. `package>=1.2.3`).

- **Dokumentation**: Jede hinzugefügte Abhängigkeit sollte mit einem Kommentar versehen werden, der ihren Zweck erklärt.

- **Test der Abhängigkeitsinstallation**: Entwickler sollten den Installationsprozess mit den aktualisierten Requirements-Dateien in einer Testumgebung überprüfen, bevor sie Pull Requests einreichen.

### 5. Dokumentation von Testfällen

- Kritische Funktionen müssen mit **expliziten Testfällen** dokumentiert werden
- Für komplexe Module sind **Testpläne** zu erstellen, die die wichtigsten Testszenarien umfassen

## Entwicklungs-Workflow

1. **Feature-Definition**: Anforderungen und erwartete Funktionalität definieren
2. **Mockup-Erstellung**: API-Antworten und Datenstrukturen simulieren
3. **Implementierung**: Code-Entwicklung gegen die Mock-Interfaces
4. **Unit-Tests**: Tests gegen die lokalen Mock-Objekte
5. **Code-Review**: Prüfung durch andere Entwickler
6. **Integration**: Zusammenführen in den Hauptzweig

## FAQ

### Was tun, wenn ein Test ohne Live-System nicht möglich ist?

- Entwickeln Sie den Code so weit wie möglich mit Mock-Objekten
- Dokumentieren Sie klar, welche Tests nach der Integration durchgeführt werden müssen
- Erstellen Sie detaillierte Testanweisungen für das Build-Team

### Wie können API-Endpunkte ohne laufendes Backend getestet werden?

- Verwenden Sie Mock-Antworten basierend auf der API-Dokumentation
- In der Frontend-Entwicklung implementieren Sie einen "Test-Modus", der statische Antworten zurückgibt
- Verwenden Sie lokale Datendateien als API-Ersatz

## Beispiele

### Mock-API für Datenbankzugriffe

```javascript
// Mock-Implementierung für Datenbankzugriff
const mockDatabase = {
  query: async (sql, params) => {
    console.log('Mock DB query:', sql, params);
    return { 
      success: true, 
      data: [
        { id: 1, name: 'Test-Eintrag 1' },
        { id: 2, name: 'Test-Eintrag 2' }
      ]
    };
  },
  // Weitere Methoden...
};

// Verwendung im Code
export async function getData() {
  // Im realen Code würde hier ein API-Aufruf stehen
  return mockDatabase.query('SELECT * FROM example');
}
```

---

Diese Policy wurde am 12.06.2025 erstellt und ist ab sofort für alle Entwicklungsarbeiten verbindlich.
