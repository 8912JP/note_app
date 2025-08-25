#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test-Skript für Excel-Migration
===============================

Erstellt eine Test-Excel-Datei mit Beispieldaten für die Migration.
"""

import pandas as pd
import os
from datetime import datetime, timedelta
import random

def create_test_excel():
    """
    Erstellt eine Test-Excel-Datei mit CRM-Beispieldaten
    """
    
    # Beispieldaten
    test_data = {
        'Vorname': [
            'Max', 'Anna', 'Thomas', 'Maria', 'Peter', 'Lisa', 'Michael', 'Sabine',
            'Klaus', 'Petra', 'Hans', 'Monika', 'Wolfgang', 'Ursula', 'Dieter'
        ],
        'Nachname': [
            'Müller', 'Schmidt', 'Weber', 'Wagner', 'Fischer', 'Meyer', 'Schulz',
            'Becker', 'Hoffmann', 'Schäfer', 'Koch', 'Bauer', 'Richter', 'Klein',
            'Wolf'
        ],
        'E-Mail': [
            'max.mueller@email.de', 'anna.schmidt@email.de', 'thomas.weber@email.de',
            'maria.wagner@email.de', 'peter.fischer@email.de', 'lisa.meyer@email.de',
            'michael.schulz@email.de', 'sabine.becker@email.de', 'klaus.hoffmann@email.de',
            'petra.schaefer@email.de', 'hans.koch@email.de', 'monika.bauer@email.de',
            'wolfgang.richter@email.de', 'ursula.klein@email.de', 'dieter.wolf@email.de'
        ],
        'Telefon': [
            '0170-1234567', '0171-2345678', '0172-3456789', '0173-4567890',
            '0174-5678901', '0175-6789012', '0176-7890123', '0177-8901234',
            '0178-9012345', '0179-0123456', '0151-1234567', '0152-2345678',
            '0153-3456789', '0154-4567890', '0155-5678901'
        ],
        'Adresse': [
            'Musterstraße 1, 12345 Berlin', 'Beispielweg 5, 23456 Hamburg',
            'Testallee 10, 34567 München', 'Demoschneise 15, 45678 Köln',
            'Probestraße 20, 56789 Frankfurt', 'Versuchweg 25, 67890 Stuttgart',
            'Übungsallee 30, 78901 Düsseldorf', 'Lerngasse 35, 89012 Dortmund',
            'Studienstraße 40, 90123 Essen', 'Forschungsweg 45, 01234 Leipzig',
            'Entwicklungsallee 50, 12345 Dresden', 'Innovationsgasse 55, 23456 Bremen',
            'Kreativstraße 60, 34567 Hannover', 'Ideenweg 65, 45678 Nürnberg',
            'Visionenallee 70, 56789 Mannheim'
        ],
        'Status': [
            'Neu', 'In Bearbeitung', 'Wartend', 'Abgeschlossen', 'Storniert',
            'Neu', 'In Bearbeitung', 'Wartend', 'Abgeschlossen', 'Storniert',
            'Neu', 'In Bearbeitung', 'Wartend', 'Abgeschlossen', 'Storniert'
        ],
        'Bearbeiter': [
            'Dr. Meyer', 'Dr. Schmidt', 'Dr. Weber', 'Dr. Wagner', 'Dr. Fischer',
            'Dr. Meyer', 'Dr. Schmidt', 'Dr. Weber', 'Dr. Wagner', 'Dr. Fischer',
            'Dr. Meyer', 'Dr. Schmidt', 'Dr. Weber', 'Dr. Wagner', 'Dr. Fischer'
        ],
        'Krankheitsstatus': [
            'Verdacht auf Brustkrebs', 'Nachsorge', 'Risikopatient', 'Gesund',
            'Verdacht auf Brustkrebs', 'Nachsorge', 'Risikopatient', 'Gesund',
            'Verdacht auf Brustkrebs', 'Nachsorge', 'Risikopatient', 'Gesund',
            'Verdacht auf Brustkrebs', 'Nachsorge', 'Risikopatient'
        ],
        'Anfrage_Datum': [
            datetime.now() - timedelta(days=random.randint(1, 30)) for _ in range(15)
        ],
        'Kontaktquelle': [
            'Website', 'Empfehlung', 'Google', 'Facebook', 'Instagram',
            'Website', 'Empfehlung', 'Google', 'Facebook', 'Instagram',
            'Website', 'Empfehlung', 'Google', 'Facebook', 'Instagram'
        ],
        'Test_Typ': [
            'iPrevent', 'iSelect', 'iPrevent', 'iSelect', 'iPrevent',
            'iSelect', 'iPrevent', 'iSelect', 'iPrevent', 'iSelect',
            'iPrevent', 'iSelect', 'iPrevent', 'iSelect', 'iPrevent'
        ]
    }
    
    # DataFrame erstellen
    df = pd.DataFrame(test_data)
    
    # Excel-Datei speichern
    filename = 'test_crm_daten.xlsx'
    df.to_excel(filename, index=False, engine='openpyxl')
    
    print(f"✅ Test-Excel-Datei erstellt: {filename}")
    print(f"   {len(df)} Zeilen mit Beispieldaten")
    print(f"   Spalten: {list(df.columns)}")
    
    return filename

def main():
    """
    Hauptfunktion
    """
    print("=== TEST-EXCEL-DATEI ERSTELLEN ===")
    
    try:
        filename = create_test_excel()
        
        print(f"\n📋 Nächste Schritte:")
        print(f"1. Führen Sie die Migration aus:")
        print(f"   python excel_to_mariadb_migration.py")
        print(f"2. Geben Sie als Dateipfad ein: {filename}")
        print(f"3. Mappen Sie die Spalten:")
        print(f"   - Vorname → vorname (3)")
        print(f"   - Nachname → nachname (4)")
        print(f"   - E-Mail → email (5)")
        print(f"   - Telefon → mobil (6)")
        print(f"   - Adresse → strasse (20)")
        print(f"   - Status → status (9)")
        print(f"   - Bearbeiter → bearbeiter (10)")
        print(f"   - Krankheitsstatus → krankheitsstatus (8)")
        print(f"   - Anfrage_Datum → anfrage_datum (1)")
        print(f"   - Kontaktquelle → kontaktquelle (14)")
        print(f"   - Test_Typ → test (28)")
        
    except Exception as e:
        print(f"❌ Fehler beim Erstellen der Test-Datei: {e}")

if __name__ == "__main__":
    main()




