# main.py
from datetime import timedelta
from fastapi import FastAPI, Depends, HTTPException, WebSocket, status, WebSocketDisconnect, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from database import Base, engine, SessionLocal
from models import User
import crud, schemas, auth, grouping
from auth import get_current_user
from auth import decode_token
from auth import get_user_by_username
from typing import List
from sqlalchemy.orm import Session
from models import Note, User, CrmEntry
from grouping import group_notes
from schemas import NoteOut
from schemas import CrmEntryCreate, CrmEntryOut, CrmEntryUpdate
import uuid

app = FastAPI()
Base.metadata.create_all(bind=engine)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"]
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/register/", response_model=schemas.User)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.username == user.username).first():
        raise HTTPException(status_code=400, detail="Benutzer existiert bereits")
    new_user = User(
        username=user.username,
        hashed_password=auth.get_password_hash(user.password)
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/token", response_model=schemas.Token)
def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    user = auth.authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Falscher Benutzername oder Passwort")
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    token = auth.create_access_token(data={"sub": user.username}, expires_delta=access_token_expires)
    return {"access_token": token, "token_type": "bearer"}

@app.get("/notes/", response_model=List[schemas.NoteOut])
def read_notes(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return crud.get_all_notes(db)

@app.post("/notes/", response_model=schemas.NoteOut, status_code=201)
async def create_note(note: schemas.NoteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_note = crud.create_note(db, note, user_id=current_user.id)
    await broadcast_update({"event": "note_created", "id": db_note.id})
    return db_note

@app.put("/notes/{note_id}", response_model=schemas.NoteOut)
async def update_note(note_id: int, note: schemas.NoteUpdate, db: Session = Depends(get_db)):
    db_note = crud.update_note(db, note_id, note)
    if not db_note:
        raise HTTPException(status_code=404, detail="Notiz nicht gefunden")
    await broadcast_update({"event": "note_updated", "id": db_note.id})
    return db_note

@app.delete("/notes/{note_id}", status_code=204)
async def delete_note(note_id: int, db: Session = Depends(get_db)):
    if not crud.delete_note(db, note_id):
        raise HTTPException(status_code=404, detail="Notiz nicht gefunden")
    await broadcast_update({"event": "note_deleted", "id": note_id})

@app.get("/notes/grouped", response_model=List[List[NoteOut]])
def get_grouped_notes(db: Session = Depends(get_db)):
    all_notes = db.query(Note).all()
    grouped = group_notes(all_notes)
    return grouped


clients: List[WebSocket] = []
crm_clients: List[WebSocket] = []

@app.get("/notes/{note_id}", response_model=schemas.NoteOut)
def get_note(note_id: int, db: Session = Depends(get_db)):
    note = crud.get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Notiz nicht gefunden")
    return note

@app.websocket("/ws/notes")
async def websocket_endpoint(websocket: WebSocket):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Token validieren & User holen – aber DB danach direkt schließen
    with SessionLocal() as db:
        payload = decode_token(token)
        if payload is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        username = payload.get("sub")
        if not username:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        user = get_user_by_username(db, username)
        if not user:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    # DB geschlossen, Verbindung kann geöffnet werden
    await websocket.accept()
    clients.append(websocket)

    try:
        while True:
            await websocket.receive_text()  # hält Verbindung offen
    except WebSocketDisconnect:
        clients.remove(websocket)


@app.websocket("/ws/crm")
async def crm_websocket(websocket: WebSocket):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Authentifiziere kurz mit temporärer DB-Session
    with SessionLocal() as db:
        payload = decode_token(token)
        if payload is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        username = payload.get("sub")
        if not username:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        user = get_user_by_username(db, username)
        if not user:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    # DB ist geschlossen, Verbindung kann weitergehen
    await websocket.accept()
    crm_clients.append(websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        crm_clients.remove(websocket)

async def broadcast_update(data: dict):
    to_remove = []
    for client in clients:
        try:
            await client.send_json(data)
        except:
            to_remove.append(client)
    for c in to_remove:
        clients.remove(c)

async def broadcast_crm_update(data: dict):
    to_remove = []
    for client in crm_clients:
        try:
            await client.send_json(data)
        except:
            to_remove.append(client)
    for c in to_remove:
        crm_clients.remove(c)

@app.get("/crm/", response_model=List[CrmEntryOut])
def get_crm_entries(db: Session = Depends(get_db)):
    return crud.get_all_crm_entries(db)

@app.post("/crm/", response_model=CrmEntryOut, status_code=201)
async def create_crm_entry(entry: CrmEntryCreate, db: Session = Depends(get_db)):
    created = crud.create_crm_entry(db, entry)
    await broadcast_crm_update({"event": "crm_created", "id": created.id})
    return created

@app.put("/crm/{entry_id}", response_model=CrmEntryOut)
async def update_crm_entry(entry_id: str, entry: CrmEntryUpdate, db: Session = Depends(get_db)):
    updated = crud.update_crm_entry(db, entry_id, entry)
    await broadcast_crm_update({"event": "crm_updated", "id": entry_id})
    return updated

@app.get("/status")
def status_check():
    return {"status": "ok"}