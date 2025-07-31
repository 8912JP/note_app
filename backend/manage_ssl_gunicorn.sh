#!/bin/bash

case "$1" in
    start)
        echo "Starting gunicorn server with SSL..."
        cd ~/flutter-backend
        source pyflutter/bin/activate
        nohup gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:443 --certfile=/path/to/cert.pem --keyfile=/path/to/key.pem > gunicorn_ssl.log 2>&1 &
        echo $! > gunicorn_ssl.pid
        echo "Gunicorn SSL server started with PID $(cat gunicorn_ssl.pid)"
        ;;
    stop)
        if [ -f gunicorn_ssl.pid ]; then
            echo "Stopping gunicorn SSL server..."
            kill $(cat gunicorn_ssl.pid)
            rm gunicorn_ssl.pid
            echo "Gunicorn SSL server stopped"
        else
            echo "No gunicorn SSL PID file found"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if [ -f gunicorn_ssl.pid ]; then
            if kill -0 $(cat gunicorn_ssl.pid) 2>/dev/null; then
                echo "Gunicorn SSL server is running (PID: $(cat gunicorn_ssl.pid))"
            else
                echo "Gunicorn SSL PID file exists but process is not running"
                rm gunicorn_ssl.pid
            fi
        else
            echo "Gunicorn SSL server is not running"
        fi
        ;;
    logs)
        tail -f gunicorn_ssl.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac 