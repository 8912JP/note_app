# WebSocket Fehlerbehebung

## Problem
Die WebSocket-Verbindung schlägt mit HTTP 500 Fehler fehl und zeigt Port `:0` an.

## Ursachen
1. **Backend-Server läuft nicht**: Der Server unter `iqmedix.cloud` ist nicht verfügbar
2. **Port-Problem**: Flutter WebSocket-Implementierung fügt fälschlicherweise Port `:0` hinzu
3. **Firewall/Proxy**: Netzwerk-Einschränkungen blockieren WebSocket-Verbindungen

## Lösungen

### 1. WebSocket temporär deaktiviert (Standard)
Die WebSocket-Verbindung ist standardmäßig deaktiviert, um Fehler zu vermeiden.

### 2. Lokale Entwicklung aktivieren
Falls Sie einen lokalen Backend-Server haben:

```dart
// In lib/notes_overview_page.dart
void _setupWebSocket() {
  apiService.connectToWebSocket(
    onEvent: (data) {
      unawaited(_handleWebSocketEvent(data));
    },
    onError: (error) => debugPrint('❌ WebSocket Fehler: $error'),
    enableReconnect: true,
    forceEnable: true, // Aktiviert lokale WebSocket-Verbindung
  );
}
```

### 3. Backend-Server starten
Stellen Sie sicher, dass der Backend-Server läuft:

```bash
# Im backend/ Verzeichnis
cd backend
python main.py
# oder
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Produktions-Server prüfen
Testen Sie den Produktions-Server:

```bash
curl -I https://iqmedix.cloud/status
```

### 5. WebSocket manuell testen
Mit einem WebSocket-Client (z.B. wscat):

```bash
wscat -c "ws://localhost:8000/ws/notes?token=YOUR_TOKEN"
```

## Status
- ✅ WebSocket-Code korrigiert
- ✅ Fehlerbehandlung verbessert
- ✅ Temporäre Deaktivierung implementiert
- ⚠️ Backend-Server muss gestartet werden
- ⚠️ Port-Problem in Flutter WebSocket-Implementierung

## Nächste Schritte
1. Backend-Server starten
2. WebSocket mit `forceEnable: true` testen
3. Produktions-Server-Status prüfen
4. Netzwerk-Konfiguration überprüfen 