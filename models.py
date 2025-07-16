# models.py

from sqlalchemy import Column, Integer, String, Date, Boolean, Table, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from database import Base
import datetime

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
