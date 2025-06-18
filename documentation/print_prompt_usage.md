# Verwendung der `print_prompt`-Funktion

Die `print_prompt`-Funktion wurde erweitert, um verschiedene Arten von Benutzerinteraktionen zu unterstützen. Sie ersetzt die frühere `promptyn`-Funktion und vereinheitlicht die Benutzerinteraktion im gesamten Skriptsystem.

## Grundfunktionen

Die Funktion bietet drei Hauptmodi:

1. **Einfache Anzeige** - Zeigt Text an, ohne auf Benutzereingabe zu warten
2. **Ja/Nein-Abfrage** - Fragt nach einer Ja/Nein-Antwort und gibt entsprechend 0 oder 1 zurück
3. **Texteingabe** - Erlaubt freie Texteingabe und gibt den eingegebenen Text zurück

## Parameter

```bash
print_prompt "Text" [Prompt-Typ] [Default-Wert]
```

- `Text`: Der anzuzeigende Text
- `Prompt-Typ` (optional):
  - Leer: Nur Anzeige ohne Benutzereingabe
  - `"yn"`: Ja/Nein-Abfrage (gibt 0 für Ja und 1 für Nein zurück)
  - `"text"`: Freie Texteingabe (gibt eingegebenen Text zurück)
- `Default-Wert` (optional, nur für Ja/Nein-Abfragen):
  - `"y"`: Default ist Ja bei leerer Eingabe
  - `"n"`: Default ist Nein bei leerer Eingabe (Standard)

## Beispiele

### Einfache Anzeige

```bash
print_prompt "Bitte beachten Sie die folgenden Hinweise:"
```

### Ja/Nein-Abfrage (Default: Nein)

```bash
print_prompt "Möchten Sie fortfahren?" "yn"
if [ $? -eq 0 ]; then
    echo "Benutzer hat Ja gewählt."
else
    echo "Benutzer hat Nein gewählt."
fi
```

### Ja/Nein-Abfrage (Default: Ja)

```bash
print_prompt "Standardkonfiguration verwenden?" "yn" "y"
if [ $? -eq 0 ]; then
    echo "Standard-Konfiguration wird verwendet."
else
    echo "Benutzerdefinierte Konfiguration wird verwendet."
fi
```

### Texteingabe

```bash
name=$(print_prompt "Bitte geben Sie Ihren Namen ein:" "text")
echo "Hallo, $name!"
```

## Unbeaufsichtigter Modus (unattended)

Im unbeaufsichtigten Modus (`UNATTENDED=1`):

- Ja/Nein-Abfragen geben immer 1 (Nein) zurück
- Texteingaben geben leere Strings zurück
- Einfache Anzeigen werden unterdrückt

Dies ermöglicht automatisierte Abläufe ohne Benutzerinteraktion.

## Hinweis zur Migration

Die alte `promptyn`-Funktion wurde entfernt. Alle Ja/Nein-Abfragen sollten nun mit `print_prompt` durchgeführt werden:

```bash
# Alt:
if promptyn "Möchten Sie fortfahren?"; then
    # Aktion wenn Ja
fi

# Neu:
print_prompt "Möchten Sie fortfahren?" "yn"
if [ $? -eq 0 ]; then
    # Aktion wenn Ja
fi
```
