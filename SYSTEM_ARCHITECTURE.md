# System-Architektur Dokumentation

## ��️ Gesamtarchitektur (AKTUELL - 01.08.2025)

```
Flutter App → HTTPS/WSS → Apache → .htaccess → Node.js-Proxy (Port 8080) → Gunicorn (Port 8000) → FastAPI → MariaDB
```

## 🖥️ Hardware & Server

### Server-Konfiguration
- **Betriebssystem:** Linux (Strato Managed Server)
- **Webserver:** Apache HTTP Server
- **SSL/TLS:** HTTPS über Apache
- **Python-Server:** Gunicorn mit Uvicorn Workers
- **Datenbank:** MariaDB
- **Proxy:** Node.js Combined-Proxy (HTTP + WebSocket)

### Ports & Services
- **Apache:** Port 443 (HTTPS), Port 80 (HTTP)
- **Gunicorn:** Port 8000 (lokal, 127.0.0.1)
- **Node.js-Proxy:** Port 8080 (öffentlich erreichbar)
- **MariaDB:** Standard-Port (lokal)

### Apache-Module (Bestätigt)
- **rewrite_module:** ✅ Geladen
- **proxy_module:** ✅ Geladen  
- **proxy_http_module:** ✅ Geladen
- **proxy_wstunnel_module:** ✅ Geladen (für WebSocket-Tunneling)
- **proxy_http2_module:** ✅ Geladen

## 📁 Dateistruktur

### Frontend (Flutter)
```
lib/
├── main.dart                    # App-Einstiegspunkt
├── api_service.dart             # HTTP/WebSocket API-Kommunikation
├── login_page.dart              # Login-Formular
├── register_page.dart           # Registrierung
├── notes_home_page.dart         # Hauptseite
├── notes_overview_page.dart     # Notizen-Übersicht
├── grouped_notes_page.dart      # Gruppierte Notizen
├── crm_overview_page.dart       # CRM-Übersicht
├── crm_entry_edit_form.dart     # CRM-Bearbeitung
├── statistik_page.dart          # Statistiken
├── form_page.dart               # Allgemeine Formulare
├── note.dart                    # Notiz-Model
├── crm_entry.dart               # CRM-Eintrag-Model
├── note_model.dart              # Notiz-Datenmodelle
└── [weitere UI-Komponenten]
```

### Backend (FastAPI)
```
backend/
├── main.py                      # FastAPI-Hauptanwendung
├── database.py                  # SQLAlchemy DB-Konfiguration
├── models.py                    # SQLAlchemy Modelle
├── schemas.py                   # Pydantic Schemas
├── crud.py                      # CRUD-Operationen
├── auth.py                      # JWT-Authentifizierung
├── grouping.py                  # Notizen-Gruppierung
├── combined-proxy.js            # Node.js HTTP/WebSocket-Proxy (AKTUELL)
├── start-node-proxy.sh          # Start-Skript für Node.js-Proxy
├── stop-node-proxy.sh           # Stop-Skript für Node.js-Proxy
├── package.json                 # Node.js Dependencies
└── [weitere Backend-Module]
```

### Server-Konfiguration
```
/
├── .htaccess                    # Apache Rewrite-Regeln & Basic Auth (AKTUELL)
├── .htpasswd                    # Basic Auth Passwörter
└── [weitere Server-Dateien]
```

## 🔄 Datenfluss (AKTUELL)

### 1. HTTP-API-Anfragen
```
Flutter App → HTTPS → Apache → .htaccess → Node.js-Proxy (Port 8080) → Gunicorn (Port 8000) → FastAPI → MariaDB
```

### 2. WebSocket-Verbindungen
```
Flutter App → WSS → Apache → .htaccess → Node.js-Proxy (Port 8080) → Gunicorn (Port 8000) → FastAPI
```

### 3. Authentifizierung
```
Login → JWT Token → Alle nachfolgenden Anfragen mit Token
```

## 🔧 Konfigurationsdateien

### .htaccess (Apache) - AKTUELL
```apache
RewriteEngine On

# CORS-Headers für HTTPS
Header always set Access-Control-Allow-Origin "https://iqmedix.cloud"
Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
Header always set Access-Control-Allow-Headers "Content-Type, Authorization, Upgrade, Connection, Sec-WebSocket-Key, Sec-WebSocket-Version, Sec-WebSocket-Protocol, Origin"
Header always set Access-Control-Allow-Credentials "true"

# WebSocket-Upgrade Headers für OPTIONS requests
RewriteCond %{REQUEST_METHOD} OPTIONS
RewriteRule ^(.*)$ $1 [R=200,L]

# API-Requests zu Node.js-Proxy weiterleiten
RewriteRule ^api/(.*) http://localhost:8080/api/$1 [P,L]

# WebSocket-Requests direkt zu FastAPI weiterleiten (Port 8000)
RewriteRule ^ws/(.*) http://localhost:8000/ws/$1 [P,L]

# Basic Auth für alle Seiten außer APIs und App-Seite
<FilesMatch "^(?!.*(api|ws|app)).*$">
    AuthType Basic
    AuthName "Geschützter Bereich"
    AuthUserFile /pages/d0/aa/d0017222/home/.htpasswd
    Require valid-user
</FilesMatch>

# Ausnahmen für API-Endpunkte
<FilesMatch "^(api|ws)">
    Satisfy Any
    Allow from all
</FilesMatch>

# Ausnahme für App-Seite (falls vorhanden)
<FilesMatch "app">
    Satisfy Any
    Allow from all
</FilesMatch>

# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
```

### Node.js Combined-Proxy (combined-proxy.js) - AKTUELL
```javascript
// Proxy-Konfiguration für HTTP-API
const apiProxy = httpProxy.createProxyServer({
  target: 'http://localhost:8000', // FastAPI Backend
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000
});

// Proxy-Konfiguration für WebSocket
const wsProxy = httpProxy.createProxyServer({
  target: 'ws://localhost:8000', // FastAPI Backend
  ws: true,
  changeOrigin: true
});
```

### FastAPI Endpunkte (main.py)
```python
# HTTP-APIs
@app.post("/api/token")                    # Login
@app.get("/api/notes/")                    # Notizen abrufen
@app.post("/api/notes/")                   # Notiz erstellen
@app.put("/api/notes/{note_id}")           # Notiz bearbeiten
@app.delete("/api/notes/{note_id}")        # Notiz löschen
@app.get("/api/notes/grouped")             # Gruppierte Notizen
@app.get("/api/crm/")                      # CRM-Einträge abrufen
@app.post("/api/crm/")                     # CRM-Eintrag erstellen
@app.put("/api/crm/{entry_id}")            # CRM-Eintrag bearbeiten
@app.delete("/api/crm/{entry_id}")         # CRM-Eintrag löschen

# WebSocket-Endpunkte
@app.websocket("/ws/notes")                # Notizen-WebSocket
@app.websocket("/ws/crm")                  # CRM-WebSocket
```

## 🔐 Authentifizierung

### JWT-Token-Flow
1. **Login:** `POST /api/token` → JWT-Token
2. **API-Calls:** `Authorization: Bearer <token>`
3. **WebSocket:** Token als URL-Parameter `?token=<jwt>`

### Basic Auth
- **Zweck:** Apache-Level-Schutz für nicht-API-Seiten
- **Datei:** `.htpasswd`
- **Ausnahmen:** API-Endpunkte und WebSocket-Pfade

## 🌐 Netzwerk-Konfiguration

### Externe URLs (AKTUELL)
- **Domain:** `iqmedix.cloud`
- **HTTPS:** `https://iqmedix.cloud`
- **HTTP API:** `http://iqmedix.cloud:8080/api/*`
- **WebSocket:** `ws://iqmedix.cloud:8080/ws/notes` oder `ws://iqmedix.cloud:8080/ws/crm`

### Port-Erreichbarkeit (Bestätigt)
- **Port 8080:** ✅ Öffentlich erreichbar (getestet mit `nc -zv iqmedix.cloud 8080`)
- **Port 443:** ✅ HTTPS funktioniert
- **Port 80:** ✅ HTTP funktioniert
- **Port 8000:** ❌ Nur lokal erreichbar (Gunicorn)

### Interne Verbindungen
- **Apache → Node.js-Proxy:** `localhost:8080`
- **Node.js-Proxy → Gunicorn:** `localhost:8000`
- **Apache → Gunicorn:** `localhost:8000` (direkt für WebSockets)

## 🐛 Aktuelle Probleme

### WebSocket-Verbindung
- **Status:** ✅ GELÖST - WebSockets gehen über Node.js-Proxy
- **Lösung:** Node.js-Proxy leitet WebSocket-Upgrades korrekt weiter
- **Konfiguration:** `combined-proxy.js` mit `ws: true` Option

### Apache-Konfiguration
- **Status:** ✅ FUNKTIONIERT - .htaccess leitet korrekt weiter
- **HTTP API:** Funktioniert über Node.js-Proxy
- **WebSocket:** Funktioniert über Node.js-Proxy

### Bekannte Issues
1. ~~PHP-Proxy sendet HTTP-Upgrade-Anfrage an Gunicorn~~ → GELÖST
2. ~~Gunicorn erwartet möglicherweise andere Art von WebSocket-Handshake~~ → GELÖST  
3. ~~Token-Validierung zwischen PHP-Proxy und FastAPI~~ → GELÖST
4. ~~Apache leitet WebSocket-Requests nicht an Node.js-Proxy weiter~~ → GELÖST

## 🔍 Debugging-Tools

### Log-Dateien
- **Apache-Errors:** `/var/log/apache2/error.log`
- **Apache-Access:** `/var/log/apache2/access.log`
- **Gunicorn-Logs:** `gunicorn.log`
- **Node.js-Proxy-Logs:** `combined-proxy.log`

### Test-Befehle
```bash
# Gunicorn-Status prüfen
ps aux | grep gunicorn

# Port 8000 prüfen
ss -tlnp | grep 8000

# Node.js-Proxy-Status prüfen
ps aux | grep combined-proxy

# Port 8080 prüfen
ss -tlnp | grep 8080

# Apache-Module prüfen
apachectl -M | grep -E "(proxy|rewrite)"

# Port-Erreichbarkeit testen
nc -zv iqmedix.cloud 8080

# WebSocket-Test
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" http://iqmedix.cloud:8080/ws/notes

# Node.js-Proxy-Logs
tail -f combined-proxy.log
```

## 🚀 Deployment

### Gunicorn-Start
```bash
nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &
```

### Node.js-Proxy-Start
```bash
cd backend
npm install
./start-node-proxy.sh
```

### Apache-Konfiguration
- **SSL-Zertifikat:** Für `iqmedix.cloud`
- **Proxy-Module:** `mod_proxy`, `mod_proxy_http`
- **Rewrite-Module:** `mod_rewrite`
- **Headers-Module:** `mod_headers`

## 📊 Monitoring

### Zu überwachende Metriken
- **Gunicorn-Prozesse:** Anzahl, Memory, CPU
- **Node.js-Proxy:** Memory, CPU, aktive Verbindungen
- **Apache-Connections:** Aktive Verbindungen
- **WebSocket-Verbindungen:** Anzahl aktiver Clients
- **API-Response-Times:** Durchschnittliche Antwortzeiten
- **Error-Rates:** 401, 500, WebSocket-Fehler

### Alerts
- Gunicorn-Prozess gestorben
- Node.js-Proxy-Prozess gestorben
- WebSocket-Verbindungen schlagen fehl
- API-Response-Times > 2 Sekunden
- Error-Rate > 5%

---

## ✅ Aktuelle Lösung (Stand: 01.08.2025)

### Rahmenbedingungen
- **Server:** Strato Managed Server
- **Admin-Zugriff:** _nicht_ vorhanden (kein root, keine Apache-Modulinstallation)
- **Webserver:** Apache (nur .htaccess editierbar)
- **Backend:** Gunicorn/Uvicorn (FastAPI) auf Port 8000
- **HTTP-API-Proxy:** Node.js (`combined-proxy.js`) - **AKTUELLE LÖSUNG!**
- **WebSocket-Proxy:** Node.js (`combined-proxy.js`) - **AKTUELLE LÖSUNG!**

### Aktueller Stand
- **HTTP-API:** ✅ Funktioniert stabil über Node.js-Proxy
- **WebSocket:** ✅ Funktioniert über Node.js-Proxy
- **Architektur:** Vereinfacht - Ein Proxy für alles
- **Flutter-App:** Verbindet sich mit `ws://iqmedix.cloud:8080/ws/notes?...`

### Technische Lösung
- **Node.js als kombinierter Proxy:**
  - Läuft als dauerhafter Prozess auf Strato
  - Kann echte WebSocket-Upgrades und bidirektionale Streams handeln
  - Leitet alle `/api/` und `/ws/` Anfragen an `localhost:8000` weiter
- **Konfiguration:**
  - `combined-proxy.js` läuft auf Port 8080
  - `package.json` mit `http-proxy` Abhängigkeit
  - Umfangreiches Logging für Debugging integriert

### Deployment-Schritte
1. **Node.js-App bei Strato starten:**
   - Im Strato-Panel: Node.js-Anwendung erstellen
   - Startdatei: `combined-proxy.js`
   - Port: 8080 (oder Strato-vorgegeben)
   - Dependencies: `npm install` ausführen

2. **Flutter-App konfiguriert:**
   - HTTP API: `http://iqmedix.cloud:8080/api/*`
   - WebSocket-URL: `ws://iqmedix.cloud:8080/ws/notes?...`
   - CRM-WebSocket-URL: `ws://iqmedix.cloud:8080/ws/crm?...`

3. **Testen:**
   - Mit curl: `curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" http://iqmedix.cloud:8080/ws/notes?token=test`
   - In Flutter-App: WebSocket-Verbindung funktioniert

### Status
- **HTTP-API-Verbindungen:** ✅ Funktioniert über Node.js-Proxy!
- **WebSocket-Verbindungen:** ✅ Funktioniert über Node.js-Proxy!
- **Architektur:** ✅ Vereinfacht und stabil!
- **Node.js-Proxy:** ✅ Beste Lösung für kombinierte HTTP/WebSocket-Proxying auf Managed Servern ohne Admin-Rechte. 