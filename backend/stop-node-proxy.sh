#!/bin/bash

# Node.js Combined Proxy Stop-Skript
# Stoppt den kombinierten HTTP/WebSocket-Proxy

echo "=== Node.js Combined Proxy Stop-Skript ==="
echo "Datum: $(date)"
echo ""

# Verzeichnis wechseln
cd "$(dirname "$0")"

# PID-Datei prüfen
PID_FILE="combined-proxy.pid"
if [ -f "$PID_FILE" ]; then
    PROXY_PID=$(cat "$PID_FILE")
    echo "PID aus Datei: $PROXY_PID"
    
    if kill -0 $PROXY_PID 2>/dev/null; then
        echo "Beende Combined Proxy (PID: $PROXY_PID)..."
        kill $PROXY_PID
        
        # Warten bis Prozess beendet ist
        for i in {1..10}; do
            if ! kill -0 $PROXY_PID 2>/dev/null; then
                echo "✅ Combined Proxy erfolgreich beendet!"
                rm -f "$PID_FILE"
                break
            fi
            sleep 1
        done
        
        # Falls Prozess noch läuft, hart beenden
        if kill -0 $PROXY_PID 2>/dev/null; then
            echo "WARNUNG: Prozess läuft noch, beende hart..."
            kill -9 $PROXY_PID
            rm -f "$PID_FILE"
        fi
    else
        echo "Combined Proxy läuft nicht (PID: $PROXY_PID)"
        rm -f "$PID_FILE"
    fi
else
    echo "Keine PID-Datei gefunden"
fi

# Alle Node.js-Proxy-Prozesse beenden
echo "Beende alle Node.js-Proxy-Prozesse..."
pkill -f "combined-proxy.js" 2>/dev/null || true
pkill -f "ws-proxy.js" 2>/dev/null || true
pkill -f "api-proxy.js" 2>/dev/null || true
# WebSocket-Proxy wird nicht mehr benötigt

# Kurz warten
sleep 2

# Prüfen ob noch Prozesse laufen
if pgrep -f "combined-proxy.js" > /dev/null; then
    echo "❌ Einige Proxy-Prozesse laufen noch!"
    pgrep -f "combined-proxy.js"
else
    echo "✅ Alle Proxy-Prozesse beendet!"
fi

echo ""
echo "Proxy-Status:"
echo "- Port 8080: $(netstat -tlnp 2>/dev/null | grep ":8080 " || echo "Frei")"
# Port 8081 wird nicht mehr benötigt
echo "- Port 8443: $(netstat -tlnp 2>/dev/null | grep ":8443 " || echo "Frei")" 