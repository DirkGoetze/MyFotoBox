# Python-Coding-Style-Policy

Diese Policy definiert die Standards für Python-Code im Fotobox2-Projekt und dient als verbindliche Vorgabe für alle Python-Entwicklungen.

## Allgemeine Formatierung

1. **PEP 8-Grundsätze**: Der Code muss den grundlegenden Empfehlungen von PEP 8 folgen.
2. **Pylint-Score**: Angestrebter Pylint-Score von 10/10 für alle Python-Module.
3. **Zeilenlänge**: Maximal 100 Zeichen pro Zeile (bei Ausnahmen durch Kommentar rechtfertigen).
4. **Einrückung**: 4 Leerzeichen, keine Tabs.
5. **Leerzeichen und Leerzeilen**:
   - Keine Leerzeichen am Zeilenende.
   - Keine doppelten Leerzeilen innerhalb von Klassen oder Funktionen.
   - Eine Leerzeile zwischen Funktionen und nach Funktionsdeklarationen.
   - Zwei Leerzeilen zwischen Klassen und Top-Level-Funktionen.

## Datei-Header und Modul-Docstrings

Jede Python-Datei muss mit folgendem Header beginnen:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# [dateiname].py
# ------------------------------------------------------------------------------
# Funktion: [Kurze Beschreibung der Datei]
# [Optionale weitere Details]
# ------------------------------------------------------------------------------
"""
[Modul-Docstring-Titel]

[Ausführliche Beschreibung des Moduls mit Details zu Funktionalitäten,
Abhängigkeiten und Verwendungszweck]
"""
```

## Importe

1. **Gruppierung**: Importe müssen in folgender Reihenfolge gruppiert werden:
   - Standard-Bibliotheken
   - Drittanbieter-Bibliotheken
   - Projekt-spezifische Importe
2. **Jede Gruppe** wird durch eine Leerzeile getrennt.
3. **Vermeidung** von Wildcard-Importen (`from x import *`).
4. **Typ-Annotations**: `from typing import ...` bei Verwendung von Typ-Hinweisen.

## Docstrings und Kommentare

1. **Format**: Docstrings müssen PEP 257 folgen.
2. **Funktions-Docstrings**: Jede öffentliche Funktion benötigt einen Docstring mit:
   - Kurzbeschreibung der Funktion
   - Parameter-Beschreibungen mit Typ-Angaben
   - Rückgabewerte mit Typ-Angaben
   - Ausnahmen, die geworfen werden können
   - Beispiele oder Hinweise zur Verwendung (wenn sinnvoll)
   
   Beispiel:

   ```python
   def function_name(param1: str, param2: Optional[int] = None) -> bool:
       """
       Kurzbeschreibung der Funktion.
       
       Args:
           param1: Beschreibung des ersten Parameters
           param2: Beschreibung des zweiten Parameters, optional
       
       Returns:
           True bei Erfolg, False bei Fehler
       
       Raises:
           ValueError: Wenn param1 leer ist
       """
   ```

3. **Klassen-Docstrings**: Jede Klasse benötigt einen Docstring mit:
   - Beschreibung der Klasse
   - Attribute der Klasse
   - Besonderheiten oder Hinweise zur Verwendung

4. **Inline-Kommentare**: Komplexe Code-Abschnitte müssen durch Inline-Kommentare erläutert werden.

## Namenskonventionen

1. **Funktionen und Variablen**: `snake_case` für Funktionen, Methoden und Variablen.
2. **Klassen**: `PascalCase` (auch `CapWords` genannt) für Klassen.
3. **Konstanten**: `UPPER_CASE_WITH_UNDERSCORES` für Konstanten.
4. **Schnittstellen**: Mit `Interface` als Suffix (z.B. `LoggerInterface`).
5. **Nicht-öffentliche Elemente**: Durch führenden Unterstrich kennzeichnen (`_private_variable`).
6. **Ausnahmen (Exceptions)**: Mit `Error` als Suffix (z.B. `ConfigurationError`).
7. **Typalias**: Mit `Type` als Suffix (z.B. `PathType = Union[str, Path]`).

## Logging

1. **Format**: Lazy %-Formatierung für alle Logging-Aufrufe verwenden:

   ```python
   # Richtig:
   logger.info("Wert: %s", value)
   
   # Falsch:
   logger.info(f"Wert: {value}")  # Keine f-Strings im Logging
   logger.info("Wert: {}".format(value))  # Keine str.format() im Logging
   ```

2. **Logger-Instanzen**: Für jedes Modul einen eigenen Logger erstellen:

   ```python
   import logging
   logger = logging.getLogger(__name__)
   ```

3. **Log-Level**: Angemessene Log-Level verwenden:
   - `DEBUG`: Detaillierte Debugging-Informationen
   - `INFO`: Bestätigung erfolgreicher Operationen
   - `WARNING`: Hinweis auf unerwartete Ereignisse
   - `ERROR`: Fehler, die Operationen behindern
   - `CRITICAL`: Kritische Fehler, die das Programm zum Absturz bringen können

## Fehlerbehandlung

1. **Spezifische Exceptions**: Immer spezifische Exceptions fangen:

   ```python
   # Richtig:
   try:
       # Code, der OSError werfen könnte
   except OSError as e:
       logger.error("Dateisystemfehler: %s", e)
   
   # Falsch:
   try:
       # Code mit verschiedenen möglichen Exceptions
   except Exception as e:  # Zu allgemein
       logger.error("Fehler: %s", e)
   ```

2. **Fehlerinformationen**: In Logs immer Fehlerdetails und Kontext angeben.
3. **Wiederherstellung**: Bei Fehlern Ressourcen freigeben und sinnvolle Rückfallwerte nutzen.
4. **Fehler-Dokumentation**: In Docstrings angeben, welche Exceptions geworfen werden.
5. **Eigene Exceptions**: Für projektspezifische Fehler eigene Exception-Klassen definieren.

## Typ-Annotationen

1. **Verwendung**: Alle Funktionen und Methoden mit Typ-Annotationen versehen.
2. **Optional-Typen**: Für optionale Parameter `Optional[Typ]` aus `typing` verwenden.
3. **Union-Typen**: Für verschiedene mögliche Typen `Union[Typ1, Typ2]` verwenden.
4. **Rückgabetypen**: Immer den Rückgabetyp angeben, auch wenn es `None` ist.
5. **Typ-Aliase**: Für komplexe Typen Typ-Aliase definieren.

## Ressourcenmanagement

1. **Context Manager**: Für Ressourcen, die geschlossen werden müssen, `with`-Statements verwenden:

   ```python
   with open('datei.txt', 'r') as f:
       content = f.read()
   ```

2. **Temporäre Dateien**: Für temporäre Dateien das `tempfile`-Modul verwenden und sicherstellen, dass diese ordnungsgemäß geschlossen und gelöscht werden.

## Fortgeschrittene Python-Features

1. **Generatoren**: Für große Datenmengen Generatoren statt Listen verwenden.
2. **Comprehensions**: List/Dict/Set-Comprehensions für einfache Transformationen nutzen.
3. **Dekoratoren**: Für wiederholte Muster (Logging, Timing, Caching) Dekoratoren einsetzen.
4. **Abstrakte Klassen**: Für Interfaces das `abc`-Modul verwenden.

## Design-Patterns

1. **Singleton**: Für Konfiguration, Logging, Datenbankverbindungen das Singleton-Pattern verwenden. Bei Verwendung von `global` ein Pylint-Disable hinzufügen:

   ```python
   # pylint: disable=global-statement
   global _INSTANCE
   ```

2. **Factory**: Für komplexe Objekterzeugung Factory-Methoden oder -Klassen nutzen.
3. **Strategy**: Für austauschbare Algorithmen Strategy-Pattern verwenden.

## Tests

1. **Test-Framework**: Für alle Tests `pytest` verwenden.
2. **Namenskonvention**: Testdateien mit `test_` Präfix benennen.
3. **Testabdeckung**: Anstreben einer Testabdeckung von mindestens 80%.
4. **Mock-Objekte**: Externe Abhängigkeiten mit `unittest.mock` oder `pytest-mock` mocken.

## Linting und Qualitätssicherung

1. **Pylint**: Regelmäßige Prüfung mit Pylint, Ziel ist ein Score von 10/10.
2. **Ausnahmen**: Pylint-Warnungen nur in begründeten Fällen und lokal mit Kommentar deaktivieren:

   ```python
   # pylint: disable=specific-error-name
   ```

3. **Formatierung**: Optional: Prüfung mit `black` oder `yapf` für konsistente Formatierung.

## Praxis-Beispiel

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# example_module.py
# ------------------------------------------------------------------------------
# Funktion: Beispielmodul für die Python-Coding-Style-Policy
# ------------------------------------------------------------------------------
"""
Beispielmodul zur Illustration der Python-Coding-Standards.

Dieses Modul dient als Referenzimplementierung und demonstriert die
Formatierung, Docstrings und andere Aspekte des Python-Coding-Standards.
"""

import os
import logging
from typing import Dict, List, Optional, Union

# Projekt-spezifische Importe
import custom_module
from utils import helper

logger = logging.getLogger(__name__)

# Konstanten
DEFAULT_TIMEOUT = 30
MAX_RETRIES = 3

class ConfigurationError(Exception):
    """Exception für Konfigurationsfehler."""
    pass

def process_data(data: Dict[str, Union[str, int]], 
                 timeout: Optional[int] = None) -> List[str]:
    """
    Verarbeitet die übergebenen Daten und gibt eine Liste von Ergebnissen zurück.
    
    Args:
        data: Dictionary mit zu verarbeitenden Daten
        timeout: Optionaler Timeout in Sekunden, Standard ist DEFAULT_TIMEOUT
    
    Returns:
        Liste der verarbeiteten Ergebnisse
    
    Raises:
        ConfigurationError: Wenn die Konfiguration ungültig ist
        ValueError: Wenn data leer ist
    """
    if not data:
        logger.error("Leere Daten übergeben")
        raise ValueError("Data cannot be empty")
    
    actual_timeout = timeout or DEFAULT_TIMEOUT
    
    try:
        # Hier würde die eigentliche Datenverarbeitung stattfinden
        results = [str(value) for key, value in data.items()]
        logger.info("Daten erfolgreich verarbeitet: %d Elemente", len(results))
        return results
    except OSError as e:
        logger.error("Fehler bei der Datenverarbeitung: %s", e)
        raise ConfigurationError(f"Verarbeitungsfehler: {e}") from e


class DataProcessor:
    """
    Prozessiert und transformiert Daten.
    
    Attributes:
        config: Konfigurationswörterbuch
        _cache: Interner Cache für verarbeitete Daten
    """
    
    def __init__(self, config: Dict[str, any]):
        """
        Initialisiert den DataProcessor mit Konfiguration.
        
        Args:
            config: Konfigurationswörterbuch
        
        Raises:
            ConfigurationError: Wenn die Konfiguration ungültig ist
        """
        self.config = config
        self._cache = {}
        
        if 'required_key' not in config:
            logger.error("Fehlende erforderliche Konfiguration: required_key")
            raise ConfigurationError("required_key fehlt in der Konfiguration")
        
        logger.info("DataProcessor initialisiert mit Konfiguration: %s", 
                   config.get('name', 'unnamed'))
    
    def process(self, item_id: str) -> Optional[Dict[str, any]]:
        """
        Verarbeitet ein Element basierend auf seiner ID.
        
        Args:
            item_id: Die ID des zu verarbeitenden Elements
            
        Returns:
            Das verarbeitete Element oder None, wenn das Element nicht gefunden wurde
        """
        if not item_id:
            logger.warning("Leere item_id übergeben")
            return None
            
        # Prüfen, ob das Element bereits im Cache ist
        if item_id in self._cache:
            logger.debug("Cache-Treffer für item_id: %s", item_id)
            return self._cache[item_id]
            
        try:
            # Hier würde die eigentliche Verarbeitung stattfinden
            result = {'id': item_id, 'processed': True}
            
            # Ergebnis im Cache speichern
            self._cache[item_id] = result
            return result
        except Exception as e:
            # Hier fangen wir allgemein Exception, weil wir verschiedene
            # unbekannte Fehler haben könnten und die Funktion robust sein soll
            logger.error("Fehler bei der Verarbeitung von item_id %s: %s", item_id, e)
            return None
```

## Implementation und Einhaltung

1. **Code-Reviews**: Bei jedem Code-Review wird auch die Einhaltung dieser Python-Coding-Style-Policy geprüft.
2. **Automatisierung**: Einrichtung von Pylint als Teil der CI/CD-Pipeline zur automatischen Prüfung.
3. **Weiterbildung**: Regelmäßige Reviews dieser Policy und Anpassung an Best Practices.
