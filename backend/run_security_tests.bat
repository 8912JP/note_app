@echo off
chcp 65001 >nul
echo.
echo ========================================
echo 🔒 SICHERHEITSTEST FÜR NOTE APP
echo ========================================
echo.

REM Prüfe ob Python installiert ist
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python ist nicht installiert oder nicht im PATH
    echo Bitte installieren Sie Python von https://python.org
    pause
    exit /b 1
)

REM Prüfe ob requests installiert ist
python -c "import requests" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  requests Modul fehlt - installiere...
    pip install requests
    if errorlevel 1 (
        echo ❌ Fehler beim Installieren von requests
        pause
        exit /b 1
    )
)

echo ✅ Python und requests sind verfügbar
echo.

REM Wechsle ins Backend-Verzeichnis
cd /d "%~dp0"

echo 📋 Führe grundlegende Sicherheitstests aus...
echo.
python security_test.py
echo.

echo.
echo 📋 Führe erweiterte Sicherheitstests aus...
echo.
python advanced_security_test.py
echo.

echo.
echo ========================================
echo 📊 TESTS ABGESCHLOSSEN
echo ========================================
echo.
echo 📄 Berichte wurden gespeichert:
echo    - security_report.json
echo    - advanced_security_report.json
echo.
echo 🌐 Externe Tests können Sie hier durchführen:
echo    - SSL Test: https://www.ssllabs.com/ssltest/
echo    - Security Headers: https://securityheaders.com/
echo    - Mozilla Observatory: https://observatory.mozilla.org/
echo.
echo Drücken Sie eine beliebige Taste zum Beenden...
pause >nul
