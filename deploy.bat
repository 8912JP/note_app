@echo off
REM Deployment-Script für Backend-Dateien (Windows)
REM Verwendung: deploy.bat

REM Server-Konfiguration
set SERVER=u3071051@85.214.234.2
set REMOTE_DIR=/pages/d0/aa/d0017222/home
set BACKEND_DIR=backend
set REMOTE_BACKEND_DIR=/pages/d0/aa/d0017222/home/flutter-backend

echo 🚀 Starte Deployment...

REM Prüfe ob backend-Verzeichnis existiert
if not exist "%BACKEND_DIR%" (
    echo ❌ Backend-Verzeichnis nicht gefunden: %BACKEND_DIR%
    pause
    exit /b 1
)

REM Kopiere Backend-Dateien auf Server (ohne rsync)
echo 📤 Kopiere Backend-Dateien...
scp -r "%BACKEND_DIR%\*" "%SERVER%:%REMOTE_BACKEND_DIR%"

REM Kopiere Server-Konfigurationsdateien
echo 📤 Kopiere Server-Konfiguration...
scp .htaccess "%SERVER%:%REMOTE_DIR%/htdocs/"
scp websocket-proxy.php "%SERVER%:%REMOTE_DIR%/htdocs/"
scp api-proxy.php "%SERVER%:%REMOTE_DIR%/htdocs/"

REM Starte Gunicorn neu
echo 🔄 Starte Gunicorn neu...
ssh "%SERVER%" "cd %REMOTE_BACKEND_DIR% && pkill -f gunicorn"
ssh "%SERVER%" "cd %REMOTE_BACKEND_DIR% && nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &"

echo ✅ Deployment abgeschlossen!
echo 📊 Status prüfen:
echo   ssh %SERVER% "ps aux ^| grep gunicorn"
echo   ssh %SERVER% "tail -f %REMOTE_BACKEND_DIR%/gunicorn.log"

pause 