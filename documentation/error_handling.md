# Fehlerbehandlung und Status-Codes

Diese Dokumentation beschreibt die standardisierte Fehlerbehandlung und HTTP-Status-Codes für die Fotobox-API.

## HTTP-Status-Codes

Die Fotobox-API verwendet folgende HTTP-Status-Codes:

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

Bei Fehlern gibt die API ein standardisiertes JSON-Objekt zurück:

```json
{
    "error": "Kurze Fehlerbeschreibung",
    "details": "Detaillierte Fehlermeldung oder technische Informationen (optional)"
}
```

## Beispiele

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

## Fehlerbehandlung im Frontend

Das Frontend sollte auf folgende Fehler vorbereitet sein:

1. **Verbindungsfehler**: Wenn keine Verbindung zum Backend hergestellt werden kann
2. **Authentifizierungsfehler**: Bei ungültigem Passwort oder fehlender Berechtigung
3. **Validierungsfehler**: Wenn übergebene Parameter ungültig sind
4. **Serverfehler**: Bei internen Fehlern im Backend

**Stand:** 10. Juni 2025
