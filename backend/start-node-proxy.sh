#!/bin/bash

# Node.js Combined Proxy Start-Skript
# Startet den kombinierten HTTP/WebSocket-Proxy

echo "=== Node.js Combined Proxy Start-Skript ==="
echo "Datum: $(date)"
echo ""

# Verzeichnis wechseln (Proxy liegt in htdocs)
cd "/pages/d0/aa/d0017222/home/htdocs"

# Prüfen ob Node.js installiert ist
if ! command -v node &> /dev/null; then
    echo "FEHLER: Node.js ist nicht installiert!"
    exit 1
fi

# Prüfen ob npm installiert ist
if ! command -v npm &> /dev/null; then
    echo "FEHLER: npm ist nicht installiert!"
    exit 1
fi

# Dependencies installieren
echo "Installiere Dependencies..."
npm install

# Prüfen ob combined-proxy.js existiert
if [ ! -f "combined-proxy.js" ]; then
    echo "FEHLER: combined-proxy.js nicht gefunden!"
    exit 1
fi

# Alte Prozesse beenden
echo "Beende alte Proxy-Prozesse..."
pkill -f "combined-proxy.js" 2>/dev/null || true
pkill -f "ws-proxy.js" 2>/dev/null || true
pkill -f "api-proxy.js" 2>/dev/null || true

# Kurz warten
sleep 2

# Ports prüfen
echo "Prüfe Ports..."
if netstat -tlnp 2>/dev/null | grep -q ":8080 "; then
    echo "WARNUNG: Port 8080 ist bereits belegt!"
fi

if netstat -tlnp 2>/dev/null | grep -q ":8443 "; then
    echo "WARNUNG: Port 8443 ist bereits belegt!"
fi

# Umgebungsvariablen setzen
export HTTP_PORT=8080
export HTTPS_PORT=8443
export NODE_ENV=production

# Combined Proxy starten
echo "Starte Combined Proxy..."
echo "HTTP-Port: $HTTP_PORT"
echo "HTTPS-Port: $HTTPS_PORT"
echo ""

# Log-Datei erstellen
LOG_FILE="combined-proxy.log"
echo "Log-Datei: $LOG_FILE"

# Combined Proxy im Hintergrund starten
nohup node combined-proxy.js > "$LOG_FILE" 2>&1 &
PROXY_PID=$!

# PID speichern
echo $PROXY_PID > combined-proxy.pid

echo "Combined Proxy gestartet mit PID: $PROXY_PID"
echo ""

# Kurz warten und Status prüfen
sleep 3

if kill -0 $PROXY_PID 2>/dev/null; then
    echo "✅ Combined Proxy läuft erfolgreich!"
    echo "PID: $PROXY_PID"
    echo "Log: $LOG_FILE"
    echo ""
    echo "Verfügbare Endpunkte:"
    echo "- HTTP API: http://localhost:8080/api/*"
    echo "- HTTPS API: https://localhost:8443/api/* (falls SSL verfügbar)"
    echo "- WebSocket: ws://iqmedix.cloud:8000/ws/* (direkt zu FastAPI)"
    echo ""
    echo "Zum Stoppen: ./stop-node-proxy.sh"
else
    echo "❌ Combined Proxy konnte nicht gestartet werden!"
    echo "Prüfe Log-Datei: $LOG_FILE"
    exit 1
fi 