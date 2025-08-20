# Email Scheduler Anleitung

## Übersicht

Der Email-Scheduler ermöglicht die automatische, periodische Abfrage und Verarbeitung von E-Mails. Er läuft als Teil des Backend-Servers und kann auch manuell gesteuert werden.

## Funktionen

### Automatische Ausführung
- **Email-Check alle 5 Minuten**: Schnelle Überprüfung auf neue E-Mails
- **Vollständiger Check alle 30 Minuten**: Umfassende Email-Verarbeitung
- **Automatischer Start**: Der Scheduler startet automatisch beim Serverstart
- **Automatischer Stopp**: Der Scheduler stoppt sauber beim Serverstopp

### Manuelle Steuerung
- **Start/Stop**: Scheduler kann manuell gestartet und gestoppt werden
- **Status-Abfrage**: Aktueller Status und Job-Informationen
- **Manueller Trigger**: Sofortige Email-Verarbeitung auf Anfrage

## API-Endpoints

### Scheduler starten
```bash
POST /api/scheduler/start
```
Startet den Email-Scheduler.

### Scheduler stoppen
```bash
POST /api/scheduler/stop
```
Stoppt den Email-Scheduler.

### Scheduler-Status abfragen
```bash
GET /api/scheduler/status
```
Gibt den aktuellen Status und Job-Informationen zurück.

### Manueller Email-Abruf
```bash
POST /api/scheduler/trigger-email-fetch
```
Löst sofort einen Email-Abruf aus.

## Manuelle Ausführung

### Als separates Skript
```bash
cd backend
python run_scheduler.py
```

### Mit dem Hauptserver
Der Scheduler startet automatisch beim Start des FastAPI-Servers:
```bash
cd backend
python main.py
```

## Konfiguration

### Umgebungsvariablen
Stelle sicher, dass folgende Variablen in der `.env`-Datei gesetzt sind:
```
IMAP_SERVER=your-imap-server
IMAP_USER=your-email@domain.com
IMAP_PASS=your-password
SENDER_FILTER=filter@domain.com
```

### Scheduler-Einstellungen
Die Scheduler-Einstellungen können in `scheduler.py` angepasst werden:
- **Check-Intervall**: Aktuell alle 5 Minuten
- **Vollständiger Check**: Aktuell alle 30 Minuten
- **Logging**: Logs werden in `email_scheduler.log` gespeichert

## Logging

Der Scheduler erstellt detaillierte Logs:
- **Datei**: `email_scheduler.log`
- **Konsole**: Live-Ausgabe
- **Level**: INFO und höher

### Log-Beispiele
```
2024-01-15 10:00:00 - __main__ - INFO - Email Scheduler gestartet
2024-01-15 10:05:00 - __main__ - INFO - Starte Email-Abruf...
2024-01-15 10:05:02 - __main__ - INFO - Email-Abruf erfolgreich abgeschlossen
```

## Fehlerbehandlung

### Häufige Probleme
1. **IMAP-Verbindungsfehler**: Überprüfe Server-Einstellungen
2. **Authentifizierungsfehler**: Überprüfe Benutzername/Passwort
3. **Datenbankfehler**: Überprüfe Datenbankverbindung

### Debugging
```bash
# Scheduler-Status prüfen
curl http://localhost:8000/api/scheduler/status

# Manuellen Email-Abruf testen
curl -X POST http://localhost:8000/api/scheduler/trigger-email-fetch

# Logs anzeigen
tail -f email_scheduler.log
```

## Monitoring

### Status-Überwachung
Der Scheduler bietet verschiedene Monitoring-Möglichkeiten:
- **API-Endpoints**: Status-Abfrage über HTTP
- **Log-Dateien**: Detaillierte Ausführungshistorie
- **WebSocket-Updates**: Echtzeit-Updates an das Frontend

### Performance
- **Ressourcenverbrauch**: Minimal, läuft im Hintergrund
- **Skalierbarkeit**: Unterstützt mehrere gleichzeitige Jobs
- **Zuverlässigkeit**: Automatische Fehlerbehandlung und Wiederherstellung

## Sicherheit

### Zugriffskontrolle
- **API-Endpoints**: Können mit Authentifizierung geschützt werden
- **Log-Dateien**: Enthalten keine sensiblen Daten
- **Umgebungsvariablen**: Passwörter werden sicher gespeichert

### Best Practices
1. **Regelmäßige Log-Rotation**: Alte Log-Dateien bereinigen
2. **Monitoring**: Scheduler-Status regelmäßig prüfen
3. **Backup**: Konfiguration und Logs sichern
4. **Updates**: APScheduler regelmäßig aktualisieren

