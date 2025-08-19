#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CRM Testdaten Generator
Generiert realistische Testdaten für das CRM-System
"""

import random
import uuid
import json
from datetime import datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import CrmEntry, Base
import os

# Datenbankverbindung aus .env laden
from dotenv import load_dotenv
load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = 3306
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Realistische Testdaten
VORNAMEN = [
    "Anna", "Maria", "Sophie", "Julia", "Lisa", "Laura", "Sarah", "Katharina", "Claudia", "Petra",
    "Michael", "Thomas", "Andreas", "Stefan", "Martin", "Christian", "Peter", "Klaus", "Wolfgang", "Hans",
    "Sabine", "Monika", "Renate", "Brigitte", "Ursula", "Gisela", "Elke", "Karin", "Angelika", "Doris",
    "Jürgen", "Dieter", "Manfred", "Rainer", "Werner", "Horst", "Günther", "Heinz", "Karl", "Walter"
]

NACHNAMEN = [
    "Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann",
    "Schäfer", "Koch", "Bauer", "Richter", "Klein", "Wolf", "Schröder", "Neumann", "Schwarz", "Zimmermann",
    "Braun", "Krüger", "Hofmann", "Hartmann", "Lange", "Schmitt", "Werner", "Schmitz", "Krause", "Meier",
    "Lehmann", "Schmid", "Schulze", "Maier", "Köhler", "Herrmann", "König", "Walter", "Mayer", "Huber"
]



KRANKHEITSSTATUS = [
    "Brustkrebs", "Prostatakrebs", "Lungenkrebs", "Darmkrebs", "Hautkrebs", "Leukämie", "Lymphom",
    "Bauchspeicheldrüsenkrebs", "Eierstockkrebs", "Gebärmutterhalskrebs", "Hirntumor", "Knochenkrebs"
]

STADIUM = ["I", "II", "III", "IV", "Früherkennung", "Nachsorge", "Rezidiv"]

STATUS = [
    "Offen", "nicht Einsender", "Einsender", "Auto Email"
]

BEARBEITER = [
    "Dr. Schmidt", "Dr. Müller", "Dr. Weber", "Dr. Fischer", "Dr. Meyer", "Dr. Wagner",
    "Frau Schulz", "Frau Hoffmann", "Frau Koch", "Frau Bauer"
]

TYP = ["Patient", "Angehöriger", "Arzt", "Pflegekraft", "Berater"]

KONTAKTQUELLE = [
    "E-Mail", "Telefon", "Empfehlung", "Internet organisch", "QS24", "Sales Rakete", "Facebook", "Messe"
]

ROLLE = ["Arzt", "Heilpraktiker", "Patient", "Sonstiges"]

TITEL = ["Herr", "Frau", "Divers", "Dr.", "Prof."]

STRASSEN = [
    "Hauptstraße", "Bahnhofstraße", "Kirchstraße", "Schulstraße", "Gartenstraße", "Lindenstraße",
    "Dorfstraße", "Bergstraße", "Waldstraße", "Seestraße", "Mühlenstraße", "Rosenstraße"
]

ORTE = [
    "Berlin", "Hamburg", "München", "Köln", "Frankfurt", "Stuttgart", "Düsseldorf", "Dortmund",
    "Essen", "Leipzig", "Bremen", "Dresden", "Hannover", "Nürnberg", "Duisburg", "Bochum",
    "Wuppertal", "Bielefeld", "Bonn", "Mannheim", "Karlsruhe", "Wiesbaden", "Münster", "Gelsenkirchen"
]

TODO_TEXTE = [
    "Anamnesebogen ausfüllen", "Termin vereinbaren", "Unterlagen anfordern", "Rückruf", 
    "Beratungsgespräch führen", "Zweitmeinung einholen", "Kostenübernahme klären",
    "Behandlungsplan erstellen", "Nachsorge planen", "Familienangehörige informieren"
]

def generate_phone():
    """Generiert eine realistische deutsche Telefonnummer"""
    prefixes = ["0151", "0152", "0155", "0157", "0159", "0170", "0171", "0172", "0173", "0174", "0175", "0176", "0177", "0178", "0179"]
    prefix = random.choice(prefixes)
    number = ''.join([str(random.randint(0, 9)) for _ in range(8)])
    return f"{prefix} {number[:4]} {number[4:]}"

def generate_festnetz():
    """Generiert eine Festnetznummer"""
    area_codes = ["030", "040", "089", "0221", "069", "0711", "0211", "0231", "0201", "0341", "0421", "0351", "0511", "0911", "0203", "0234", "0202", "0234", "0209", "0621", "0721", "0611", "0251", "0209"]
    area_code = random.choice(area_codes)
    number = ''.join([str(random.randint(0, 9)) for _ in range(7)])
    return f"{area_code} {number[:3]} {number[3:]}"

def generate_email(vorname, nachname):
    """Generiert eine E-Mail-Adresse basierend auf Namen"""
    domains = ["gmail.com", "yahoo.de", "web.de", "t-online.de", "freenet.de", "gmx.de", "hotmail.com", "outlook.com"]
    domain = random.choice(domains)
    
    # Verschiedene E-Mail-Formate
    formats = [
        f"{vorname.lower()}.{nachname.lower()}@{domain}",
        f"{vorname.lower()}{nachname.lower()}@{domain}",
        f"{vorname.lower()}_{nachname.lower()}@{domain}",
        f"{vorname.lower()[0]}{nachname.lower()}@{domain}",
        f"{vorname.lower()}{nachname.lower()[0]}@{domain}"
    ]
    return random.choice(formats)

def generate_address():
    """Generiert eine realistische Adresse"""
    strasse = random.choice(STRASSEN)
    hausnummer = str(random.randint(1, 200))
    plz = str(random.randint(10000, 99999))
    ort = random.choice(ORTE)
    return strasse, hausnummer, plz, ort

def generate_todos():
    """Generiert realistische ToDo-Items"""
    todos = []
    num_todos = random.randint(0, 4)
    
    for _ in range(num_todos):
        text = random.choice(TODO_TEXTE)
        done = random.choice([True, False])
        todo = {
            "text": text,
            "done": done
        }
        todos.append(todo)
    
    return todos

def generate_date_in_year(year):
    """Generiert ein zufälliges Datum im angegebenen Jahr"""
    start_date = datetime(year, 1, 1)
    end_date = datetime(year, 12, 31)
    time_between = end_date - start_date
    days_between = time_between.days
    random_days = random.randint(0, days_between)
    return start_date + timedelta(days=random_days)

def generate_wiedervorlage(anfrage_datum):
    """Generiert ein Wiedervorlage-Datum basierend auf dem Anfrage-Datum"""
    if random.random() < 0.3:  # 30% Chance für Wiedervorlage
        days_ahead = random.randint(1, 90)
        return anfrage_datum + timedelta(days=days_ahead)
    return None

def create_crm_entry(year):
    """Erstellt einen einzelnen CRM-Eintrag"""
    vorname = random.choice(VORNAMEN)
    nachname = random.choice(NACHNAMEN)
    titel = random.choice(TITEL)
    
    anfrage_datum = generate_date_in_year(year)
    wiedervorlage = generate_wiedervorlage(anfrage_datum)
    
    strasse, hausnummer, plz, ort = generate_address()
    
    entry = CrmEntry(
        id=str(uuid.uuid4()),
        anfrage_datum=anfrage_datum,
        titel=titel,
        vorname=vorname,
        nachname=nachname,
        email=generate_email(vorname, nachname),
        mobil=generate_phone(),
        festnetz=generate_festnetz(),
        krankheitsstatus=random.choice(KRANKHEITSSTATUS),
        todos=json.dumps(generate_todos()),
        status=random.choice(STATUS),
        bearbeiter=random.choice(BEARBEITER),
        wiedervorlage=wiedervorlage,
        typ=random.choice(TYP),
        stadium=random.choice(STADIUM),
        kontaktquelle=random.choice(KONTAKTQUELLE),
        erledigt=random.choice([True, False]),
        infos=f"Patient meldete sich über {random.choice(KONTAKTQUELLE)}. {random.choice(['Dringend', 'Routine', 'Nachfrage'])} Anfrage.",
        nachricht=f"Sehr geehrte Damen und Herren,\n\nich interessiere mich für Informationen zu {random.choice(KRANKHEITSSTATUS)}.\n\nMit freundlichen Grüßen\n{vorname} {nachname}",
        strasse=strasse,
        hausnummer=hausnummer,
        plz=plz,
        ort=ort,
        rolle=random.choice(ROLLE)
    )
    
    return entry

def main():
    """Hauptfunktion zum Generieren der Testdaten"""
    print("🚀 CRM Testdaten Generator")
    print("=" * 50)
    
    # Datenbankverbindung herstellen
    try:
        engine = create_engine(DATABASE_URL)
        SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
        db = SessionLocal()
        
        print("✅ Datenbankverbindung erfolgreich")
    except Exception as e:
        print(f"❌ Fehler bei der Datenbankverbindung: {e}")
        print("\n📝 Bitte passe die DATABASE_URL in der Datei an:")
        print("DATABASE_URL = 'mysql+pymysql://username:password@localhost/database_name'")
        return
    
    # Bestehende Einträge löschen (optional)
    try:
        count = db.query(CrmEntry).count()
        if count > 0:
            print(f"🗑️  Lösche {count} bestehende CRM-Einträge...")
            db.query(CrmEntry).delete()
            db.commit()
            print("✅ Bestehende Einträge gelöscht")
    except Exception as e:
        print(f"⚠️  Warnung beim Löschen bestehender Einträge: {e}")
    
    # Daten für 2024 generieren
    print("\n📅 Generiere 300 Einträge für 2024...")
    entries_2024 = []
    for i in range(300):
        entry = create_crm_entry(2024)
        entries_2024.append(entry)
        if (i + 1) % 50 == 0:
            print(f"   {i + 1}/300 Einträge erstellt...")
    
    # Daten für 2025 generieren
    print("\n📅 Generiere 300 Einträge für 2025...")
    entries_2025 = []
    for i in range(300):
        entry = create_crm_entry(2025)
        entries_2025.append(entry)
        if (i + 1) % 50 == 0:
            print(f"   {i + 1}/300 Einträge erstellt...")
    
    # Alle Einträge in die Datenbank einfügen
    print("\n💾 Speichere Einträge in der Datenbank...")
    try:
        db.add_all(entries_2024 + entries_2025)
        db.commit()
        print("✅ Alle Einträge erfolgreich gespeichert!")
        
        # Statistiken anzeigen
        total_count = db.query(CrmEntry).count()
        count_2024 = db.query(CrmEntry).filter(
            CrmEntry.anfrage_datum >= datetime(2024, 1, 1),
            CrmEntry.anfrage_datum <= datetime(2024, 12, 31)
        ).count()
        count_2025 = db.query(CrmEntry).filter(
            CrmEntry.anfrage_datum >= datetime(2025, 1, 1),
            CrmEntry.anfrage_datum <= datetime(2025, 12, 31)
        ).count()
        
        print(f"\n📊 Statistiken:")
        print(f"   Gesamt: {total_count} Einträge")
        print(f"   2024: {count_2024} Einträge")
        print(f"   2025: {count_2025} Einträge")
        
    except Exception as e:
        print(f"❌ Fehler beim Speichern: {e}")
        db.rollback()
    
    finally:
        db.close()
        print("\n✅ Fertig!")

if __name__ == "__main__":
    main()
