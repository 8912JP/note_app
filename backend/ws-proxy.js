const http = require('http');
const httpProxy = require('http-proxy');

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

// HTTP-Server (für nicht-WebSocket-Requests)
const server = http.createServer((req, res) => {
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Nur WebSocket-Verbindungen erlaubt');
});

// WebSocket-Upgrade-Handler
server.on('upgrade', (req, socket, head) => {
  console.log('WebSocket-Upgrade angefragt für:', req.url);
  
  // Leite an Gunicorn/Uvicorn weiter
  proxy.ws(req, socket, head);
});

// Server starten
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`WebSocket-Proxy läuft auf Port ${PORT}`);
  console.log(`Leitet WebSocket-Verbindungen an ws://localhost:8000 weiter`);
}); 