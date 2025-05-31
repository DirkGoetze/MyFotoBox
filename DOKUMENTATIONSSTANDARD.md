# Kommentar- und Funktionsdokumentationsstandard für Shell-Skripte

Dieses Schema soll für alle Shell-Skripte in zukünftigen Projekten verwendet werden.

-------------------------------------------------------------------------------
# funktionsname
-------------------------------------------------------------------------------
# Funktion: Kurzbeschreibung der Aufgabe der Funktion (max. 78 Zeichen)
# [Optional: weitere Details, Parameter, Rückgabewerte, Besonderheiten]
funktionsname() {
    # Funktionscode ...
}

Beispiel:
-------------------------------------------------------------------------------
# update_system
-------------------------------------------------------------------------------
# Funktion: Aktualisiert die Systempakete mit apt-get update (Schritt 1/9)
update_system() {
    echo "[1/9] Systempakete werden aktualisiert ..."
    apt-get update -qq > /dev/null
}

Hinweise:
- Die Rahmenlinien bestehen immer aus 78 Bindestrichen.
- Nach dem Funktionsnamen folgt eine Zeile mit der Beschreibung.
- Optional können weitere Details ergänzt werden.
- Dieses Schema ist für alle Shell-Skripte und bash-Funktionen zu verwenden.
