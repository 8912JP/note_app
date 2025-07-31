# Deployment-Script für Backend-Dateien (PowerShell)
# Verwendung: .\deploy.ps1

# Server-Konfiguration
$SERVER = "u3071051@85.214.234.2"
$REMOTE_DIR = "/pages/d0/aa/d0017222/home"
$BACKEND_DIR = "backend"
$REMOTE_BACKEND_DIR = "/pages/d0/aa/d0017222/home/flutter-backend"

Write-Host "🚀 Starte Deployment..." -ForegroundColor Green

# Prüfe ob backend-Verzeichnis existiert
if (-not (Test-Path $BACKEND_DIR)) {
    Write-Host "❌ Backend-Verzeichnis nicht gefunden: $BACKEND_DIR" -ForegroundColor Red
    Read-Host "Drücken Sie Enter zum Beenden"
    exit 1
}

# Kopiere Backend-Dateien auf Server
Write-Host "📤 Kopiere Backend-Dateien..." -ForegroundColor Yellow
scp -r "$BACKEND_DIR\*" "$SERVER`:$REMOTE_BACKEND_DIR"

# Kopiere Server-Konfigurationsdateien
Write-Host "📤 Kopiere Server-Konfiguration..." -ForegroundColor Yellow
scp .htaccess "$SERVER`:$REMOTE_DIR/htdocs/"
scp websocket-proxy.php "$SERVER`:$REMOTE_DIR/htdocs/"
scp api-proxy.php "$SERVER`:$REMOTE_DIR/htdocs/"

# Starte Gunicorn neu
Write-Host "🔄 Starte Gunicorn neu..." -ForegroundColor Yellow
ssh $SERVER "cd $REMOTE_BACKEND_DIR && pkill -f gunicorn"
ssh $SERVER "cd $REMOTE_BACKEND_DIR && nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &"

Write-Host "✅ Deployment abgeschlossen!" -ForegroundColor Green
Write-Host "📊 Status prüfen:" -ForegroundColor Cyan
Write-Host "  ssh $SERVER 'ps aux | grep gunicorn'" -ForegroundColor Gray
Write-Host "  ssh $SERVER 'tail -f $REMOTE_BACKEND_DIR/gunicorn.log'" -ForegroundColor Gray

Read-Host "Drücken Sie Enter zum Beenden" 