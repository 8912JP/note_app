@echo off
echo 🚀 Starte Web-Build...

REM Aktuelle Zeit für Build-Zeitstempel
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set BUILD_DATE=%%a-%%b-%%c
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set BUILD_TIME=!BUILD_DATE! %%a:%%b

echo 📅 Build-Zeit: %BUILD_TIME%

REM Flutter Web Build mit Build-Zeit
flutter build web --dart-define=BUILD_TIME="%BUILD_TIME%"

echo ✅ Web-Build abgeschlossen!
echo 📁 Build-Ordner: build/web/
pause
