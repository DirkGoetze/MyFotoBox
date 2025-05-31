#!/bin/bash

# Interaktive Auswahl, falls kein Parameter übergeben wurde
if [ -z "$1" ]; then
    echo "Welche Funktion soll getestet werden?"
    select opt in "--install" "--update" "--remove"; do
        case $opt in
            --install|--update|--remove)
                set -- "$opt"
                break
                ;;
            *)
                echo "Bitte eine gültige Option wählen."
                ;;
        esac
    done
fi

# Bei --install: Abfrage, ob alte Projektbestandteile entfernt werden sollen
if [ "$1" = "--install" ]; then
    echo "Alte Projektbestandteile entfernen? (j/n)"
    read -p "Antwort: " REMOVE_OLD
    if [[ "$REMOVE_OLD" =~ ^[JjYy]$ ]]; then
        echo "Alte Projektbestandteile werden entfernt ..."
        rm -rf /opt/fotobox
        rm -f /etc/nginx/sites-available/fotobox /etc/nginx/sites-enabled/fotobox
        rm -f /etc/systemd/system/fotobox-backend.service
        deluser --quiet --remove-home fotoboxuser 2>/dev/null
        delgroup --quiet fotoboxgroup 2>/dev/null
        # ggf. weitere Aufräumarbeiten
    else
        echo "Alte Projektbestandteile bleiben erhalten."
    fi
fi

wget https://raw.githubusercontent.com/DirkGoetze/fotobox2/main/fotobox.sh
sleep 2
sudo chmod +x fotobox.sh
sleep 2
clear
sudo ./fotobox.sh $opt
