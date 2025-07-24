# schemas.py
from pydantic import BaseModel, computed_field, field_serializer
from typing import List, Optional, Any
from datetime import datetime, date


# ---------- Label ----------

class LabelBase(BaseModel):
    name: str

class LabelCreate(LabelBase):
    pass

class Label(LabelBase):
    id: int

    class Config:
        orm_mode = True

# ---------- Note ----------

class NoteBase(BaseModel):
    first_name: str
    last_name: str
    address: Optional[str] = None
    email: Optional[str] = None
    telephone: Optional[str] = None
    note_text: str
    custom_date: Optional[date] = None
    gender: str
    labels: List[Any] = []  # Akzeptiert Strings und Label-Objekte
    crm_entry_id: Optional[str] = None
    tracking_type: Optional[str] = None

class NoteCreate(NoteBase):
    pass

class NoteUpdate(NoteBase):
    is_done: Optional[bool] = None

class NoteOut(NoteBase):
    id: int
    is_done: bool
    created_at: datetime

    class Config:
        from_attributes = True

    @field_serializer('labels')
    def serialize_labels(self, labels, _info):
        # labels kann eine Liste von Label-Objekten oder Strings sein
        return [l.name if hasattr(l, 'name') else l for l in labels]

# ---------- User ----------

class UserBase(BaseModel):
    username: str

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: int

    class Config:
        orm_mode = True

# ---------- Auth ----------

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class TokenData(BaseModel):
    username: Optional[str] = None

class ToDoItem(BaseModel):
    text: str
    done: bool = False

class CrmEntryBase(BaseModel):
    anfrage_datum: Optional[datetime]
    titel: Optional[str] = None
    vorname: Optional[str] = None
    nachname: Optional[str] = None
    email: Optional[str] = None
    mobil: Optional[str] = None
    festnetz: Optional[str] = None
    krankheitsstatus: Optional[str] = None
    todos: Optional[List[ToDoItem]] = []
    status: Optional[str] = None
    bearbeiter: Optional[str] = None
    wiedervorlage: Optional[datetime] = None
    typ: Optional[str] = None
    stadium: Optional[str] = None
    kontaktquelle: Optional[str] = None
    infos: Optional[str] = None
    nachricht: Optional[str] = None
    erledigt: bool = False
    strasse: Optional[str] = None
    hausnummer: Optional[str] = None
    plz: Optional[str] = None
    ort: Optional[str] = None
    land: Optional[str] = None

class CrmEntryCreate(CrmEntryBase):
    id: str  # Wird vom Frontend mitgegeben (z. B. UUID)

class CrmEntryOut(CrmEntryBase):
    id: str

    class Config:
        orm_mode = True

class CrmEntry(CrmEntryBase):
    id: int
    class Config:
        orm_mode = True

class CrmEntryUpdate(BaseModel):
    titel: Optional[str]
    vorname: Optional[str]
    nachname: Optional[str]
    email: Optional[str]
    mobil: Optional[str]
    festnetz: Optional[str]
    krankheitsstatus: Optional[str]
    todos: Optional[List[ToDoItem]]
    status: Optional[str]
    bearbeiter: Optional[str]
    wiedervorlage: Optional[datetime]
    typ: Optional[str]
    stadium: Optional[str]
    kontaktquelle: Optional[str]
    erledigt: Optional[bool]
    strasse: Optional[str] = None
    hausnummer: Optional[str] = None
    plz: Optional[str] = None
    ort: Optional[str] = None
    land: Optional[str] = None
    infos: Optional[str] = None
    nachricht: Optional[str] = None