#!/bin/bash

# Email Scheduler Management Script
# Verwendung: ./manage_scheduler.sh {start|stop|status|trigger|logs}

case "$1" in
    start)
        echo "🚀 Starting email scheduler..."
        cd ~/flutter-backend
        source pyflutter/bin/activate
        
        # Prüfe ob Server läuft
        if ! pgrep -f "gunicorn main:app" > /dev/null; then
            echo "❌ Gunicorn server is not running. Please start the server first:"
            echo "   ./manage_gunicorn.sh start"
            exit 1
        fi
        
        # Starte Scheduler über API
        response=$(curl -s -X POST http://localhost:8000/api/scheduler/start)
        echo "📧 Scheduler start response: $response"
        
        # Zeige Status
        sleep 2
        echo ""
        echo "📊 Current scheduler status:"
        curl -s http://localhost:8000/api/scheduler/status | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/api/scheduler/status
        ;;
    stop)
        echo "🛑 Stopping email scheduler..."
        response=$(curl -s -X POST http://localhost:8000/api/scheduler/stop)
        echo "📧 Scheduler stop response: $response"
        ;;
    status)
        echo "📊 Email Scheduler Status:"
        if curl -s http://localhost:8000/api/scheduler/status > /dev/null 2>&1; then
            curl -s http://localhost:8000/api/scheduler/status | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/api/scheduler/status
        else
            echo "❌ Cannot connect to scheduler API. Server might not be running."
        fi
        ;;
    trigger)
        echo "📧 Triggering manual email fetch..."
        response=$(curl -s -X POST http://localhost:8000/api/scheduler/trigger-email-fetch)
        echo "📧 Manual fetch response: $response"
        ;;
    logs)
        echo "📋 Email Scheduler Logs:"
        if [ -f email_scheduler.log ]; then
            tail -f email_scheduler.log
        else
            echo "❌ No scheduler log file found."
            echo "💡 Scheduler logs might be in gunicorn.log"
            if [ -f gunicorn.log ]; then
                echo "📋 Recent gunicorn logs (scheduler related):"
                grep -i "scheduler\|email" gunicorn.log | tail -20
            fi
        fi
        ;;
    test)
        echo "🧪 Testing email scheduler functionality..."
        
        # Test 1: Server läuft?
        echo "1️⃣ Testing server connection..."
        if curl -s http://localhost:8000/api/notes/ > /dev/null 2>&1; then
            echo "   ✅ Server is responding"
        else
            echo "   ❌ Server is not responding"
            exit 1
        fi
        
        # Test 2: Scheduler API erreichbar?
        echo "2️⃣ Testing scheduler API..."
        if curl -s http://localhost:8000/api/scheduler/status > /dev/null 2>&1; then
            echo "   ✅ Scheduler API is responding"
        else
            echo "   ❌ Scheduler API is not responding"
            exit 1
        fi
        
        # Test 3: Scheduler Status
        echo "3️⃣ Testing scheduler status..."
        status=$(curl -s http://localhost:8000/api/scheduler/status)
        echo "   📊 Status: $status"
        
        # Test 4: Manueller Trigger
        echo "4️⃣ Testing manual email fetch..."
        trigger_response=$(curl -s -X POST http://localhost:8000/api/scheduler/trigger-email-fetch)
        echo "   📧 Trigger response: $trigger_response"
        
        echo "✅ All tests completed!"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|trigger|logs|test}"
        echo ""
        echo "Commands:"
        echo "  start   - Start email scheduler"
        echo "  stop    - Stop email scheduler"
        echo "  status  - Show scheduler status"
        echo "  trigger - Trigger manual email fetch"
        echo "  logs    - Show scheduler logs"
        echo "  test    - Run comprehensive tests"
        echo ""
        echo "Note: Make sure the gunicorn server is running first:"
        echo "      ./manage_gunicorn.sh start"
        exit 1
        ;;
esac
