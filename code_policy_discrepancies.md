# Identifizierte Abweichungen zwischen Code und Policies

## Einleitung

Dieses Dokument listet die identifizierten Abweichungen zwischen der aktuellen Codebase und den definierten Richtlinien (Policies) auf. Abweichungen, die bereits behoben wurden, sind als "KORRIGIERT" markiert.

## Frontend-Abweichungen

### 1. Header-Link-Inkonsistenzen (KORRIGIERT)

**Problem**: In den HTML-Dateien (capture.html, gallery.html, settings.html, contact.html) wurde der Header-Titel-Link auf "capture.html" gesetzt, aber gemäß der Frontend-Routing-Policy und der JavaScript-Funktion `setHeaderTitle` sollte er auf "install.html" zeigen.

**Korrekturmaßnahmen**: 
- Alle Header-Links in den HTML-Dateien wurden von "capture.html" auf "install.html" geändert, um der Frontend-Routing-Policy zu entsprechen.
- Die Korrektur betraf folgende Dateien:
  - frontend/capture.html
  - frontend/gallery.html
  - frontend/settings.html
  - frontend/contact.html

**Richtlinienreferenz**: `policies/frontend_routing_policy.md`

### 2. Menü-Items und Navigationslogik

**Beobachtung**: Die Menü-Items in `main.js` enthalten "Home", das auf "capture.html" verweist, was konzeptionell korrekt ist, da "capture.html" als Hauptseite für die Fotoaufnahme definiert ist.

**Schlussfolgerung**: Keine Abweichung, entspricht der Frontend-Routing-Policy.

## Backend-Abweichungen

### 3. API-Einstellungs-Parameter

**Problem**: In der API-Endpunkte-Policy wird `gallery_timeout_ms` als Parameter in den API-Einstellungen erwähnt, aber es ist im Backend-Code nicht explizit als Einstellung implementiert.

**Empfohlene Maßnahme**: Sicherstellen, dass der Parameter `gallery_timeout_ms` in der `/api/settings`-Route korrekt verarbeitet wird.

## Zusammenfassung

Die wichtigste identifizierte Abweichung (Header-Links) wurde korrigiert. Das Backend sollte hinsichtlich der vollständigen Implementierung aller in der API-Endpunkte-Policy definierten Parameter überprüft werden.

**Datum der Überprüfung**: 10. Juni 2025
