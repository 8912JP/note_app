from sqlalchemy.orm import Session
from sqlalchemy import desc
from fastapi import HTTPException
import models
import schemas
from models import CrmEntry
from schemas import CrmEntryCreate, CrmEntryUpdate
import uuid

# ============================
# 📋 Alle Notizen
# ============================

def get_all_notes(db: Session):
    return db.query(models.Note).order_by(desc(models.Note.created_at)).all()

def get_notes_for_user(db: Session, user_id: int):
    return (
        db.query(models.Note)
        .filter(models.Note.user_id == user_id)
        .order_by(desc(models.Note.created_at))
        .all()
    )

# ============================
# 🏷️ Label-Helper
# ============================

def create_label_if_not_exists(db: Session, name: str):
    label = db.query(models.Label).filter(models.Label.name == name).first()
    if not label:
        label = models.Label(name=name)
        db.add(label)
        db.commit()
        db.refresh(label)
    return label

# ============================
# 🆕 Erstellen
# ============================

def create_note(db: Session, note_in: schemas.NoteCreate, user_id: int):
    db_note = models.Note(
        first_name=note_in.first_name,
        last_name=note_in.last_name,
        email=note_in.email,
        telephone=note_in.telephone,
        address=note_in.address,
        note_text=note_in.note_text,
        custom_date=note_in.custom_date,
        gender=note_in.gender,
        user_id=user_id,
        crm_entry_id=note_in.crm_entry_id,
        tracking_type=note_in.tracking_type,
    )
    db.add(db_note)
    db.commit()
    db.refresh(db_note)

    for name in note_in.labels:
        label = create_label_if_not_exists(db, name)
        db_note.labels.append(label)

    db.commit()
    db.refresh(db_note)
    return db_note

# ============================
# ✏️ Bearbeiten
# ============================

def update_note(db: Session, note_id: int, note_in: schemas.NoteUpdate):
    db_note = db.query(models.Note).filter(models.Note.id == note_id).first()
    if not db_note:
        return None

    update_data = note_in.dict(exclude_unset=True)
    print('Update Note:', update_data)  # Logging für Debug

    for attr, val in update_data.items():
        if attr != "labels":
            # crm_entry_id und tracking_type nur überschreiben, wenn nicht None
            if attr in ["crm_entry_id", "tracking_type"] and val is None:
                continue
            setattr(db_note, attr, val)

    # Speziell für is_done, falls es im Update enthalten ist
    if 'is_done' in update_data:
        db_note.is_done = update_data['is_done']

    if note_in.labels is not None:
        db_note.labels.clear()
        for name in note_in.labels:
            label = create_label_if_not_exists(db, name)
            db_note.labels.append(label)

    db.commit()
    db.refresh(db_note)
    return db_note

# ============================
# 🗑️ Löschen
# ============================

def delete_note(db: Session, note_id: int):
    db_note = db.query(models.Note).filter(models.Note.id == note_id).first()
    if not db_note:
        return False
    db.delete(db_note)
    db.commit()
    return True

# ============================
# 🔍 Einzelne Notiz
# ============================

def get_note_by_id(db: Session, note_id: int):
    return db.query(models.Note).filter(models.Note.id == note_id).first()

def get_all_crm_entries(db: Session):
    return db.query(CrmEntry).order_by(desc(CrmEntry.anfrage_datum), desc(CrmEntry.id)).all()

def create_crm_entry(db: Session, entry: CrmEntryCreate):
    # 🛠️ ToDoItems als Liste von Dicts extrahieren:
    entry_data = entry.model_dump()
    if entry_data.get("todos"):
        entry_data["todos"] = [todo.model_dump() for todo in entry.todos]

    # Setze anfrage_datum auf aktuelles Datum, falls nicht gesetzt
    if not entry_data.get("anfrage_datum"):
        from datetime import datetime
        entry_data["anfrage_datum"] = datetime.now()

    # Keine spezielle Behandlung für bearbeiter_history nötig

    db_entry = CrmEntry(**entry_data)
    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    return db_entry


def update_crm_entry(db: Session, entry_id: str, updated_entry: CrmEntryUpdate):
    db_entry = db.query(models.CrmEntry).filter(models.CrmEntry.id == entry_id).first()
    if not db_entry:
        raise HTTPException(status_code=404, detail="Eintrag nicht gefunden")

    # Spezielle Behandlung für Bearbeiter-Feld: Alle Bearbeiter sammeln
    if hasattr(updated_entry, 'bearbeiter') and updated_entry.bearbeiter is not None:
        current_bearbeiter = db_entry.bearbeiter or ""
        new_bearbeiter = updated_entry.bearbeiter
        
        # Wenn sich der Bearbeiter geändert hat, füge den neuen zur Liste hinzu
        if new_bearbeiter and new_bearbeiter != current_bearbeiter:
            # Sammle alle bestehenden Bearbeiter
            all_bearbeiter = []
            if current_bearbeiter:
                all_bearbeiter = [b.strip() for b in current_bearbeiter.split(',') if b.strip()]
            
            # Füge neuen Bearbeiter hinzu, falls noch nicht vorhanden
            if new_bearbeiter not in all_bearbeiter:
                all_bearbeiter.append(new_bearbeiter)
            
            # Aktualisiere das bearbeiter-Feld mit allen Bearbeitern
            updated_entry.bearbeiter = ', '.join(all_bearbeiter)

    # Aktualisiere alle Felder
    for key, value in updated_entry.dict(exclude_unset=True).items():
        setattr(db_entry, key, value)

    db.commit()
    db.refresh(db_entry)
    return db_entry

def create_crm_entry_from_email(db, anrede, vorname, nachname, mobil, email, nachricht, infos, strasse=None, hausnummer=None, plz=None, ort=None, land=None, informationsgebiet=None, einverstaendnis=None, betreff=None, anfrage_datum=None, kontaktquelle=None, email_message_id=None):
    # Verbesserte Duplikat-Prüfung: Suche nach ähnlichen Einträgen
    from datetime import datetime, timedelta
    
    # Prüfe zuerst auf Message-ID (eindeutigster Indikator)
    if email_message_id:
        existing_entry = db.query(CrmEntry).filter(
            CrmEntry.email_message_id == email_message_id
        ).first()
        
        if existing_entry:
            print(f"⚠️ Duplikat gefunden (Message-ID): E-Mail {email_message_id} bereits verarbeitet")
            return existing_entry
    
    if anfrage_datum:
        # Erweiterte Zeitfenster-Prüfung (±2 Stunden statt ±1 Stunde)
        time_window_start = anfrage_datum - timedelta(hours=2)
        time_window_end = anfrage_datum + timedelta(hours=2)
        
        # Prüfe auf Duplikate basierend auf mehreren Kriterien
        existing_entries = db.query(CrmEntry).filter(
            CrmEntry.email == email,
            CrmEntry.anfrage_datum >= time_window_start,
            CrmEntry.anfrage_datum <= time_window_end
        ).all()
        
        # Wenn E-Mail-Adresse und Zeitfenster übereinstimmen, prüfe weitere Kriterien
        for existing_entry in existing_entries:
            # Prüfe auf identischen Betreff
            if existing_entry.betreff == betreff:
                print(f"⚠️ Duplikat gefunden (Betreff): E-Mail '{betreff}' von {email} bereits verarbeitet")
                return existing_entry
            
            # Prüfe auf ähnliche Nachricht (erste 50 Zeichen)
            if (existing_entry.nachricht and nachricht and 
                existing_entry.nachricht[:50] == nachricht[:50]):
                print(f"⚠️ Duplikat gefunden (Nachricht): E-Mail von {email} mit ähnlicher Nachricht bereits verarbeitet")
                return existing_entry
            
            # Prüfe auf identische Kontaktdaten (Vorname + Nachname + E-Mail)
            if (existing_entry.vorname == vorname and 
                existing_entry.nachname == nachname and 
                existing_entry.email == email):
                print(f"⚠️ Duplikat gefunden (Kontaktdaten): E-Mail von {vorname} {nachname} ({email}) bereits verarbeitet")
                return existing_entry
    
    # Zusätzliche Prüfung: Suche nach sehr ähnlichen Einträgen in den letzten 24 Stunden
    if anfrage_datum:
        day_start = anfrage_datum - timedelta(hours=24)
        recent_entries = db.query(CrmEntry).filter(
            CrmEntry.email == email,
            CrmEntry.anfrage_datum >= day_start
        ).all()
        
        for recent_entry in recent_entries:
            # Prüfe auf identische E-Mail-Adresse und ähnlichen Zeitraum
            if recent_entry.email == email:
                print(f"⚠️ Mögliches Duplikat: E-Mail von {email} bereits in den letzten 24 Stunden verarbeitet")
                return recent_entry
    
    entry = CrmEntry(
        id=str(uuid.uuid4()),
        titel=anrede,
        vorname=vorname,
        nachname=nachname,
        mobil=mobil,
        email=email,
        nachricht=nachricht,
        infos=infos,
        informationsgebiet=informationsgebiet,
        einverstaendnis=einverstaendnis,
        betreff=betreff,
        anfrage_datum=anfrage_datum,
        strasse=strasse,
        hausnummer=hausnummer,
        plz=plz,
        ort=ort,
        land=land,
        status='Auto Email',
        kontaktquelle=kontaktquelle,
        email_message_id=email_message_id,  # Message-ID hinzufügen
        # Keine spezielle Behandlung für bearbeiter_history nötig
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    print(f"✅ Neuer CRM-Eintrag erstellt: {betreff} von {email} (Message-ID: {email_message_id})")
    
    # WebSocket-Broadcast für neue CRM-Einträge
    try:
        # Import hier, um zirkuläre Imports zu vermeiden
        from main import broadcast_update
        
        # Konvertiere CRM-Eintrag zu Dict für JSON-Serialisierung
        crm_dict = {
            'id': entry.id,
            'anfrage_datum': entry.anfrage_datum.isoformat() if entry.anfrage_datum else None,
            'titel': entry.titel,
            'vorname': entry.vorname,
            'nachname': entry.nachname,
            'email': entry.email,
            'mobil': entry.mobil,
            'festnetz': entry.festnetz,
            'krankheitsstatus': entry.krankheitsstatus,
            'todos': entry.todos,
            'status': entry.status,
            'bearbeiter': entry.bearbeiter,
            'wiedervorlage': entry.wiedervorlage.isoformat() if entry.wiedervorlage else None,
            'typ': entry.typ,
            'stadium': entry.stadium,
            'kontaktquelle': entry.kontaktquelle,
            'erledigt': entry.erledigt,
            'infos': entry.infos,
            'nachricht': entry.nachricht,
            'informationsgebiet': entry.informationsgebiet,
            'einverstaendnis': entry.einverstaendnis,
            'betreff': entry.betreff,
            'strasse': entry.strasse,
            'hausnummer': entry.hausnummer,
            'plz': entry.plz,
            'ort': entry.ort,
            'land': entry.land,
            'rolle': entry.rolle,
            'rabatt': entry.rabatt,
            'krankenversicherung': entry.krankenversicherung,
            'test': entry.test,
            'email_message_id': entry.email_message_id,
            'email_processed_at': entry.email_processed_at.isoformat() if entry.email_processed_at else None,
        }
        
        # Sende WebSocket-Event asynchron
        import asyncio
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # Wenn Loop läuft, erstelle Task
                loop.create_task(broadcast_update({
                    "event": "crm_created",
                    "id": entry.id,
                    "crm_entry": crm_dict,
                    "user": "email_system",
                    "timestamp": str(datetime.now())
                }))
            else:
                # Wenn Loop nicht läuft, führe direkt aus
                asyncio.run(broadcast_update({
                    "event": "crm_created",
                    "id": entry.id,
                    "crm_entry": crm_dict,
                    "user": "email_system",
                    "timestamp": str(datetime.now())
                }))
        except RuntimeError:
            # Fallback: Verwende asyncio.run
            asyncio.run(broadcast_update({
                "event": "crm_created",
                "id": entry.id,
                "crm_entry": crm_dict,
                "user": "email_system",
                "timestamp": str(datetime.now())
            }))
        
        print(f"📡 WebSocket-Event gesendet: crm_created für {entry.id}")
        
    except Exception as e:
        print(f"⚠️ Fehler beim WebSocket-Broadcast: {e}")
        # Fehler beim WebSocket-Broadcast sollte nicht die E-Mail-Verarbeitung stoppen
    
    return entry

# ============================
# 🗑️ Löschen CRM
# ============================
def delete_crm_entry(db: Session, entry_id: str):
    db_entry = db.query(CrmEntry).filter(CrmEntry.id == entry_id).first()
    if not db_entry:
        return False
    db.delete(db_entry)
    db.commit()
    return True