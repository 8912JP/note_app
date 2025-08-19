# Server-Ausführung über PuTTY

## 🚀 Vorbereitung

### 1. Dateien auf Server hochladen
Stelle sicher, dass folgende Dateien im `backend` Ordner auf dem Server vorhanden sind:
- `generate_test_data.py`
- `.env` (mit Datenbankverbindung)
- `models.py`
- `database.py`

### 2. Python-Abhängigkeiten installieren
```bash
cd backend
pip install sqlalchemy pymysql python-dotenv
```

## 🏃‍♂️ Ausführung über PuTTY

### 1. Verbindung zum Server
```bash
ssh username@your-server.com
cd /path/to/your/note_app/backend
```

### 2. Skript ausführen
```bash
python generate_test_data.py
```

### 3. Erwartete Ausgabe
```
🚀 CRM Testdaten Generator
==================================================
✅ Datenbankverbindung erfolgreich
🗑️  Lösche 0 bestehende CRM-Einträge...

📅 Generiere 300 Einträge für 2024...
   50/300 Einträge erstellt...
   100/300 Einträge erstellt...
   ...
   300/300 Einträge erstellt...

📅 Generiere 300 Einträge für 2025...
   50/300 Einträge erstellt...
   100/300 Einträge erstellt...
   ...
   300/300 Einträge erstellt...

💾 Speichere Einträge in der Datenbank...
✅ Alle Einträge erfolgreich gespeichert!

📊 Statistiken:
   Gesamt: 600 Einträge
   2024: 300 Einträge
   2025: 300 Einträge

✅ Fertig!
```

## ⚠️ Wichtige Hinweise

### Backup vor Ausführung
```bash
# Backup der bestehenden CRM-Einträge erstellen
mysql -u username -p database_name -e "CREATE TABLE crm_entries_backup AS SELECT * FROM crm_entries;"
```

### Fehlerbehebung

#### Import-Fehler
```
ModuleNotFoundError: No module named 'models'
```
**Lösung**: Stelle sicher, dass du im `backend` Ordner bist und alle Dateien vorhanden sind.

#### Datenbankverbindungsfehler
```
❌ Fehler bei der Datenbankverbindung
```
**Lösung**: Überprüfe die `.env` Datei und stelle sicher, dass MariaDB läuft.

#### Berechtigungsfehler
```
Permission denied
```
**Lösung**: Stelle sicher, dass du Schreibrechte im Verzeichnis hast.

## 📊 Nach der Ausführung

### Überprüfung in HeidiSQL
```sql
-- Gesamtanzahl prüfen
SELECT COUNT(*) FROM crm_entries;

-- Nach Jahren gruppiert
SELECT 
    YEAR(anfrage_datum) as Jahr,
    COUNT(*) as Anzahl
FROM crm_entries 
GROUP BY YEAR(anfrage_datum)
ORDER BY Jahr;

-- Status-Verteilung
SELECT status, COUNT(*) as Anzahl
FROM crm_entries 
GROUP BY status
ORDER BY Anzahl DESC;
```

### Überprüfung in der App
- Starte die Flutter-App
- Gehe zur CRM-Übersicht
- Prüfe, ob die 600 neuen Einträge angezeigt werden
- Teste die Filter- und Suchfunktionen

## 🔧 Anpassungen

### Weniger Einträge generieren
Ändere in `generate_test_data.py`:
```python
for i in range(100):  # Statt 300
```

### Andere Jahre hinzufügen
```python
# Daten für 2023 generieren
print("\n📅 Generiere 300 Einträge für 2023...")
entries_2023 = []
for i in range(300):
    entry = create_crm_entry(2023)
    entries_2023.append(entry)
```

### Nur bestimmte Jahre
```python
# Nur 2025
db.add_all(entries_2025)  # Statt entries_2024 + entries_2025
```
