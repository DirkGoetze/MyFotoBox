# Policy: Softwarediagramme (ASCII- und Ablaufdiagramme)

## Ziel
Diese Policy legt verbindliche Regeln für die Erstellung von Softwarediagrammen (insbesondere ASCII-Ablaufdiagramme) im Projekt fest. Sie dient der einheitlichen, klaren und nachvollziehbaren Dokumentation von Softwareabläufen, Installationsprozessen und Systemlogik.

## Diagrammstil

- **Rechtecke:** Jeder Prozess- oder Funktionsschritt wird als Rechteck mit ASCII-Linien dargestellt.
- **Breite:** Alle Rechtecke und Spalten sind einheitlich breit (maximal 78 Zeichen, Standard: 78 Zeichen).
- **Ausrichtung:** Texte in den Zellen sind linksbündig, der rechte Rand ist einheitlich.
- **Verbindungen:** Der zu erwartende (OK-)Pfad läuft immer nach unten weiter (vertikale Linie `|`).
- **Entscheidungen:** Verzweigungen werden als zwei (oder mehr) nebeneinanderliegende Rechtecke dargestellt:
  - Linke Spalte: OK- oder Standardfall
  - Rechte Spalte: Fehler- oder Sonderfall (z.B. Abbruch)
- **Fehlerfälle:** Fehler-/Abbruchpfade sind nach rechts ausgelagert und klar erkennbar.
- **Schrittbeschriftung:** Jeder Schritt ist klar und prägnant beschriftet. Details (z.B. Befehle, Optionen) können als Aufzählung im Rechteck stehen.
- **Legende:** Am Ende des Diagramms ist eine Legende mit den wichtigsten Konventionen und Symbolen anzugeben.

## Beispiel für einfache Verzweigung (z.B. if then)

```text
+------------------------------------------------------------------------------+
| Prüfe Root-Rechte                                                            |
+------------------------------------------------------------------------------+
| OK                                    | Fehler                               |
+---------------------------------------+--------------------------------------+
|                                       | Abbruch:                             |
|                                       | Keine Root-Rechte                    |
+---------------------------------------+--------------------------------------+
```

## Beispiel für komplexe Verzweigungen (z.B. if then elif else fi, case)

```text
+------------------------------------------------------------------------------+
| Parameter auswerten                                                          |
+------------------------------------------------------------------------------+
| Parameter 1       | Parameter 2       | Parameter 3       | Parameter (n)    |
+---------------------------------------+--------------------------------------+
        |                   |                   |                   |
 +-----------------+ +-----------------+ +-----------------+ +-----------------+
 | Schritt a       | | Schritt a       | | Schritt a       | | Schritt a       |
 +-----------------+ +-----------------+ +-----------------+ +-----------------+
        |                   |                   |                   |
 +-----------------+ +-----------------+        |            +-----------------+
 | Schritt a       | | Schritt a       |        |            | Schritt a       |
 +-----------------+ +-----------------+        |            +-----------------+
        |                   |                   |                   |
 +-----------------+        |                   |                   |            
 | Schritt a       |        |                   |                   |
 +-----------------+        |                   |                   |            
        |                   |                   |                   |
+------------------------------------------------------------------------------+
| Parameter auswerten abgeschlossen                                            |
+------------------------------------------------------------------------------+

```

## Anwendung

- Diese Policy ist für alle neuen und zu aktualisierenden Softwarediagramme im Projekt verbindlich.
- Sie gilt für Installations-, Ablauf-, Architektur- und Entscheidungsdiagramme, die als ASCII-Grafik dokumentiert werden.
- Bei komplexeren Verzweigungen (z.B. mehr als zwei Fälle) sind weitere Spalten nach demselben Muster zu ergänzen.
- Die Diagramme sind so zu gestalten, dass sie in Markdown-Dateien und Plaintext-Dokumenten gut lesbar sind.

## Ablage

- Die Policy ist im Ordner `policies/` als `softwarediagramm_policy.md` zu hinterlegen.
- Ein Verweis auf diese Policy ist in allen relevanten Dokumentationsdateien (z.B. README, Installationsanleitung, Ablaufdiagrammen) zu ergänzen.

---

**Hinweis:**
Für grafische Diagramme (z.B. Mermaid, PlantUML) gelten gesonderte Konventionen, siehe `diagramm_policy.md`.
