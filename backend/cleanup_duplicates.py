#!/usr/bin/env python3
"""
Skript zur Bereinigung von doppelten CRM-Einträgen
"""

import sys
import os
from datetime import datetime, timedelta
from sqlalchemy import and_, or_
from database import SessionLocal
from models import CrmEntry

def cleanup_duplicates():
    """Bereinigt doppelte CRM-Einträge basierend auf verschiedenen Kriterien"""
    db = SessionLocal()
    
    try:
        print("🔍 Starte Bereinigung von doppelten CRM-Einträgen...")
        
        # 1. Finde Duplikate basierend auf E-Mail-Adresse und Zeitfenster
        print("\n📧 Suche Duplikate basierend auf E-Mail-Adresse...")
        
        # Hole alle Einträge der letzten 7 Tage
        week_ago = datetime.now() - timedelta(days=7)
        recent_entries = db.query(CrmEntry).filter(
            CrmEntry.anfrage_datum >= week_ago
        ).order_by(CrmEntry.email, CrmEntry.anfrage_datum).all()
        
        duplicates_found = []
        processed_emails = set()
        
        for entry in recent_entries:
            if not entry.email:
                continue
                
            # Prüfe auf Duplikate in einem 2-Stunden-Fenster
            time_window_start = entry.anfrage_datum - timedelta(hours=2)
            time_window_end = entry.anfrage_datum + timedelta(hours=2)
            
            similar_entries = db.query(CrmEntry).filter(
                and_(
                    CrmEntry.email == entry.email,
                    CrmEntry.anfrage_datum >= time_window_start,
                    CrmEntry.anfrage_datum <= time_window_end,
                    CrmEntry.id != entry.id  # Nicht sich selbst
                )
            ).all()
            
            for similar in similar_entries:
                # Prüfe auf identischen Betreff
                if similar.betreff == entry.betreff:
                    duplicates_found.append((entry, similar, "Betreff"))
                    break
                
                # Prüfe auf ähnliche Nachricht
                if (similar.nachricht and entry.nachricht and 
                    similar.nachricht[:50] == entry.nachricht[:50]):
                    duplicates_found.append((entry, similar, "Nachricht"))
                    break
                
                # Prüfe auf identische Kontaktdaten
                if (similar.vorname == entry.vorname and 
                    similar.nachname == entry.nachname):
                    duplicates_found.append((entry, similar, "Kontaktdaten"))
                    break
        
        # 2. Zeige gefundene Duplikate
        if duplicates_found:
            print(f"\n⚠️ Gefunden: {len(duplicates_found)} Duplikat-Paare")
            
            for i, (entry1, entry2, reason) in enumerate(duplicates_found, 1):
                print(f"\n{i}. Duplikat ({reason}):")
                print(f"   Eintrag 1: {entry1.id} - {entry1.betreff} - {entry1.email} - {entry1.anfrage_datum}")
                print(f"   Eintrag 2: {entry2.id} - {entry2.betreff} - {entry2.email} - {entry2.anfrage_datum}")
                
                # Behalte den neueren Eintrag, lösche den älteren
                if entry1.anfrage_datum > entry2.anfrage_datum:
                    to_delete = entry2
                    to_keep = entry1
                else:
                    to_delete = entry1
                    to_keep = entry2
                
                print(f"   → Behalte: {to_keep.id} (neuer)")
                print(f"   → Lösche: {to_delete.id} (älter)")
                
                # Lösche den älteren Eintrag
                db.delete(to_delete)
            
            # Änderungen speichern
            db.commit()
            print(f"\n✅ {len(duplicates_found)} Duplikate bereinigt")
        else:
            print("\n✅ Keine Duplikate gefunden")
        
        # 3. Statistiken
        total_entries = db.query(CrmEntry).count()
        recent_entries_count = db.query(CrmEntry).filter(
            CrmEntry.anfrage_datum >= week_ago
        ).count()
        
        print(f"\n📊 Statistiken:")
        print(f"   - Gesamt CRM-Einträge: {total_entries}")
        print(f"   - Einträge der letzten 7 Tage: {recent_entries_count}")
        
    except Exception as e:
        print(f"❌ Fehler bei der Bereinigung: {e}")
        db.rollback()
    finally:
        db.close()

def show_duplicates():
    """Zeigt Duplikate an ohne sie zu löschen"""
    db = SessionLocal()
    
    try:
        print("🔍 Zeige mögliche Duplikate an...")
        
        # Hole alle Einträge der letzten 7 Tage
        week_ago = datetime.now() - timedelta(days=7)
        recent_entries = db.query(CrmEntry).filter(
            CrmEntry.anfrage_datum >= week_ago
        ).order_by(CrmEntry.email, CrmEntry.anfrage_datum).all()
        
        duplicates_found = []
        
        for entry in recent_entries:
            if not entry.email:
                continue
                
            # Prüfe auf Duplikate in einem 2-Stunden-Fenster
            time_window_start = entry.anfrage_datum - timedelta(hours=2)
            time_window_end = entry.anfrage_datum + timedelta(hours=2)
            
            similar_entries = db.query(CrmEntry).filter(
                and_(
                    CrmEntry.email == entry.email,
                    CrmEntry.anfrage_datum >= time_window_start,
                    CrmEntry.anfrage_datum <= time_window_end,
                    CrmEntry.id != entry.id
                )
            ).all()
            
            for similar in similar_entries:
                # Prüfe auf identischen Betreff
                if similar.betreff == entry.betreff:
                    duplicates_found.append((entry, similar, "Betreff"))
                    break
                
                # Prüfe auf ähnliche Nachricht
                if (similar.nachricht and entry.nachricht and 
                    similar.nachricht[:50] == entry.nachricht[:50]):
                    duplicates_found.append((entry, similar, "Nachricht"))
                    break
                
                # Prüfe auf identische Kontaktdaten
                if (similar.vorname == entry.vorname and 
                    similar.nachname == entry.nachname):
                    duplicates_found.append((entry, similar, "Kontaktdaten"))
                    break
        
        if duplicates_found:
            print(f"\n⚠️ Gefunden: {len(duplicates_found)} Duplikat-Paare")
            
            for i, (entry1, entry2, reason) in enumerate(duplicates_found, 1):
                print(f"\n{i}. Duplikat ({reason}):")
                print(f"   Eintrag 1: {entry1.id} - {entry1.betreff} - {entry1.email} - {entry1.anfrage_datum}")
                print(f"   Eintrag 2: {entry2.id} - {entry2.betreff} - {entry2.email} - {entry2.anfrage_datum}")
        else:
            print("\n✅ Keine Duplikate gefunden")
            
    except Exception as e:
        print(f"❌ Fehler beim Anzeigen der Duplikate: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--show":
        show_duplicates()
    else:
        print("🔧 CRM-Duplikat-Bereinigung")
        print("Verwendung:")
        print("  python cleanup_duplicates.py --show  # Zeigt Duplikate an")
        print("  python cleanup_duplicates.py         # Bereinigt Duplikate")
        
        if len(sys.argv) == 1:
            response = input("\nMöchten Sie Duplikate bereinigen? (j/N): ")
            if response.lower() in ['j', 'ja', 'y', 'yes']:
                cleanup_duplicates()
            else:
                print("Bereinigung abgebrochen")


