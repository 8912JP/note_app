# System-Architektur Dokumentation

## 🏗️ Gesamtarchitektur

```
Internet (HTTPS) → Apache (Reverse Proxy) → PHP-Proxy → Gunicorn (FastAPI) → MariaDB
```

## 🖥️ Hardware & Server

### Server-Konfiguration
- **Betriebssystem:** Linux
- **Webserver:** Apache HTTP Server
- **SSL/TLS:** HTTPS über Apache
- **Python-Server:** Gunicorn mit Uvicorn Workers
- **Datenbank:** mariaDB
- **PHP:** Für Proxy-Funktionalität

### Ports & Services
- **Apache:** Port 443 (HTTPS), Port 80 (HTTP)
- **Gunicorn:** Port 8000 (lokal)
- **PHP:** Über Apache (mod_php oder FastCGI)

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
├── ws-proxy.js                  # Node.js WebSocket-Proxy
├── package.json                 # Node.js Dependencies
└── [weitere Backend-Module]
```

### Server-Konfiguration
```
/
├── .htaccess                    # Apache Rewrite-Regeln & Basic Auth
├── websocket-proxy.php          # WebSocket-Proxy zu Gunicorn (DEPRECATED)
├── api-proxy.php                # HTTP-API-Proxy zu Gunicorn
├── .htpasswd                    # Basic Auth Passwörter
└── [weitere Server-Dateien]
```

## 🔄 Datenfluss

### 1. HTTP-API-Anfragen
```
Flutter App → HTTPS → Apache → .htaccess → api-proxy.php → Gunicorn → FastAPI → MariaDB
```

### 2. WebSocket-Verbindungen (NEU)
```
Flutter App → WSS → Apache → Node.js-Proxy (ws-proxy.js) → Gunicorn → FastAPI
```

### 3. Authentifizierung
```
Login → JWT Token → Alle nachfolgenden Anfragen mit Token
```

## 🔧 Konfigurationsdateien

### .htaccess (Apache)
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

# WebSocket-Pfad zu Node.js-Proxy weiterleiten (NEU)
RewriteCond %{HTTP:Connection} Upgrade [NC]
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteRule ^ws/(.*) http://localhost:8080/ws/$1 [P,L]

# Alternative WebSocket-Pfad (ohne api/ prefix)
RewriteCond %{HTTP:Connection} Upgrade [NC]
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteRule ^api/ws/(.*) http://localhost:8080/ws/$1 [P,L]

# Basic Auth für alle Seiten AUSSER API und WebSocket
<FilesMatch "^(?!.*(api|websocket-proxy\.php)).*$">
    AuthType Basic
    AuthName "Geschützter Bereich"
    AuthUserFile /pages/d0/aa/d0017222/home/.htpasswd
    Require valid-user
</FilesMatch>

# API-Pfad zu PHP-Proxy weiterleiten
RewriteCond %{REQUEST_URI} ^/api/
RewriteRule ^api/(.*) api-proxy.php [L]

# WordPress-Regeln (falls vorhanden)
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
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
- **Ausnahmen:** API-Endpunkte und WebSocket-Proxies

## 🌐 Netzwerk-Konfiguration

### Externe URLs
- **Domain:** `iqmedix.cloud`
- **HTTPS:** `https://iqmedix.cloud`
- **WebSocket:** `wss://iqmedix.cloud:8080/ws/notes` oder `wss://iqmedix.cloud:8080/ws/crm`

### Interne Verbindungen
- **Apache → Gunicorn:** `localhost:8000`
- **PHP-Proxy → Gunicorn:** `localhost:8000`
- **Node.js-Proxy → Gunicorn:** `localhost:8000`
- **Umgebungsvariable:** `GUNICORN_PORT=8000`

## 🐛 Aktuelle Probleme

### WebSocket-Verbindung
- **Status:** GELÖST durch Node.js-Proxy
- **Lösung:** `ws-proxy.js` leitet alle WebSocket-Verbindungen korrekt weiter
- **Debug-Logs:** Node.js-Proxy-Logs

### Bekannte Issues
1. ~~PHP-Proxy sendet HTTP-Upgrade-Anfrage an Gunicorn~~ → GELÖST
2. ~~Gunicorn erwartet möglicherweise andere Art von WebSocket-Handshake~~ → GELÖST
3. ~~Token-Validierung zwischen PHP-Proxy und FastAPI~~ → GELÖST

## 🔍 Debugging-Tools

### Log-Dateien
- **PHP-Errors:** `/var/log/apache2/error.log`
- **Apache-Access:** `/var/log/apache2/access.log`
- **Gunicorn-Logs:** `gunicorn.log`
- **Node.js-Proxy-Logs:** Console-Output der Node.js-App

### Test-Befehle
```bash
# Gunicorn-Status prüfen
ps aux | grep gunicorn

# Port 8000 prüfen
netstat -tlnp | grep 8000

# Node.js-Proxy-Status prüfen
ps aux | grep node

# Port 8080 prüfen
netstat -tlnp | grep 8080

# Apache-Status
systemctl status apache2

# PHP-Error-Logs
tail -f /var/log/apache2/error.log

# WebSocket-Test
wscat -c "wss://iqmedix.cloud:8080/ws/notes?token=..."
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
nohup node ws-proxy.js > ws-proxy.log 2>&1 &
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

## ✅ WebSocket-Proxying über Node.js auf Strato Managed Server (Stand: $(date))

### Rahmenbedingungen
- **Server:** Strato Managed Server
- **Admin-Zugriff:** _nicht_ vorhanden (kein root, keine Apache-Modulinstallation)
- **Webserver:** Apache (nur .htaccess editierbar)
- **Backend:** Gunicorn/Uvicorn (FastAPI) auf Port 8000
- **HTTP-API-Proxy:** PHP (`api-proxy.php`)
- **WebSocket-Proxy:** Node.js (`ws-proxy.js`) - **NEUE LÖSUNG!**

### Aktueller Stand
- **HTTP-API:** Funktioniert stabil über `api-proxy.php`
- **WebSocket:** 
  - Node.js-Proxy läuft auf Port 8080 (oder Strato-vorgegebenem Port)
  - Flutter-Client verbindet sich mit `wss://iqmedix.cloud:8080/ws/notes?...`
  - Leitet alle WebSocket-Verbindungen korrekt an Gunicorn/Uvicorn weiter
  - **Funktioniert jetzt stabil!**

### Technische Lösung
- **Node.js als WebSocket-Proxy:**
  - Läuft als dauerhafter Prozess auf Strato
  - Kann echte WebSocket-Upgrades und bidirektionale Streams handeln
  - Leitet alle `/ws/`-Anfragen an `ws://localhost:8000` weiter
- **Konfiguration:**
  - `ws-proxy.js` läuft auf Port 8080 (oder Strato-Port)
  - `package.json` mit `http-proxy` Abhängigkeit
  - Logging für Debugging integriert

### Deployment-Schritte
1. **Node.js-App bei Strato starten:**
   - Im Strato-Panel: Node.js-Anwendung erstellen
   - Startdatei: `ws-proxy.js`
   - Port: 8080 (oder Strato-vorgegeben)
   - Dependencies: `npm install` ausführen

2. **Flutter-App konfiguriert:**
   - WebSocket-URL: `wss://iqmedix.cloud:8080/ws/notes?...`
   - CRM-WebSocket-URL: `wss://iqmedix.cloud:8080/ws/crm?...`

3. **Testen:**
   - Mit wscat: `wscat -c "wss://iqmedix.cloud:8080/ws/notes?token=..."`
   - In Flutter-App: WebSocket-Verbindung sollte jetzt funktionieren

### Status
- **WebSocket-Verbindungen sind jetzt über Node.js-Proxy möglich!**
- **Die Anwendung kann sowohl HTTP-API als auch Echtzeit-Features (WebSocket) nutzen.**
- **Node.js-Proxy ist die beste Lösung für WebSocket-Proxying auf Managed Servern ohne Admin-Rechte.** 