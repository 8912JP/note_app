#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Excel zu MariaDB Migration Tool für CRM-Daten
============================================

Dieses Skript migriert CRM-Daten aus einer Excel-Datei in die MariaDB-Datenbank.
Es unterstützt verschiedene Excel-Formate und bietet Mapping-Funktionalität.
"""

import pandas as pd
import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from database import SessionLocal, engine
from models import CrmEntry, Base
import os
import sys
from typing import Dict, Any, Optional
import logging

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('migration.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class ExcelToMariaDBMigrator:
    def __init__(self, excel_file_path: str):
        """
        Initialisiert den Migrator
        
        Args:
            excel_file_path: Pfad zur Excel-Datei
        """
        self.excel_file_path = excel_file_path
        self.db = SessionLocal()
        
    def read_excel_file(self, sheet_name: Optional[str] = None) -> pd.DataFrame:
        """
        Liest die Excel-Datei ein
        
        Args:
            sheet_name: Name des Arbeitsblatts (optional)
            
        Returns:
            DataFrame mit den Excel-Daten
        """
        try:
            if sheet_name:
                df = pd.read_excel(self.excel_file_path, sheet_name=sheet_name)
            else:
                df = pd.read_excel(self.excel_file_path)
            
            logger.info(f"Excel-Datei erfolgreich gelesen: {len(df)} Zeilen gefunden")
            logger.info(f"Spalten: {list(df.columns)}")
            return df
            
        except Exception as e:
            logger.error(f"Fehler beim Lesen der Excel-Datei: {e}")
            raise
    
    def map_excel_columns_to_db(self, df: pd.DataFrame) -> Dict[str, str]:
        """
        Zeigt die verfügbaren Spalten und lässt den Benutzer das Mapping definieren
        
        Args:
            df: DataFrame mit Excel-Daten
            
        Returns:
            Dictionary mit Mapping von Excel-Spalten zu DB-Feldern
        """
        print("\n=== VERFÜGBARE EXCEL-SPALTEN ===")
        for i, col in enumerate(df.columns, 1):
            print(f"{i}. {col}")
        
        print("\n=== VERFÜGBARE DB-FELDER ===")
        db_fields = [
            'anfrage_datum', 'titel', 'vorname', 'nachname', 'email', 'mobil', 
            'festnetz', 'krankheitsstatus', 'status', 'bearbeiter', 'wiedervorlage',
            'typ', 'stadium', 'kontaktquelle', 'infos', 'nachricht', 
            'informationsgebiet', 'einverstaendnis', 'betreff', 'strasse', 
            'hausnummer', 'plz', 'ort', 'land', 'rolle', 'rabatt', 
            'krankenversicherung', 'test'
        ]
        
        for i, field in enumerate(db_fields, 1):
            print(f"{i}. {field}")
        
        print("\n=== SPALTEN-MAPPING KONFIGURIEREN ===")
        print("Geben Sie für jede Excel-Spalte die entsprechende DB-Feldnummer ein.")
        print("Drücken Sie Enter für Spalten, die übersprungen werden sollen.")
        
        mapping = {}
        for col in df.columns:
            while True:
                try:
                    choice = input(f"Excel-Spalte '{col}' → DB-Feld (Nummer oder Enter zum Überspringen): ").strip()
                    if not choice:
                        print(f"Spalte '{col}' wird übersprungen")
                        break
                    
                    field_num = int(choice) - 1
                    if 0 <= field_num < len(db_fields):
                        mapping[col] = db_fields[field_num]
                        print(f"✓ '{col}' → '{db_fields[field_num]}'")
                        break
                    else:
                        print("Ungültige Nummer. Bitte erneut versuchen.")
                except ValueError:
                    print("Bitte eine gültige Nummer eingeben.")
        
        return mapping
    
    def convert_value(self, value, target_type: str) -> Any:
        """
        Konvertiert Werte in den korrekten Datentyp
        
        Args:
            value: Zu konvertierender Wert
            target_type: Ziel-Datentyp
            
        Returns:
            Konvertierter Wert
        """
        if pd.isna(value) or value == '':
            return None
            
        try:
            if target_type == 'datetime':
                if isinstance(value, str):
                    # Versuche verschiedene Datumsformate
                    for fmt in ['%Y-%m-%d', '%d.%m.%Y', '%d/%m/%Y', '%Y-%m-%d %H:%M:%S']:
                        try:
                            return datetime.strptime(value, fmt)
                        except ValueError:
                            continue
                    return None
                elif isinstance(value, datetime):
                    return value
                else:
                    return pd.to_datetime(value)
                    
            elif target_type == 'string':
                return str(value).strip()
                
            elif target_type == 'boolean':
                if isinstance(value, bool):
                    return value
                elif isinstance(value, str):
                    return value.lower() in ['true', '1', 'ja', 'yes', 'wahr']
                else:
                    return bool(value)
                    
            else:
                return value
                
        except Exception as e:
            logger.warning(f"Fehler bei Konvertierung von {value} zu {target_type}: {e}")
            return None
    
    def create_crm_entry(self, row: pd.Series, mapping: Dict[str, str]) -> CrmEntry:
        """
        Erstellt einen CRM-Eintrag aus einer Excel-Zeile
        
        Args:
            row: Excel-Zeile als Series
            mapping: Spalten-Mapping
            
        Returns:
            CrmEntry-Objekt
        """
        # Standardwerte
        entry_data = {
            'id': str(uuid.uuid4()),
            'erledigt': False,
            'anfrage_datum': datetime.now(timezone.utc)
        }
        
        # Mapping anwenden
        for excel_col, db_field in mapping.items():
            if excel_col in row.index:
                value = row[excel_col]
                
                # Datentyp-spezifische Konvertierung
                if db_field == 'anfrage_datum':
                    converted_value = self.convert_value(value, 'datetime')
                elif db_field in ['email', 'mobil', 'festnetz', 'strasse', 'hausnummer', 'plz', 'ort', 'land']:
                    converted_value = self.convert_value(value, 'string')
                elif db_field == 'erledigt':
                    converted_value = self.convert_value(value, 'boolean')
                else:
                    converted_value = self.convert_value(value, 'string')
                
                if converted_value is not None:
                    entry_data[db_field] = converted_value
        
        return CrmEntry(**entry_data)
    
    def migrate_data(self, mapping: Dict[str, str], batch_size: int = 100) -> int:
        """
        Führt die Migration durch
        
        Args:
            mapping: Spalten-Mapping
            batch_size: Anzahl der Einträge pro Batch
            
        Returns:
            Anzahl der migrierten Einträge
        """
        try:
            # Excel-Datei lesen
            df = self.read_excel_file()
            
            total_rows = len(df)
            migrated_count = 0
            
            logger.info(f"Starte Migration von {total_rows} Zeilen...")
            
            # Daten in Batches verarbeiten
            for i in range(0, total_rows, batch_size):
                batch_df = df.iloc[i:i+batch_size]
                batch_entries = []
                
                for _, row in batch_df.iterrows():
                    try:
                        entry = self.create_crm_entry(row, mapping)
                        batch_entries.append(entry)
                        migrated_count += 1
                        
                        if migrated_count % 10 == 0:
                            logger.info(f"Fortschritt: {migrated_count}/{total_rows} Einträge verarbeitet")
                            
                    except Exception as e:
                        logger.error(f"Fehler bei Zeile {i + len(batch_entries) + 1}: {e}")
                        continue
                
                # Batch in Datenbank speichern
                if batch_entries:
                    try:
                        self.db.add_all(batch_entries)
                        self.db.commit()
                        logger.info(f"Batch {i//batch_size + 1} erfolgreich gespeichert")
                    except Exception as e:
                        self.db.rollback()
                        logger.error(f"Fehler beim Speichern von Batch {i//batch_size + 1}: {e}")
                        # Einzelne Einträge versuchen
                        for entry in batch_entries:
                            try:
                                self.db.add(entry)
                                self.db.commit()
                            except Exception as e2:
                                self.db.rollback()
                                logger.error(f"Fehler beim Speichern einzelner Einträge: {e2}")
            
            logger.info(f"Migration abgeschlossen: {migrated_count} von {total_rows} Einträgen migriert")
            return migrated_count
            
        except Exception as e:
            logger.error(f"Fehler bei der Migration: {e}")
            raise
        finally:
            self.db.close()
    
    def preview_data(self, num_rows: int = 5) -> None:
        """
        Zeigt eine Vorschau der Excel-Daten
        
        Args:
            num_rows: Anzahl der Vorschau-Zeilen
        """
        try:
            df = self.read_excel_file()
            print(f"\n=== VORSCHAU DER ERSTEN {num_rows} ZEILEN ===")
            print(df.head(num_rows).to_string())
            print(f"\nDatentypen:")
            print(df.dtypes.to_string())
            
        except Exception as e:
            logger.error(f"Fehler bei der Vorschau: {e}")

def main():
    """
    Hauptfunktion für die Migration
    """
    print("=== EXCEL ZU MARIADB CRM MIGRATION ===")
    
    # Excel-Datei-Pfad abfragen
    excel_path = input("Pfad zur Excel-Datei: ").strip()
    
    if not os.path.exists(excel_path):
        print(f"Fehler: Datei '{excel_path}' nicht gefunden!")
        return
    
    # Migrator initialisieren
    migrator = ExcelToMariaDBMigrator(excel_path)
    
    # Vorschau anzeigen
    preview = input("\nVorschau der Daten anzeigen? (j/n): ").lower().strip()
    if preview in ['j', 'ja', 'y', 'yes']:
        migrator.preview_data()
    
    # Spalten-Mapping konfigurieren
    df = migrator.read_excel_file()
    mapping = migrator.map_excel_columns_to_db(df)
    
    if not mapping:
        print("Keine Spalten gemappt. Migration abgebrochen.")
        return
    
    # Bestätigung
    print(f"\n=== MIGRATION KONFIGURATION ===")
    print(f"Excel-Datei: {excel_path}")
    print(f"Gemappte Spalten: {len(mapping)}")
    for excel_col, db_field in mapping.items():
        print(f"  {excel_col} → {db_field}")
    
    confirm = input("\nMigration starten? (j/n): ").lower().strip()
    if confirm not in ['j', 'ja', 'y', 'yes']:
        print("Migration abgebrochen.")
        return
    
    # Migration durchführen
    try:
        migrated_count = migrator.migrate_data(mapping)
        print(f"\n✅ Migration erfolgreich abgeschlossen!")
        print(f"   {migrated_count} Einträge wurden migriert.")
        print(f"   Log-Datei: migration.log")
        
    except Exception as e:
        print(f"\n❌ Fehler bei der Migration: {e}")
        logger.error(f"Migration fehlgeschlagen: {e}")

if __name__ == "__main__":
    main()
