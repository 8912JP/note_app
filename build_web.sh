#!/bin/bash

# Build-Script für die Web-App mit korrekter Build-Zeit
echo "🚀 Starte Web-Build..."

# Aktuelle Zeit für Build-Zeitstempel
BUILD_TIME=$(date '+%Y-%m-%d %H:%M')

echo "📅 Build-Zeit: $BUILD_TIME"

# Flutter Web Build mit Build-Zeit
flutter build web --dart-define=BUILD_TIME="$BUILD_TIME"

echo "✅ Web-Build abgeschlossen!"
echo "📁 Build-Ordner: build/web/"
