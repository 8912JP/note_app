# schemas.py

from pydantic import BaseModel
from typing import List, Optional
import datetime

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
    custom_date: Optional[datetime.date] = None
    gender: str
    labels: List[str] = []  # beim Erstellen nur Namen

class NoteCreate(NoteBase):
    pass

class NoteUpdate(NoteBase):
    is_done: Optional[bool] = None

class NoteOut(NoteBase):
    id: int
    is_done: bool
    created_at: datetime.datetime
    labels: List[Label]

    class Config:
        orm_mode = True

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
    