# Einfache Ausführung des CRM Testdaten Generators

## 🚀 Schnellstart

### 1. Im Backend-Ordner sein
```bash
cd backend
```

### 2. Skript ausführen
```bash
python generate_test_data.py
```

## ⚠️ Falls Fehler auftreten:

### Fehler: "No module named 'sqlalchemy'"
```bash
# Installiere die benötigten Pakete
pip install sqlalchemy pymysql python-dotenv

# Oder mit pip3
pip3 install sqlalchemy pymysql python-dotenv
```

### Fehler: "No module named 'models'"
```bash
# Stelle sicher, dass du im backend Ordner bist
pwd  # Sollte auf .../backend enden
ls   # Sollte models.py, database.py, generate_test_data.py zeigen
```

### Fehler: "No module named 'database'"
```bash
# Stelle sicher, dass alle Dateien vorhanden sind
ls -la *.py
# Sollte zeigen: database.py, models.py, generate_test_data.py
```

## 🔧 Alternative Ausführungsmethoden

### Mit Python3
```bash
python3 generate_test_data.py
```

### Mit Backend-Umgebung
```bash
# Falls dein Backend eine virtuelle Umgebung verwendet
source venv/bin/activate
python generate_test_data.py
```

### Mit uvicorn-Umgebung
```bash
# Verwende die gleiche Python-Installation wie dein Backend
uvicorn main:app --reload &
python generate_test_data.py
```

## 📊 Erwartete Ausgabe
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

## 🆘 Hilfe

Falls weiterhin Probleme auftreten:

1. **Prüfe Python-Version**: `python --version`
2. **Prüfe installierte Pakete**: `pip list | grep sqlalchemy`
3. **Prüfe Backend-Funktion**: `python -c "from database import engine; print('Backend funktioniert')"`
4. **Prüfe .env Datei**: `ls -la .env`

Das Skript verwendet jetzt die gleiche Datenbankverbindung wie dein Backend!
