# Build-Anweisungen

## Web-Build mit korrekter Version und Build-Zeit

### Für Linux/Mac:
```bash
chmod +x build_web.sh
./build_web.sh
```

### Für Windows:
```cmd
build_web.bat
```

### Manueller Build:
```bash
flutter build web --dart-define=BUILD_TIME="$(date '+%Y-%m-%d %H:%M')"
```

## Version aktualisieren

1. Version in `pubspec.yaml` ändern:
   ```yaml
   version: 1.0.0+1  # Version + Build-Nummer
   ```

2. Build ausführen mit einem der obigen Befehle

## Build-Info

Die Build-Informationen werden automatisch aus der `pubspec.yaml` gelesen:
- **Version**: Aus `version` in pubspec.yaml
- **Build-Nummer**: Aus `+1` in pubspec.yaml  
- **Build-Datum**: Wird beim Build gesetzt (nicht Login-Zeit)
- **Plattform**: Automatisch erkannt (Web/Native)

## Troubleshooting

Falls die Version nicht korrekt angezeigt wird:
1. `flutter clean` ausführen
2. `flutter pub get` ausführen
3. Build neu ausführen
