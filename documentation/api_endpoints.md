# API-Endpunkte der Fotobox

Diese Dokumentation enthält alle verfügbaren API-Endpunkte und deren Funktionen im Fotobox-Projekt.

## Authentifizierung und Zugriffssteuerung

| Endpunkt | Methode | Funktion | Request-Format | Response-Format |
|----------|---------|----------|----------------|-----------------|
| `/api/login` | POST | Überprüft ein übermitteltes Passwort und erstellt eine Session | `{"password": "string"}` | `{"success": true/false}` |
| `/api/check_password_set` | GET | Überprüft, ob bereits ein Admin-Passwort eingerichtet wurde | - | `{"password_set": true/false}` |

## Konfiguration und Einstellungen

| Endpunkt | Methode | Funktion | Request-Format | Response-Format |
|----------|---------|----------|----------------|-----------------|
| `/api/settings` | GET | Ruft alle aktuellen Einstellungen ab | - | `{"event_name": "string", "event_date": "string", "camera_mode": "string", "resolution_width": "string", "resolution_height": "string", "storage_path": "string", "show_splash": "string", "photo_timer": "string", "gallery_timeout_ms": "string", "color_mode": "string", ...}` |
| `/api/settings` | POST | Speichert neue Einstellungen | `{"event_name": "string", "event_date": "string", "camera_mode": "string", "resolution_width": "string", "resolution_height": "string", "storage_path": "string", "show_splash": "string", "photo_timer": "string", "gallery_timeout_ms": "string", "color_mode": "string", "admin_password": "string", ...}` | `{"status": "ok"}` |
| `/api/nginx_status` | GET | Gibt die aktuelle NGINX-Konfiguration zurück | - | JSON mit NGINX-Konfiguration |

## Fotoverwaltung

| Endpunkt | Methode | Funktion | Request-Format | Response-Format |
|----------|---------|----------|----------------|-----------------|
| `/api/take_photo` | POST | Löst die Aufnahme eines Fotos aus | `{"delay": integer}` (optional) | `{"status": "ok"}` |
| `/api/gallery` | GET | Gibt eine Liste der Fotos im gallery-Ordner zurück | - | `{"photos": ["file1.jpg", "file2.jpg", ...]}` |
| `/api/photos` | GET | Gibt eine Liste der Originalfotos zurück | - | `{"photos": ["file1.jpg", "file2.jpg", ...]}` |

## System und Updates

| Endpunkt | Methode | Funktion |
|----------|---------|----------|
| `/api/update` | GET | Prüft, ob ein Update verfügbar ist |
| `/api/update` | POST | Führt ein Update durch |
| `/api/backup` | POST | Erstellt ein Backup |

## Weitere Endpunkte

| Endpunkt | Methode | Funktion |
|----------|---------|----------|
| `/login` | GET | Zeigt die Login-Oberfläche an |
| `/login` | POST | Verarbeitet den Login-Versuch |
| `/logout` | GET | Beendet die Session |
| `/config` | GET | Zeigt die Konfigurationsoberfläche an (erfordert Login) |
| `/update` | POST | Alternative Schnittstelle für Updates |

**Stand:** 10. Juni 2025

---

**Hinweis:** Diese Liste wird automatisch aus dem aktuellen Quellcode generiert und sollte bei jeder Änderung der API aktualisiert werden.
