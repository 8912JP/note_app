const https = require('https');
const http = require('http');
const httpProxy = require('http-proxy');
const fs = require('fs');
const path = require('path');

// Proxy-Konfiguration für HTTP-API (lange Timeouts für stabile Verbindungen)
const apiProxy = httpProxy.createProxyServer({
  target: 'http://localhost:8000', // FastAPI Backend
  changeOrigin: true,
  timeout: 0, // 0 = kein Timeout (Node http-proxy)
  proxyTimeout: 0,
  xfwd: true, // X-Forwarded-For Header hinzufügen
});

// Proxy-Konfiguration für WebSocket (Timeoute deaktiviert)
const wsProxy = httpProxy.createProxyServer({
  target: 'ws://localhost:8000', // FastAPI Backend
  ws: true,
  changeOrigin: true,
  timeout: 0, // 0 = kein Timeout
  proxyTimeout: 0,
  xfwd: true, // X-Forwarded-For Header hinzufügen
});

// Erweiterte Logging für Debugging
apiProxy.on('error', (err, req, res) => {
  console.error('❌ API-Proxy-Fehler:', err.message);
  console.error('❌ API-Proxy-Fehler Details:', err);
  if (res && !res.headersSent) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'API Proxy error: ' + err.message }));
  }
});

wsProxy.on('error', (err, req, socket) => {
  console.error('❌ WebSocket-Proxy-Fehler:', err.message);
  console.error('❌ WebSocket-Proxy-Fehler Details:', err);
  console.error('❌ WebSocket-Proxy-Fehler URL:', req.url);
  console.error('❌ WebSocket-Proxy-Fehler Headers:', req.headers);
  if (socket && !socket.destroyed) {
    socket.destroy();
  }
});

apiProxy.on('proxyReq', (proxyReq, req, res) => {
  console.log('📡 HTTP-API-Request für:', req.url, req.method);
  
  // CORS-Headers setzen
  res.setHeader('Access-Control-Allow-Origin', 'https://iqmedix.cloud');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Upgrade, Connection, Sec-WebSocket-Key, Sec-WebSocket-Version, Sec-WebSocket-Protocol, Origin');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Max-Age', '86400');
  
  // OPTIONS Preflight Request
  if (req.method === 'OPTIONS') {
    console.log('📡 OPTIONS Preflight Request behandelt');
    res.writeHead(200);
    res.end();
    return;
  }
  
  // Authorization Header weiterleiten
  if (req.headers.authorization) {
    proxyReq.setHeader('Authorization', req.headers.authorization);
    console.log('📡 Authorization Header weitergeleitet');
  }
  
  // Content-Type weiterleiten
  if (req.headers['content-type']) {
    proxyReq.setHeader('Content-Type', req.headers['content-type']);
  }
  
  // URL-Pfad anpassen (api/ entfernen)
  const originalUrl = req.url;
  if (originalUrl.startsWith('/api/')) {
    const newPath = originalUrl.replace('/api/', '/');
    proxyReq.path = newPath;
    console.log('📡 API-Pfad angepasst von', originalUrl, 'zu', newPath);
  }
});

apiProxy.on('proxyRes', (proxyRes, req, res) => {
  console.log('📡 HTTP-API-Response:', proxyRes.statusCode, 'für', req.url);
  
  // CORS-Headers auch in Response setzen
  res.setHeader('Access-Control-Allow-Origin', 'https://iqmedix.cloud');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
});

wsProxy.on('proxyReqWs', (proxyReq, req, socket) => {
  console.log('🔌 WebSocket-Upgrade für:', req.url);
  console.log('🔌 WebSocket-Method:', req.method);
  console.log('🔌 WebSocket-Headers:', JSON.stringify(req.headers, null, 2));
  console.log('🔌 Proxy-Request-Path:', proxyReq.path);
  console.log('🔌 Proxy-Request-Headers:', JSON.stringify(proxyReq.getHeaders(), null, 2));
  
  // URL-Pfad anpassen für WebSocket
  const originalUrl = req.url;
  if (originalUrl.startsWith('/ws/')) {
    // WebSocket-Pfad bleibt gleich
    console.log('🔌 WebSocket-Pfad bleibt:', originalUrl);
  } else if (originalUrl.startsWith('/api/ws/')) {
    // api/ws/ zu /ws/ konvertieren
    const newPath = originalUrl.replace('/api/ws/', '/ws/');
    proxyReq.path = newPath;
    console.log('🔌 WebSocket-Pfad angepasst von', originalUrl, 'zu', newPath);
  }
  
  // WebSocket-spezifische Headers weiterleiten
  if (req.headers['sec-websocket-key']) {
    proxyReq.setHeader('Sec-WebSocket-Key', req.headers['sec-websocket-key']);
    console.log('🔌 Sec-WebSocket-Key weitergeleitet');
  }
  if (req.headers['sec-websocket-version']) {
    proxyReq.setHeader('Sec-WebSocket-Version', req.headers['sec-websocket-version']);
    console.log('🔌 Sec-WebSocket-Version weitergeleitet');
  }
  if (req.headers['sec-websocket-protocol']) {
    proxyReq.setHeader('Sec-WebSocket-Protocol', req.headers['sec-websocket-protocol']);
    console.log('🔌 Sec-WebSocket-Protocol weitergeleitet');
  }
  
  // Authorization Header weiterleiten (für Token)
  if (req.headers.authorization) {
    proxyReq.setHeader('Authorization', req.headers.authorization);
    console.log('🔌 Authorization Header weitergeleitet');
  }
  
  // Origin Header weiterleiten
  if (req.headers.origin) {
    proxyReq.setHeader('Origin', req.headers.origin);
    console.log('🔌 Origin Header weitergeleitet');
  }
});

// WebSocket-Verbindungs-Events
wsProxy.on('open', (proxySocket) => {
  console.log('🔌 WebSocket-Verbindung zu Backend geöffnet');
  console.log('🔌 Proxy-Socket Details:', {
    remoteAddress: proxySocket.remoteAddress,
    remotePort: proxySocket.remotePort,
    localAddress: proxySocket.localAddress,
    localPort: proxySocket.localPort
  });
});

wsProxy.on('close', (proxySocket) => {
  console.log('🔌 WebSocket-Verbindung zu Backend geschlossen');
});

// SSL-Zertifikate (falls verfügbar)
let sslOptions = null;
try {
  // Versuche SSL-Zertifikate zu laden (falls vorhanden)
  const certPath = '/pages/d0/aa/d0017222/home/ssl/';
  if (fs.existsSync(path.join(certPath, 'cert.pem'))) {
    sslOptions = {
      key: fs.readFileSync(path.join(certPath, 'key.pem')),
      cert: fs.readFileSync(path.join(certPath, 'cert.pem'))
    };
    console.log('🔒 SSL-Zertifikate für Combined-Proxy geladen');
  }
} catch (error) {
  console.log('⚠️ SSL-Zertifikate für Combined-Proxy nicht verfügbar, verwende HTTP');
}

// HTTP-Server für alle Requests
const httpServer = http.createServer((req, res) => {
  console.log('=== HTTP-Request erhalten ===');
  console.log('URL:', req.url);
  console.log('Method:', req.method);
  console.log('Headers:', JSON.stringify(req.headers, null, 2));
  console.log('Connection:', req.headers.connection);
  console.log('Upgrade:', req.headers.upgrade);
  console.log('============================');

  // API-Pfade
  if (req.url.startsWith('/api/') && !req.url.startsWith('/api/ws/')) {
    console.log('→ Leite API-Request weiter');
    apiProxy.web(req, res);
  } else if (req.url.startsWith('/ws/')) {
    // WebSocket-Pfade als HTTP-Request - leite an FastAPI weiter
    console.log('→ Leite WebSocket-Request zu FastAPI (Port 8000) weiter');
    wsProxy.web(req, res);
  } else {
    console.log('→ 404 - Ungültiger Pfad');
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Nur API- und WebSocket-Pfade erlaubt');
  }
});

// Deaktiviere Standard-Timeouts auf HTTP-Server-Ebene
httpServer.timeout = 0; // Kein Inaktivitäts-Timeout
httpServer.keepAliveTimeout = 120000; // 120s für Keep-Alive

// HTTPS-Server für alle Requests (falls SSL verfügbar)
let httpsServer = null;
if (sslOptions) {
  httpsServer = https.createServer(sslOptions, (req, res) => {
    console.log('=== HTTPS-Request erhalten ===');
    console.log('URL:', req.url);
    console.log('Method:', req.method);
    console.log('============================');
    
    // API-Pfade
    if (req.url.startsWith('/api/') && !req.url.startsWith('/api/ws/')) {
      apiProxy.web(req, res);
    } else if (req.url.startsWith('/ws/')) {
      // WebSocket-Pfade als HTTP-Request - leite an WebSocket-Proxy weiter
      console.log('WebSocket-Pfad als HTTP-Request erkannt:', req.url);
      wsProxy.web(req, res);
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Nur API- und WebSocket-Pfade erlaubt');
    }
  });
  // Deaktiviere Standard-Timeouts auf HTTPS-Server-Ebene
  httpsServer.timeout = 0;
  httpsServer.keepAliveTimeout = 120000;
}

// WebSocket-Upgrade-Handler für HTTP
httpServer.on('upgrade', (req, socket, head) => {
  console.log('=== HTTP WebSocket-Upgrade angefragt ===');
  console.log('URL:', req.url);
  console.log('Method:', req.method);
  console.log('Headers:', JSON.stringify(req.headers, null, 2));
  console.log('Connection:', req.headers.connection);
  console.log('Upgrade:', req.headers.upgrade);
  console.log('============================');

  // WebSocket-Pfade direkt zu FastAPI weiterleiten
  if (req.url.startsWith('/ws/') || req.url.startsWith('/api/ws/')) {
    console.log('→ Leite WebSocket-Upgrade zu FastAPI (Port 8000) weiter');
    wsProxy.ws(req, socket, head);
  } else {
    console.log('→ Ungültiger WebSocket-Pfad, schließe Verbindung');
    socket.destroy();
  }
});

// WebSocket-Upgrade-Handler für HTTPS (falls verfügbar)
if (httpsServer) {
  httpsServer.on('upgrade', (req, socket, head) => {
    console.log('=== HTTPS WebSocket-Upgrade angefragt ===');
    console.log('URL:', req.url);
    console.log('Method:', req.method);
    console.log('Headers:', JSON.stringify(req.headers, null, 2));
    console.log('============================');
    
    // WebSocket-Pfade
    if (req.url.startsWith('/ws/') || req.url.startsWith('/api/ws/')) {
      console.log('→ Leite HTTPS WebSocket-Upgrade zu FastAPI (Port 8000) weiter');
      wsProxy.ws(req, socket, head);
    } else {
      console.log('→ Ungültiger WebSocket-Pfad:', req.url);
      socket.destroy();
    }
  });
}

// Server starten
const HTTP_PORT = process.env.HTTP_PORT || 8080;
const HTTPS_PORT = process.env.HTTPS_PORT || 8443;

httpServer.listen(HTTP_PORT, () => {
  console.log(`🚀 HTTP Combined-Proxy läuft auf Port ${HTTP_PORT}`);
  console.log(`📡 Leitet API-Anfragen an http://localhost:8000 weiter`);
  console.log(`🔌 Leitet WebSocket-Verbindungen an ws://localhost:8000 weiter`);
  console.log(`🌐 Verfügbare Endpunkte:`);
  console.log(`   - API: http://localhost:${HTTP_PORT}/api/*`);
  console.log(`   - WebSocket: ws://localhost:${HTTP_PORT}/ws/*`);
});

if (httpsServer) {
  httpsServer.listen(HTTPS_PORT, () => {
    console.log(`🚀 HTTPS Combined-Proxy läuft auf Port ${HTTPS_PORT}`);
    console.log(`📡 Leitet API-Anfragen an http://localhost:8000 weiter`);
    console.log(`🔌 Leitet WebSocket-Verbindungen an ws://localhost:8000 weiter`);
    console.log(`🌐 Verfügbare Endpunkte:`);
    console.log(`   - API: https://localhost:${HTTPS_PORT}/api/*`);
    console.log(`   - WebSocket: wss://localhost:${HTTPS_PORT}/ws/*`);
  });
} else {
  console.log('⚠️ HTTPS Combined-Proxy nicht verfügbar - nur HTTP aktiv');
}

// Graceful Shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Combined-Proxy wird beendet...');
  httpServer.close(() => {
    console.log('✅ HTTP Combined-Proxy beendet');
  });
  if (httpsServer) {
    httpsServer.close(() => {
      console.log('✅ HTTPS Combined-Proxy beendet');
    });
  }
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Combined-Proxy wird beendet...');
  httpServer.close(() => {
    console.log('✅ HTTP Combined-Proxy beendet');
  });
  if (httpsServer) {
    httpsServer.close(() => {
      console.log('✅ HTTPS Combined-Proxy beendet');
    });
  }
  process.exit(0);
}); 