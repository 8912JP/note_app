# Gunicorn Konfiguration
bind = "0.0.0.0:8000"

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

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "info"

# Process naming
proc_name = "gunicorn_fastapi"