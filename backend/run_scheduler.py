#!/usr/bin/env python3
"""
Email Scheduler - Manuelle Ausführung
Dieses Skript startet den Email-Scheduler für die periodische Email-Verarbeitung.
"""

import time
import signal
import sys
from scheduler import start_email_scheduler, stop_email_scheduler, get_scheduler_status

def signal_handler(sig, frame):
    """Signal Handler für sauberes Beenden"""
    print("\n🛑 Beende Email-Scheduler...")
    stop_email_scheduler()
    print("✅ Email-Scheduler gestoppt")
    sys.exit(0)

def main():
    """Hauptfunktion"""
    print("🚀 Starte Email-Scheduler...")
    
    # Signal Handler für sauberes Beenden
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Starte Scheduler
        start_email_scheduler()
        print("✅ Email-Scheduler erfolgreich gestartet")
        print("📧 Email-Check läuft alle 5 Minuten")
        print("📧 Vollständiger Email-Check alle 30 Minuten")
        print("🛑 Drücke Ctrl+C zum Beenden")
        
        # Zeige initialen Status
        status = get_scheduler_status()
        print(f"📊 Scheduler Status: {'Aktiv' if status['is_running'] else 'Inaktiv'}")
        for job in status['jobs']:
            print(f"   - {job['name']}: Nächster Lauf um {job['next_run']}")
        
        # Halte das Programm am Leben
        while True:
            time.sleep(60)  # Warte 1 Minute
            # Zeige Status alle 5 Minuten
            if int(time.time()) % 300 == 0:  # Alle 5 Minuten
                status = get_scheduler_status()
                print(f"📊 Scheduler läuft noch... Jobs: {len(status['jobs'])}")
                
    except KeyboardInterrupt:
        print("\n🛑 Beende Email-Scheduler...")
    except Exception as e:
        print(f"❌ Fehler: {e}")
    finally:
        stop_email_scheduler()
        print("✅ Email-Scheduler gestoppt")

if __name__ == "__main__":
    main()

