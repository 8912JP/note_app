import os
import logging
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from email_service import fetch_and_process_emails
from dotenv import load_dotenv

# .env laden
load_dotenv()

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('email_scheduler.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class EmailScheduler:
    def __init__(self):
        self.scheduler = BackgroundScheduler()
        self.is_running = False
    
    def start(self):
        """Startet den Scheduler"""
        if not self.is_running:
            # Email-Check alle 5 Minuten
            self.scheduler.add_job(
                func=self._fetch_emails_job,
                trigger=CronTrigger(minute='*/5'),  # Alle 5 Minuten
                id='email_fetch_job',
                name='Email Fetch Job',
                replace_existing=True
            )
            
            # Zusätzlich alle 30 Minuten einen vollständigen Check
            self.scheduler.add_job(
                func=self._fetch_emails_job,
                trigger=CronTrigger(minute='*/30'),  # Alle 30 Minuten
                id='email_fetch_job_full',
                name='Email Fetch Job Full',
                replace_existing=True
            )
            
            self.scheduler.start()
            self.is_running = True
            logger.info("Email Scheduler gestartet")
    
    def stop(self):
        """Stoppt den Scheduler"""
        if self.is_running:
            self.scheduler.shutdown()
            self.is_running = False
            logger.info("Email Scheduler gestoppt")
    
    def _fetch_emails_job(self):
        """Job-Funktion für Email-Abruf"""
        try:
            logger.info("Starte Email-Abruf...")
            fetch_and_process_emails()
            logger.info("Email-Abruf erfolgreich abgeschlossen")
        except Exception as e:
            logger.error(f"Fehler beim Email-Abruf: {str(e)}")
    
    def get_status(self):
        """Gibt den aktuellen Status des Schedulers zurück"""
        jobs = []
        for job in self.scheduler.get_jobs():
            jobs.append({
                'id': job.id,
                'name': job.name,
                'next_run': str(job.next_run_time),
                'trigger': str(job.trigger)
            })
        
        return {
            'is_running': self.is_running,
            'jobs': jobs
        }

# Globale Scheduler-Instanz
email_scheduler = EmailScheduler()

def start_email_scheduler():
    """Startet den Email-Scheduler"""
    email_scheduler.start()

def stop_email_scheduler():
    """Stoppt den Email-Scheduler"""
    email_scheduler.stop()

def get_scheduler_status():
    """Gibt den Scheduler-Status zurück"""
    return email_scheduler.get_status()

