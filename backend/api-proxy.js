const https = require('https');
const http = require('http');
const httpProxy = require('http-proxy');
const fs = require('fs');
const path = require('path');

// Proxy-Konfiguration für HTTP-API
const apiProxy = httpProxy.createProxyServer({
  target: 'http://localhost:8000', // FastAPI Backend
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000
});

// Logging für Debugging
apiProxy.on('error', (err, req, res) => {
  console.error('API-Proxy-Fehler:', err);
  if (res && !res.headersSent) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Proxy error: ' + err.message }));
  }
});

apiProxy.on('proxyReq', (proxyReq, req, res) => {
  console.log('HTTP-API-Request für:', req.url, req.method);
  
  // CORS-Headers setzen
  res.setHeader('Access-Control-Allow-Origin', 'https://iqmedix.cloud');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Upgrade, Connection, Sec-WebSocket-Key, Sec-WebSocket-Version, Sec-WebSocket-Protocol, Origin');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Max-Age', '86400');
  
  // OPTIONS Preflight Request
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  
  // Authorization Header weiterleiten
  if (req.headers.authorization) {
    proxyReq.setHeader('Authorization', req.headers.authorization);
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
    console.log('Pfad angepasst von', originalUrl, 'zu', newPath);
  }
});

apiProxy.on('proxyRes', (proxyRes, req, res) => {
  console.log('HTTP-API-Response:', proxyRes.statusCode, 'für', req.url);
  
  // CORS-Headers auch in Response setzen
  res.setHeader('Access-Control-Allow-Origin', 'https://iqmedix.cloud');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
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
    console.log('SSL-Zertifikate für API-Proxy geladen');
  }
} catch (error) {
  console.log('SSL-Zertifikate für API-Proxy nicht verfügbar, verwende HTTP');
}

// HTTP-Server für API-Requests
const httpServer = http.createServer((req, res) => {
  // Nur API-Pfade erlauben
  if (req.url.startsWith('/api/')) {
    apiProxy.web(req, res);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Nur API-Pfade erlaubt');
  }
});

// HTTPS-Server für API-Requests (falls SSL verfügbar)
let httpsServer = null;
if (sslOptions) {
  httpsServer = https.createServer(sslOptions, (req, res) => {
    // Nur API-Pfade erlauben
    if (req.url.startsWith('/api/')) {
      apiProxy.web(req, res);
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Nur API-Pfade erlaubt');
    }
  });
}

// Server starten
const HTTP_PORT = process.env.API_HTTP_PORT || 8081;
const HTTPS_PORT = process.env.API_HTTPS_PORT || 8444;

httpServer.listen(HTTP_PORT, () => {
  console.log(`HTTP API-Proxy läuft auf Port ${HTTP_PORT}`);
  console.log(`Leitet API-Anfragen an http://localhost:8000 weiter`);
});

if (httpsServer) {
  httpsServer.listen(HTTPS_PORT, () => {
    console.log(`HTTPS API-Proxy läuft auf Port ${HTTPS_PORT}`);
    console.log(`Leitet API-Anfragen an http://localhost:8000 weiter`);
  });
} else {
  console.log('HTTPS API-Proxy nicht verfügbar - nur HTTP aktiv');
}

// Graceful Shutdown
process.on('SIGTERM', () => {
  console.log('API-Proxy wird beendet...');
  httpServer.close(() => {
    console.log('HTTP API-Proxy beendet');
  });
  if (httpsServer) {
    httpsServer.close(() => {
      console.log('HTTPS API-Proxy beendet');
    });
  }
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('API-Proxy wird beendet...');
  httpServer.close(() => {
    console.log('HTTP API-Proxy beendet');
  });
  if (httpsServer) {
    httpsServer.close(() => {
      console.log('HTTPS API-Proxy beendet');
    });
  }
  process.exit(0);
}); 