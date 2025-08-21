# Backend-Server Setup

## Problem
Die Anwendung zeigt Fehler wie:
- "Server nicht verfügbar (404)"
- "Server nicht erreichbar"
- WebSocket-Verbindungsfehler

## Lösung: Backend-Server starten

### 1. Python-Umgebung prüfen
```bash
python --version
pip --version
```

### 2. Abhängigkeiten installieren
```bash
cd backend
pip install -r requirements.txt
```

### 3. Backend-Server starten
```bash
# Option 1: Mit uvicorn (empfohlen)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Option 2: Mit Python direkt
python main.py

# Option 3: Mit gunicorn (für Produktion)
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker
```

### 4. Server testen
```bash
# Status prüfen
curl http://localhost:8000/status

# API testen
curl http://localhost:8000/api/notes/
```

### 5. WebSocket aktivieren
Nachdem der Server läuft, können Sie die WebSocket-Verbindung aktivieren:

```dart
// In lib/notes_overview_page.dart
void _setupWebSocket() {
  apiService.connectToWebSocket(
    onEvent: (data) {
      unawaited(_handleWebSocketEvent(data));
    },
    onError: (error) => debugPrint('❌ WebSocket Fehler: $error'),
    enableReconnect: true,
    forceEnable: true, // Aktiviert WebSocket-Verbindung
  );
}
```

## Troubleshooting

### Port bereits belegt
```bash
# Port 8000 prüfen
netstat -an | findstr :8000

# Anderen Port verwenden
uvicorn main:app --reload --host 0.0.0.0 --port 8001
```

### Datenbank-Probleme
```bash
# SQLite-Datenbank prüfen
ls backend/notes.db

# Datenbank neu erstellen (falls nötig)
rm backend/notes.db
python -c "from database import Base, engine; Base.metadata.create_all(bind=engine)"
```

### Firewall-Probleme
- Windows Firewall für Port 8000 freigeben
- Antivirus-Software prüfen

## Status-Codes
- ✅ 200: Erfolg
- ❌ 401: Nicht autorisiert (Token ungültig)
- ❌ 404: Server nicht verfügbar
- ❌ 500: Server-Fehler

## Nächste Schritte
1. Backend-Server starten
2. Flutter-App neu starten
3. WebSocket mit `forceEnable: true` aktivieren
4. API-Aufrufe testen 