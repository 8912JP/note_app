# Datei-Struktur Übersicht

## 🖥️ **Server-Dateien (htdocs/)**
```
/pages/d0/aa/d0017222/home/htdocs/
├── .htaccess                    # Apache-Konfiguration
├── websocket-proxy.php          # WebSocket-Proxy
├── api-proxy.php                # HTTP-API-Proxy
├── test-php.php                 # PHP-Test-Datei
├── websocket-debug.log          # WebSocket-Debug-Logs
└── [WordPress-Dateien]
```

## 🐍 **Backend-Dateien (Server)**
```
/pages/d0/aa/d0017222/home/flutter-backend/
├── main.py                      # FastAPI-Hauptanwendung
├── database.py                  # Datenbank-Konfiguration
├── models.py                    # SQLAlchemy Modelle
├── schemas.py                   # Pydantic Schemas
├── crud.py                      # CRUD-Operationen
├── auth.py                      # JWT-Authentifizierung
├── grouping.py                  # Notizen-Gruppierung
├── gunicorn.log                 # Gunicorn-Logs
└── [weitere Backend-Module]
```

## 📱 **Frontend-Dateien (Lokal)**
```
lib/
├── main.dart                    # App-Einstiegspunkt
├── api_service.dart             # HTTP/WebSocket API-Kommunikation
├── login_page.dart              # Login-Formular
├── register_page.dart           # Registrierung
├── notes_home_page.dart         # Hauptseite
├── notes_overview_page.dart     # Notizen-Übersicht
├── grouped_notes_page.dart      # Gruppierte Notizen
├── crm_overview_page.dart       # CRM-Übersicht
├── crm_entry_edit_form.dart     # CRM-Bearbeitung
├── statistik_page.dart          # Statistiken
├── form_page.dart               # Allgemeine Formulare
├── note.dart                    # Notiz-Model
├── crm_entry.dart               # CRM-Eintrag-Model
├── note_model.dart              # Notiz-Datenmodelle
└── [weitere UI-Komponenten]
```

## 🚀 **Deployment-Scripts (Lokal)**
```
deploy.sh                        # Automatisches Backend-Deployment
FILE_STRUCTURE.md                # Diese Übersicht
SYSTEM_ARCHITECTURE.md           # System-Dokumentation
```

## 📊 **Log-Dateien (Server)**
```
/pages/d0/aa/d0017222/home/htdocs/
├── websocket-debug.log          # WebSocket-Debug-Info
└── test-write.log               # PHP-Test-Logs

/pages/d0/aa/d0017222/home/flutter-backend/
└── gunicorn.log                 # Gunicorn-Logs
```

## 🔧 **Wichtige Befehle:**

### **Backend deployen:**
```bash
./deploy.sh
```

### **Server-Status prüfen:**
```bash
ssh u3071051@85.214.234.2 'ps aux | grep gunicorn'
ssh u3071051@85.214.234.2 'tail -f /pages/d0/aa/d0017222/home/flutter-backend/gunicorn.log'
```

### **WebSocket-Debug-Logs prüfen:**
```bash
ssh u3071051@85.214.234.2 'cd /pages/d0/aa/d0017222/home/htdocs && cat websocket-debug.log'
```

### **PHP-Test ausführen:**
```bash
ssh u3071051@85.214.234.2 'cd /pages/d0/aa/d0017222/home/htdocs && php test-php.php'
```

---

**Hinweis:** Alle Backend-Dateien werden automatisch mit `deploy.sh` auf den Server kopiert. 