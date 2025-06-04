# Netzwerkkonfiguration der Fotobox – Einsatzsszenarien und Empfehlungen

## Einleitung

Die Fotobox kann flexibel in verschiedenen Netzwerksituationen betrieben werden. Die wichtigsten Einstellungen (wie Bind-Adresse, Port, Servername, Webroot usw.) ermöglichen es, die Weboberfläche optimal an die jeweilige Umgebung anzupassen. Im Folgenden werden die drei typischen Einsatzszenarien Schritt für Schritt erläutert – jeweils mit Empfehlungen für die Konfiguration.

---

## Szenario 1: Standalone-Betrieb (kein Netz)

**Beschreibung:**

- Die Fotobox läuft auf einem einzelnen Gerät ohne Netzwerkverbindung oder soll ausschließlich lokal genutzt werden.

**Empfohlene Einstellungen:**

- **Bind-Adresse:** `127.0.0.1` (nur lokal erreichbar)
- **Port:** beliebig (z.B. 8080, 8888)
- **Servername:** optional
- **URL-Pfad:** optional
- **Konfigurationstyp:** intern (Default-Site von NGINX)
- **HTTPS/SSL:** unwichtig

**Hinweis:**

- Die Weboberfläche ist nur auf dem Gerät selbst erreichbar. Ideal für Einzelplatzbetrieb oder Testzwecke.

---

## Szenario 2: Betrieb im lokalen Netzwerk

**Beschreibung:**

- Die Fotobox soll von mehreren Geräten im selben lokalen Netzwerk (z.B. WLAN) erreichbar sein.

**Empfohlene Einstellungen:**

- **Bind-Adresse:** `0.0.0.0` (alle Interfaces) oder spezifische lokale IP (z.B. `192.168.x.x`)
- **Port:** anpassbar (z.B. 80, 8080)
- **Servername:** sinnvoll (z.B. `fotobox.local` für mDNS/Bonjour)
- **URL-Pfad:** optional (z.B. `/fotobox/`)
- **Konfigurationstyp:** extern oder intern
- **HTTPS/SSL:** optional

**Hinweis:**

- Die Weboberfläche ist im gesamten lokalen Netz erreichbar. Für mehr Komfort kann ein Servername vergeben werden.

---

## Szenario 3: Cloud- oder externer Zugriff

**Beschreibung:**

- Die Fotobox soll aus dem Internet oder über VPN erreichbar sein (z.B. für Fernzugriff, Event-Cloud).

**Empfohlene Einstellungen:**

- **Bind-Adresse:** `0.0.0.0` oder spezifische öffentliche IP
- **Port:** anpassbar (z.B. 80, 443, 8080)
- **Servername:** sinnvoll (z.B. DNS-Name oder DynDNS)
- **URL-Pfad:** optional
- **Konfigurationstyp:** extern
- **HTTPS/SSL:** wichtig (z.B. Let's Encrypt)

**Hinweis:**

- Für den sicheren Betrieb im Internet ist HTTPS/SSL dringend empfohlen. Firewall und Portfreigaben beachten!

---

## Übersichtstabelle: Einstellungen je Szenario

| Einstellung        | Standalone (kein Netz) | Lokales Netz         | Cloud/extern         |
|--------------------|------------------------|----------------------|----------------------|
| Bind-Adresse       | 127.0.0.1              | 0.0.0.0 / lokale IP  | 0.0.0.0 / öffentl. IP|
| Port               | beliebig               | anpassbar            | anpassbar            |
| Servername         | optional               | sinnvoll             | sinnvoll             |
| URL-Pfad           | optional               | optional             | optional             |
| Konfigurationstyp  | intern                 | extern/optional      | extern/optional      |
| Status/Validierung | wichtig                | wichtig              | wichtig              |
| HTTPS/SSL          | unwichtig              | optional             | wichtig              |

---

**Fazit:**

Mit diesen Einstellungen kann die Fotobox flexibel und sicher an die jeweilige Netzwerksituation angepasst werden – egal ob Einzelplatz, lokales Netz oder (später) Cloud-Betrieb. Die Übersicht hilft, schnell die passenden Werte zu finden.
