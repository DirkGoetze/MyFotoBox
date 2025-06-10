# API-Endpunkte-Policy

Diese Policy definiert alle verfügbaren API-Endpunkte und deren Funktionen im Fotobox-Projekt und dient als technische Vorgabe für Entwickler.

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
| `/api/take_photo` | POST | Löst die Aufnahme eines Fotos aus | `{"delay": number}` (optional) | `{"status": "ok"}` |
| `/api/gallery` | GET | Gibt eine Liste der Fotos im gallery-Ordner zurück | - | `{"photos": ["foto1.jpg", "foto2.jpg", ...]}` |
| `/api/photos` | GET | Gibt eine Liste der Originalfotos zurück | - | `{"photos": ["foto1.jpg", "foto2.jpg", ...]}` |

## System und Updates

| Endpunkt | Methode | Funktion | Request-Format | Response-Format |
|----------|---------|----------|----------------|-----------------|
| `/api/update` | GET | Prüft, ob ein Update verfügbar ist | - | `{"update_available": true/false, "local_version": "string", "remote_version": "string"}` |
| `/api/update` | POST | Führt ein Update durch | - | String mit Update-Status oder Fehlermeldung |
| `/api/backup` | POST | Erstellt ein Backup | - | String mit Backup-Status oder Fehlermeldung |

## Weitere Endpunkte

| Endpunkt | Methode | Funktion | Request-Format | Response-Format |
|----------|---------|----------|----------------|-----------------|
| `/login` | GET | Zeigt die Login-Oberfläche an | - | HTML-Formular |
| `/login` | POST | Verarbeitet den Login-Versuch | Formular-Parameter: `password` | Weiterleitung zu `/config` oder Fehlermeldung |
| `/logout` | GET | Beendet die Session | - | Weiterleitung zu `/login` |
| `/config` | GET | Zeigt die Konfigurationsoberfläche an (erfordert Login) | - | HTML-Konfigurationsseite |
| `/update` | POST | Alternative Schnittstelle für Updates | - | String mit Update-Status oder Fehlermeldung |

**Stand:** 10. Juni 2025

---

**Hinweise für Implementierung:**

1. Alle API-Endpunkte sollten konsistent mit dem dokumentierten Format antworten
2. Fehlerbehandlung gemäß error_handling_policy.md implementieren
3. Authentifizierungsprüfung bei allen schreibenden Operationen durchführen
4. Bei Updates immer vorher ein Backup erstellen
5. Datenbankzugriffe über manage_database.py abstrahieren

Diese API-Policy ist verbindlich für alle Backend-Entwicklungen am Fotobox-Projekt.
