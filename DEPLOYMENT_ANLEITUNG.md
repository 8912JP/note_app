# Deployment-Anleitung: Node.js-Proxy auf Strato-Server

## 🎯 Ziel
Vollständige Migration von PHP-Proxies zu Node.js-Proxies für bessere WebSocket-Unterstützung und HTTPS-Integration.

## 📋 Vorbereitung (Lokal)

### 1. Dateien prüfen
Stelle sicher, dass folgende Dateien im `backend/` Verzeichnis vorhanden sind:
- ✅ `combined-proxy.js` - Hauptproxy für HTTP/WebSocket
- ✅ `api-proxy.js` - Separater API-Proxy (Backup)
- ✅ `ws-proxy.js` - Separater WebSocket-Proxy (Backup)
- ✅ `package.json` - Node.js Dependencies
- ✅ `start-node-proxy.sh` - Start-Skript
- ✅ `stop-node-proxy.sh` - Stop-Skript

### 2. .htaccess bereits aktualisiert
Die `.htaccess` wurde bereits von PHP-Proxies auf Node.js-Proxies umgestellt:
```apache
# WebSocket-Pfad zu Node.js-Proxy weiterleiten
RewriteRule ^api/ws/(.*) http://localhost:8080/api/ws/$1 [P,L]
RewriteRule ^ws/(.*) http://localhost:8080/ws/$1 [P,L]

# API-Pfad zu Node.js-Proxy weiterleiten
RewriteRule ^api/(.*) http://localhost:8080/api/$1 [P,L]
```

## 🚀 Deployment auf Strato-Server

### Schritt 1: Dateien hochladen
```bash
# Alle Dateien ins backend/ Verzeichnis hochladen
scp backend/combined-proxy.js user@server:/path/to/backend/
scp backend/package.json user@server:/path/to/backend/
scp backend/start-node-proxy.sh user@server:/path/to/backend/
scp backend/stop-node-proxy.sh user@server:/path/to/backend/
```

### Schritt 2: Dependencies installieren
```bash
# Auf dem Server ausführen:
cd /path/to/backend/
npm install
```

### Schritt 3: Skripte ausführbar machen
```bash
# Auf dem Server ausführen:
chmod +x start-node-proxy.sh
chmod +x stop-node-proxy.sh
```

### Schritt 4: Alte PHP-Proxies stoppen (optional)
```bash
# Falls noch PHP-Proxies laufen, diese beenden
pkill -f "api-proxy.php"
pkill -f "websocket-proxy.php"
```

### Schritt 5: Node.js-Proxy starten
```bash
# Auf dem Server ausführen:
./start-node-proxy.sh
```

**Erwartete Ausgabe:**
```
=== Node.js Combined Proxy Start-Skript ===
Datum: [Datum]
Installiere Dependencies...
Combined Proxy gestartet mit PID: [PID]
✅ Combined Proxy läuft erfolgreich!
PID: [PID]
Log: combined-proxy.log

Verfügbare Endpunkte:
- HTTP API: http://localhost:8080/api/*
- HTTPS API: https://localhost:8443/api/* (falls SSL verfügbar)
- WebSocket: ws://localhost:8080/ws/* oder wss://localhost:8443/ws/*
```

## 🔍 Testing nach Deployment

### 1. Proxy-Status prüfen
```bash
# Auf dem Server ausführen:
ps aux | grep combined-proxy
netstat -tlnp | grep 8080
```

### 2. Logs überwachen
```bash
# Auf dem Server ausführen:
tail -f combined-proxy.log
```

### 3. API-Test
```bash
# Von deinem lokalen System aus:
curl -X GET "https://iqmedix.cloud/api/notes" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. WebSocket-Test
```bash
# Mit wscat (falls installiert):
wscat -c "wss://iqmedix.cloud/api/ws/notes?token=YOUR_TOKEN"
```

## 🔧 Konfiguration

### Ports
- **HTTP:** 8080 (Standard)
- **HTTPS:** 8443 (Standard)
- **Umgebungsvariablen:** `HTTP_PORT`, `HTTPS_PORT`

### SSL-Zertifikate
Der Proxy versucht automatisch SSL-Zertifikate zu laden:
```
/pages/d0/aa/d0017222/home/ssl/
├── cert.pem
└── key.pem
```

Falls nicht verfügbar, läuft der Proxy nur über HTTP.

## 📊 Monitoring

### Log-Dateien
- `combined-proxy.log` - Hauptlog
- `combined-proxy.pid` - Prozess-ID

### Status-Checks
```bash
# Proxy läuft?
ps aux | grep combined-proxy

# Ports belegt?
netstat -tlnp | grep 8080
netstat -tlnp | grep 8443

# Logs anzeigen
tail -f combined-proxy.log
```

## 🛠️ Troubleshooting

### Problem: Port bereits belegt
```bash
# Lösung:
./stop-node-proxy.sh
./start-node-proxy.sh
```

### Problem: FastAPI-Backend nicht erreichbar
```bash
# Prüfen ob Gunicorn läuft:
ps aux | grep gunicorn

# Falls nicht, starten:
cd /path/to/backend/
nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &
```

### Problem: SSL-Zertifikate nicht gefunden
```
Log: "SSL-Zertifikate für Combined-Proxy nicht verfügbar, verwende HTTP"
Lösung: Proxy läuft trotzdem, nur ohne HTTPS
```

## 🔄 Rollback (Falls Probleme)

### 1. Node.js-Proxy stoppen
```bash
./stop-node-proxy.sh
```

### 2. .htaccess zurücksetzen
```apache
# WebSocket-Pfad zu PHP-Proxy weiterleiten
RewriteRule ^api/ws/(.*) websocket-proxy.php [L,P]
RewriteRule ^ws/(.*) websocket-proxy.php [L,P]

# API-Pfad zu PHP-Proxy weiterleiten
RewriteRule ^api/(.*) api-proxy.php [L]
```

### 3. PHP-Proxies wieder aktivieren
Die PHP-Proxy-Dateien sind noch vorhanden und können wieder verwendet werden.

## ✅ Vorteile der neuen Lösung

1. **Bessere WebSocket-Unterstützung:** Native WebSocket-Handling
2. **HTTPS-Integration:** Automatische SSL-Zertifikat-Erkennung
3. **Performance:** Weniger Overhead als PHP
4. **Logging:** Detaillierte Request/Response-Logs
5. **Fehlerbehandlung:** Robuste Error-Handling
6. **Skalierbarkeit:** Einfache Erweiterung um weitere Features

## 📝 Nächste Schritte

1. **Deployment:** Node.js-Proxy auf Server starten
2. **Testing:** API und WebSocket-Funktionalität testen
3. **Monitoring:** Logs überwachen
4. **Optimierung:** Performance-Tuning bei Bedarf
5. **Sicherheit:** SSL-Zertifikate konfigurieren (falls gewünscht)

---

**Status:** ✅ Vorbereitet  
**Nächster Schritt:** Deployment auf Strato-Server 