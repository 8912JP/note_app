#!/bin/bash

# Deployment-Script für Backend-Dateien
# Verwendung: ./deploy.sh

# Server-Konfiguration
SERVER="u3071051@85.214.234.2"
REMOTE_DIR="/pages/d0/aa/d0017222/home"
BACKEND_DIR="backend"
REMOTE_BACKEND_DIR="/pages/d0/aa/d0017222/home/flutter-backend"

echo "🚀 Starte Deployment..."

# Prüfe ob backend-Verzeichnis existiert
if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Backend-Verzeichnis nicht gefunden: $BACKEND_DIR"
    exit 1
fi

# Kopiere Backend-Dateien auf Server
echo "📤 Kopiere Backend-Dateien..."
rsync -avz --delete \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='venv' \
    --exclude='env' \
    "$BACKEND_DIR/" \
    "$SERVER:$REMOTE_BACKEND_DIR/"

# Kopiere Server-Konfigurationsdateien
echo "📤 Kopiere Server-Konfiguration..."
scp .htaccess "$SERVER:$REMOTE_DIR/htdocs/"
scp websocket-proxy.php "$SERVER:$REMOTE_DIR/htdocs/"
scp api-proxy.php "$SERVER:$REMOTE_DIR/htdocs/"

# Starte Gunicorn neu (falls gewünscht)
echo "🔄 Starte Gunicorn neu..."
ssh "$SERVER" "cd $REMOTE_BACKEND_DIR && pkill -f gunicorn"
ssh "$SERVER" "cd $REMOTE_BACKEND_DIR && nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &"

echo "✅ Deployment abgeschlossen!"
echo "📊 Status prüfen:"
echo "  ssh $SERVER 'ps aux | grep gunicorn'"
echo "  ssh $SERVER 'tail -f $REMOTE_BACKEND_DIR/gunicorn.log'" 