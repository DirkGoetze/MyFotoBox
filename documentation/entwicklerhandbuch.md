# Entwicklerhandbuch: Fotobox2

Dieses Entwicklerhandbuch dokumentiert die technische Struktur, Architektur und Best Practices für die Entwicklung des Fotobox2-Projekts. Es dient als Referenz für alle Entwickler, die am Projekt arbeiten oder neue Module implementieren möchten.

## Inhaltsverzeichnis

1. [Projektstruktur](#1-projektstruktur)
2. [Modulare Architektur](#2-modulare-architektur)
3. [Frontend-Entwicklung](#3-frontend-entwicklung)
4. [Backend-Entwicklung](#4-backend-entwicklung)
5. [Authentifizierung und Sicherheit](#5-authentifizierung-und-sicherheit)
6. [Datenbankverwaltung](#6-datenbankverwaltung)
7. [Fehlerbehandlung und Logging](#7-fehlerbehandlung-und-logging)
8. [Migration von Legacy-Code](#8-migration-von-legacy-code)
9. [Testen und Qualitätssicherung](#9-testen-und-qualitätssicherung)
10. [Versionierung und Deployment](#10-versionierung-und-deployment)
11. [FolderManager und Dateisystem](#11-foldermanager-und-dateisystem)
12. [Logging-System](#12-logging-system)
13. [Backend-Service-Verwaltung](#13-backend-service-verwaltung)
14. [Deinstallationssystem](#14-deinstallationssystem)
15. [Dokumentationsstandards](#15-dokumentationsstandards)
16. [CLI-Tools](#16-cli-tools)

## 1. Projektstruktur

Das Fotobox2-Projekt folgt einer klaren Ordnerstruktur, um die Wartbarkeit und Erweiterbarkeit zu gewährleisten:

```bash
fotobox2/
├── backend/           # Python-Backend mit API-Endpunkten und Systemfunktionen
│   ├── api_*.py       # API-Endpunkte für verschiedene Module
│   ├── manage_*.py    # Module für verschiedene Systemfunktionen
│   ├── utils.py       # Hilfsfunktionen und generische Klassen
│   └── scripts/       # Shell-Skripte für Systeminteraktion
│       ├── lib_*.sh   # Bibliotheksskripte für Shell-Funktionen
│       └── manage_*.sh # Shell-Module für Systemverwaltung
├── frontend/          # Frontend-Dateien
│   ├── *.html         # HTML-Seiten
│   ├── js/            # JavaScript-Dateien
│   │   ├── manage_*.js # Systemmodule 
│   │   ├── ui_components.js # UI-Komponenten
│   │   └── utils.js   # Hilfsfunktionen
│   ├── css/           # Stylesheets
│   └── photos/        # Foto-Ausgabeordner
├── conf/              # Konfigurations- und Abhängigkeitsdateien
│   ├── requirements_*.inf # Abhängigkeiten
│   ├── version.inf    # Versionsinformationen
│   ├── cameras/       # Kamera-Konfiguration
│   └── nginx/         # NGINX-Konfiguration
├── documentation/     # Dokumentation
├── policies/          # Entwicklungsrichtlinien
└── tests/             # Test-Skripte und Tools
```

Die Ordnerstruktur wird dynamisch vom System erstellt und verwaltet durch das zentrale Ordnerverwaltungssystem (`manage_folders.sh` und `manage_folders.py`).

> **AKTUALISIERUNG (Juli 2025)**: Das Dateisystem wird jetzt vollständig durch den `FolderManager` verwaltet, der eine konsistente und sichere Verwaltung aller Pfade gewährleistet.

## 2. Modulare Architektur

### 2.1 Backend-Architektur

Das Backend basiert auf einer modularen Architektur mit klaren Verantwortlichkeiten:

1. **API-Module (`api_*.py`)**: Stellen REST-API-Endpunkte bereit und nutzen Flask-Blueprints
2. **Verwaltungsmodule (`manage_*.py`)**: Implementieren Geschäftslogik und Systemfunktionen
3. **Shellskript-Module (`scripts/manage_*.sh`)**: Interagieren mit dem Betriebssystem
4. **Hilfsbibliotheken (`lib_*.sh`, `utils.py`)**: Bieten wiederverwendbare Funktionen

> **AKTUALISIERUNG (Juli 2025)**: Alle Module verwenden jetzt konsistente Fehlerbehandlung mit `ApiResponse` und `handle_api_exception` für API-Module sowie `Result<T>` für Frontend-Integration.

### 2.2 Module und ihre Verantwortlichkeiten

| Modultyp | Präfix | Verantwortlichkeiten |
|----------|--------|----------------------|
| API-Module | `api_` | HTTP-Endpunkte, Request/Response-Handling, Auth-Checks |
| Verwaltungsmodule | `manage_` | Geschäftslogik, Datenverarbeitung, Systemoperationen |
| Shell-Module | `scripts/manage_` | OS-Interaktion, systemd, NGINX, Dateisystem |
| Frontend-Module | `js/manage_` | UI-Logik, API-Kommunikation, Datenvalidierung |

## 3. Frontend-Entwicklung

## 4. Backend-Entwicklung

## 5. Authentifizierung und Sicherheit

> **AKTUALISIERUNG (Juli 2025)**: Die Authentifizierung wurde von Session-basiert auf Token-basiert (JWT) umgestellt.

### 5.1 Token-basierte Authentifizierung

Das Backend verwendet JWT (JSON Web Tokens) für die Authentifizierung:

```python
# Token-Erzeugung (Backend)
def generate_token():
    payload = {
        'exp': datetime.datetime.utcnow() + TOKEN_EXPIRY,
        'iat': datetime.datetime.utcnow(),
        'sub': 'admin'
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')

# Token-Validierung (Backend)
@wraps(f)
def decorated(*args, **kwargs):
    token = request.headers.get('X-Auth-Token')
    if not token:
        return ApiResponse.error('Token fehlt', status_code=401)
    
    try:
        jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
    except:
        return ApiResponse.error('Ungültiger Token', status_code=401)
        
    return f(*args, **kwargs)
```

Das Frontend speichert den Token im `localStorage` und fügt ihn automatisch allen API-Anfragen hinzu:

```javascript
// Token-Speicherung (Frontend)
localStorage.setItem(AUTH_TOKEN_KEY, token);
setAuthToken(token);

// API-Header-Konfiguration
function setAuthToken(token) {
    if (token) {
        _defaultHeaders['X-Auth-Token'] = token;
    } else {
        delete _defaultHeaders['X-Auth-Token'];
    }
}
```

### 5.2 Sicherheitsmaßnahmen

- **Passwort-Hashing**: bcrypt mit angemessener Arbeitsfaktor
- **CSRF-Schutz**: Token-basierte Authentifizierung verhindert CSRF
- **Pfad-Validierung**: Alle Pfade werden durch den `FolderManager` validiert
- **SQL-Injection-Schutz**: Parametrisierte Abfragen in allen DB-Operationen
- **Input-Validierung**: Serverseitige Validierung aller Eingaben
- **Error-Handling**: Keine sensiblen Informationen in Fehlermeldungen

## 6. Datenbankverwaltung

## 7. Fehlerbehandlung und Logging

> **AKTUALISIERUNG (Juli 2025)**: Einführung einer konsistenten Fehlerbehandlung mit `ApiResponse`, `handle_api_exception` und `Result<T>`.

### 7.1 Backend Fehlerbehandlung

#### 7.1.1 ApiResponse-Pattern

Alle API-Endpunkte verwenden das `ApiResponse`-Pattern für konsistente Antworten:

```python
class ApiResponse:
    @staticmethod
    def success(data=None, message=None):
        return {
            'success': True,
            'data': data,
            'message': message
        }
    
    @staticmethod
    def error(message, status_code=400, details=None):
        return {
            'success': False,
            'error': message,
            'details': details
        }, status_code
```

#### 7.1.2 Exception-Handler

Die zentrale Exception-Handler-Funktion sorgt für einheitliche Fehlerbehandlung:

```python
def handle_api_exception(exception, endpoint=None):
    """
    Behandelt Exceptions in API-Endpunkten einheitlich
    
    Args:
        exception: Die aufgetretene Exception
        endpoint: Der betroffene API-Endpunkt
        
    Returns:
        Einheitliche Fehlerantwort
    """
    error_msg = str(exception)
    status_code = 500
    details = None
    
    # Spezifische Fehlertypen
    if isinstance(exception, ValueError):
        status_code = 400
    elif isinstance(exception, PermissionError):
        status_code = 403
    elif isinstance(exception, FileNotFoundError):
        status_code = 404
    elif isinstance(exception, AuthError):
        status_code = 401
    
    # Logging
    logger.error(f"API-Fehler bei {endpoint}: {error_msg}")
    
    return ApiResponse.error(
        message=error_msg,
        status_code=status_code,
        details=details
    )
```

#### 7.1.3 Strukturierte Fehlerklassen

Alle Module definieren spezifische Fehlerklassen:

```python
class AuthError(Exception):
    """Basisklasse für Authentifizierungs-bezogene Fehler"""
    pass

class TokenError(AuthError):
    """Fehler bei der Token-Verarbeitung"""
    pass

class DatabaseError(Exception):
    """Basisklasse für Datenbankfehler"""
    pass

class ConfigError(Exception):
    """Basisklasse für Konfigurationsfehler"""
    pass
```

### 7.2 Frontend Fehlerbehandlung

#### 7.2.1 Result-Pattern

Das Frontend verwendet die `Result<T>`-Klasse für Typensicherheit und konsistentes Error-Handling:

```javascript
class Result {
    constructor(success, data = null, error = null) {
        this.success = success;
        this.data = data;
        this.error = error;
    }
    
    static ok(data) {
        return new Result(true, data);
    }
    
    static fail(error) {
        return new Result(false, null, error);
    }
}
```

#### 7.2.2 API-Fehlerbehandlung

```javascript
async function handleResponse(response) {
    checkForNewToken(response);
    
    const contentType = response.headers.get('content-type');
    const isJson = contentType && contentType.includes('application/json');
    
    if (!response.ok) {
        const error = isJson ? await response.json() : { message: response.statusText };
        if (response.status === 401 && _authToken) {
            // Token ist abgelaufen oder ungültig
            setAuthToken(null);
            warn('Auth-Token ungültig - Benutzer muss sich neu anmelden');
        }
        return Promise.reject(error);
    }
    
    return isJson ? response.json() : response.text();
}
```

## 8. Migration von Legacy-Code

## 9. Testen und Qualitätssicherung

## 10. Versionierung und Deployment

## 11. FolderManager und Dateisystem

> **AKTUALISIERUNG (Juli 2025)**: Der FolderManager ist jetzt die zentrale Komponente für alle Dateisystem-Operationen.

### 11.1 FolderManager-Klasse

Der `FolderManager` dient als zentrale Komponente für die Verwaltung aller Dateipfade im System. Er stellt sicher, dass:

1. Alle Pfade konsistent und sicher sind
2. Berechtigungsprobleme vermieden werden
3. Verzeichnisstrukturen korrekt initialisiert werden
4. Pfade plattformübergreifend funktionieren

```python
# Beispiel für die Verwendung des FolderManagers
from manage_folders import FolderManager

folder_manager = FolderManager()

# Pfade abrufen
config_dir = folder_manager.get_path('config')
log_dir = folder_manager.get_path('log')
photos_dir = folder_manager.get_path('photos')

# Pfade validieren
if folder_manager.is_valid_path(user_input_path):
    # Pfad sicher verwenden
    
# Verzeichnisse erstellen
folder_manager.ensure_directory(log_dir)
```

### 11.2 Wichtige Methoden des FolderManagers

| Methode | Beschreibung |
|---------|--------------|
| `get_path(key)` | Gibt einen absoluten Pfad anhand eines logischen Schlüssels zurück |
| `ensure_directory(path)` | Stellt sicher, dass ein Verzeichnis existiert, erstellt es bei Bedarf |
| `is_valid_path(path, base_key=None)` | Prüft, ob ein Pfad gültig und sicher ist |
| `list_directories(base_key)` | Listet alle Unterverzeichnisse eines Basis-Verzeichnisses auf |
| `normalize_path(path)` | Normalisiert einen Pfad für plattformübergreifende Konsistenz |
| `get_relative_path(path, base_key)` | Gibt einen relativen Pfad zu einem Basis-Verzeichnis zurück |

### 11.3 Best Practices für Dateisystem-Operationen

1. **Immer den FolderManager verwenden**:

```python
# Gut:
log_dir = folder_manager.get_path('log')

# Schlecht:
log_dir = '/opt/fotobox/log'
```

2.**Pfade validieren**:

```python
if not folder_manager.is_valid_path(user_path):
    return ApiResponse.error('Ungültiger Pfad', status_code=400)
```

3.**Relativen Pfad verwenden für Client-Kommunikation**:

```python
# Für API-Antworten
relative_path = folder_manager.get_relative_path(full_path, 'photos')
return ApiResponse.success({'path': relative_path})
```

## 12. Logging-System

Das Logging-System in Fotobox2 verwendet die Python-Standardbibliothek `logging` und bietet strukturierte Protokollierung für alle Komponenten.

### 12.1 Logging-Konfiguration

Das Logging-System verwendet eine hierarchische Struktur mit verschiedenen Log-Levels und Ausgabeformaten:

```python
# Beispiel für die Logging-Konfiguration
def setup_logging(log_dir, level=logging.INFO):
    """Richtet das Logging-System ein"""
    logger = logging.getLogger()
    logger.setLevel(level)
    
    # Formatter für konsistente Ausgabe
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # File Handler für persistente Logs
    file_handler = RotatingFileHandler(
        os.path.join(log_dir, 'fotobox.log'),
        maxBytes=10*1024*1024,  # 10 MB
        backupCount=5
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    return logger
```

### 12.2 Log-Levels

Das System verwendet folgende Log-Levels:

| Level | Verwendung |
|-------|------------|
| DEBUG | Detaillierte Informationen für Entwicklung und Debugging |
| INFO | Allgemeine Informationen über den Programmablauf |
| WARNING | Potenziell problematische Situationen |
| ERROR | Fehler, die Funktionen beeinträchtigen |
| CRITICAL | Schwerwiegende Fehler, die den Betrieb gefährden |

### 12.3 Best Practices für Logging

- Verwenden Sie spezifische Logger für jedes Modul: `logger = logging.getLogger(__name__)`
- Fügen Sie kontextbezogene Informationen hinzu: `logger.error(f"Datenbankfehler in {table_name}: {err}")`
- Vermeiden Sie sensitive Daten in Logs (Passwörter, Token)
- Protokollieren Sie Start und Ende wichtiger Operationen

## 13. Backend-Service-Verwaltung

Die Fotobox2 verwendet systemd für die Backend-Service-Verwaltung, wodurch eine zuverlässige Ausführung und Überwachung gewährleistet wird.

### 13.1 Service-Konfiguration

Der Backend-Service wird über eine systemd-Unit-Datei konfiguriert:

```ini
[Unit]
Description=Fotobox Backend (Flask)
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=fotobox
Group=fotobox
WorkingDirectory=/opt/fotobox/backend
Environment=PYTHONPATH=/opt/fotobox/backend
Environment=FOTOBOX_ENV=production
ExecStart=/opt/fotobox/backend/venv/bin/python app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 13.2 Service-Management

Die Klasse `BackendService` in `manage_backend_service.py` stellt Funktionen für die Service-Verwaltung bereit:

```python
def start_service(self) -> Tuple[bool, str]:
    """Startet den Fotobox-Backend-Service"""
    try:
        exit_code, stdout, stderr = self._execute_systemctl("start fotobox-backend")
        success = exit_code == 0
        message = stdout if success else stderr
        return success, message
    except Exception as e:
        logger.error(f"Fehler beim Starten des Services: {str(e)}")
        return False, f"Service-Start fehlgeschlagen: {str(e)}"
```

### 13.3 Service-Installation

Der Service wird während der Installation registriert und aktiviert:

```python
def install_service(self) -> Tuple[bool, str]:
    """Installiert und aktiviert den systemd-Service"""
    try:
        # Service-Datei kopieren
        shutil.copy(self.service_file, self.systemd_path)
        
        # Berechtigungen setzen
        os.chmod(self.systemd_path, 0o644)
        
        # systemd neu laden und Service aktivieren
        self._execute_systemctl("daemon-reload")
        self._execute_systemctl("enable fotobox-backend")
        
        return True, "Service erfolgreich installiert"
    except Exception as e:
        return False, f"Installation fehlgeschlagen: {str(e)}"
```

## 14. Deinstallationssystem

Fotobox2 bietet ein umfassendes Deinstallationssystem, das alle Komponenten sauber entfernt und wichtige Daten sichert.

### 14.1 Deinstallations-Workflow

1. Backup aller wichtigen Daten (Fotos, Datenbank, Konfiguration)
2. Stoppen und Entfernen des systemd-Services
3. Entfernen der NGINX-Konfiguration
4. Entfernen aller Dateien im Installationsverzeichnis
5. Aufräumen temporärer Dateien

### 14.2 API-Integration

Das Deinstallationssystem ist über API-Endpunkte zugänglich:

```python
@api_uninstall.route('/api/uninstall/prepare', methods=['POST'])
@token_required
def prepare_uninstall() -> Dict[str, Any]:
    """
    Bereitet die Deinstallation vor (erstellt Backup)
    """
    try:
        success, backup_path = manage_uninstall.create_backup()
        if not success:
            return ApiResponse.error(f"Backup fehlgeschlagen: {backup_path}")
            
        return ApiResponse.success(
            data={"backup_path": backup_path},
            message="Backup erfolgreich erstellt"
        )
    except Exception as e:
        return handle_api_exception(e, "prepare_uninstall")
```

### 14.3 Daten-Backup

Vor der Deinstallation werden alle wichtigen Daten gesichert:

```python
def create_backup() -> Tuple[bool, str]:
    """Erstellt ein Backup vor der Deinstallation"""
    try:
        # Zeitstempel für Backup-Datei
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        backup_dir = folder_manager.get_path('backup')
        folder_manager.ensure_directory(backup_dir)
        
        # Backup-Datei erstellen
        backup_file = os.path.join(backup_dir, f"fotobox_backup_{timestamp}.zip")
        
        # Dateien für Backup sammeln
        files_to_backup = [
            folder_manager.get_path('photos'),
            folder_manager.get_path('database'),
            folder_manager.get_path('config')
        ]
        
        # ZIP-Archiv erstellen
        create_zip_archive(backup_file, files_to_backup)
        
        return True, backup_file
    except Exception as e:
        logger.error(f"Backup fehlgeschlagen: {str(e)}")
        return False, str(e)
```

## 15. Dokumentationsstandards

Fotobox2 folgt klaren Dokumentationsstandards für alle Komponenten, um die Wartbarkeit und Erweiterbarkeit zu gewährleisten.

### 15.1 Quellcode-Dokumentation

#### 15.1.1 Python-Dokumentation

Python-Code verwendet Docstrings im Google-Format:

```python
def function_name(param1, param2):
    """Kurze Beschreibung der Funktion.
    
    Längere Beschreibung mit Details zur Funktionalität,
    Implementierung und Verwendung.
    
    Args:
        param1: Beschreibung des ersten Parameters
        param2: Beschreibung des zweiten Parameters
        
    Returns:
        Beschreibung des Rückgabewerts
        
    Raises:
        ExceptionType: Beschreibung, wann die Exception ausgelöst wird
    """
```

#### 15.1.2 JavaScript-Dokumentation

JavaScript verwendet JSDoc-Kommentare:

```javascript
/**
 * Kurze Beschreibung der Funktion
 * 
 * @param {string} param1 - Beschreibung des ersten Parameters
 * @param {number} param2 - Beschreibung des zweiten Parameters
 * @returns {boolean} - Beschreibung des Rückgabewerts
 * @throws {Error} - Beschreibung, wann ein Fehler geworfen wird
 */
function functionName(param1, param2) {
    // Implementierung
}
```

### 15.2 Markdown-Dokumentation

Für Benutzer- und Entwicklerhandbücher werden folgende Prinzipien angewendet:

1. Klare Überschriften-Hierarchie (# für Haupttitel, ## für Abschnitte)
2. Inhaltsverzeichnis mit Links zu allen Abschnitten
3. Codebeispiele in Syntax-hervorgehobenen Blöcken
4. Tabellen für strukturierte Informationen
5. Hinweise und Warnungen mit Blockzitaten (>)

## 16. CLI-Tools

---

*Dieses Entwicklerhandbuch wird regelmäßig aktualisiert, um Änderungen an der Projektarchitektur und den Best Practices zu reflektieren.*

**Stand:** 2. Juli 2025
