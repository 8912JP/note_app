# WebSocket Reverse Proxy Setup

## Problem
Die WebSocket-Verbindung schlägt fehl, obwohl der Server läuft und die API funktioniert.

## Ursache
Der Reverse Proxy leitet WebSocket-Verbindungen nicht korrekt weiter.

## Lösung: Proxy-Konfiguration

### 1. Apache WebSocket-Proxy (empfohlen)
```apache
# In .htaccess oder Apache-Konfiguration
RewriteEngine On

# WebSocket-Upgrade Headers
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule ^/ws/(.*) ws://localhost:8000/ws/$1 [P,L]

# Alternative mit ProxyPass
ProxyPass /ws/ ws://localhost:8000/ws/
ProxyPassReverse /ws/ ws://localhost:8000/ws/
```

### 2. Nginx WebSocket-Proxy
```nginx
location /ws/ {
    proxy_pass http://localhost:8000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### 3. PHP WebSocket-Proxy (falls vorhanden)
```php
<?php
// websocket-proxy.php
$target = 'ws://localhost:8000' . $_SERVER['REQUEST_URI'];
$context = stream_context_create();
$sp = stream_socket_client($target, $errno, $errstr, 30, STREAM_CLIENT_CONNECT, $context);

if (!$sp) {
    header("HTTP/1.1 502 Bad Gateway");
    exit;
}

// WebSocket-Handshake weiterleiten
$headers = getallheaders();
$ws_key = $headers['Sec-WebSocket-Key'] ?? '';
$ws_version = $headers['Sec-WebSocket-Version'] ?? '';

// Upgrade-Response senden
header("HTTP/1.1 101 Switching Protocols");
header("Upgrade: websocket");
header("Connection: Upgrade");
header("Sec-WebSocket-Accept: " . base64_encode(sha1($ws_key . '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', true)));

// Bidirektionale Kommunikation
stream_copy_to_stream($sp, STDOUT);
stream_copy_to_stream(STDIN, $sp);
?>
```

## Test der WebSocket-Verbindung

### 1. Direkter Test (ohne Proxy)
```bash
# Test mit wscat
wscat -c "ws://localhost:8000/ws/notes?token=YOUR_TOKEN"
```

### 2. Proxy-Test
```bash
# Test über Proxy
wscat -c "wss://iqmedix.cloud/ws/notes?token=YOUR_TOKEN"
```

### 3. Browser-Test
```javascript
// In Browser-Konsole
const ws = new WebSocket('wss://iqmedix.cloud/ws/notes?token=YOUR_TOKEN');
ws.onopen = () => console.log('Connected');
ws.onmessage = (e) => console.log('Message:', e.data);
ws.onerror = (e) => console.log('Error:', e);
```

## Troubleshooting

### 1. Proxy-Logs prüfen
```bash
# Apache Error-Logs
tail -f /var/log/apache2/error.log

# Nginx Error-Logs
tail -f /var/log/nginx/error.log
```

### 2. Backend-Logs prüfen
```bash
# Gunicorn-Logs
tail -f gunicorn.log

# Uvicorn-Logs
tail -f uvicorn.log
```

### 3. Netzwerk-Verbindung testen
```bash
# Port 8000 prüfen
netstat -tlnp | grep 8000

# WebSocket-Handshake testen
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" -H "Sec-WebSocket-Version: 13" http://localhost:8000/ws/notes
```

## Nächste Schritte

1. **Proxy-Konfiguration prüfen**: Stellen Sie sicher, dass WebSocket-Upgrade-Header korrekt weitergeleitet werden
2. **Backend-Logs analysieren**: Prüfen Sie, ob WebSocket-Anfragen das Backend erreichen
3. **Firewall-Einstellungen**: Stellen Sie sicher, dass Port 8000 erreichbar ist
4. **SSL/TLS-Konfiguration**: Prüfen Sie, ob WSS korrekt konfiguriert ist

## Status
- ✅ HTTP-API funktioniert über Proxy
- ❌ WebSocket-Verbindung schlägt fehl
- ⚠️ Reverse Proxy-Konfiguration muss angepasst werden 