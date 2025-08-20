#!/bin/bash

case "$1" in
    start)
        echo "Starting gunicorn server with email scheduler..."
        cd ~/flutter-backend
        source pyflutter/bin/activate
        
        # Prüfe ob bereits ein Server läuft
        if pgrep -f "gunicorn main:app" > /dev/null; then
            echo "⚠️  Gunicorn server is already running. Stopping first..."
            $0 stop
            sleep 2
        fi
        
        # Starte Gunicorn mit Email-Scheduler
        echo "🚀 Starting gunicorn with email scheduler..."
        nohup gunicorn main:app -w 1 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 > gunicorn.log 2>&1 &
        echo $! > gunicorn.pid
        echo "✅ Gunicorn server started with PID $(cat gunicorn.pid)"
        
        # Warte kurz und prüfe Status
        sleep 3
        if pgrep -f "gunicorn main:app" > /dev/null; then
            echo "✅ Server is running successfully"
            echo "📧 Email scheduler should be active"
            echo "🔍 Check logs with: $0 logs"
        else
            echo "❌ Server failed to start. Check logs:"
            tail -n 10 gunicorn.log
        fi
        ;;
    stop)
        echo "Stopping gunicorn server and email scheduler..."
        # Erst versuchen über PID-Datei zu stoppen
        if [ -f gunicorn.pid ]; then
            kill $(cat gunicorn.pid) 2>/dev/null
            rm gunicorn.pid
        fi
        # Dann nach laufenden Gunicorn-Prozessen suchen und diese beenden
        pkill -f "gunicorn main:app"
        echo "✅ Gunicorn server and email scheduler stopped"
        ;;
    restart)
        echo "🔄 Restarting gunicorn server..."
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        # Prüfe ob Gunicorn-Prozesse laufen
        if pgrep -f "gunicorn main:app" > /dev/null; then
            echo "✅ Gunicorn server is running with PIDs:"
            pgrep -f "gunicorn main:app"
            # PID-Datei aktualisieren wenn nötig
            if [ ! -f gunicorn.pid ]; then
                pgrep -f "gunicorn main:app" | head -n1 > gunicorn.pid
            fi
            
            # Teste API-Endpoints
            echo ""
            echo "🔍 Testing API endpoints..."
            
            # Teste Scheduler-Status
            if curl -s http://localhost:8000/api/scheduler/status > /dev/null 2>&1; then
                echo "✅ Scheduler API is responding"
                echo "📊 Scheduler status:"
                curl -s http://localhost:8000/api/scheduler/status | python3 -m json.tool 2>/dev/null || echo "   (Status response received)"
            else
                echo "❌ Scheduler API not responding"
            fi
            
            # Teste Notes-API
            if curl -s http://localhost:8000/api/notes/ > /dev/null 2>&1; then
                echo "✅ Notes API is responding"
            else
                echo "❌ Notes API not responding"
            fi
            
        else
            echo "❌ Gunicorn server is not running"
            # PID-Datei löschen falls vorhanden
            [ -f gunicorn.pid ] && rm gunicorn.pid
        fi
        ;;
    logs)
        if [ -f gunicorn.log ]; then
            tail -f gunicorn.log
        else
            echo "❌ No log file found. Server might not be running."
        fi
        ;;
    scheduler-status)
        echo "📧 Email Scheduler Status:"
        curl -s http://localhost:8000/api/scheduler/status | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/api/scheduler/status
        ;;
    scheduler-start)
        echo "🚀 Starting email scheduler..."
        curl -X POST http://localhost:8000/api/scheduler/start
        echo ""
        ;;
    scheduler-stop)
        echo "🛑 Stopping email scheduler..."
        curl -X POST http://localhost:8000/api/scheduler/stop
        echo ""
        ;;
    scheduler-trigger)
        echo "📧 Triggering manual email fetch..."
        curl -X POST http://localhost:8000/api/scheduler/trigger-email-fetch
        echo ""
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|scheduler-status|scheduler-start|scheduler-stop|scheduler-trigger}"
        echo ""
        echo "Commands:"
        echo "  start              - Start gunicorn server with email scheduler"
        echo "  stop               - Stop gunicorn server and email scheduler"
        echo "  restart            - Restart gunicorn server"
        echo "  status             - Show server status and test APIs"
        echo "  logs               - Show live server logs"
        echo "  scheduler-status   - Show email scheduler status"
        echo "  scheduler-start    - Start email scheduler manually"
        echo "  scheduler-stop     - Stop email scheduler manually"
        echo "  scheduler-trigger  - Trigger manual email fetch"
        exit 1
        ;;
esac 