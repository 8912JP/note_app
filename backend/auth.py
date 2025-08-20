from datetime import datetime, timedelta
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User
import os
from dotenv import load_dotenv

# 🔐 Lade Umgebungsvariablen (SECRET_KEY etc.)
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY", "testsecretkey")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440  # Zeit die nach der man sich wieder anmelden muss

# FastAPI OAuth2-Scheme für REST-Endpunkte
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/token", auto_error=True)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# 📦 Datenbank-Session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# 🔐 Passwort-Funktionen
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)


# 🔍 Nutzer aus DB
def get_user_by_username(db: Session, username: str):
    return db.query(User).filter(User.username == username).first()


# ✅ Login-Check für REST
def authenticate_user(db: Session, username: str, password: str):
    user = get_user_by_username(db, username)
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user


# 🔐 Token erstellen (JWT)
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


# ✅ Auth für REST-Endpunkte via Depends()
def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token ungültig oder abgelaufen",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if not username:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = get_user_by_username(db, username)
    if not user:
        raise credentials_exception
    return user


# ✅ Token-Decoder für WebSocket & andere manuelle Prüfungen
def decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None
