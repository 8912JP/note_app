#!/bin/bash

echo "🚀 Flutter WASM Build für Note-App..."

# Flutter WASM Build
echo "📦 Erstelle WASM Build..."
flutter build web --wasm --base-href /app/

if [ $? -eq 0 ]; then
    echo "✅ WASM Build erfolgreich erstellt!"
    
    # In htdocs/app/ kopieren
    echo "📁 Kopiere Build in htdocs/app/..."
    cp -r build/web/* backend/htdocs/app/
    
    if [ $? -eq 0 ]; then
        echo "✅ Build erfolgreich in htdocs/app/ kopiert!"
        echo "🌐 App ist jetzt unter https://iqmedix.cloud/app/ verfügbar"
    else
        echo "❌ Fehler beim Kopieren in htdocs/app/"
        exit 1
    fi
else
    echo "❌ WASM Build fehlgeschlagen!"
    exit 1
fi





