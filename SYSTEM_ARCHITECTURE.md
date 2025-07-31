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
└── [weitere Backend-Module]
```

### Server-Konfiguration
```
/
├── .htaccess                    # Apache Rewrite-Regeln & Basic Auth
├── websocket-proxy.php          # WebSocket-Proxy zu Gunicorn
├── api-proxy.php                # HTTP-API-Proxy zu Gunicorn
├── .htpasswd                    # Basic Auth Passwörter
└── [weitere Server-Dateien]
```

## 🔄 Datenfluss

### 1. HTTP-API-Anfragen
```
Flutter App → HTTPS → Apache → .htaccess → api-proxy.php → Gunicorn → FastAPI → MariaDB
```

### 2. WebSocket-Verbindungen
```
Flutter App → WSS → Apache → .htaccess → websocket-proxy.php → Gunicorn → FastAPI
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

# WebSocket-Pfad zu PHP-Proxy weiterleiten
RewriteCond %{HTTP:Connection} Upgrade [NC]
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteRule ^api/ws/(.*) websocket-proxy.php [L,P]

# Alternative WebSocket-Pfad (ohne api/ prefix)
RewriteCond %{HTTP:Connection} Upgrade [NC]
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteRule ^ws/(.*) websocket-proxy.php [L,P]

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
- **WebSocket:** `wss://iqmedix.cloud/ws/notes` oder `wss://iqmedix.cloud/ws/crm`

### Interne Verbindungen
- **Apache → Gunicorn:** `localhost:8000`
- **PHP-Proxy → Gunicorn:** `localhost:8000`
- **Umgebungsvariable:** `GUNICORN_PORT=8000`

## 🐛 Aktuelle Probleme

### WebSocket-Verbindung
- **Fehler:** `HTTP status code: 401`
- **Ursache:** PHP-Proxy kann nicht korrekt mit Gunicorn kommunizieren
- **Debug-Logs:** `/tmp/websocket-debug.log`

### Bekannte Issues
1. PHP-Proxy sendet HTTP-Upgrade-Anfrage an Gunicorn
2. Gunicorn erwartet möglicherweise andere Art von WebSocket-Handshake
3. Token-Validierung zwischen PHP-Proxy und FastAPI

## 🔍 Debugging-Tools

### Log-Dateien
- **PHP-Errors:** `/var/log/apache2/error.log`
- **Apache-Access:** `/var/log/apache2/access.log`
- **Gunicorn-Logs:** `gunicorn.log`
- **WebSocket-Debug:** `/tmp/websocket-debug.log`

### Test-Befehle
```bash
# Gunicorn-Status prüfen
ps aux | grep gunicorn

# Port 8000 prüfen
netstat -tlnp | grep 8000

# Apache-Status
systemctl status apache2

# PHP-Error-Logs
tail -f /var/log/apache2/error.log

# WebSocket-Debug-Logs
tail -f /tmp/websocket-debug.log
```

## 🚀 Deployment

### Gunicorn-Start
```bash
nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &
```

### Apache-Konfiguration
- **SSL-Zertifikat:** Für `iqmedix.cloud`
- **Proxy-Module:** `mod_proxy`, `mod_proxy_http`
- **Rewrite-Module:** `mod_rewrite`
- **Headers-Module:** `mod_headers`

## 📊 Monitoring

### Zu überwachende Metriken
- **Gunicorn-Prozesse:** Anzahl, Memory, CPU
- **Apache-Connections:** Aktive Verbindungen
- **WebSocket-Verbindungen:** Anzahl aktiver Clients
- **API-Response-Times:** Durchschnittliche Antwortzeiten
- **Error-Rates:** 401, 500, WebSocket-Fehler

### Alerts
- Gunicorn-Prozess gestorben
- WebSocket-Verbindungen schlagen fehl
- API-Response-Times > 2 Sekunden
- Error-Rate > 5%

---

**Letzte Aktualisierung:** $(date)
**Version:** 1.0
**Status:** Debugging WebSocket-Verbindung 