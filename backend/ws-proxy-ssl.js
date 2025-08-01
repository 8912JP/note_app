const https = require('https');
const http = require('http');
const httpProxy = require('http-proxy');
const fs = require('fs');
const path = require('path');

// Proxy-Konfiguration
const proxy = httpProxy.createProxyServer({
  target: 'ws://localhost:8000', // Gunicorn/Uvicorn Backend
  ws: true,
  changeOrigin: true
});

// Logging für Debugging
proxy.on('error', (err, req, res) => {
  console.error('Proxy-Fehler:', err);
});

proxy.on('proxyReqWs', (proxyReq, req, socket) => {
  console.log('WebSocket-Upgrade für:', req.url);
});

proxy.on('proxyReq', (proxyReq, req, res) => {
  console.log('HTTP-Request für:', req.url);
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
    console.log('SSL-Zertifikate geladen');
  }
} catch (error) {
  console.log('SSL-Zertifikate nicht verfügbar, verwende HTTP');
}

// HTTP-Server (für nicht-WebSocket-Requests)
const httpServer = http.createServer((req, res) => {
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Nur WebSocket-Verbindungen erlaubt');
});

// HTTPS-Server (falls SSL verfügbar)
let httpsServer = null;
if (sslOptions) {
  httpsServer = https.createServer(sslOptions, (req, res) => {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Nur WebSocket-Verbindungen erlaubt');
  });
}

// WebSocket-Upgrade-Handler für HTTP
httpServer.on('upgrade', (req, socket, head) => {
  console.log('HTTP WebSocket-Upgrade angefragt für:', req.url);
  proxy.ws(req, socket, head);
});

// WebSocket-Upgrade-Handler für HTTPS (falls verfügbar)
if (httpsServer) {
  httpsServer.on('upgrade', (req, socket, head) => {
    console.log('HTTPS WebSocket-Upgrade angefragt für:', req.url);
    proxy.ws(req, socket, head);
  });
}

// Server starten
const HTTP_PORT = process.env.HTTP_PORT || 8080;
const HTTPS_PORT = process.env.HTTPS_PORT || 8443;

httpServer.listen(HTTP_PORT, () => {
  console.log(`HTTP WebSocket-Proxy läuft auf Port ${HTTP_PORT}`);
  console.log(`Leitet WebSocket-Verbindungen an ws://localhost:8000 weiter`);
});

if (httpsServer) {
  httpsServer.listen(HTTPS_PORT, () => {
    console.log(`HTTPS WebSocket-Proxy läuft auf Port ${HTTPS_PORT}`);
    console.log(`Leitet WebSocket-Verbindungen an ws://localhost:8000 weiter`);
  });
} else {
  console.log('HTTPS nicht verfügbar - nur HTTP aktiv');
} 