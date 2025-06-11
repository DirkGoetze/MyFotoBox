// ------------------------------------------------------------------------------
// config.js (leere Version)
// ------------------------------------------------------------------------------
// Diese Datei wurde geleert, um Fehler zu vermeiden, da sie in settings.html
// nicht mehr benötigt wird, aber möglicherweise noch durch das Anti-Cache-System
// geladen wird.
// ------------------------------------------------------------------------------

// Keine Funktionalität - alle relevanten Funktionen wurden in settings.js verschoben
console.log('Hinweis: config.js wurde geleert, da sie in settings.html nicht mehr benötigt wird');

// Schutz vor TypeError durch Überprüfung der DOM-Elemente
if (document.getElementById('updateForm')) {
    document.getElementById('updateForm').onsubmit = function(e) {
        e.preventDefault();
        console.log('Update-Formular für config.html, nicht für settings.html.');
    };
}

// Diese Datei sollte in zukünftigen Versionen entfernt werden, sobald das Caching-Problem behoben ist.
