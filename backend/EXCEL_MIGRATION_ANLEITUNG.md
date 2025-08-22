# Excel zu MariaDB CRM Migration - Anleitung

## Übersicht

Diese Anleitung erklärt, wie Sie Ihre CRM-Daten aus einer Excel-Datei in die MariaDB-Datenbank migrieren können.

## Voraussetzungen

1. **Python-Abhängigkeiten installieren:**
   ```bash
   pip install pandas openpyxl sqlalchemy pymysql python-dotenv
   ```

2. **Umgebungsvariablen konfiguriert:**
   - Stellen Sie sicher, dass Ihre `.env`-Datei die Datenbankverbindung enthält
   - Die Datenbank muss erreichbar sein

3. **Excel-Datei bereit:**
   - Die Excel-Datei sollte im `.xlsx` oder `.xls` Format vorliegen
   - Idealerweise haben Sie eine saubere Struktur ohne leere Zeilen am Anfang

## Schritt-für-Schritt Anleitung

### 1. Migration starten

```bash
cd backend
python excel_to_mariadb_migration.py
```

### 2. Excel-Datei auswählen

Das Skript fragt nach dem Pfad zu Ihrer Excel-Datei:
```
Pfad zur Excel-Datei: /pfad/zu/ihrer/crm_daten.xlsx
```

### 3. Datenvorschau (optional)

Sie können eine Vorschau der ersten 5 Zeilen anzeigen lassen:
```
Vorschau der Daten anzeigen? (j/n): j
```

### 4. Spalten-Mapping konfigurieren

Das Skript zeigt Ihnen:
- **Verfügbare Excel-Spalten** (aus Ihrer Datei)
- **Verfügbare DB-Felder** (aus der CRM-Tabelle)

Für jede Excel-Spalte geben Sie die entsprechende DB-Feldnummer ein:

```
Excel-Spalte 'Vorname' → DB-Feld (Nummer oder Enter zum Überspringen): 3
✓ 'Vorname' → 'vorname'

Excel-Spalte 'Nachname' → DB-Feld (Nummer oder Enter zum Überspringen): 4
✓ 'Nachname' → 'nachname'

Excel-Spalte 'E-Mail' → DB-Feld (Nummer oder Enter zum Überspringen): 5
✓ 'E-Mail' → 'email'
```

### 5. Migration bestätigen

Das Skript zeigt eine Zusammenfassung:
```
=== MIGRATION KONFIGURATION ===
Excel-Datei: /pfad/zu/ihrer/crm_daten.xlsx
Gemappte Spalten: 8
  Vorname → vorname
  Nachname → nachname
  E-Mail → email
  ...

Migration starten? (j/n): j
```

### 6. Migration durchführen

Das Skript:
- Verarbeitet die Daten in Batches von 100 Einträgen
- Zeigt den Fortschritt an
- Erstellt eine Log-Datei (`migration.log`)
- Behandelt Fehler gracefully

## Verfügbare DB-Felder

| Nummer | Feldname | Beschreibung |
|--------|----------|--------------|
| 1 | anfrage_datum | Datum der Anfrage |
| 2 | titel | Titel (Dr., Prof., etc.) |
| 3 | vorname | Vorname |
| 4 | nachname | Nachname |
| 5 | email | E-Mail-Adresse |
| 6 | mobil | Mobiltelefon |
| 7 | festnetz | Festnetztelefon |
| 8 | krankheitsstatus | Aktueller Krankheitsstatus |
| 9 | status | Bearbeitungsstatus |
| 10 | bearbeiter | Zuständiger Bearbeiter |
| 11 | wiedervorlage | Wiedervorlage-Datum |
| 12 | typ | Typ der Anfrage |
| 13 | stadium | Krankheitsstadium |
| 14 | kontaktquelle | Quelle des Kontakts |
| 15 | infos | Zusätzliche Informationen |
| 16 | nachricht | Nachrichtentext |
| 17 | informationsgebiet | Informationsgebiet (z.B. Brustkrebs) |
| 18 | einverstaendnis | Datenschutzerklärung |
| 19 | betreff | E-Mail-Betreff |
| 20 | strasse | Straße |
| 21 | hausnummer | Hausnummer |
| 22 | plz | Postleitzahl |
| 23 | ort | Ort |
| 24 | land | Land |
| 25 | rolle | Rolle (Patient, Angehöriger, etc.) |
| 26 | rabatt | Rabattinformationen |
| 27 | krankenversicherung | Krankenversicherung |
| 28 | test | Testtyp (iPrevent, iSelect, etc.) |

## Datentyp-Konvertierung

Das Skript konvertiert automatisch:

- **Datum/Zeit:** Unterstützt verschiedene Formate (`YYYY-MM-DD`, `DD.MM.YYYY`, etc.)
- **Strings:** Werden getrimmt und bereinigt
- **Boolean:** Erkennt `true`, `1`, `ja`, `yes`, `wahr` als `True`
- **Leere Werte:** Werden zu `NULL` konvertiert

## Fehlerbehandlung

### Häufige Probleme:

1. **Datenbankverbindung fehlgeschlagen:**
   - Überprüfen Sie die `.env`-Datei
   - Stellen Sie sicher, dass die Datenbank erreichbar ist

2. **Excel-Datei kann nicht gelesen werden:**
   - Überprüfen Sie den Dateipfad
   - Stellen Sie sicher, dass die Datei nicht geöffnet ist
   - Überprüfen Sie das Dateiformat

3. **Spalten-Mapping-Fehler:**
   - Verwenden Sie nur gültige Nummern
   - Überspringen Sie Spalten mit Enter

4. **Datentyp-Konvertierungsfehler:**
   - Überprüfen Sie die Log-Datei für Details
   - Das Skript überspringt problematische Zeilen

## Log-Datei

Die Migration erstellt eine `migration.log`-Datei mit:
- Erfolgreiche Operationen
- Fehler und Warnungen
- Fortschrittsinformationen
- Statistiken

## Nach der Migration

1. **Daten überprüfen:**
   ```sql
   SELECT COUNT(*) FROM crm_entries;
   SELECT * FROM crm_entries LIMIT 5;
   ```

2. **Duplikate prüfen:**
   ```sql
   SELECT email, COUNT(*) 
   FROM crm_entries 
   WHERE email IS NOT NULL 
   GROUP BY email 
   HAVING COUNT(*) > 1;
   ```

3. **Datenqualität prüfen:**
   ```sql
   SELECT 
     COUNT(*) as total,
     COUNT(email) as with_email,
     COUNT(mobil) as with_mobile
   FROM crm_entries;
   ```

## Tipps für erfolgreiche Migration

1. **Excel-Datei vorbereiten:**
   - Entfernen Sie leere Zeilen am Anfang
   - Stellen Sie sicher, dass die Spaltenüberschriften eindeutig sind
   - Bereinigen Sie offensichtliche Datenfehler

2. **Testen Sie mit einer kleinen Datei:**
   - Erstellen Sie eine Test-Datei mit 5-10 Zeilen
   - Führen Sie die Migration durch
   - Überprüfen Sie die Ergebnisse

3. **Backup erstellen:**
   - Erstellen Sie ein Backup der Datenbank vor der Migration
   - Sichern Sie die ursprüngliche Excel-Datei

4. **Batch-Größe anpassen:**
   - Bei großen Dateien können Sie die Batch-Größe im Code anpassen
   - Standard: 100 Einträge pro Batch

## Support

Bei Problemen:
1. Überprüfen Sie die `migration.log`-Datei
2. Stellen Sie sicher, dass alle Abhängigkeiten installiert sind
3. Überprüfen Sie die Datenbankverbindung
4. Testen Sie mit einer kleinen Test-Datei
