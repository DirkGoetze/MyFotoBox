# Fotospeicherstruktur für Events (Frontend)
#
# - Für jedes Event wird ein eigener Unterordner im Originalfoto-Ordner angelegt.
# - Originalfotos:      /frontend/photos/originals/<eventname>/
# - Galerieansichten:   /frontend/photos/gallery/<eventname>/
#
# - Beim Anlegen eines neuen Events wird der Galerie-Ordner für das Event geleert.
# - Galerie-Bilder werden in platzsparendem, bildschirmoptimiertem Format (z.B. JPEG/WebP, max. 1920x1080) gespeichert.
# - Die Anzeige der Galerie erfolgt eventbasiert und bildschirmoptimiert.
#
# - Die Ordnerstruktur wird vom Backend beim Anlegen eines Events automatisch erzeugt und verwaltet.
#
# - Siehe BACKUP_STRATEGIE.md: Auch diese Ordner und Inhalte sind in die Backup-Logik einzubeziehen.
