# 🔒 Sicherheitstest-Anleitung für Note App

Diese Anleitung beschreibt verschiedene Möglichkeiten, die Sicherheit Ihrer Note App zu testen.

## 📋 Übersicht der Sicherheitstests

### 1. **Interne Python-Tests (Empfohlen)**

#### Grundlegende Sicherheitstests
```bash
cd backend
python security_test.py
```

#### Erweiterte Penetration Tests
```bash
cd backend
python advanced_security_test.py
```

### 2. **Externe Sicherheitstools**

#### A. **SSL Labs SSL Test**
- **URL**: https://www.ssllabs.com/ssltest/
- **Eingabe**: `iqmedix.cloud`
- **Testet**: SSL/TLS-Konfiguration, Zertifikate, Cipher Suites

#### B. **Security Headers Test**
- **URL**: https://securityheaders.com/
- **Eingabe**: `https://iqmedix.cloud`
- **Testet**: Security-Header (HSTS, CSP, X-Frame-Options, etc.)

#### C. **Mozilla Observatory**
- **URL**: https://observatory.mozilla.org/
- **Eingabe**: `https://iqmedix.cloud`
- **Testet**: Umfassende Web-Sicherheit

#### D. **Qualys SSL Test**
- **URL**: https://www.ssllabs.com/ssltest/
- **Testet**: Detaillierte SSL/TLS-Analyse

### 3. **Port-Scanning Tools**

#### A. **Nmap (Kommandozeile)**
```bash
# Grundlegender Port-Scan
nmap iqmedix.cloud

# Detaillierter Scan
nmap -sS -sV -O iqmedix.cloud

# Spezifische Ports
nmap -p 21,22,23,25,53,80,110,143,443,3306,5432,27017,6379 iqmedix.cloud
```

#### B. **Online Port Scanner**
- **URL**: https://www.yougetsignal.com/tools/open-ports/
- **Eingabe**: `iqmedix.cloud`
- **Ports**: 80, 443, 3306, 5432, 27017, 6379

### 4. **Vulnerability Scanner**

#### A. **Nikto (Web-Server Scanner)**
```bash
# Installation (Ubuntu/Debian)
sudo apt-get install nikto

# Scan durchführen
nikto -h iqmedix.cloud

# Detaillierter Scan
nikto -h iqmedix.cloud -Format txt -o nikto_report.txt
```

#### B. **OWASP ZAP (Zed Attack Proxy)**
- **Download**: https://owasp.org/www-project-zap/
- **Verwendung**: GUI-basiert, sehr umfassend
- **Testet**: SQL-Injection, XSS, CSRF, etc.

### 5. **API-Sicherheitstests**

#### A. **Postman Security Tests**
```bash
# Collection für API-Tests erstellen
# Endpunkte testen:
# - GET /api/notes/ (ohne Auth)
# - POST /api/token (mit falschen Credentials)
# - GET /api/users/ (ohne Auth)
```

#### B. **OWASP API Security Top 10 Tests**
- **Broken Object Level Authorization**
- **Broken User Authentication**
- **Excessive Data Exposure**
- **Lack of Resources & Rate Limiting**
- **Broken Function Level Authorization**

### 6. **Datenbank-Sicherheitstests**

#### A. **MySQL/MariaDB Port-Test**
```bash
# Teste ob MySQL-Port erreichbar ist
telnet iqmedix.cloud 3306

# Oder mit nmap
nmap -p 3306 iqmedix.cloud
```

#### B. **SQL-Injection Tests**
```bash
# Mit sqlmap (fortgeschritten)
sqlmap -u "https://iqmedix.cloud/api/notes/?search=test" --level=1 --risk=1
```

### 7. **WebSocket-Sicherheitstests**

#### A. **WebSocket Client Test**
```javascript
// Browser Console
const ws = new WebSocket('wss://iqmedix.cloud/ws/');
ws.onopen = () => console.log('WebSocket verbunden');
ws.onmessage = (event) => console.log('Nachricht:', event.data);
ws.onerror = (error) => console.log('Fehler:', error);
```

#### B. **WebSocket Penetration Testing**
```bash
# Mit wscat (Node.js Tool)
npm install -g wscat
wscat -c wss://iqmedix.cloud/ws/
```

## 🚨 Kritische Sicherheitsaspekte

### 1. **Datenbank-Zugriff**
- ✅ **Geschützt**: Datenbank läuft nur lokal (127.0.0.1)
- ✅ **Firewall**: Port 3306 nicht von außen erreichbar
- ✅ **Credentials**: In .env-Datei gespeichert

### 2. **HTTPS/TLS**
- ✅ **SSL-Zertifikat**: Gültig für iqmedix.cloud
- ✅ **Redirect**: HTTP → HTTPS funktioniert
- ⚠️ **Security-Header**: Können verbessert werden

### 3. **API-Sicherheit**
- ✅ **JWT-Authentifizierung**: Implementiert
- ✅ **CORS**: Konfiguriert für iqmedix.cloud
- ⚠️ **Rate Limiting**: Nicht implementiert

### 4. **WebSocket-Sicherheit**
- ✅ **WSS**: Sichere WebSocket-Verbindung
- ✅ **Proxy**: Über Node.js-Proxy geroutet
- ⚠️ **Authentifizierung**: WebSocket-Auth prüfen

## 📊 Test-Ergebnisse interpretieren

### ✅ **Sicher (Grün)**
- HTTPS funktioniert korrekt
- Datenbank nicht von außen erreichbar
- API-Endpunkte erfordern Authentifizierung
- SSL-Zertifikat gültig

### ⚠️ **Verbesserung empfohlen (Gelb)**
- Security-Header fehlen
- Rate Limiting nicht implementiert
- CORS könnte restriktiver sein

### ❌ **Kritisch (Rot)**
- Datenbank-Port offen
- SQL-Injection-Schwachstellen
- XSS-Schwachstellen
- Authentication Bypass möglich

## 🔧 Sicherheitsverbesserungen

### 1. **Security-Header hinzufügen**
```apache
# In .htaccess
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "DENY"
Header always set X-XSS-Protection "1; mode=block"
Header always set Content-Security-Policy "default-src 'self'"
```

### 2. **Rate Limiting implementieren**
```python
# In main.py
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.get("/api/notes/")
@limiter.limit("10/minute")
def read_notes(request: Request, db: Session = Depends(get_db)):
    # ...
```

### 3. **CORS restriktiver machen**
```python
# In main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://iqmedix.cloud"],  # Nur spezifische Domain
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

## 📝 Test-Checkliste

### Vor dem Test
- [ ] App läuft und ist erreichbar
- [ ] HTTPS funktioniert
- [ ] Backup der aktuellen Konfiguration

### Während des Tests
- [ ] Grundlegende Sicherheitstests ausführen
- [ ] Externe Tools verwenden
- [ ] Ergebnisse dokumentieren
- [ ] Kritische Probleme sofort beheben

### Nach dem Test
- [ ] Berichte analysieren
- [ ] Verbesserungen implementieren
- [ ] Tests wiederholen
- [ ] Dokumentation aktualisieren

## 🆘 Bei Problemen

### Häufige Probleme
1. **SSL-Zertifikat abgelaufen**: Erneuern beim Hosting-Provider
2. **Datenbank-Port offen**: Firewall-Regeln prüfen
3. **Security-Header fehlen**: .htaccess anpassen
4. **CORS-Fehler**: CORS-Konfiguration prüfen

### Support
- **Strato Support**: Für Hosting-spezifische Probleme
- **FastAPI Dokumentation**: Für Backend-Probleme
- **OWASP Guidelines**: Für Sicherheitsstandards

## 📈 Regelmäßige Tests

### Empfohlene Test-Frequenz
- **Täglich**: Automatisierte Grundtests
- **Wöchentlich**: Manuelle Sicherheitstests
- **Monatlich**: Vollständige Penetration Tests
- **Quartalsweise**: Externe Sicherheitsaudits

### Automatisierung
```bash
# Cron-Job für tägliche Tests
0 2 * * * cd /path/to/backend && python security_test.py >> security_log.txt
```

---

**⚠️ Wichtig**: Diese Tests sind für Sicherheitszwecke gedacht. Verwenden Sie sie nur auf Ihren eigenen Systemen oder mit ausdrücklicher Erlaubnis.
