# Fehlerbehandlungs-Policy

Diese Policy definiert die standardisierte Fehlerbehandlung und HTTP-Status-Codes für die Fotobox-API und dient als technische Vorgabe für Entwickler.

## HTTP-Status-Codes

Die Fotobox-API muss folgende HTTP-Status-Codes verwenden:

| Status-Code | Bedeutung | Anwendungsfall |
|------------|-----------|---------------|
| 200 (OK) | Anfrage erfolgreich | Standardrückgabe für erfolgreiche GET und POST Anfragen |
| 201 (Created) | Ressource erstellt | Nach erfolgreicher Erstellung einer neuen Ressource (z.B. Foto) |
| 400 (Bad Request) | Ungültige Anfrage | Wenn Anfrageparameter fehlen oder ungültig sind |
| 401 (Unauthorized) | Nicht authentifiziert | Wenn keine gültige Authentifizierung vorhanden ist |
| 403 (Forbidden) | Zugriff verweigert | Wenn der Benutzer nicht berechtigt ist |
| 404 (Not Found) | Ressource nicht gefunden | Wenn die angeforderte Ressource nicht existiert |
| 500 (Internal Server Error) | Serverfehler | Bei internen Fehlern in der API |

## Fehlerrückgabe-Format

Bei Fehlern muss die API das folgende standardisierte JSON-Objekt zurückgeben:

```json
{
    "error": "Kurze Fehlerbeschreibung",
    "details": "Detaillierte Fehlermeldung oder technische Informationen (optional)"
}
```

## Implementierungsrichtlinien

1. **Strukturierte Fehlerbehandlung**: Alle API-Routen müssen in Try-Catch-Blöcken gekapselt sein, um unerwartete Fehler abzufangen.

2. **Einheitliche Fehlerstruktur**: Alle Fehlerantworten müssen dem oben definierten Format folgen.

3. **Log-Level**: Schwerwiegende Fehler (500er) müssen im System-Log mit voller Fehlermeldung protokolliert werden.

4. **Sicherheitsaspekte**: Sensible Informationen (Datenbankverbindungsdetails, Passwörter, Tokenwerte) dürfen nie in Fehlermeldungen enthalten sein.

5. **Client-Feedback**: Benutzerfreundliche Fehlermeldungen für Frontend-Anzeigen müssen separat von technischen Details gehalten werden.

## Codebeispiel für die Implementierung

```python
@app.route('/api/example', methods=['POST'])
def api_example():
    try:
        # Validierung
        data = request.get_json(force=True)
        if 'required_field' not in data:
            return jsonify({
                'error': 'Fehlende Parameter',
                'details': 'Das Feld required_field muss angegeben werden'
            }), 400
            
        # Verarbeitung
        result = process_data(data)
        if not result:
            return jsonify({
                'error': 'Ressource nicht gefunden',
                'details': 'Die angeforderte Ressource konnte nicht gefunden werden'
            }), 404
            
        # Erfolgsfall
        return jsonify({'status': 'ok', 'data': result})
        
    except Exception as e:
        # Schweren Fehler loggen
        app.logger.error(f"Fehler in /api/example: {str(e)}")
        return jsonify({
            'error': 'Interner Serverfehler',
            'details': 'Ein unerwarteter Fehler ist aufgetreten'
        }), 500
```

## Beispiele für Fehlerrückgaben

### 1. Ungültige Login-Anfrage (401)

```http
POST /api/login
Content-Type: application/json

{
    "password": "falsches-passwort"
}
```

Antwort:
```json
{
    "success": false
}
```
(Status-Code: 401)

### 2. Fehlende Parameter (400)

```http
POST /api/settings
Content-Type: application/json

{
    // Leeres Objekt, fehlende Parameter
}
```

Antwort:
```json
{
    "error": "Fehlende Parameter",
    "details": "Mindestens ein Parameter muss angegeben werden"
}
```
(Status-Code: 400)

### 3. Serverfehler (500)

```http
GET /api/gallery
```

Antwort (wenn beispielsweise das Verzeichnis fehlt oder nicht lesbar ist):
```json
{
    "error": "Fehler beim Auflisten der Galerie-Bilder",
    "details": "Verzeichnis nicht lesbar oder nicht vorhanden"
}
```
(Status-Code: 500)

**Stand:** 10. Juni 2025

Diese Fehlerbehandlungs-Policy ist verbindlich für alle Backend-Entwicklungen am Fotobox-Projekt.
