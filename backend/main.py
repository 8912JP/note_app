# main.py
from datetime import timedelta, datetime
import os
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
    allow_methods=["*"], allow_headers=["*"],
    allow_origin_regex=r"https?://.*"
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
@app.post("/api/token", response_model=schemas.Token)
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
@app.get("/api/notes/", response_model=List[schemas.NoteOut])
@app.get("/api/notes/", response_model=List[schemas.NoteOut])
def read_notes(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    notes = crud.get_all_notes(db)
    return [schemas.NoteOut.from_orm(n) for n in notes]

@app.post("/notes/", response_model=schemas.NoteOut, status_code=201)
@app.post("/api/notes/", response_model=schemas.NoteOut, status_code=201)
async def create_note(note: schemas.NoteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    print(f"📝 Erstelle neue Note für User: {current_user.username}")
    db_note = crud.create_note(db, note, user_id=current_user.id)
    note_data = schemas.NoteOut.from_orm(db_note)
    print(f"📡 Sende Broadcast für neue Note: {db_note.id}")
    
    # Konvertiere datetime zu String für JSON-Serialisierung
    note_dict = note_data.dict()
    if 'created_at' in note_dict and note_dict['created_at'] is not None:
        note_dict['created_at'] = note_dict['created_at'].isoformat()
    
    await broadcast_update({
        "event": "note_created", 
        "id": db_note.id,
        "note": note_dict,
        "timestamp": str(datetime.now())
    })
    return db_note

@app.put("/notes/{note_id}", response_model=schemas.NoteOut)
@app.put("/api/notes/{note_id}", response_model=schemas.NoteOut)
async def update_note(note_id: int, note: schemas.NoteUpdate, db: Session = Depends(get_db)):
    print(f"📝 Aktualisiere Note: {note_id}")
    db_note = crud.update_note(db, note_id, note)
    if not db_note:
        raise HTTPException(status_code=404, detail="Notiz nicht gefunden")
    note_data = schemas.NoteOut.from_orm(db_note)
    print(f"📡 Sende Broadcast für aktualisierte Note: {db_note.id}")
    
    # Kurze Verzögerung, damit WebSocket-Clients Zeit haben, sich zu verbinden
    import asyncio
    await asyncio.sleep(0.5)
    
    # Konvertiere datetime zu String für JSON-Serialisierung
    note_dict = note_data.dict()
    if 'created_at' in note_dict and note_dict['created_at'] is not None:
        note_dict['created_at'] = note_dict['created_at'].isoformat()
    
    await broadcast_update({
        "event": "note_updated", 
        "id": db_note.id,
        "note": note_dict,
        "timestamp": str(datetime.now())
    })
    return db_note

@app.delete("/notes/{note_id}", status_code=204)
@app.delete("/api/notes/{note_id}", status_code=204)
async def delete_note(note_id: int, db: Session = Depends(get_db)):
    print(f"🗑️ Lösche Note: {note_id}")
    if not crud.delete_note(db, note_id):
        raise HTTPException(status_code=404, detail="Notiz nicht gefunden")
    print(f"📡 Sende Broadcast für gelöschte Note: {note_id}")
    await broadcast_update({
        "event": "note_deleted", 
        "id": note_id,
        "timestamp": str(datetime.now())
    })

@app.get("/notes/grouped", response_model=List[List[schemas.NoteOut]])
@app.get("/api/notes/grouped", response_model=List[List[schemas.NoteOut]])
def get_grouped_notes(db: Session = Depends(get_db)):
    all_notes = db.query(Note).all()
    grouped = grouping.group_notes(all_notes)
    return [[schemas.NoteOut.from_orm(n) for n in group] for group in grouped]


clients: List[WebSocket] = []
crm_clients: List[WebSocket] = []

@app.get("/notes/{note_id}", response_model=schemas.NoteOut)
@app.get("/api/notes/{note_id}", response_model=schemas.NoteOut)
def get_note(note_id: int, db: Session = Depends(get_db)):
    note = crud.get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Notiz nicht gefunden")
    return schemas.NoteOut.from_orm(note)

@app.websocket("/ws/notes")
async def websocket_endpoint(websocket: WebSocket):
    client_id = f"client_{len(clients)}_{id(websocket)}"
    print(f"🔌 WebSocket-Verbindung angefragt: {client_id}")
    print(f"📊 Aktuelle Clients vor Verbindung: {len(clients)}")
    
    token = websocket.query_params.get("token")
    if not token:
        print(f"❌ Kein Token für {client_id}")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Token validieren & User holen – aber DB danach direkt schließen
    with SessionLocal() as db:
        payload = decode_token(token)
        if payload is None:
            print(f"❌ Ungültiger Token für {client_id}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        username = payload.get("sub")
        if not username:
            print(f"❌ Kein Username im Token für {client_id}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        user = get_user_by_username(db, username)
        if not user:
            print(f"❌ User nicht gefunden für {client_id}: {username}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    # DB geschlossen, Verbindung kann geöffnet werden
    await websocket.accept()
    clients.append(websocket)
    print(f"✅ WebSocket-Verbindung akzeptiert: {client_id} (User: {username})")
    print(f"📊 Aktive WebSocket-Clients nach Hinzufügung: {len(clients)}")
    print(f"📋 Client-IDs: {[f'client_{i}_{id(c)}' for i, c in enumerate(clients)]}")

    try:
        while True:
            message = await websocket.receive_text()
            print(f"📥 Nachricht von {client_id}: {message}")
            
            # Ping/Pong für Verbindungsüberwachung
            if message.startswith('{"type":"ping"'):
                await websocket.send_text('{"type":"pong","timestamp":"' + str(datetime.now()) + '"}')
                print(f"↪️ Pong gesendet an {client_id}")
            
    except WebSocketDisconnect:
        # Safeguard: Verbindung nur entfernen, wenn sie noch registriert ist
        if websocket in clients:
            clients.remove(websocket)
            print(f"🔌 WebSocket-Verbindung getrennt: {client_id}")
        else:
            print(f"⚠️ WebSocket bereits entfernt (Disconnect): {client_id}")
        print(f"📊 Verbleibende WebSocket-Clients: {len(clients)}")
        print(f"📋 Verbleibende Client-IDs: {[f'client_{i}_{id(c)}' for i, c in enumerate(clients)]}")
    except Exception as e:
        print(f"❌ WebSocket-Fehler für {client_id}: {e}")
        if websocket in clients:
            clients.remove(websocket)
        else:
            print(f"⚠️ WebSocket bereits entfernt (Fehlerpfad): {client_id}")
        print(f"📊 Verbleibende WebSocket-Clients nach Fehler: {len(clients)}")
        print(f"📋 Verbleibende Client-IDs: {[f'client_{i}_{id(c)}' for i, c in enumerate(clients)]}")


@app.websocket("/ws/crm")
async def crm_websocket(websocket: WebSocket):
    client_id = f"crm_client_{len(crm_clients)}_{id(websocket)}"
    print(f"🔌 CRM WebSocket-Verbindung angefragt: {client_id}")
    
    token = websocket.query_params.get("token")
    if not token:
        print(f"❌ Kein Token für CRM {client_id}")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Authentifiziere kurz mit temporärer DB-Session
    with SessionLocal() as db:
        payload = decode_token(token)
        if payload is None:
            print(f"❌ Ungültiger Token für CRM {client_id}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        username = payload.get("sub")
        if not username:
            print(f"❌ Kein Username im Token für CRM {client_id}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        user = get_user_by_username(db, username)
        if not user:
            print(f"❌ User nicht gefunden für CRM {client_id}: {username}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    # DB ist geschlossen, Verbindung kann weitergehen
    await websocket.accept()
    crm_clients.append(websocket)
    print(f"✅ CRM WebSocket-Verbindung akzeptiert: {client_id} (User: {username})")
    print(f"📊 Aktive CRM WebSocket-Clients: {len(crm_clients)}")

    try:
        while True:
            message = await websocket.receive_text()
            print(f"📥 CRM Nachricht von {client_id}: {message}")
            
            # Ping/Pong für Verbindungsüberwachung
            if message.startswith('{"type":"ping"'):
                await websocket.send_text('{"type":"pong","timestamp":"' + str(datetime.now()) + '"}')
                print(f"↪️ CRM Pong gesendet an {client_id}")
            
    except WebSocketDisconnect:
        crm_clients.remove(websocket)
        print(f"🔌 CRM WebSocket-Verbindung getrennt: {client_id}")
        print(f"📊 Verbleibende CRM WebSocket-Clients: {len(crm_clients)}")
    except Exception as e:
        print(f"❌ CRM WebSocket-Fehler für {client_id}: {e}")
        if websocket in crm_clients:
            crm_clients.remove(websocket)
        print(f"📊 Verbleibende CRM WebSocket-Clients: {len(crm_clients)}")

async def broadcast_update(data: dict):
    print(f"📡 Broadcast an {len(clients)} Clients: {data}")
    print(f"📋 Client-IDs vor Broadcast: {[f'client_{i}_{id(c)}' for i, c in enumerate(clients)]}")
    
    if len(clients) == 0:
        print("⚠️ Keine WebSocket-Clients verbunden - Broadcast wird nicht gesendet")
        return
    
    to_remove = []
    for i, client in enumerate(clients):
        try:
            print(f"📤 Sende Broadcast an Client {i} (ID: client_{i}_{id(client)})")
            await client.send_json(data)
            print(f"✅ Broadcast erfolgreich an Client {i}")
        except Exception as e:
            print(f"❌ Broadcast-Fehler an Client {i}: {e}")
            print(f"❌ Fehler-Typ: {type(e).__name__}")
            to_remove.append(client)
    
    # Entferne tote Verbindungen
    for c in to_remove:
        if c in clients:
            clients.remove(c)
            print(f"🗑️ Tote WebSocket-Verbindung entfernt")
    
    print(f"📊 Verbleibende WebSocket-Clients nach Broadcast: {len(clients)}")
    print(f"📋 Verbleibende Client-IDs: {[f'client_{i}_{id(c)}' for i, c in enumerate(clients)]}")

async def broadcast_crm_update(data: dict):
    print(f"📡 CRM Broadcast an {len(crm_clients)} Clients: {data}")
    to_remove = []
    for i, client in enumerate(crm_clients):
        try:
            await client.send_json(data)
            print(f"✅ CRM Broadcast erfolgreich an Client {i}")
        except Exception as e:
            print(f"❌ CRM Broadcast-Fehler an Client {i}: {e}")
            to_remove.append(client)
    
    # Entferne tote Verbindungen
    for c in to_remove:
        if c in crm_clients:
            crm_clients.remove(c)
            print(f"🗑️ Tote CRM WebSocket-Verbindung entfernt")
    
    print(f"📊 Verbleibende CRM WebSocket-Clients nach Broadcast: {len(crm_clients)}")

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

@app.delete("/crm/{entry_id}", status_code=204)
async def delete_crm_entry(entry_id: str, db: Session = Depends(get_db)):
    if not crud.delete_crm_entry(db, entry_id):
        raise HTTPException(status_code=404, detail="CRM-Eintrag nicht gefunden")

@app.get("/status")
@app.get("/api/status")
def status_check():
    return {"status": "ok", "message": "Server is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": "2025-07-30"}

@app.get("/public/status")
def public_status():
    return {"status": "public", "message": "This endpoint is public"}

@app.get("/")
def root():
    return {"message": "FastAPI Server is running", "endpoints": ["/status", "/health", "/public/status"]}

@app.get("/debug/websocket")
def debug_websocket():
    """Debug-Endpoint für WebSocket-Status"""
    return {
        "active_clients": len(clients),
        "active_crm_clients": len(crm_clients),
        "client_ids": [f"client_{i}_{id(client)}" for i, client in enumerate(clients)],
        "crm_client_ids": [f"crm_client_{i}_{id(client)}" for i, client in enumerate(crm_clients)],
        "process_id": os.getpid(),
    }

@app.get("/api/debug/websocket")
def debug_websocket_api():
    """Debug-Endpoint für WebSocket-Status (API-Route)"""
    return {
        "active_clients": len(clients),
        "active_crm_clients": len(crm_clients),
        "client_ids": [f"client_{i}_{id(client)}" for i, client in enumerate(clients)],
        "crm_client_ids": [f"crm_client_{i}_{id(client)}" for i, client in enumerate(crm_clients)],
        "process_id": os.getpid(),
    }

@app.post("/debug/broadcast")
async def debug_broadcast():
    """Debug-Endpoint für manuelle Broadcast-Tests"""
    test_data = {
        "event": "test_broadcast",
        "id": 999,
        "message": "Test-Broadcast vom Server",
        "timestamp": str(datetime.now())
    }
    print(f"🧪 Manueller Broadcast-Test: {test_data}")
    await broadcast_update(test_data)
    return {"message": "Test-Broadcast gesendet", "data": test_data}

@app.post("/api/debug/broadcast")
async def debug_broadcast_api():
    """Debug-Endpoint für manuelle Broadcast-Tests (API-Route)"""
    test_data = {
        "event": "test_broadcast",
        "id": 999,
        "message": "Test-Broadcast vom Server",
        "timestamp": str(datetime.now())
    }
    print(f"🧪 Manueller Broadcast-Test (API): {test_data}")
    print(f"📊 Aktuelle Clients vor Test-Broadcast: {len(clients)}")
    await broadcast_update(test_data)
    return {"message": "Test-Broadcast gesendet", "data": test_data, "clients_count": len(clients)}

@app.post("/api/debug/test-websocket")
async def test_websocket_connection():
    """Test-Endpoint für direkte WebSocket-Tests"""
    print(f"🧪 Teste WebSocket-Verbindungen direkt...")
    print(f"📊 Aktuelle Clients: {len(clients)}")
    
    # Teste direkte Nachrichten an alle Clients
    test_message = {
        "event": "direct_test",
        "id": 888,
        "message": "Direkter WebSocket-Test",
        "timestamp": str(datetime.now())
    }
    
    success_count = 0
    for i, client in enumerate(clients):
        try:
            print(f"📤 Sende direkte Test-Nachricht an Client {i}")
            await client.send_json(test_message)
            print(f"✅ Direkte Nachricht erfolgreich an Client {i}")
            success_count += 1
        except Exception as e:
            print(f"❌ Direkte Nachricht fehlgeschlagen an Client {i}: {e}")
    
    return {
        "message": "Direkter WebSocket-Test abgeschlossen",
        "total_clients": len(clients),
        "successful_sends": success_count,
        "test_message": test_message
    }