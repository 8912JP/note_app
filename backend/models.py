# models.py

from sqlalchemy import Column, Integer, String, Date, Boolean, Table, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from database import Base
import datetime
from sqlalchemy import JSON

# =======================
# 🔐 User-Modell
# =======================
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(100), unique=True, index=True)
    hashed_password = Column(String(200))

    notes = relationship("Note", back_populates="owner")

# =======================
# 🏷️ Labels & Notizen
# =======================
note_label = Table(
    "note_label", Base.metadata,
    Column("note_id", ForeignKey("notes.id"), primary_key=True),
    Column("label_id", ForeignKey("labels.id"), primary_key=True),
)

class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(100))
    last_name = Column(String(100))
    email = Column(String(100))
    telephone = Column(String(100))
    address = Column(String(200))
    note_text = Column(String(1000))
    custom_date = Column(Date, nullable=True)
    gender = Column(String(10))
    is_done = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    user_id = Column(Integer, ForeignKey("users.id"))  # 🔐 Beziehung zu User
    owner = relationship("User", back_populates="notes")

    labels = relationship("Label", secondary=note_label, back_populates="notes")

class Label(Base):
    __tablename__ = "labels"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True)

    notes = relationship("Note", secondary=note_label, back_populates="labels")

class CrmEntry(Base):
    __tablename__ = "crm_entries"

    id = Column(String(36), primary_key=True, index=True)  # UUID Länge 36
    anfrage_datum = Column(DateTime)
    titel = Column(String(255))
    vorname = Column(String(100))
    nachname = Column(String(100))
    email = Column(String(100), index=True)
    mobil = Column(String(50))
    festnetz = Column(String(50))
    krankheitsstatus = Column(String(100))
    todos = Column(JSON, nullable=True, )  # JSON als String, Länge optional je nach DB
    status = Column(String(100))
    bearbeiter = Column(String(100))
    wiedervorlage = Column(DateTime, nullable=True)
    typ = Column(String(50), nullable=True)
    stadium = Column(String(100))
    kontaktquelle = Column(String(100))
    erledigt = Column(Boolean, default=False)
    infos = Column(String(1000), nullable=True)
    nachricht = Column(String(1000), nullable=True)  # Feld für die Nachricht aus der E-Mail
    informationsgebiet = Column(String(255), nullable=True)  # z.B. Brustkrebs
    einverstaendnis = Column(String(255), nullable=True)  # Datenschutzerklärung
    betreff = Column(String(255), nullable=True)  # Betreff der E-Mail
    strasse = Column(String(255), nullable=True)
    hausnummer = Column(String(20), nullable=True)
    plz = Column(String(20), nullable=True)
    ort = Column(String(100), nullable=True)
    land = Column(String(100), nullable=True)