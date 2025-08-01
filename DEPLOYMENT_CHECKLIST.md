# Deployment-Checkliste: Node.js-Proxy

## ✅ Vorbereitung (Lokal)
- [ ] Alle Node.js-Proxy-Dateien erstellt
- [ ] .htaccess aktualisiert (PHP → Node.js)
- [ ] package.json mit Dependencies konfiguriert
- [ ] Start/Stop-Skripte erstellt

## 🚀 Deployment auf Server

### Schritt 1: Dateien hochladen
- [ ] `combined-proxy.js` hochgeladen
- [ ] `package.json` hochgeladen  
- [ ] `start-node-proxy.sh` hochgeladen
- [ ] `stop-node-proxy.sh` hochgeladen
- [ ] `.htaccess` aktualisiert

### Schritt 2: Server-Setup
- [ ] `cd /path/to/backend/`
- [ ] `npm install` ausgeführt
- [ ] `chmod +x start-node-proxy.sh`
- [ ] `chmod +x stop-node-proxy.sh`

### Schritt 3: Proxy starten
- [ ] `./start-node-proxy.sh` ausgeführt
- [ ] Erfolgreiche Start-Meldung erhalten
- [ ] PID-Datei erstellt
- [ ] Log-Datei erstellt

### Schritt 4: Status prüfen
- [ ] `ps aux | grep combined-proxy` - Proxy läuft
- [ ] `netstat -tlnp | grep 8080` - Port belegt
- [ ] `tail -f combined-proxy.log` - Logs anzeigen

## 🔍 Testing

### API-Tests
- [ ] `curl -X GET "https://iqmedix.cloud/api/notes"` funktioniert
- [ ] Login über API funktioniert
- [ ] Notizen erstellen/bearbeiten funktioniert
- [ ] CRM-Funktionen funktionieren

### WebSocket-Tests
- [ ] WebSocket-Verbindung aufbaut
- [ ] Echtzeit-Updates funktionieren
- [ ] Token-Authentifizierung funktioniert
- [ ] Verbindung bleibt stabil

## 📊 Monitoring

### Logs überwachen
- [ ] Keine Fehler in `combined-proxy.log`
- [ ] Request/Response-Logs vorhanden
- [ ] WebSocket-Upgrade-Logs vorhanden

### Performance
- [ ] API-Response-Zeiten akzeptabel
- [ ] WebSocket-Verbindungen stabil
- [ ] Keine Memory-Leaks

## 🔄 Rollback (Falls nötig)

### Schneller Rollback
- [ ] `./stop-node-proxy.sh` ausgeführt
- [ ] .htaccess auf PHP-Proxies zurückgesetzt
- [ ] PHP-Proxies wieder aktiv
- [ ] Anwendung funktioniert wieder

## ✅ Erfolgskriterien

### Funktionale Tests
- [ ] Flutter-App kann sich verbinden
- [ ] Login/Logout funktioniert
- [ ] Notizen-CRUD funktioniert
- [ ] CRM-Funktionen funktionieren
- [ ] WebSocket-Echtzeit-Updates funktionieren

### Technische Tests
- [ ] Keine 500er Fehler
- [ ] Keine WebSocket-Verbindungsfehler
- [ ] CORS-Headers korrekt gesetzt
- [ ] SSL/TLS funktioniert (falls verfügbar)

### Performance-Tests
- [ ] API-Response < 2 Sekunden
- [ ] WebSocket-Verbindung stabil
- [ ] Keine Memory-Leaks nach 24h

## 📝 Nach Deployment

### Dokumentation
- [ ] Deployment-Datum notiert
- [ ] Erfolgreiche Tests dokumentiert
- [ ] Monitoring-Prozess eingerichtet
- [ ] Rollback-Prozedur getestet

### Monitoring-Setup
- [ ] Log-Rotation konfiguriert
- [ ] Alert-System eingerichtet
- [ ] Performance-Monitoring aktiviert

---

**Status:** 📋 Checkliste bereit  
**Nächster Schritt:** Deployment nach Checkliste durchführen 