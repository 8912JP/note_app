#!/bin/bash

case "$1" in
    start)
        echo "Starting gunicorn server..."
        cd ~/flutter-backend
        source pyflutter/bin/activate
        nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &
        echo $! > gunicorn.pid
        echo "Gunicorn server started with PID $(cat gunicorn.pid)"
        ;;
    stop)
        echo "Stopping gunicorn server..."
        # Erst versuchen über PID-Datei zu stoppen
        if [ -f gunicorn.pid ]; then
            kill $(cat gunicorn.pid) 2>/dev/null
            rm gunicorn.pid
        fi
        # Dann nach laufenden Gunicorn-Prozessen suchen und diese beenden
        pkill -f "gunicorn main:app"
        echo "Gunicorn server stopped"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        # Prüfe ob Gunicorn-Prozesse laufen
        if pgrep -f "gunicorn main:app" > /dev/null; then
            echo "Gunicorn server is running with PIDs:"
            pgrep -f "gunicorn main:app"
            # PID-Datei aktualisieren wenn nötig
            if [ ! -f gunicorn.pid ]; then
                pgrep -f "gunicorn main:app" | head -n1 > gunicorn.pid
            fi
        else
            echo "Gunicorn server is not running"
            # PID-Datei löschen falls vorhanden
            [ -f gunicorn.pid ] && rm gunicorn.pid
        fi
        ;;
    logs)
        tail -f gunicorn.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac 