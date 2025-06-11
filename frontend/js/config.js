// config.js
// Enthält alle Funktionen und Event-Handler, die ausschließlich für die Konfigurationsseite (config.html) benötigt werden.

// Diese Datei wurde deaktiviert, da sie in settings.html nicht benötigt wird,
// aber möglicherweise von anderen Seiten verwendet wird.
// Alle Funktionalitäten wurden entfernt, um Fehler zu vermeiden.
// Die ursprüngliche Funktionalität war:

/*
// Overlay für Passwort-Login erzeugen
if (document.getElementById('loginForm')) {
    let pwOverlay = document.getElementById('pwLoginOverlay');
    if (!pwOverlay) {
        pwOverlay = document.createElement('div');
        pwOverlay.id = 'pwLoginOverlay';
        pwOverlay.style.position = 'fixed';
        pwOverlay.style.top = '0';
        pwOverlay.style.left = '0';
        pwOverlay.style.width = '100vw';
        pwOverlay.style.height = '100vh';
        pwOverlay.style.background = 'rgba(0,0,0,0.5)';
        pwOverlay.style.display = 'flex';
        pwOverlay.style.alignItems = 'center';
        pwOverlay.style.justifyContent = 'center';
        pwOverlay.style.zIndex = '9999';
        pwOverlay.innerHTML = `
        <form id="pwLoginForm" style="background:#fff;padding:2.5em 2.5em 2em 2.5em;min-width:320px;max-width:90vw;border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,0.25);position:relative;display:flex;flex-direction:column;align-items:center;">
            <h2 style="margin-top:0;margin-bottom:1.5em;">Einstellungen Login</h2>
            <label style="width:100%;margin-bottom:1em;font-size:1.1em;">Passwort:<br>
                <input type="password" id="adminPasswordOverlay" style="width:100%;padding:0.5em;font-size:1.1em;margin-top:0.5em;border-radius:8px;border:1px solid #bbb;" required autocomplete="current-password">
            </label>
            <div style="font-size:0.95em;color:#666;margin-bottom:1em;">Hinweis: Passwort muss mindestens 4 Zeichen lang sein.</div>
            <div style="display:flex;gap:1em;width:100%;justify-content:space-between;">
                <button type="submit" style="flex:1;padding:0.7em;font-size:1.1em;border-radius:8px;background:#0078d7;color:#fff;border:none;cursor:pointer;">Login</button>
                <button type="button" id="pwLoginCancelBtn" style="flex:1;padding:0.7em;font-size:1.1em;border-radius:8px;background:#aaa;color:#222;border:none;cursor:pointer;">Abbrechen</button>
            </div>
            <span id="loginStatusOverlay" style="color:#c00;margin-top:1em;min-height:1.5em;display:block;"></span>
        </form>`;
        document.body.appendChild(pwOverlay);
        pwOverlay.addEventListener('mousedown', function(e) {
            if (e.target === pwOverlay) {
                pwOverlay.style.display = 'none';
                document.getElementById('loginForm').style.display = '';
            }
        });
        document.addEventListener('keydown', function escHandler(e) {
            if (pwOverlay.style.display !== 'none' && e.key === 'Escape') {
                pwOverlay.style.display = 'none';
                document.getElementById('loginForm').style.display = '';
            }
        });
        document.getElementById('pwLoginCancelBtn').onclick = function() {
            pwOverlay.style.display = 'none';
            document.getElementById('loginForm').style.display = '';
        };
    } else {
        pwOverlay.style.display = 'flex';
    }
    document.getElementById('loginForm').style.display = 'none';
    document.getElementById('pwLoginForm').onsubmit = async function(e) {
        e.preventDefault();
        const pw = document.getElementById('adminPasswordOverlay').value;
        if(pw.length < 4) {
            document.getElementById('loginStatusOverlay').textContent = 'Passwort zu kurz! (mind. 4 Zeichen)';
            return;
        }
        const res = await fetch('/api/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ password: pw })
        });
        if(res.ok) {
            const data = await res.json();
            if(data.success) {                pwOverlay.classList.add('hidden');
                document.getElementById('configForm').classList.add('form-visible');
                document.getElementById('updateForm').classList.add('form-visible');
                loadConfigFromServer();
                loadNginxConfig();
            } else {
                document.getElementById('loginStatusOverlay').textContent = 'Falsches Passwort!';
            }
        } else {
            document.getElementById('loginStatusOverlay').textContent = 'Fehler bei der Anmeldung!';
        }
    };
    setTimeout(()=>{
        document.getElementById('adminPasswordOverlay').focus();
    }, 100);
    function loadConfigFromServer() {
        fetch('/api/settings').then(r=>r.json()).then(config => {
            if(config.camera_mode) document.getElementById('camera_mode').value = config.camera_mode;
            if(config.resolution_width) document.getElementById('resolution_width').value = config.resolution_width;
            if(config.resolution_height) document.getElementById('resolution_height').value = config.resolution_height;
            if(config.storage_path) document.getElementById('storage_path').value = config.storage_path;
            if(config.event_name) document.getElementById('event_name').value = config.event_name;
            if(config.gallery_timeout_ms) document.getElementById('gallery_timeout').value = Math.round(config.gallery_timeout_ms/1000);
            if(config.photo_timer) document.getElementById('photo_timer').value = config.photo_timer;
            if(document.getElementById('admin_password')) document.getElementById('admin_password').value = '';
        });
    }
    document.getElementById('configForm').onsubmit = function(e) {
        e.preventDefault();
        const config = {
            camera_mode: document.getElementById('camera_mode').value,
            resolution_width: document.getElementById('resolution_width').value,
            resolution_height: document.getElementById('resolution_height').value,
            storage_path: document.getElementById('storage_path').value,
            event_name: document.getElementById('event_name').value,
            gallery_timeout_ms: parseInt(document.getElementById('gallery_timeout').value,10)*1000||60000
        };
        const newPass = document.getElementById('admin_password')?.value;
        if(newPass && newPass.length >= 4) config.admin_password = newPass;
        if(newPass && newPass.length > 0 && newPass.length < 4) {
            document.getElementById('status').textContent = 'Passwort zu kurz! (mind. 4 Zeichen)';
            setTimeout(()=>document.getElementById('status').textContent='', 2500);
            return;
        }
        fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        }).then(()=>{
            document.getElementById('status').textContent = 'Gespeichert!';
            setTimeout(()=>document.getElementById('status').textContent='', 1500);
            if(newPass) document.getElementById('admin_password').value = '';
        });
    };
    document.getElementById('updateForm').onsubmit = function(e) {
        e.preventDefault();
        document.getElementById('updateStatus').textContent = 'Update läuft ...';
        fetch('/update', { method: 'POST' })
            .then(r => r.text())
            .then(txt => {
                document.getElementById('updateStatus').textContent = txt || 'Update/Backup abgeschlossen.';
            })
            .catch(()=>{
                document.getElementById('updateStatus').textContent = 'Fehler beim Update/Backup!';
            });
    };
    function loadNginxConfig() {
        const section = document.getElementById('nginxConfigSection');
        const info = document.getElementById('nginxConfigInfo');
        if(!section || !info) return;
        section.style.display = 'block';
        info.textContent = 'Lade Webserver-Konfiguration ...';
        fetch('/api/nginx_status')
            .then(r => r.json())
            .then(cfg => {
                if(cfg.error) {
                    info.innerHTML = '<span style="color:red">Fehler: '+(cfg.details||cfg.error)+'</span>';
                } else {
                    info.innerHTML =
                        `<b>Typ:</b> ${cfg.config_type}<br>`+
                        `<b>Bind-Adresse:</b> ${cfg.bind_address}<br>`+
                        `<b>Port:</b> ${cfg.port}<br>`+
                        `<b>Servername:</b> ${cfg.server_name}<br>`+
                        `<b>Webroot:</b> ${cfg.webroot_path}<br>`+
                        `<b>URL:</b> <a href="${cfg.url}" target="_blank">${cfg.url}</a><br>`+
                        `<b>Erreichbar:</b> ${cfg.reachable ? 'Ja' : 'Nein'}`;
                }
            })
            .catch(e => {
                info.innerHTML = '<span style="color:red">Fehler beim Laden der Webserver-Konfiguration.</span>';
            });
    }
}

// Autosave für Konfigurationsseite
function showAutosaveToast(msg, success=true) {
    const toast = document.getElementById('autosaveToast');
    toast.textContent = msg;
    toast.className = success ? 'success' : 'error';
    toast.style.display = 'block';
    clearTimeout(window._autosaveToastTimeout);
    window._autosaveToastTimeout = setTimeout(() => {
        toast.style.display = 'none';
    }, 7000);
}

function autosaveConfigField(field, label) {
    field.addEventListener('change', function() {
        const config = {};
        if(field.name === 'photo_timer') {
            let val = parseInt(field.value, 10);
            if(isNaN(val) || val < 2 || val > 10) {
                showAutosaveToast('Timer muss zwischen 2 und 10 Sekunden liegen!', false);
                field.value = 5;
                return;
            }
            config['photo_timer'] = val;
        } else {
            config[field.name] = (field.type === 'number') ? parseInt(field.value, 10) : field.value;
            if(field.name === 'gallery_timeout') config['gallery_timeout_ms'] = config['gallery_timeout']*1000;
        }
        fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        }).then(r => {
            if(r.ok) {
                showAutosaveToast(label + ' angepasst ...', true);
            } else {
                showAutosaveToast(label + ' konnte nicht gespeichert werden!', false);
            }
        }).catch(() => {
            showAutosaveToast(label + ' konnte nicht gespeichert werden!', false);
        });
    });
}

if(document.getElementById('configForm')) {
    const fields = [
        {id:'color_mode', label:'Farbschema'},
        {id:'gallery_timeout', label:'Galerie-Timeout'},
        {id:'event_name', label:'Eventname'},
        {id:'storage_path', label:'Speicherpfad'},
        {id:'camera_mode', label:'Kamera-Modus'},
        {id:'photo_timer', label:'Foto-Timer'}
    ];
    fields.forEach(f => {
        const el = document.getElementById(f.id);
        if(el) autosaveConfigField(el, f.label);
    });
    const resW = document.getElementById('resolution_width');
    const resH = document.getElementById('resolution_height');
    if(resW && resH) {
        [resW, resH].forEach(field => {
            field.addEventListener('change', function() {
                const config = {
                    resolution_width: parseInt(resW.value, 10) || '',
                    resolution_height: parseInt(resH.value, 10) || ''
                };
                fetch('/api/settings', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(config)
                }).then(function(r) {
                    if(r.ok) {
                        showAutosaveToast('Foto-Auflösung angepasst ...', true);
                    } else {
                        showAutosaveToast('Foto-Auflösung konnte nicht gespeichert werden!', false);
                    }
                }).catch(function() {
                    showAutosaveToast('Foto-Auflösung konnte nicht gespeichert werden!', false);
                });
            });
        });
    }
}
