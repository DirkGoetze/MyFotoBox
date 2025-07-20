#!/bin/bash
# ------------------------------------------------------------------------------
# manage_settings.sh
# ------------------------------------------------------------------------------
# Funktion: Bereitstellung einer einheitlichen Schnittstelle für die Lese- und
# ......... Schreiboperationen auf die Datenbank.
# ......... 
# ......... 
# ......... 
# ------------------------------------------------------------------------------
# HINWEIS: Dieses Skript ist Bestandteil der Backend-Logik und darf nur im
# Unterordner 'backend/scripts/' abgelegt werden 
# ---------------------------------------------------------------------------
# POLICY-HINWEIS: Dieses Skript ist ein reines Funktions-/Modulskript und 
# enthält keine main()-Funktion mehr. Die Nutzung als eigenständiges 
# CLI-Programm ist nicht vorgesehen. Die Policy zur main()-Funktion gilt nur 
# für Hauptskripte.
#
# HINWEIS: Dieses Skript erfordert lib_core.sh und sollte nie direkt 
# .......  aufgerufen werden.
# ---------------------------------------------------------------------------

# ===========================================================================
# Hilfsfunktionen zur Einbindung externer Skript-Ressourcen
# ===========================================================================
# Guard für dieses Management-Skript
MANAGE_SETTINGS_LOADED=0
# ===========================================================================

# ===========================================================================
# Globale Konstanten (Vorgaben und Defaults für die Installation)
# ===========================================================================
# Die meisten globalen Konstanten werden bereits durch lib_core.sh gesetzt.
# bereitgestellt. Hier definieren wir nur Konstanten, die noch nicht durch 
# lib_core.sh gesetzt wurden oder die speziell für die Installation 
# überschrieben werden müssen.
# ---------------------------------------------------------------------------

# ===========================================================================
# Lokale Konstanten (Vorgaben und Defaults nur für die Installation)
# ===========================================================================
# Debug-Modus: Lokal und global steuerbar
# DEBUG_MOD_LOCAL: Wird in jedem Skript individuell definiert (Standard: 0)
# DEBUG_MOD_GLOBAL: Überschreibt alle lokalen Einstellungen (Standard: 0)
DEBUG_MOD_LOCAL=0            # Lokales Debug-Flag für einzelne Skripte
: "${DEBUG_MOD_GLOBAL:=0}"   # Globales Flag, das alle lokalen überstimmt

# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

# ---------------------------------------------------------------------------
# Hilfsfunktionen zur Werte- und Schlüssel-Verwaltung
# ---------------------------------------------------------------------------

# _parse_hierarchical_key
_parse_hierarchical_key_debug_0001="INFO: Extrahiere Hierarchie-Namen und Schlüsselname aus: '%s'"
_parse_hierarchical_key_debug_0002="SUCCESS: Hierarchie-Namen: '%s', Schlüsselname: '%s'"

_parse_hierarchical_key() {
    # -----------------------------------------------------------------------
    # _parse_hierarchical_key
    # -----------------------------------------------------------------------
    # Funktion.: Extrahiert den Hierarchie-Namen und den eigentlichen 
    # .........  Schlüsselnamen aus einem hierarchischen Schlüssel.
    # Parameter: $1 - Hierarchischer Schlüssel (z.B. "nginx.ssl.enabled")
    # Rückgabe.: hierarchisches Array mit Hierarchie-Namen 
    # .........  Schlüsselnamen
    # -----------------------------------------------------------------------
    local key="$1"

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_parse_hierarchical_key_debug_0001" "$key")"

    # Überprüfen, ob der Schlüssel angegeben ist
    if ! check_param "$key" "key"; then return 1; fi

    # Ersten Punkt finden und den String aufteilen
    local hierarchy_name="${key%%.*}"
    local key_name="${key#*.}"
    
    # Sonderfall: Kein Punkt im Schlüssel
    if [ "$key" = "$key_name" ]; then
        key_name=""
    fi
    
    # Ergebnis ausgeben
    debug "$(printf "$_parse_hierarchical_key_debug_0002" "$hierarchy_name" "$key_name")"
    echo "$hierarchy_name" "$key_name"
    return 0
}

# _clean_key
_clean_key_debug_0001="INFO: Bereinige Schlüsselname: '%s'"
_clean_key_debug_0002="SUCCESS: Bereinigter Schlüsselname: '%s'"

_clean_key() {
    # -----------------------------------------------------------------------
    # _clean_key
    # -----------------------------------------------------------------------
    # Funktion.: Bereinigt einen Schlüsselnamen, um sicherzustellen, dass er 
    # .........  nur gültige Zeichen enthält.
    # Parameter: $1 - Schlüsselname
    # .........  $2 - (Optional) Standard-Schlüsselname
    # Rückgabe.: Bereinigter Schlüsselname
    # -----------------------------------------------------------------------
    local key="$1"
    local default="${2:-}"

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_clean_key_debug_0001" "$key")"

    # Überprüfen, ob der Schlüssel angegeben ist
    if ! check_param "$key" "key"; then return 1; fi

    # Ungültige Zeichen entfernen (nur a-z, A-Z, 0-9, ., _ und - sind erlaubt)
    key=$(echo "$key" | sed 's/[^a-zA-Z0-9._-]//g')

    # Führende und nachfolgende Punkte/Unterstriche entfernen
    key=$(echo "$key" | sed 's/^[._]*//' | sed 's/[._]*$//')
    
    # Mehrfache Punkte auf einen reduzieren
    key=$(echo "$key" | sed 's/\.\.*/\./g')

    # Wenn der bereinigte Schlüssel leer ist, den Standard verwenden
    if [ -z "$key" ] && [ -n "$default" ]; then
        key="$default"
    fi

    # Ergebnis ausgeben
    debug "$(printf "$_clean_key_debug_0002" "$key")"
    echo "$key"
    return 0
}

# _validate_key
_validate_key_debug_0001="INFO: Validierung des Schlüssels: '%s'"
_validate_key_debug_0002="ERROR: Ungültiger Schlüsselname: Schlüssel ist leer."
_validate_key_debug_0003="ERROR: Ungültiger Schlüsselname: '%s' enthält ungültige Zeichen. Erlaubt sind: a-z, A-Z, 0-9, ., _ und -."
_validate_key_debug_0004="ERROR: Ungültiger Schlüsselname: '%s' darf nicht mit einem Punkt oder Unterstrich beginnen oder enden."
_validate_key_debug_0005="ERROR: Ungültiger Schlüsselname: '%s' darf keine aufeinanderfolgenden Punkte oder Unterstriche enthalten."
_validate_key_debug_0006="SUCCESS: Schlüssel '%s' ist gültig."

_validate_key() {
    # -----------------------------------------------------------------------
    # _validate_key
    # -----------------------------------------------------------------------
    # Funktion.: Validiert einen Schlüsselnamen auf korrekte Zeichen und Format.
    # .........  Der Schlüsselname darf nur alphanumerische Zeichen, Punkte,
    # .........  Unterstriche und Bindestriche enthalten. Er darf nicht mit 
    # .........  einem Punkt oder Unterstrich beginnen oder enden und keine 
    # .........  aufeinanderfolgenden Punkte oder Unterstriche haben.
    # Parameter: $1 - Schlüsselname
    # Rückgabe.: 0 - Schlüssel ist gültig
    # .........  1 - Schlüssel ist ungültig
    # -----------------------------------------------------------------------
    local key="$1"

    # Überprüfen, ob der Schlüssel angegeben ist - Leerer Schlüssel ungültig
    if ! check_param "$key" "key"; then 
        debug "$_validate_key_debug_0002"
        return 1; 
    fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_validate_key_debug_0001" "$key")"

    # Ungültige Zeichen prüfen (nur a-z, A-Z, 0-9, ., _ und - sind erlaubt)
    if ! [[ "$key" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        debug "$(printf "$_validate_key_debug_0003" "$key")"
        return 1
    fi

    # Prüfen, ob der Schlüssel mit einem Punkt oder Unterstrich beginnt oder endet
    if [[ "$key" =~ ^[._] || "$key" =~ [._]$ ]]; then
        debug "$(printf "$_validate_key_debug_0004" "$key")"
        return 1
    fi

    # Prüfen auf aufeinanderfolgende Punkte oder Unterstriche
    if [[ "$key" =~ \.\. || "$key" =~ __ || "$key" =~ \._ || "$key" =~ _\. ]]; then
        debug "$(printf "$_validate_key_debug_0005" "$key")"
        return 1
    fi

    debug "$(printf "$_validate_key_debug_0006" "$key")"
    return 0
}

# _generate_group_id
_generate_group_id_debug_0001="INFO: Generiere Gruppen-ID mit Präfix '%s', Zeitstempel '%s' und Zufallsstring '%s'"
_generate_group_id_debug_0002="SUCCESS: Generierte Gruppen-ID: '%s'"

_generate_group_id() {
    # -----------------------------------------------------------------------
    # generate_group_id
    # -----------------------------------------------------------------------
    # Funktion.: Diese Funktion erzeugt eine eindeutige ID für eine 
    # .........  Änderungsgruppe.
    # Parameter: $1 - (Optional) Präfix für die Gruppen-ID
    # Rückgabe.: Eindeutige Gruppen-ID
    # -----------------------------------------------------------------------
    local prefix="${1:-}"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local random=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)
    
    # Debug-Ausgabe eröffnen
    debug "$(printf "$_generate_group_id_debug_0001" "$prefix" "$timestamp" "$random")"

    # Generiere die Gruppen-ID
    if [ -n "$prefix" ]; then
        debug "$(printf "$_generate_group_id_debug_0002" "${prefix}_${timestamp}_${random}")"
        echo "${prefix}_${timestamp}_${random}"
    else
        debug "$(printf "$_generate_group_id_debug_0002" "grp_${timestamp}_${random}")"
        echo "grp_${timestamp}_${random}"
    fi
}

# ---------------------------------------------------------------------------
# Hilfsfunktionen zur Hierarchie-Verwaltung
# ---------------------------------------------------------------------------

# _hierarchy_exists
_hierarchy_exists_debug_0001="INFO: Prüfe, ob Hierarchie '%s' in der Datenbank existiert."
_hierarchy_exists_debug_0002="SUCCESS: Hierarchie '%s' existiert in der Datenbank."
_hierarchy_exists_debug_0003="WARN: Hierarchie '%s' existiert noch nicht in der Datenbank."

_hierarchy_exists() {
    # -----------------------------------------------------------------------
    # _hierarchy_exists
    # -----------------------------------------------------------------------
    # Funktion.: Diese Funktion prüft, ob eine Hierarchie bereits in der 
    # .........  Datenbank registriert ist.
    # Parameter: $1 - Name der Hierarchie
    # .........  $2 - (Optional) Pfad zur Datenbank
    # Rückgabe: 0, wenn die Hierarchie existiert, sonst 1
    # -----------------------------------------------------------------------
    local hierarchy_name="$1"
    local db_file="${2:-$(get_data_file)}"

    # Überprüfen, ob der Hierarchiename und der Datenbankpfad angegeben sind
    if ! check_param "$hierarchy_name" "hierarchy_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_hierarchy_exists_debug_0001" "$hierarchy_name")"

    # Hierarchienamen bereinigen und validieren
    hierarchy_name=$(_clean_key "$hierarchy_name")
    if ! _validate_key "$hierarchy_name"; then
        return 1
    fi
    
    # Prüfen, ob die Hierarchie in der Datenbank existiert
    local exists=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM config_hierarchies WHERE hierarchy_name='$hierarchy_name';")
    
    # Ergebnis prüfen und zurückgeben
    if [ "$exists" -gt 0 ]; then
        debug "$(printf "$_hierarchy_exists_debug_0002" "$hierarchy_name")"
        return 0  # Hierarchie existiert
    else
        debug "$(printf "$_hierarchy_exists_debug_0003" "$hierarchy_name")"
        return 1  # Hierarchie existiert nicht
    fi
}

# _get_hierarchy_id
_get_hierarchy_id_debug_0001="INFO: Abrufen der Hierarchie-ID für '%s' aus der Datenbank '%s'."
_get_hierarchy_id_debug_0002="ERROR: Hierarchie '%s' existiert nicht in der Datenbank."
_get_hierarchy_id_debug_0003="SUCCESS: Hierarchie-ID für '%s': %s"
_get_hierarchy_id_log_0001="Hierarchie '%s' existiert nicht in der Datenbank."
_get_hierarchy_id_log_0002="Hierarchie-ID für '%s': %s"

_get_hierarchy_id() {
    # -----------------------------------------------------------------------
    # _get_hierarchy_id
    # -----------------------------------------------------------------------
    # Funktion.: Gibt die Datenbank-ID einer Hierarchie zurück.
    # Parameter: $1 - Name der Hierarchie
    # .........  $2 - (Optional) Pfad zur Datenbank
    # Rückgabe.: ID der Hierarchie oder leer, wenn die Hierarchie nicht
    # .........  existiert 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local hierarchy_name="$1"
    local db_file="${2:-$(get_data_file)}"
    
    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$hierarchy_name" "hierarchy_name"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$register_config_hierarchy_debug_0001" "$hierarchy_name" "$db_file")"

    # Hierarchienamen bereinigen
    hierarchy_name=$(_clean_key "$hierarchy_name")

    # ID aus der Datenbank abrufen
    local hierarchy_id=$(sqlite3 "$db_file" "SELECT id FROM config_hierarchies WHERE hierarchy_name='$hierarchy_name';")

    # Prüfen, ob die Hierarchie-ID gefunden wurde
    if [ -z "$hierarchy_id" ]; then
        debug "$(printf "$_get_hierarchy_id_debug_0002" "$hierarchy_name")"
        log "$(printf "$_get_hierarchy_id_log_0001" "$hierarchy_name")"
        echo ""  # Leere Ausgabe, wenn die Hierarchie nicht existiert
        return 1
    fi

    # Hierarchie-ID zurückgeben
    debug "$(printf "$_get_hierarchy_id_debug_0003" "$hierarchy_name" "$hierarchy_id")"
    log "$(printf "$_get_hierarchy_id_log_0002" "$hierarchy_name" "$hierarchy_id")"
    echo "$hierarchy_id"
}

# ===========================================================================
# Konfigurationsfunktionen
# ===========================================================================

# register_config_hierarchy
register_config_hierarchy_debug_0001="INFO: Registriere Konfigurationshierarchie '%s' mit Beschreibung '%s', Verantwortlichem '%s'."
register_config_hierarchy_debug_0002="ERROR: Ungültiger Hierarchiename: '%s'. Hierarchie konnte nicht registriert werden."
register_config_hierarchy_debug_0003="WARN: Hierarchie '%s' existiert bereits."
register_config_hierarchy_debug_0004="ERROR: Fehler beim Einfügen der Hierarchie in die Datenbank: %s"
register_config_hierarchy_debug_0005="SUCCESS: Konfigurationshierarchie '%s' erfolgreich registriert."
register_config_hierarchy_log_0001="Ungültiger Hierarchiename: '%s'. Hierarchie konnte nicht registriert werden."
register_config_hierarchy_log_0002="Hierarchie '%s' existiert bereits."
register_config_hierarchy_log_0003="Fehler beim Einfügen der Hierarchie in die Datenbank: %s"
register_config_hierarchy_log_0004="Konfigurationshierarchie '%s' erfolgreich registriert."

register_config_hierarchy() {
    # -----------------------------------------------------------------------
    # register_config_hierarchy
    # -----------------------------------------------------------------------
    # Funktion.: Registriert eine neue Konfigurationshierarchie in der
    # .........  Datenbank.
    # Parameter: $1 - Name der Hierarchie
    # .........  $2 - Beschreibung
    # .........  $3 - Verantwortliche Person/Modul
    # .........  $4 - (Optional) Hierarchie-Daten als JSON
    # .........  $5 - (Optional) Pfad zur Datenbank
    # Rückgabe: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local hierarchy_name="$1"
    local description="$2"
    local responsible="$3"
    local hierarchy_data="${4:-{}}"  # Standardwert für leere Hierarchie-Daten
    local db_file="${5:-$(get_data_file)}"

    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$hierarchy_name" "hierarchy_name"; then return 1; fi
    if ! check_param "$description" "description"; then return 1; fi
    if ! check_param "$responsible" "responsible"; then return 1; fi
    if ! check_param "$hierarchy_data" "hierarchy_data"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$register_config_hierarchy_debug_0001" "$hierarchy_name" "$description" "$responsible")"

    # Hierarchienamen bereinigen und validieren
    hierarchy_name=$(_clean_key "$hierarchy_name")
    if ! _validate_key "$hierarchy_name"; then
        debug "$(printf "$register_config_hierarchy_debug_0002" "$hierarchy_name")"
        log "$(printf "$register_config_hierarchy_log_0001" "$hierarchy_name")"
        return 1
    fi
    
    # Prüfen, ob die Hierarchie bereits existiert
    if _hierarchy_exists "$hierarchy_name" "$db_file"; then
        debug "$(printf "$register_config_hierarchy_debug_0003" "$hierarchy_name")"
        log "$(printf "$register_config_hierarchy_log_0002" "$hierarchy_name")"
        return 0
    fi
    
    # Hierarchie in die Datenbank einfügen
    if [ "$hierarchy_data" = "{}" ]; then
        # Einfaches leeres JSON direkt im SQL verwenden
        sqlite3 "$db_file" "INSERT INTO config_hierarchies (hierarchy_name, description, responsible, hierarchy_data) 
                           VALUES ('$hierarchy_name', '$description', '$responsible', '{}')"
    else
        # Für nicht-leere JSON-Werte die json()-Funktion verwenden
        sqlite3 "$db_file" "INSERT INTO config_hierarchies (hierarchy_name, description, responsible, hierarchy_data) 
                           VALUES ('$hierarchy_name', '$description', '$responsible', json('$hierarchy_data'))"
    fi

    # Prüfen, ob der Einfügevorgang erfolgreich war
    if [ $? -ne 0 ]; then
        debug "$(printf "$register_config_hierarchy_debug_0004" "$(sqlite3 "$db_file" "SELECT sqlite_error_msg();")")"
        log "$(printf "$register_config_hierarchy_log_0003" "$(sqlite3 "$db_file" "SELECT sqlite_error_msg();")")"
        return 1
    fi    

    # Erfolgsmeldung ausgeben
    debug "$(printf "$register_config_hierarchy_debug_0005" "$hierarchy_name")"
    log "$(printf "$register_config_hierarchy_log_0004" "$hierarchy_name")"
    return 0
}

# has_config_value
_has_config_value_debug_0001="INFO: Überprüfe, ob Konfigurationswert '%s' existiert."
_has_config_value_debug_0002="ERROR: Ungültiger Schlüsselname: '%s'."
_has_config_value_debug_0003="ERROR: Hierarchie '%s' existiert nicht in der Datenbank '%s'."
_has_config_value_debug_0004="SUCCESS: Konfigurationswert für '%s' in der Hierarchie '%s' existiert."
_has_config_value_debug_0005="ERROR: Konfigurationswert für '%s' in der Hierarchie '%s' existiert nicht."
_has_config_value_log_0001="Ungültiger Schlüsselname: '%s'."
_has_config_value_log_0002="Hierarchie '%s' existiert nicht in der Datenbank '%s'."
_has_config_value_log_0003="Konfigurationswert für '%s' in der Hierarchie '%s' existiert."
_has_config_value_log_0004="Konfigurationswert für '%s' in der Hierarchie '%s' existiert nicht."

has_config_value() {
    # -----------------------------------------------------------------------
    # has_config_value
    # -----------------------------------------------------------------------
    # Funktion.: Funktion prüft, ob ein Konfigurationswert existiert.
    # Parameter: $1 - Schlüsselname (z.B. "nginx.port")
    # .........  $2 - (Optional) Pfad zur Datenbank
    # Rückgabe.: 0, wenn der Wert existiert, sonst 1
    # -----------------------------------------------------------------------
    local full_key="$1"
    local db_file="${2:-$(get_data_file)}"

    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$full_key" "full_key"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$_has_config_value_debug_0001" "$full_key")"

    # Schlüssel validieren
    if ! _validate_key "$full_key"; then
        debug "$(printf "$_has_config_value_debug_0002" "$full_key")"
        log "$(printf "$_has_config_value_log_0001" "$full_key")"
        return 1
    fi

    # Hierarchie und eigentlichen Schlüssel extrahieren
    local parts=($(_parse_hierarchical_key "$full_key"))
    local hierarchy_name="${parts[0]}"
    local key_name="${parts[1]}"

    # Wenn die Hierarchie nicht existiert, gibt es auch keinen Wert
    if ! _hierarchy_exists "$hierarchy_name" "$db_file"; then
        debug "$(printf "$_has_config_value_debug_0003" "$hierarchy_name" "$db_file")"
        log "$(printf "$_has_config_value_log_0002" "$hierarchy_name" "$db_file")"
        return 1
    fi

    # Hierarchie-ID abrufen
    local hierarchy_id=$(_get_hierarchy_id "$hierarchy_name" "$db_file")

    # Prüfen, ob der Schlüssel existiert
    local exists=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM settings WHERE hierarchy_id=$hierarchy_id AND key='$key_name' AND is_active=1;")

    # Ergebnis prüfen und zurückgeben  
    if [ "$exists" -gt 0 ]; then
        debug "$(printf "$_has_config_value_debug_0004" "$key_name" "$hierarchy_name")"
        log "$(printf "$_has_config_value_log_0003" "$key_name" "$hierarchy_name")"
        return 0  # Wert existiert
    else
        debug "$(printf "$_has_config_value_debug_0005" "$key_name" "$hierarchy_name")"
        log "$(printf "$_has_config_value_log_0004" "$key_name" "$hierarchy_name")"
        return 1  # Wert existiert nicht
    fi
}

# get_config_value
get_config_value_debug_0001="INFO: Abrufen des Konfigurationswerts für '%s' aus der Hierarchie '%s'."
get_config_value_debug_0002="ERROR: Ungültiger Schlüsselname: '%s'."
get_config_value_debug_0003="ERROR: Hierarchie '%s' existiert nicht in der Datenbank '%s'."
get_config_value_debug_0004="SUCCESS: Konfigurationswert für '%s' in der Hierarchie '%s' abgerufen: '%s'."
get_config_value_log_0001="Ungültiger Schlüsselname: '%s'."
get_config_value_log_0002="Hierarchie '%s' existiert nicht in der Datenbank '%s'."
get_config_value_log_0003="Konfigurationswert für '%s' in der Hierarchie '%s' abgerufen: '%s'."

get_config_value() {
    # -----------------------------------------------------------------------
    # get_config_value
    # -----------------------------------------------------------------------
    # Funktion.: Funktion liest einen Konfigurationswert aus der Datenbank.
    # Parameter: $1 - Schlüsselname (z.B. "nginx.port")
    # .........  $2 - (Optional) Pfad zur Datenbank
    # Rückgabe.: Der Wert des Schlüssels oder leer, wenn der Schlüssel
    # .........  nicht existiert Returncode 0, wenn der Wert existiert,
    # .........  sonst 1
    # -----------------------------------------------------------------------
    local full_key="$1"
    local db_file="${2:-$(get_data_file)}"
    
    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$full_key" "full_key"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$get_config_value_debug_0001" "$full_key")"

    # Schlüssel validieren
    if ! _validate_key "$full_key"; then
        debug "$(printf "$get_config_value_debug_0002" "$full_key")"
        log "$(printf "$get_config_value_log_0001" "$full_key")"
        return 1
    fi
    
    # Hierarchie und eigentlichen Schlüssel extrahieren
    local parts=($(_parse_hierarchical_key "$full_key"))
    local hierarchy_name="${parts[0]}"
    local key_name="${parts[1]}"
    
    # Wenn die Hierarchie nicht existiert, gibt es auch keinen Wert
    if ! _hierarchy_exists "$hierarchy_name" "$db_file"; then
        debug "$(printf "$get_config_value_debug_0003" "$hierarchy_name" "$db_file")"
        log "$(printf "$get_config_value_log_0002" "$hierarchy_name" "$db_file")"
        return 1
    fi
    
    # Hierarchie-ID abrufen
    local hierarchy_id=$(_get_hierarchy_id "$hierarchy_name" "$db_file")
    
    # Wert aus der Datenbank abrufen
    local value=$(sqlite3 "$db_file" "SELECT value FROM settings WHERE hierarchy_id=$hierarchy_id AND key='$key_name' AND is_active=1;")
    
    echo "$value"
    
    # Wenn der Wert leer ist, prüfen, ob der Schlüssel wirklich existiert
    if [ -z "$value" ]; then
        has_config_value "$full_key" "$db_file"
        return $?
    else
        debug "$(printf "$get_config_value_debug_0004" "$key_name" "$hierarchy_name" "$value")"
        log "$(printf "$get_config_value_log_0003" "$key_name" "$hierarchy_name" "$value")"
        return 0
    fi
}

# set_config_value
set_config_value_debug_0001="INFO: Setze Konfigurationswert für '%s' auf '%s' (Typ: '%s', Beschreibung: '%s', Gewichtung: %d, Änderungsgruppe: '%s')."
set_config_value_debug_0002="ERROR: Ungültiger Schlüsselname: '%s'."
set_config_value_debug_0003="ERROR: Ungültiger Schlüssel: %s - keine Hierarchie angegeben."
set_config_value_debug_0004="ERROR: Fehler beim Erstellen der Hierarchie '%s'"
set_config_value_debug_0005="SUCCESS: Konfigurationswert für '%s' in der Hierarchie '%s' gesetzt: '%s'."
set_config_value_debug_0006="ERROR: Konfigurationswert für '%s' in der Hierarchie '%s' konnte nicht gesetzt werden: %s"
set_config_value_log_0001="Ungültiger Schlüsselname: '%s'."
set_config_value_log_0002="Ungültiger Schlüssel: %s - keine Hierarchie angegeben."
set_config_value_log_0003="Fehler beim Erstellen der Hierarchie '%s'."
set_config_value_log_0004="Konfigurationswert für '%s' in der Hierarchie '%s' gesetzt: '%s'."
set_config_value_log_0005="Konfigurationswert für '%s' in der Hierarchie '%s' konnte nicht gesetzt werden: %s."

set_config_value() {
    # -----------------------------------------------------------------------
    # set_config_value
    # -----------------------------------------------------------------------
    # Funktion.: Funktion schreibt einen Konfigurationswert in die Datenbank.
    # Parameter: $1 - Schlüsselname (z.B. "nginx.port")
    # .........  $2 - Zu setzender Wert
    # .........  $3 - (Optional) Datentyp (string, int, bool, float, json)
    # .........  $4 - (Optional) Beschreibung des Konfigurationsschlüssels
    # .........  $5 - (Optional) Gewichtung
    # .........  $6 - (Optional) Gruppen-ID für zusammengehörige Änderungen
    # .........  $7 - (Optional) Pfad zur Datenbank
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local full_key="$1"
    local value="$2"
    local value_type="${3:-string}"
    local description="${4:-}"
    local weight="${5:-0}"
    local change_group="${6:-}"
    local db_file="${7:-$(get_data_file)}"

    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$full_key" "full_key"; then return 1; fi
    if ! check_param "$value" "value"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$set_config_value_debug_0001" "$full_key")"

    # Schlüssel validieren
    if ! _validate_key "$full_key"; then
        debug "$(printf "$set_config_value_debug_0002" "$full_key")"
        return 1
    fi

    # Hierarchie und eigentlichen Schlüssel extrahieren
    local parts=($(_parse_hierarchical_key "$full_key"))
    local hierarchy_name="${parts[0]}"
    local key_name="${parts[1]}"

    # Wenn kein Schlüsselname vorhanden ist (z.B. nur "nginx" ohne ".port"), abbrechen
    if [ -z "$key_name" ]; then
        debug "$(printf "$set_config_value_debug_0003" "$full_key")"
        return 1
    fi

    # Wenn die Hierarchie nicht existiert, automatisch anlegen
    if ! _hierarchy_exists "$hierarchy_name" "$db_file"; then
        register_config_hierarchy "$hierarchy_name" \
                                 "Automatisch erstellte Hierarchie" \
                                 "system" \
                                 '{"auto_created":true}' \
                                 "$db_file"
        if [ $? -ne 0 ]; then
            debug "$(printf "$set_config_value_debug_0004" "$hierarchy_name")"
            return 1
        fi
    fi

    # Hierarchie-ID abrufen
    local hierarchy_id=$(_get_hierarchy_id "$hierarchy_name" "$db_file")

    # Wenn keine Change Group angegeben wurde, eine generieren
    if [ -z "$change_group" ]; then
        change_group=$(_generate_group_id "$hierarchy_name")
    fi

    # Prüfen, ob der Schlüssel bereits existiert
    local old_value=""
    local setting_id=""
    local exists=$(sqlite3 "$db_file" "SELECT id, value FROM settings WHERE hierarchy_id=$hierarchy_id AND key='$key_name';") || {
        sqlite3 "$db_file" "ROLLBACK;"
        debug "Fehler bei der Abfrage nach existierendem Schlüssel"
        return 1
    }
    debug "Existierender Schlüssel: $exists"

    if [ -n "$exists" ]; then
        # Schlüssel existiert bereits, alten Wert speichern und aktualisieren
        setting_id=$(echo "$exists" | cut -d'|' -f1)
        old_value=$(echo "$exists" | cut -d'|' -f2)
        
        # Wert aktualisieren
        sqlite3 "$db_file" "UPDATE settings SET 
                           value='$value', 
                           value_type='$value_type', 
                           description=COALESCE('$description', description), 
                           updated_at=datetime('now','localtime'), 
                           weight=$weight, 
                           change_group='$change_group'
                           WHERE id=$setting_id;" || {
            sqlite3 "$db_file" "ROLLBACK;"
            debug "Fehler beim Aktualisieren des Settings"
            return 1
        }
        debug "Schlüssel aktualisiert: ID=$setting_id, alter Wert='$old_value', neuer Wert='$value'"
        
        # Änderungshistorie speichern
        sqlite3 "$db_file" "INSERT INTO settings_history (setting_id, old_value, new_value, changed_at, changed_by, change_reason) 
                           VALUES ($setting_id, '$old_value', '$value', datetime('now','localtime'), 'script', 'API call');" || {
            sqlite3 "$db_file" "ROLLBACK;"
            debug "Fehler beim Einfügen der Änderungshistorie"
            return 1
        }
        debug "Änderungshistorie für Schlüssel '$key_name' gespeichert"

    else
        # Schlüssel existiert noch nicht, neu anlegen
        sqlite3 "$db_file" "INSERT INTO settings (hierarchy_id, key, value, value_type, description, weight, change_group, is_active) 
                           VALUES ($hierarchy_id, '$key_name', '$value', '$value_type', '$description', $weight, '$change_group', 1);" || {
            sqlite3 "$db_file" "ROLLBACK;"
            debug "Fehler beim Erstellen des neuen Settings"
            return 1
        }
        debug "Neuer Schlüssel '$key_name' in Hierarchie '$hierarchy_name' angelegt mit Wert '$value'"
        
        # Setting-ID für weitere Operationen abrufen
        setting_id=$(sqlite3 "$db_file" "SELECT last_insert_rowid();") || {
            sqlite3 "$db_file" "ROLLBACK;"
            debug "Fehler beim Abrufen der Setting-ID"
            return 1
        }
        debug "Neue Setting-ID: $setting_id"
    fi

    # Änderungsgruppe in der Datenbank registrieren
    local group_exists=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM change_groups WHERE group_name='$change_group';") || {
        sqlite3 "$db_file" "ROLLBACK;"
        debug "Fehler beim Prüfen der existierenden Änderungsgruppe"
        return 1
    }
    debug "Existierende Änderungsgruppe: $group_exists"
    
    if [ "$group_exists" -eq 0 ]; then
        # Neue Änderungsgruppe anlegen
        sqlite3 "$db_file" "INSERT INTO change_groups (group_name, description, status, priority) 
                           VALUES ('$change_group', 'Auto-generated change group', 'pending', 0);" || {
            sqlite3 "$db_file" "ROLLBACK;"
            debug "Fehler beim Erstellen der Änderungsgruppe"
            return 1
        }
    fi
    debug "Änderungsgruppe '$change_group' erfolgreich registriert"

    # Verknüpfung zwischen Setting und Änderungsgruppe herstellen
    local change_group_id=$(sqlite3 "$db_file" "SELECT id FROM change_groups WHERE group_name='$change_group';") || {
        sqlite3 "$db_file" "ROLLBACK;"
        debug "Fehler beim Abrufen der change_group_id"
        return 1
    }
    debug "Change Group ID: $change_group_id"

    local link_exists=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM settings_change_groups WHERE setting_id=$setting_id AND change_group_id=$change_group_id;") || {
        sqlite3 "$db_file" "ROLLBACK;"
        debug "Fehler beim Prüfen der Verknüpfung"
        return 1
    }
    debug "Existierende Verknüpfung: $link_exists"
    
    if [ "$link_exists" -eq 0 ]; then
        sqlite3 "$db_file" "INSERT INTO settings_change_groups (setting_id, change_group_id) 
                           VALUES ($setting_id, $change_group_id);" || {
            sqlite3 "$db_file" "ROLLBACK;"
            debug "Fehler beim Erstellen der Verknüpfung"
            return 1
        }
    fi
    debug "Verknüpfung zwischen Setting-ID $setting_id und Änderungsgruppe-ID $change_group_id erfolgreich hergestellt"

    # Prüfen, ob der Einfügevorgang erfolgreich war
    if [ $? -ne 0 ]; then
        debug "$(printf "$set_config_value_debug_0006" "$key_name" "$hierarchy_name" "$(sqlite3 "$db_file" "SELECT sqlite_error_msg();")")"
        log "$(printf "$set_config_value_log_0005" "$key_name" "$hierarchy_name" "$(sqlite3 "$db_file" "SELECT sqlite_error_msg();")")"
        return 1
    fi

    # Erfolgsmeldung ausgeben
    debug "$(printf "$set_config_value_debug_0005" "$key_name" "$hierarchy_name" "$value")"
    log "$(printf "$set_config_value_log_0004" "$key_name" "$hierarchy_name" "$value")"
    return 0
}

# del_config_value
del_config_value_debug_0001="INFO: Lösche Konfigurationswert '%s'."
del_config_value_debug_0002="ERROR: Ungültiger Schlüsselname: '%s'."
del_config_value_debug_0003="ERROR: Hierarchie '%s' existiert nicht in der Datenbank '%s'."
del_config_value_debug_0004="ERROR: Schlüssel '%s' existiert nicht in der Hierarchie '%s'."
del_config_value_debug_0005="SUCCESS: Konfigurationswert '%s' gelöscht (physisch: %s)."
del_config_value_log_0001="Ungültiger Schlüsselname: '%s'."
del_config_value_log_0002="Hierarchie '%s' existiert nicht in der Datenbank '%s'."
del_config_value_log_0003="Schlüssel '%s' existiert nicht in der Hierarchie '%s'."
del_config_value_log_0004="Konfigurationswert '%s' gelöscht (physisch: %s)."

del_config_value() {
    # -----------------------------------------------------------------------
    # del_config_value
    # -----------------------------------------------------------------------
    # Funktion.: Funktion löscht einen Konfigurationswert aus der Datenbank.
    # Parameter: $1 - Schlüsselname (z.B. "nginx.port")
    # .........  $2 - (Optional) Markierung für physisches Löschen (default: false)
    # .........  $3 - (Optional) Pfad zur Datenbank
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local full_key="$1"
    local physical_delete="${2:-false}"
    local db_file="${3:-$(get_data_file)}"
    
    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$full_key" "full_key"; then return 1; fi
    if ! check_param "$physical_delete" "physical_delete"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$del_config_value_debug_0001" "$full_key")"

    # Schlüssel validieren
    if ! _validate_key "$full_key"; then
        debug "$(printf "$del_config_value_debug_0002" "$full_key")"
        log "$(printf "$del_config_value_log_0001" "$full_key")"
        return 1
    fi
    
    # Hierarchie und eigentlichen Schlüssel extrahieren
    local parts=($(_parse_hierarchical_key "$full_key"))
    local hierarchy_name="${parts[0]}"
    local key_name="${parts[1]}"
    
    # Wenn die Hierarchie nicht existiert, gibt es nichts zu löschen
    if ! _hierarchy_exists "$hierarchy_name" "$db_file"; then
        debug "$(printf "$del_config_value_debug_0003" "$hierarchy_name" "$db_file")"
        log "$(printf "$del_config_value_log_0002" "$hierarchy_name" "$db_file")"
        return 1
    fi
    
    # Hierarchie-ID abrufen
    local hierarchy_id=$(_get_hierarchy_id "$hierarchy_name" "$db_file")
    
    # Prüfen, ob der Schlüssel existiert
    local setting_id=$(sqlite3 "$db_file" "SELECT id FROM settings WHERE hierarchy_id=$hierarchy_id AND key='$key_name';")
    if [ -z "$setting_id" ]; then
        debug "$(printf "$del_config_value_debug_0004" "$key_name" "$hierarchy_name")"
        log "$(printf "$del_config_value_log_0003" "$key_name" "$hierarchy_name")"
        return 1  # Schlüssel existiert nicht
    fi
    
    # Transaktion starten
    sqlite3 "$db_file" "BEGIN TRANSACTION;"
    
    # Je nach Löschmodus (logisch oder physisch)
    if [ "$physical_delete" = "true" ]; then
        # Physisches Löschen: Eintrag komplett aus der Datenbank entfernen
        sqlite3 "$db_file" "DELETE FROM settings WHERE id=$setting_id;"
        sqlite3 "$db_file" "DELETE FROM settings_history WHERE setting_id=$setting_id;"
        sqlite3 "$db_file" "DELETE FROM settings_change_groups WHERE setting_id=$setting_id;"
    else
        # Logisches Löschen: Eintrag nur als inaktiv markieren
        sqlite3 "$db_file" "UPDATE settings SET is_active=0, updated_at=datetime('now','localtime') WHERE id=$setting_id;"
        
        # Änderungshistorie speichern
        local old_value=$(sqlite3 "$db_file" "SELECT value FROM settings WHERE id=$setting_id;")
        sqlite3 "$db_file" "INSERT INTO settings_history (setting_id, old_value, new_value, changed_at, changed_by, change_reason) 
                           VALUES ($setting_id, '$old_value', 'DELETED', datetime('now','localtime'), 'script', 'Logical delete');"
    fi
    
    # Transaktion abschließen
    sqlite3 "$db_file" "COMMIT;"
    
    # Abschlussmeldung ausgeben
    debug "$(printf "$del_config_value_debug_0005" "$full_key" "$physical_delete")"
    log "$(printf "$del_config_value_log_0004" "$full_key" "$physical_delete")"
    return 0
}

# lst_config_values
lst_config_values_debug_0001="INFO: Liste der Konfigurationswerte mit Präfix '%s' im Format '%s' aus der Datenbank '%s'."

lst_config_values() {
    # -----------------------------------------------------------------------
    # lst_config_values
    # -----------------------------------------------------------------------
    # Funktion.: Listet alle Konfigurationswerte auf, die zu einer bestimmten 
    # .........  Hierarchie gehören.
    # Parameter: $1 - (Optional) Präfix für hierarchische Filterung
    # .........  $2 - (Optional) Format der Ausgabe (text, json)
    # .........  $3 - (Optional) Pfad zur Datenbank
    # Rückgabe.: Liste aller Schlüssel-Wert-Paare im angegebenen Format
    # -----------------------------------------------------------------------
    local prefix="${1:-}"
    local format="${2:-text}"
    local db_file="${3:-$(get_data_file)}"
    
    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$prefix" "prefix"; then return 1; fi
    if ! check_param "$format" "format"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$lst_config_values_debug_0001" "$prefix" "$format" "$db_file")"

    # Wenn ein Präfix angegeben ist, diesen bereinigen
    local where_clause=""
    local join_clause=""
    if [ -n "$prefix" ]; then
        # Hierarchie und eigentlichen Schlüssel extrahieren
        local parts=($(_parse_hierarchical_key "$prefix"))
        local hierarchy_name="${parts[0]}"
        local key_prefix="${parts[1]}"
        
        # Wenn die Hierarchie nicht existiert, leere Liste zurückgeben
        if ! _hierarchy_exists "$hierarchy_name" "$db_file"; then
            if [ "$format" = "json" ]; then
                echo "{}"
            fi
            return 0
        fi
        
        # Hierarchie-ID abrufen
        local hierarchy_id=$(_get_hierarchy_id "$hierarchy_name" "$db_file")

        # Where-Klausel für die Abfrage erstellen
        where_clause="WHERE h.id = $hierarchy_id AND s.is_active = 1"
        if [ -n "$key_prefix" ]; then
            where_clause="$where_clause AND s.key LIKE '$key_prefix%'"
        fi
    else
        # Keine Filterung, alle aktiven Einstellungen zurückgeben
        where_clause="WHERE s.is_active = 1"
    fi
    
    # Join-Klausel für die Abfrage erstellen
    join_clause="JOIN config_hierarchies h ON s.hierarchy_id = h.id"
    
    # Abfrage je nach Format ausführen
    if [ "$format" = "json" ]; then
        # JSON-Format
        sqlite3 -json "$db_file" "SELECT h.hierarchy_name || '.' || s.key AS full_key, s.value, s.value_type 
                                 FROM settings s $join_clause $where_clause;"
    else
        # Text-Format (key=value)
        sqlite3 "$db_file" "SELECT h.hierarchy_name || '.' || s.key, s.value 
                           FROM settings s $join_clause $where_clause;" | while read -r line; do
            key=$(echo "$line" | cut -d'|' -f1)
            value=$(echo "$line" | cut -d'|' -f2)
            echo "$key=$value"
        done
    fi
    
    return 0
}

# ===========================================================================
# Komplexere Operationen
# ===========================================================================

# apply_config_changes
apply_config_changes_debug_0001="INFO: Wende Änderungen der Änderungsgruppe '%s' an der Datenbank '%s' an."
apply_config_changes_debug_0002="ERROR: Änderungsgruppe '%s' existiert nicht."
apply_config_changes_debug_0003="SUCCESS: Änderungen der Änderungsgruppe '%s' erfolgreich angewendet."
apply_config_changes_log_0001="Änderungsgruppe '%s' existiert nicht."
apply_config_changes_log_0002="Änderungen der Änderungsgruppe '%s' erfolgreich angewendet."

apply_config_changes() {
    # -----------------------------------------------------------------------
    # apply_config_changes
    # -----------------------------------------------------------------------
    # Funktion.: Markiert alle Änderungen einer Gruppe als angewendet.
    # Parameter: $1 - Gruppen-ID
    # .........  $2 - (Optional) Pfad zur Datenbank
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local change_group="$1"
    local db_file="${2:-$(get_data_file)}"

    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$change_group" "change_group"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$apply_config_changes_debug_0001" "$change_group" "$db_file")"

    # Prüfen, ob die Änderungsgruppe existiert
    local group_exists=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM change_groups WHERE group_name='$change_group';")
    if [ "$group_exists" -eq 0 ]; then
        echo "Änderungsgruppe '$change_group' existiert nicht." >&2
        return 1
    fi

    # Transaktion starten
    sqlite3 "$db_file" "BEGIN TRANSACTION;"

    # Status der Änderungsgruppe auf 'complete' setzen
    sqlite3 "$db_file" "UPDATE change_groups SET status='complete', updated_at=datetime('now','localtime') WHERE group_name='$change_group';"

    # Transaktion abschließen
    sqlite3 "$db_file" "COMMIT;"

    # Prüfe ob erfolgreich
    if [ $? -ne 0 ]; then
        debug "$(printf "$apply_config_changes_debug_0002" "$change_group")"
        log "$(printf "$apply_config_changes_log_0001" "$change_group")"
        return 1
    fi

    debug "$(printf "$apply_config_changes_debug_0003" "$change_group")"
    log "$(printf "$apply_config_changes_log_0002" "$change_group")"
    return 0
}

# rollback_config_changes
rollback_config_changes_debug_0001="INFO: Setzt alle Änderungen der Änderungsgruppe '%s' zurück, Datenbank '%s'."
rollback_config_changes_debug_0002="ERROR: Änderungsgruppe '%s' existiert nicht."
rollback_config_changes_debug_0003="ERROR: Fehler beim Zurücksetzen der Änderungen der Änderungsgruppe '%s'"
rollback_config_changes_debug_0004="SUCCESS: Änderungen der Änderungsgruppe '%s' erfolgreich zurückgesetzt."
rollback_config_changes_log_0001="Änderungsgruppe '%s' existiert nicht."
rollback_config_changes_log_0002="Fehler beim Zurücksetzen der Änderungen der Änderungsgruppe '%s'"
rollback_config_changes_log_0003="Änderungen der Änderungsgruppe '%s' erfolgreich zurückgesetzt."

rollback_config_changes() {
    # -----------------------------------------------------------------------
    # rollback_config_changes
    # -----------------------------------------------------------------------
    # Funktion.: Stellt die vorherigen Werte einer Änderungsgruppe wieder her
    # Parameter: $1 - Gruppen-ID
    # .........  $2 - (Optional) Pfad zur Datenbank
    # Rückgabe.: 0 bei Erfolg, 1 bei Fehler
    # -----------------------------------------------------------------------
    local change_group="$1"
    local db_file="${2:-$(get_data_file)}"

    # Überprüfen, ob alle erforderlichen Parameter angegeben sind
    if ! check_param "$change_group" "change_group"; then return 1; fi
    if ! check_param "$db_file" "db_file"; then return 1; fi

    # Debug-Ausgabe eröffnen
    debug "$(printf "$rollback_config_changes_debug_0001" "$change_group" "$db_file")"

    # Prüfen, ob die Änderungsgruppe existiert
    local group_exists=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM change_groups WHERE group_name='$change_group';")
    if [ "$group_exists" -eq 0 ]; then
        debug "$(printf "$rollback_config_changes_debug_0002" "$change_group")"
        log "$(printf "$rollback_config_changes_log_0001" "$change_group")"
        return 1
    fi

    # Transaktion starten
    sqlite3 "$db_file" "BEGIN TRANSACTION;"

    # Change-Group-ID abrufen
    local change_group_id=$(sqlite3 "$db_file" "SELECT id FROM change_groups WHERE group_name='$change_group';")

    # Alle betroffenen Einstellungen abrufen
    local settings_result=$(sqlite3 "$db_file" "
        SELECT s.id, h.hierarchy_name, s.key, sh.old_value 
        FROM settings s
        JOIN settings_change_groups scg ON s.id = scg.setting_id
        JOIN settings_history sh ON s.id = sh.setting_id
        JOIN config_hierarchies h ON s.hierarchy_id = h.id
        WHERE scg.change_group_id = $change_group_id
        AND sh.changed_at = (
            SELECT MAX(changed_at)
            FROM settings_history
            WHERE setting_id = s.id
        );"
    )

    # Für jede Einstellung den alten Wert wiederherstellen
    echo "$settings_result" | while IFS='|' read -r setting_id hierarchy_name key old_value; do
        # Aktuellen Wert abrufen und als Historie speichern
        local current_value=$(sqlite3 "$db_file" "SELECT value FROM settings WHERE id=$setting_id;")
        
        # Alten Wert wiederherstellen
        sqlite3 "$db_file" "UPDATE settings SET value='$old_value', updated_at=datetime('now','localtime') WHERE id=$setting_id;"
        
        # Änderungshistorie speichern
        sqlite3 "$db_file" "INSERT INTO settings_history (setting_id, old_value, new_value, changed_at, changed_by, change_reason) 
                           VALUES ($setting_id, '$current_value', '$old_value', datetime('now','localtime'), 'script', 'Rollback of change group $change_group');"
    done

    # Status der Änderungsgruppe auf 'rolled-back' setzen
    sqlite3 "$db_file" "UPDATE change_groups SET status='rolled-back', updated_at=datetime('now','localtime') WHERE group_name='$change_group';"

    # Transaktion abschließen
    sqlite3 "$db_file" "COMMIT;"

    # Prüfen, ob der Rollback erfolgreich war
    if [ $? -ne 0 ]; then
        debug "$(printf "$rollback_config_changes_debug_0003" "$change_group")"
        log "$(printf "$rollback_config_changes_log_0002" "$change_group")"
        return 1
    fi

    # Erfolgsmeldung ausgeben
    debug "$(printf "$rollback_config_changes_debug_0004" "$change_group")"
    log "$(printf "$rollback_config_changes_log_0003" "$change_group")"
    return 0
}

# ===========================================================================
# TODO: Noch zu implementierende Funktionen
# ===========================================================================

# ---------------------------------------------------------------------------
# TODO: Implementiere get_config_group
# ---------------------------------------------------------------------------
# Funktion: Gibt alle Schlüssel-Wert-Paare einer Änderungsgruppe zurück
# Parameter:
#   $1 - Gruppen-ID
#   $2 - (Optional) Pfad zur Datenbank
# Rückgabe: Liste aller Schlüssel-Wert-Paare dieser Gruppe
# Returncode: 0 wenn erfolgreich, 1 bei Fehler
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# TODO: Implementiere list_registered_hierarchies
# ---------------------------------------------------------------------------
# Funktion: Listet alle registrierten Konfigurationshierarchien auf
# Parameter:
#   $1 - (Optional) Pfad zur Datenbank
# Ausgabe: Liste aller registrierten Hierarchien im Format "name|beschreibung|verantwortlicher"
# Returncode: 0 wenn erfolgreich, 1 bei Fehler
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# TODO: Implementiere validate_hierarchy_path
# ---------------------------------------------------------------------------
# Funktion: Validiert einen Hierarchiepfad gegen registrierte Hierarchien
# Parameter:
#   $1 - Hierarchiepfad (z.B. "nginx.ssl")
#   $2 - (Optional) Pfad zur Datenbank
# Returncode: 0 wenn gültig, 1 wenn ungültig
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# TODO: Implementiere initialize_default_hierarchies
# ---------------------------------------------------------------------------
# Funktion: Registriert die Standard-Hierarchien für das System
# Parameter:
#   $1 - (Optional) Pfad zur Datenbank
# Returncode: 0 wenn erfolgreich, 1 bei Fehler
# ---------------------------------------------------------------------------
