import os
import logging

# Erstelle logs Verzeichnis falls es nicht existiert
os.makedirs('logs', exist_ok=True)

# Gunicorn Logger-Konfiguration
def setup_gunicorn_logging():
    # Logger für Gunicorn
    gunicorn_logger = logging.getLogger('gunicorn.error')
    gunicorn_logger.setLevel(logging.ERROR)  # Nur ERROR-Level
    
    # File Handler für Fehler
    error_handler = logging.FileHandler('logs/error.log')
    error_handler.setLevel(logging.ERROR)
    error_formatter = logging.Formatter('%(asctime)s - GUNICORN - %(levelname)s - %(message)s')
    error_handler.setFormatter(error_formatter)
    gunicorn_logger.addHandler(error_handler)
    
    # Logger für Access-Logs (normale Aktivitäten)
    access_logger = logging.getLogger('gunicorn.access')
    access_logger.setLevel(logging.INFO)
    
    # File Handler für Access-Logs
    access_handler = logging.FileHandler('logs/gunicorn.log')
    access_handler.setLevel(logging.INFO)
    access_formatter = logging.Formatter('%(asctime)s - GUNICORN - %(levelname)s - %(message)s')
    access_handler.setFormatter(access_formatter)
    access_logger.addHandler(access_handler)
    
    return gunicorn_logger, access_logger

# Logging initialisieren
error_logger, access_logger = setup_gunicorn_logging()

# Gunicorn Konfiguration
bind = "127.0.0.1:8000"  # Nur localhost - sicher!

# WICHTIG: Für WebSockets darf es nur einen Worker geben, sonst sind die
# in-memory WebSocket-Clientlisten pro Prozess getrennt und Broadcasts gehen verloren.
workers = 1

worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2

# Kein Preload bei WebSockets, damit keine doppelten Clientlisten entstehen
preload_app = False

reload = False  # Für Produktion auf False setzen

# Logging - Saubere Trennung
accesslog = "logs/gunicorn.log"
errorlog = "logs/error.log"
loglevel = "error"  # Nur ERROR-Level in error.log
# INFO-Nachrichten gehen automatisch in accesslog

# Process naming
proc_name = "gunicorn_fastapi"