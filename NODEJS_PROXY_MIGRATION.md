# Node.js Proxy Migration - HTTP zu HTTPS Umstellung

## 🎯 Ziel

Vollständige Migration von PHP-Proxies zu Node.js-Proxies für bessere WebSocket-Unterstützung und HTTPS-Integration.

## 📋 Migration-Übersicht

### Vorher (PHP-basiert)
```
Flutter App → HTTPS → Apache → .htaccess → PHP-Proxy → Gunicorn → FastAPI
```

### Nachher (Node.js-basiert)
```
Flutter App → HTTPS → Apache → .htaccess → Node.js-Proxy → Gunicorn → FastAPI
```

## 🆕 Neue Dateien

### Node.js-Proxy-Dateien
- `backend/combined-proxy.js` - Kombinierter HTTP/WebSocket-Proxy
- `backend/api-proxy.js` - Separater HTTP-API-Proxy
- `backend/start-node-proxy.sh` - Start-Skript
- `backend/stop-node-proxy.sh` - Stop-Skript

### Aktualisierte Dateien
- `backend/package.json` - Erweiterte Dependencies und Scripts
- `.htaccess` - Umstellung auf Node.js-Proxy

## 🔧 Konfiguration

### Ports
- **HTTP-API:** Port 8080 (oder Umgebungsvariable `HTTP_PORT`)
- **HTTPS-API:** Port 8443 (oder Umgebungsvariable `HTTPS_PORT`)
- **WebSocket:** Port 8080 (gleicher Port wie HTTP)

### SSL-Zertifikate
Der Node.js-Proxy versucht automatisch SSL-Zertifikate zu laden:
```
/pages/d0/aa/d0017222/home/ssl/
├── cert.pem
└── key.pem
```

Falls SSL-Zertifikate nicht verfügbar sind, läuft der Proxy nur über HTTP.

## 🚀 Deployment

### 1. Dependencies installieren
```bash
cd backend
npm install
```

### 2. Proxy starten
```bash
# Automatisch mit Skript
./start-node-proxy.sh

# Oder manuell
npm start
```

### 3. Proxy stoppen
```bash
# Automatisch mit Skript
./stop-node-proxy.sh

# Oder manuell
npm run stop
```

### 4. Proxy neustarten
```bash
npm run restart
```

## 🔄 URL-Mapping

### HTTP-API-Endpunkte
```
Vorher: https://iqmedix.cloud/api/token
Nachher: https://iqmedix.cloud/api/token (gleich)

Intern: http://localhost:8080/api/token → http://localhost:8000/token
```

### WebSocket-Endpunkte
```
Vorher: wss://iqmedix.cloud/api/ws/notes
Nachher: wss://iqmedix.cloud/api/ws/notes (gleich)

Intern: ws://localhost:8080/api/ws/notes → ws://localhost:8000/ws/notes
```

## 📊 Monitoring

### Log-Dateien
- `backend/combined-proxy.log` - Hauptlog des Combined-Proxies
- `backend/combined-proxy.pid` - Prozess-ID für Management

### Status-Checks
```bash
# Proxy-Status prüfen
ps aux | grep combined-proxy

# Ports prüfen
netstat -tlnp | grep 8080
netstat -tlnp | grep 8443

# Logs anzeigen
tail -f backend/combined-proxy.log
```

## 🔍 Debugging

### Häufige Probleme

#### 1. Port bereits belegt
```bash
# Lösung: Alte Prozesse beenden
./stop-node-proxy.sh
```

#### 2. SSL-Zertifikate nicht gefunden
```
Log: "SSL-Zertifikate für Combined-Proxy nicht verfügbar, verwende HTTP"
Lösung: Proxy läuft trotzdem, nur ohne HTTPS
```

#### 3. FastAPI-Backend nicht erreichbar
```
Log: "API-Proxy-Fehler: connect ECONNREFUSED 127.0.0.1:8000"
Lösung: Gunicorn-Server starten
```

### Test-Befehle
```bash
# HTTP-API testen
curl -X GET "http://localhost:8080/api/notes" \
  -H "Authorization: Bearer YOUR_TOKEN"

# WebSocket testen
wscat -c "ws://localhost:8080/ws/notes?token=YOUR_TOKEN"
```

## 🔄 Rollback

Falls Probleme auftreten, kann auf PHP-Proxies zurückgewechselt werden:

### 1. .htaccess zurücksetzen
```apache
# WebSocket-Pfad zu PHP-Proxy weiterleiten
RewriteCond %{HTTP:Connection} Upgrade [NC]
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteRule ^api/ws/(.*) websocket-proxy.php [L,P]

# API-Pfad zu PHP-Proxy weiterleiten
RewriteCond %{REQUEST_URI} ^/api/
RewriteRule ^api/(.*) api-proxy.php [L]
```

### 2. Node.js-Proxy stoppen
```bash
./stop-node-proxy.sh
```

## ✅ Vorteile der Node.js-Lösung

1. **Bessere WebSocket-Unterstützung:** Native WebSocket-Handling
2. **HTTPS-Integration:** Automatische SSL-Zertifikat-Erkennung
3. **Performance:** Weniger Overhead als PHP
4. **Logging:** Detaillierte Request/Response-Logs
5. **Fehlerbehandlung:** Robuste Error-Handling
6. **Skalierbarkeit:** Einfache Erweiterung um weitere Features

## 📝 Nächste Schritte

1. **Testing:** Proxy lokal testen
2. **Deployment:** Auf Strato-Server deployen
3. **Monitoring:** Logs überwachen
4. **Optimierung:** Performance-Tuning bei Bedarf
5. **Sicherheit:** SSL-Zertifikate konfigurieren

---

**Status:** ✅ Implementiert  
**Nächster Schritt:** Testing und Deployment 