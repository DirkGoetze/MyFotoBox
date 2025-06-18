#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
utils.py - Allgemeine Hilfsfunktionen für das Fotobox2-Backend
"""

import os
import re
import json
import uuid
import time
import datetime
import hashlib
from typing import Dict, List, Union, Optional, Any, Callable

import logging
logger = logging.getLogger(__name__)


def format_bytes(size: int, decimal_places: int = 2) -> str:
    """
    Formatiert eine Dateigröße in eine lesbare Form

    Args:
        size: Anzahl der Bytes
        decimal_places: Anzahl der Dezimalstellen

    Returns:
        Formatierte Größe (z.B. "1.23 MB")
    """
    if size == 0:
        return "0 Bytes"
    
    size_names = ("Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = 0
    factor = 1024.0
    
    while size >= factor and i < len(size_names) - 1:
        size /= factor
        i += 1
        
    return f"{size:.{decimal_places}f} {size_names[i]}"


def normalize_string(text: str) -> str:
    """
    Normalisiert einen String für die Verwendung als ID oder technischer Bezeichner
    
    Entfernt Sonderzeichen und Umlaute, ersetzt Leerzeichen durch Unterstriche
    und stellt sicher, dass der String nur aus alphanumerischen Zeichen und Unterstrichen besteht.

    Args:
        text: Der zu normalisierende Text

    Returns:
        Normalisierter String, sicher für ID-Verwendung
    """
    # Umlaute und spezielle Zeichen ersetzen
    replacements = {
        'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss',
        'Ä': 'Ae', 'Ö': 'Oe', 'Ü': 'Ue',
        ' ': '_', '-': '_'
    }
    
    # Ersetze bekannte Zeichen
    for key, value in replacements.items():
        text = text.replace(key, value)
    
    # Entferne alle nicht-alphanumerischen Zeichen (außer Unterstrich)
    text = re.sub(r'[^a-zA-Z0-9_]', '', text)
    
    # Entferne führende Zahlen oder Unterstriche
    text = re.sub(r'^[0-9_]+', '', text)
    
    # Ersetze mehrere aufeinanderfolgende Unterstriche durch einen einzelnen
    text = re.sub(r'_+', '_', text)
    
    # Stelle sicher, dass der String nicht leer ist
    if not text:
        text = f"item_{int(time.time())}"
    
    return text


def format_date(date: Optional[datetime.datetime] = None,
               include_time: bool = False,
               date_format: Optional[str] = None) -> str:
    """
    Formatiert ein Datum als String im deutschen Format

    Args:
        date: Das zu formatierende Datum, Standard ist das aktuelle Datum/Zeit
        include_time: Ob die Uhrzeit eingeschlossen werden soll
        date_format: Benutzerdefiniertes Format (überschreibt andere Parameter)

    Returns:
        Das formatierte Datum
    """
    if date is None:
        date = datetime.datetime.now()
        
    if date_format:
        return date.strftime(date_format)
        
    if include_time:
        return date.strftime("%d.%m.%Y %H:%M")
        
    return date.strftime("%d.%m.%Y")


def generate_uuid() -> str:
    """
    Generiert eine UUID v4

    Returns:
        Die generierte UUID als String
    """
    return str(uuid.uuid4())


def is_valid_email(email: str) -> bool:
    """
    Prüft, ob ein String eine gültige E-Mail-Adresse ist

    Args:
        email: Die zu prüfende E-Mail-Adresse

    Returns:
        True wenn gültig, sonst False
    """
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def is_valid_date(date_string: str, format_str: str = "%d.%m.%Y") -> bool:
    """
    Prüft, ob ein String ein gültiges Datum ist

    Args:
        date_string: Das zu prüfende Datum
        format_str: Das Format des Datums

    Returns:
        True wenn gültig, sonst False
    """
    try:
        datetime.datetime.strptime(date_string, format_str)
        return True
    except ValueError:
        return False


def deep_copy(obj: Any) -> Any:
    """
    Tiefe Kopie eines Objekts

    Args:
        obj: Das zu kopierende Objekt

    Returns:
        Eine tiefe Kopie des Objekts
    """
    return json.loads(json.dumps(obj))


def parse_query_string(query_string: str) -> Dict[str, str]:
    """
    Analysiert einen URL-Query-String

    Args:
        query_string: Der zu analysierende Query-String

    Returns:
        Ein Dictionary mit den Query-Parametern
    """
    if query_string.startswith('?'):
        query_string = query_string[1:]
        
    params = {}
    for pair in query_string.split('&'):
        if '=' in pair:
            key, value = pair.split('=', 1)
            params[key] = value
        else:
            params[pair] = ''
            
    return params


def update_query_param(url: str, param: str, value: str) -> str:
    """
    Fügt einen Query-Parameter zu einer URL hinzu oder aktualisiert ihn

    Args:
        url: Die URL
        param: Der Parameter-Name
        value: Der Parameter-Wert

    Returns:
        Die aktualisierte URL
    """
    pattern = re.compile(r'([?&])' + re.escape(param) + r'=[^&]*(&|$)')
    separator = '&' if '?' in url else '?'
    
    if pattern.search(url):
        return pattern.sub(r'\1' + param + '=' + value + r'\2', url)
    else:
        return url + separator + param + '=' + value


def safe_file_name(filename: str) -> str:
    """
    Bereinigt einen Dateinamen für sichere Verwendung im Dateisystem

    Args:
        filename: Der zu bereinigende Dateiname

    Returns:
        Ein sicherer Dateiname
    """
    # Entferne ungültige Zeichen
    safe_name = re.sub(r'[^\w\s.-]', '_', filename)
    
    # Entferne führende und nachfolgende Punkte und Leerzeichen
    safe_name = safe_name.strip('. ')
    
    # Ersetze mehrere Leerzeichen durch ein einzelnes
    safe_name = re.sub(r'\s+', ' ', safe_name)
    
    # Wenn der Name jetzt leer ist, verwende einen Standardwert
    if not safe_name:
        safe_name = f"file_{int(time.time())}"
        
    return safe_name


def merge_dicts(dict1: Dict, dict2: Dict, deep: bool = False) -> Dict:
    """
    Führt zwei Dictionaries zusammen

    Args:
        dict1: Erstes Dictionary
        dict2: Zweites Dictionary (überschreibt Werte aus dict1)
        deep: Ob ein tiefes Merge durchgeführt werden soll

    Returns:
        Das zusammengeführte Dictionary
    """
    result = dict1.copy()
    
    if not deep:
        result.update(dict2)
        return result
        
    for key, value in dict2.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge_dicts(result[key], value, deep)
        else:
            result[key] = value
            
    return result


def ensure_dir(directory: str) -> bool:
    """
    Stellt sicher, dass ein Verzeichnis existiert

    Args:
        directory: Pfad zum Verzeichnis

    Returns:
        True wenn das Verzeichnis existiert oder erstellt wurde
    """
    if not os.path.exists(directory):
        try:
            os.makedirs(directory)
            logger.debug(f"Verzeichnis erstellt: {directory}")
            return True
        except OSError as e:
            logger.error(f"Fehler beim Erstellen des Verzeichnisses {directory}: {e}")
            return False
    return True


def hash_string(text: str, algorithm: str = 'sha256') -> str:
    """
    Erstellt einen Hash aus einem String

    Args:
        text: Der zu hashende Text
        algorithm: Der zu verwendende Algorithmus ('md5', 'sha1', 'sha256', 'sha512')

    Returns:
        Der Hash als Hexadezimal-String
    """
    if algorithm == 'md5':
        hash_obj = hashlib.md5(text.encode())
    elif algorithm == 'sha1':
        hash_obj = hashlib.sha1(text.encode())
    elif algorithm == 'sha256':
        hash_obj = hashlib.sha256(text.encode())
    elif algorithm == 'sha512':
        hash_obj = hashlib.sha512(text.encode())
    else:
        raise ValueError(f"Unbekannter Hash-Algorithmus: {algorithm}")
        
    return hash_obj.hexdigest()


def retry(max_tries: int = 3, delay_seconds: int = 1, 
          backoff_factor: int = 2, exceptions: tuple = (Exception,)) -> Callable:
    """
    Decorator für automatische Wiederholungsversuche bei Funktionen

    Args:
        max_tries: Maximale Anzahl an Versuchen
        delay_seconds: Verzögerung zwischen Versuchen in Sekunden
        backoff_factor: Faktor für die Verzögerung (exponentieller Backoff)
        exceptions: Tuple von Exceptions, die abgefangen werden sollen

    Returns:
        Dekorierte Funktion
    """
    def decorator(func):
        def wrapper(*args, **kwargs):
            mtries, mdelay = max_tries, delay_seconds
            while mtries > 1:
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    logger.warning(
                        f"Funktion {func.__name__} fehlgeschlagen mit {e}, "
                        f"Wiederholungsversuch in {mdelay} Sekunden..."
                    )
                    time.sleep(mdelay)
                    mtries -= 1
                    mdelay *= backoff_factor
            return func(*args, **kwargs)
        return wrapper
    return decorator


# Füge hier weitere nützliche Hilfsfunktionen hinzu

if __name__ == "__main__":
    # Testcode für die Funktionen
    print(f"Formatierte Bytes: {format_bytes(1024*1024)}")
    print(f"Aktuelles Datum: {format_date()}")
    print(f"UUID: {generate_uuid()}")
    print(f"E-Mail gültig: {is_valid_email('test@example.com')}")
    print(f"Datum gültig: {is_valid_date('01.01.2023')}")
