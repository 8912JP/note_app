# Strato Node.js WebSocket-Proxy Setup

## 🚀 Schritt-für-Schritt Anleitung

### 1. Node.js-App bei Strato erstellen

1. **Strato-Panel öffnen**
   - Gehe zu deinem Strato-Kundenbereich
   - Navigiere zu "Webspace" → "Node.js-Anwendungen"

2. **Neue Node.js-App erstellen**
   - Klicke auf "Node.js-Anwendung hinzufügen"
   - **Name:** `websocket-proxy` (oder beliebig)
   - **Startdatei:** `ws-proxy.js`
   - **Port:** `8080` (oder den von Strato vorgegebenen Port)
   - **Node.js-Version:** Wähle die neueste verfügbare Version

3. **Dependencies installieren**
   - Im Terminal oder über Strato's SSH-Zugang:
   ```bash
   cd /path/to/your/backend
   npm install
   ```

### 2. Dateien hochladen

Lade folgende Dateien in deinen Webspace hoch:

**`backend/ws-proxy.js`** (bereits erstellt)
**`backend/package.json`** (bereits erstellt)

### 3. Node.js-App starten

1. **Im Strato-Panel:**
   - Gehe zu deiner Node.js-App
   - Klicke auf "Starten" oder "Deploy"

2. **Über SSH (falls verfügbar):**
   ```bash
   cd /path/to/your/backend
   nohup node ws-proxy.js > ws-proxy.log 2>&1 &
   ```

### 4. Port-Konfiguration prüfen

**Wichtig:** Strato vergibt oft eigene Ports. Prüfe im Panel, welchen Port deine Node.js-App bekommen hat.

**Falls der Port nicht 8080 ist, musst du die Flutter-App anpassen:**

```dart
// In lib/api_service.dart und lib/crm_overview_page.dart
// Ersetze 8080 mit dem tatsächlichen Port

final wsUrl = 'wss://iqmedix.cloud:DEIN_PORT/ws/notes?token=$_accessToken';
```

### 5. Testen

#### Mit wscat (falls verfügbar):
```bash
npm install -g wscat
wscat -c "wss://iqmedix.cloud:8080/ws/notes?token=DEIN_TOKEN"
```

#### Mit curl (HTTP-Test):
```bash
curl -I https://iqmedix.cloud:8080/
# Sollte "Nur WebSocket-Verbindungen erlaubt" zurückgeben
```

#### In der Flutter-App:
- Starte die App
- Prüfe die Logs auf WebSocket-Verbindungsfehler
- Sollte jetzt funktionieren!

### 6. Troubleshooting

#### Node.js-App startet nicht:
```bash
# Prüfe Logs
tail -f ws-proxy.log

# Prüfe ob Port belegt ist
netstat -tlnp | grep 8080

# Prüfe Node.js-Prozess
ps aux | grep node
```

#### WebSocket-Verbindung schlägt fehl:
1. **Prüfe Port:** Ist es wirklich 8080 oder ein anderer?
2. **Prüfe Firewall:** Ist der Port von außen erreichbar?
3. **Prüfe Gunicorn:** Läuft das Backend auf Port 8000?

#### Flutter-App kann sich nicht verbinden:
1. **URL prüfen:** `wss://iqmedix.cloud:8080/ws/notes?...`
2. **Token prüfen:** Ist der JWT-Token gültig?
3. **CORS prüfen:** Sind die Headers korrekt?

### 7. Monitoring

#### Node.js-Proxy-Logs:
```bash
tail -f ws-proxy.log
```

#### Gunicorn-Logs:
```bash
tail -f gunicorn.log
```

#### Apache-Logs:
```bash
tail -f /var/log/apache2/error.log
```

### 8. Automatischer Neustart

Falls die Node.js-App abstürzt, kannst du einen automatischen Neustart einrichten:

```bash
# Mit PM2 (falls verfügbar)
npm install -g pm2
pm2 start ws-proxy.js --name websocket-proxy
pm2 save
pm2 startup
```

### 9. Backup-Strategie

Falls Node.js nicht funktioniert, kannst du temporär zurück zu PHP-Proxy:

```dart
// In lib/api_service.dart
// Kommentiere die Node.js-URL aus und aktiviere PHP-Proxy
// final wsUrl = 'wss://iqmedix.cloud:8080/ws/notes?token=$_accessToken';
final wsUrl = 'wss://iqmedix.cloud/ws/notes?token=$_accessToken';
```

---

## ✅ Checkliste

- [ ] Node.js-App im Strato-Panel erstellt
- [ ] `ws-proxy.js` und `package.json` hochgeladen
- [ ] `npm install` ausgeführt
- [ ] Node.js-App gestartet
- [ ] Port-Konfiguration geprüft
- [ ] Flutter-App mit korrektem Port konfiguriert
- [ ] WebSocket-Verbindung getestet
- [ ] Logs überwacht

---

## 🆘 Support

Falls etwas nicht funktioniert:

1. **Prüfe die Logs** (siehe oben)
2. **Teste mit wscat** (falls verfügbar)
3. **Prüfe Strato's Node.js-Dokumentation**
4. **Kontaktiere Strato-Support** (falls Node.js-Probleme)

**Die Node.js-Lösung sollte das WebSocket-Problem endgültig lösen!** 🎉 