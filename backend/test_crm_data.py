#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test-Skript für CRM-Daten
"""

from database import SessionLocal
from models import CrmEntry

def test_crm_data():
    """Testet, ob CRM-Daten in der Datenbank vorhanden sind"""
    print("🔍 Teste CRM-Daten in der Datenbank...")
    
    db = SessionLocal()
    try:
        # Zähle alle CRM-Einträge
        count = db.query(CrmEntry).count()
        print(f"📊 Anzahl CRM-Einträge in der Datenbank: {count}")
        
        if count > 0:
            # Zeige die ersten 3 Einträge
            entries = db.query(CrmEntry).limit(3).all()
            print("\n📋 Erste 3 CRM-Einträge:")
            for i, entry in enumerate(entries, 1):
                print(f"  {i}. ID: {entry.id}")
                print(f"     Name: {entry.vorname} {entry.nachname}")
                print(f"     Email: {entry.email}")
                print(f"     Datum: {entry.anfrage_datum}")
                print(f"     Status: {entry.status}")
                print()
        else:
            print("❌ Keine CRM-Einträge in der Datenbank gefunden!")
            
    except Exception as e:
        print(f"❌ Fehler beim Testen: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    test_crm_data()
