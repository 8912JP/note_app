from sqlalchemy.orm import Session
from sqlalchemy import desc
import models
import schemas

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
        user_id=user_id
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

    for attr, val in note_in.dict(exclude_unset=True).items():
        if attr != "labels":
            setattr(db_note, attr, val)

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
