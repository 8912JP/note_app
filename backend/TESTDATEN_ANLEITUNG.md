# CRM Testdaten Generator - Anleitung

## 📋 Übersicht
Das Skript `generate_test_data.py` generiert realistische Testdaten für das CRM-System:
- **300 Einträge für 2024**
- **300 Einträge für 2025**
- Realistische deutsche Namen, Adressen und Kontaktdaten
- Verschiedene Krankheitsstatus, Stadien und Bearbeiter
- Verwendet die aktuellen Status- und Kontaktquellen-Werte aus dem System

## 🚀 Vorbereitung

### 1. Datenbankverbindung konfigurieren
Das Skript verwendet automatisch die Datenbankverbindung aus deiner `.env` Datei:
- `DB_USER` - MariaDB Benutzername
- `DB_PASS` - MariaDB Passwort  
- `DB_HOST` - Datenbankserver
- `DB_NAME` - Datenbankname

Stelle sicher, dass deine `.env` Datei im `backend` Ordner vorhanden ist.

### 2. Abhängigkeiten installieren
Stelle sicher, dass folgende Python-Pakete installiert sind:

```bash
pip install sqlalchemy pymysql
```

## 🏃‍♂️ Ausführung

### Option 1: Direkt über Python
```bash
cd backend
python generate_test_data.py
```

### Option 2: Über HeidiSQL (Alternative)
Falls du lieber über HeidiSQL arbeiten möchtest:

1. **SQL-Dump erstellen**: Das Skript kann auch einen SQL-Dump generieren
2. **In HeidiSQL importieren**: Den generierten SQL-Code in HeidiSQL ausführen

## 📊 Generierte Daten

### Personen-Daten
- **Namen**: Realistische deutsche Vor- und Nachnamen
- **Titel**: Herr, Frau, Dr., Prof. Dr.
- **E-Mail**: Verschiedene Formate basierend auf Namen
- **Telefon**: Deutsche Mobil- und Festnetznummern

### Adressen
- **Straßen**: Häufige deutsche Straßennamen
- **Städte**: Große deutsche Städte
- **PLZ**: Realistische Postleitzahlen

### CRM-spezifische Daten
- **Krankheitsstatus**: Brustkrebs, Prostatakrebs, etc.
- **Stadium**: I-IV, Früherkennung, Nachsorge, Rezidiv
- **Status**: Offen, nicht Einsender, Einsender, Auto Email
- **Bearbeiter**: Verschiedene Ärzte und Mitarbeiter
- **Kontaktquelle**: E-Mail, Telefon, Empfehlung, Internet organisch, QS24, Sales Rakete, Facebook, Messe
- **Rolle**: Arzt, Heilpraktiker, Patient, Sonstiges

### ToDo-Items
- Realistische Aufgaben wie "Anamnesebogen ausfüllen"
- Zufällige Anzahl (0-4) pro Eintrag
- Zufälliger Status (erledigt/nicht erledigt)

## ⚠️ Wichtige Hinweise

### Daten löschen
Das Skript löscht **alle bestehenden CRM-Einträge** vor dem Einfügen der Testdaten. Stelle sicher, dass du keine wichtigen Daten hast!

### Backup erstellen
Erstelle vor der Ausführung ein Backup deiner Datenbank:

```sql
-- In HeidiSQL ausführen
CREATE TABLE crm_entries_backup AS SELECT * FROM crm_entries;
```

### Fehlerbehebung

#### Verbindungsfehler
```
❌ Fehler bei der Datenbankverbindung: (pymysql.err.OperationalError) (2003, "Can't connect to MySQL server")
```
**Lösung**: Überprüfe die DATABASE_URL und stelle sicher, dass MariaDB läuft.

#### Tabellenfehler
```
❌ Fehler beim Speichern: (pymysql.err.ProgrammingError) (1146, "Table 'database.crm_entries' doesn't exist")
```
**Lösung**: Stelle sicher, dass die Datenbanktabellen erstellt wurden (durch Ausführung von `main.py`).

## 📈 Nach der Ausführung

Nach erfolgreicher Ausführung kannst du in HeidiSQL prüfen:

```sql
-- Gesamtanzahl
SELECT COUNT(*) FROM crm_entries;

-- Nach Jahren
SELECT 
    YEAR(anfrage_datum) as Jahr,
    COUNT(*) as Anzahl
FROM crm_entries 
GROUP BY YEAR(anfrage_datum)
ORDER BY Jahr;

-- Nach Status
SELECT status, COUNT(*) as Anzahl
FROM crm_entries 
GROUP BY status
ORDER BY Anzahl DESC;

-- Nach Kontaktquelle
SELECT kontaktquelle, COUNT(*) as Anzahl
FROM crm_entries 
GROUP BY kontaktquelle
ORDER BY Anzahl DESC;



## 🔧 Anpassungen

Du kannst das Skript anpassen, um:
- Mehr/weniger Einträge zu generieren
- Andere Jahre hinzuzufügen
- Zusätzliche Felder zu befüllen
- Realistischere Daten zu erstellen

Ändere einfach die entsprechenden Listen am Anfang der Datei oder die Generierungslogik.
