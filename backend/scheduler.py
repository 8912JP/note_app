import logging
import os
from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
import imaplib
import email
from email.header import decode_header
import re
import email.utils
from database import SessionLocal
from crud import create_crm_entry_from_email
from sqlalchemy.exc import SQLAlchemyError
from dotenv import load_dotenv

# .env laden
load_dotenv()

# E-Mail-Konfiguration
IMAP_SERVER = os.getenv("IMAP_SERVER", "imap.strato.de")
IMAP_USER = os.getenv("IMAP_USER", "julian.pfohl@iqmedix.eu")
IMAP_PASS = os.getenv("IMAP_PASS", "your_password_here")
SENDER_FILTER = os.getenv("SENDER_FILTER", "noreply@iqmedix.eu")

# Logging-Konfiguration für Email Scheduler
def setup_scheduler_logging():
    # Erstelle logs Verzeichnis falls es nicht existiert
    os.makedirs('logs', exist_ok=True)
    
    # Logger für normale Email Scheduler Logs
    scheduler_logger = logging.getLogger('email_scheduler')
    scheduler_logger.setLevel(logging.INFO)
    
    # File Handler für normale Scheduler Logs
    scheduler_handler = logging.FileHandler('logs/email.log')
    scheduler_handler.setLevel(logging.INFO)
    scheduler_formatter = logging.Formatter('%(asctime)s - EMAIL_SCHEDULER - %(levelname)s - %(message)s')
    scheduler_handler.setFormatter(scheduler_formatter)
    scheduler_logger.addHandler(scheduler_handler)
    
    # File Handler für Fehler (geht ins kombinierte error.log)
    error_handler = logging.FileHandler('logs/error.log')
    error_handler.setLevel(logging.ERROR)
    error_formatter = logging.Formatter('%(asctime)s - EMAIL_SCHEDULER - %(levelname)s - %(message)s')
    error_handler.setFormatter(error_formatter)
    scheduler_logger.addHandler(error_handler)
    
    return scheduler_logger

# Logger initialisieren
logger = setup_scheduler_logging()

# =======================
# 📧 Fortschrittliche E-Mail-Parsing-Funktionen
# (aus email_service.py übernommen)
# =======================

def extract_from_html(html):
    """Extrahiert strukturierte Daten aus HTML-E-Mails"""
    def extract_class(cls):
        match = re.search(r'class=["\\\']{}["\\\']>([^<]+)'.format(cls), html)
        return match.group(1).strip() if match else ""
    
    strasse = extract_class("street-address")
    ort = extract_class("locality")
    plz = extract_class("postal-code")
    land = extract_class("country-name")
    vorname = extract_class("given-name")
    nachname = extract_class("family-name")
    email_val = extract_class("email")
    mobil = extract_class("tel")
    
    # Hausnummer aus strasse extrahieren, falls nötig
    hausnummer = ""
    if strasse:
        match = re.match(r"(.+?)\s*(\d+[a-zA-Z]*)$", strasse)
        if match:
            strasse = match.group(1).strip()
            hausnummer = match.group(2).strip()
        else:
            # Falls noch keine Hausnummer, prüfe auf Punkt am Ende
            match = re.match(r"(.+?)[\.,\s]+(\d+[a-zA-Z]*)$", strasse)
            if match:
                strasse = match.group(1).strip()
                hausnummer = match.group(2).strip()
    
    return {
        "strasse": strasse,
        "hausnummer": hausnummer,
        "plz": plz,
        "ort": ort,
        "land": land,
        "vorname": vorname,
        "nachname": nachname,
        "email": email_val,
        "mobil": mobil,
    }

def extract_informationsgebiet_from_html(html):
    """Extrahiert Informationsgebiete aus HTML-E-Mails"""
    th_pattern = r'Zu welchem Informationsgebiet.*?</th>\s*<td[^>]*>(.*?)</td>'
    match = re.search(th_pattern, html, re.DOTALL)
    if match:
        td_content = match.group(1)
        items = re.findall(r'<li[^>]*>([^<]+)</li>', td_content)
        # Entferne Zeilenumbrüche und mehrfachen Whitespace in jedem Eintrag
        cleaned = [' '.join(item.split()) for item in items if item.strip()]
        return ', '.join(cleaned)
    return ""

def parse_kontaktquelle_from_betreff(betreff: str) -> str:
    """Bestimmt die Kontaktquelle aus dem E-Mail-Betreff"""
    if not betreff:
        return ''
    betreff_lower = betreff.lower()
    if 'ads-conversion' in betreff_lower:
        return 'Ads'
    if 'kontakt' in betreff_lower:
        return 'Website DE'
    if 'contact' in betreff_lower:
        return 'Website EN'
    return ''

def parse_structured_email(body: str, html: str = None) -> dict:
    """Parst strukturierte E-Mail-Daten aus Text und HTML"""
    # HTML-Priorität für Adress- und Personenfelder
    html_fields = {}
    if html:
        html_fields = extract_from_html(html)
    
    lines = [line.strip() for line in body.splitlines() if line.strip()]
    
    def get_value(field):
        for i, line in enumerate(lines):
            norm_line = line.lower().replace("*", "").replace(":", "").strip()
            norm_field = field.lower().replace("*", "").replace(":", "").strip()
            if norm_field in norm_line:
                for next_line in lines[i+1:]:
                    if next_line.strip():
                        return next_line.strip()
        return ""
    
    # Mobilnummer gezielt extrahieren (Fallback)
    mobil = html_fields.get("mobil") or ""
    if not mobil:
        for i, line in enumerate(lines):
            if "telefonnummer" in line.lower():
                match = re.search(r"([0-9]{6,})", line)
                if match:
                    mobil = match.group(1)
                elif i+1 < len(lines):
                    match = re.search(r"([0-9]{6,})", lines[i+1])
                    if match:
                        mobil = match.group(1)
                break
    
    # E-Mail gezielt extrahieren (Fallback)
    email_val = html_fields.get("email") or ""
    if not email_val:
        for i, line in enumerate(lines):
            if "e-mail" in line.lower():
                match = re.search(r"([\w\.-]+@[\w\.-]+)", line)
                if match:
                    email_val = match.group(1)
                elif i+1 < len(lines):
                    match = re.search(r"([\w\.-]+@[\w\.-]+)", lines[i+1])
                    if match:
                        email_val = match.group(1)
                break
    
    # Adresse gezielt extrahieren (Fallback)
    strasse = html_fields.get("strasse") or ""
    hausnummer = html_fields.get("hausnummer") or ""
    plz = html_fields.get("plz") or ""
    ort = html_fields.get("ort") or ""
    land = html_fields.get("land") or ""
    
    if not strasse or not plz or not ort or not land:
        for i, line in enumerate(lines):
            if "adresse" in line.lower():
                adr_lines = []
                for l in lines[i+1:i+6]:
                    if l:
                        adr_lines.append(l.replace("+", " ").strip())
                if len(adr_lines) > 0 and not strasse:
                    match = re.match(r"(.+?)\s+(\d+\w*)", adr_lines[0])
                    if match:
                        strasse = match.group(1)
                        hausnummer = match.group(2)
                    else:
                        strasse = adr_lines[0]
                if len(adr_lines) > 1 and not plz and not ort:
                    match = re.match(r"(\d{4,5})\s+(.+)", adr_lines[1])
                    if match:
                        plz = match.group(1)
                        ort = match.group(2)
                    else:
                        ort = adr_lines[1]
                if len(adr_lines) > 2 and not land:
                    land = adr_lines[2]
                break
    
    # Vorname/Nachname (Fallback)
    vorname = html_fields.get("vorname") or get_value("Vorname")
    nachname = html_fields.get("nachname") or get_value("Nachname")
    
    # Informationsgebiet extrahieren
    infos = ""
    if html:
        infos = extract_informationsgebiet_from_html(html)
    if not infos:
        infos = get_value("Informationsgebiet")
    
    return {
        "anrede": get_value("Anrede"),
        "vorname": vorname,
        "nachname": nachname,
        "mobil": mobil,
        "email": email_val,
        "strasse": strasse,
        "hausnummer": hausnummer,
        "plz": plz,
        "ort": ort,
        "land": land,
        "nachricht": get_value("Ihre Nachricht an uns") or get_value("Benachrichtigung zur Abholung"),
        "infos": infos,
        "informationsgebiet": infos,
        "einverstaendnis": get_value("Einverständnis"),
    }

class EmailScheduler:
    def __init__(self):
        self.scheduler = BackgroundScheduler()
        self.is_running = False
        logger.info("EmailScheduler initialisiert")
        
    def start(self):
        if self.is_running:
            logger.warning("EmailScheduler läuft bereits")
            return
            
        try:
            # Job alle 5 Minuten für neue Emails
            self.scheduler.add_job(
                self._fetch_emails_job,
                CronTrigger(minute='*/5'),
                id='email_fetch_job',
                name='Email Fetch Job'
            )
            
            # Job alle 30 Minuten für vollständigen Abruf (nur als Backup)
            # self.scheduler.add_job(
            #     self._fetch_emails_job_full,
            #     CronTrigger(minute='*/30'),
            #     id='email_fetch_job_full',
            #     name='Email Fetch Job Full'
            # )
            
            self.scheduler.start()
            self.is_running = True
            logger.info("EmailScheduler erfolgreich gestartet")
            
        except Exception as e:
            logger.error(f"Fehler beim Starten des EmailSchedulers: {e}")
            raise
    
    def stop(self):
        if not self.is_running:
            logger.warning("EmailScheduler läuft nicht")
            return
            
        try:
            self.scheduler.shutdown()
            self.is_running = False
            logger.info("EmailScheduler gestoppt")
        except Exception as e:
            logger.error(f"Fehler beim Stoppen des EmailSchedulers: {e}")
            raise
    
    def get_status(self):
        if not self.is_running:
            return {
                "is_running": False,
                "jobs": []
            }
        
        jobs = []
        for job in self.scheduler.get_jobs():
            jobs.append({
                "id": job.id,
                "name": job.name,
                "next_run": job.next_run_time.isoformat() if job.next_run_time else None,
                "trigger": str(job.trigger)
            })
        
        return {
            "is_running": True,
            "jobs": jobs
        }
    
    def _fetch_emails_job(self):
        """Job für regelmäßigen Email-Abruf (alle 5 Minuten)"""
        try:
            logger.info("Starte Email-Abruf...")
            self._fetch_emails()
            logger.info("Email-Abruf erfolgreich abgeschlossen")
        except Exception as e:
            logger.error(f"Fehler beim Email-Abruf: {e}")
    
    def _fetch_emails_job_full(self):
        """Job für vollständigen Email-Abruf (alle 30 Minuten)"""
        try:
            logger.info("Starte vollständigen Email-Abruf...")
            self._fetch_emails(full_scan=True)
            logger.info("Vollständiger Email-Abruf erfolgreich abgeschlossen")
        except Exception as e:
            logger.error(f"Fehler beim vollständigen Email-Abruf: {e}")
    
    def _fetch_emails(self, full_scan=False):
        """Email-Abruf-Logik"""
        try:
            # IMAP-Verbindung aufbauen
            mail = imaplib.IMAP4_SSL(IMAP_SERVER)
            mail.login(IMAP_USER, IMAP_PASS)
            mail.select('INBOX')
            
            # Suche nach E-Mails mit Filter
            if full_scan:
                status, messages = mail.search(None, f'(FROM "{SENDER_FILTER}")')
            else:
                status, messages = mail.search(None, f'(UNSEEN FROM "{SENDER_FILTER}")')
            
            if status != 'OK':
                logger.error("Fehler beim Suchen nach E-Mails")
                return
            
            email_ids = messages[0].split()
            
            if not email_ids:
                logger.info("Keine neuen E-Mails gefunden")
                return
            
            logger.info(f"Gefunden: {len(email_ids)} E-Mail(s)")
            
            # E-Mails verarbeiten
            for email_id in email_ids:
                try:
                    status, msg_data = mail.fetch(email_id, '(RFC822)')
                    if status != 'OK':
                        continue
                    
                    email_body = msg_data[0][1]
                    email_message = email.message_from_bytes(email_body)
                    
                    # E-Mail-Header extrahieren
                    subject = email_message["Subject"] if email_message["Subject"] else ""
                    
                    # Anfrage-Datum aus E-Mail-Header
                    date_tuple = email.utils.parsedate_tz(email_message["Date"])
                    anfrage_datum = None
                    if date_tuple:
                        anfrage_datum = datetime.fromtimestamp(email.utils.mktime_tz(date_tuple))
                    
                    # E-Mail-Body und HTML extrahieren (wie in email_service.py)
                    body = ""
                    html = None
                    if email_message.is_multipart():
                        for part in email_message.walk():
                            if part.get_content_type() == "text/plain":
                                body += part.get_payload(decode=True).decode('utf-8', errors='ignore')
                            elif part.get_content_type() == "text/html":
                                html = part.get_payload(decode=True).decode('utf-8', errors='ignore')
                    else:
                        body = email_message.get_payload(decode=True).decode('utf-8', errors='ignore')
                        html = None
                    
                    # Fortschrittliche E-Mail-Verarbeitung verwenden
                    self._convert_email_to_crm_advanced(subject, anfrage_datum, body, html, email_id, mail)
                    
                except Exception as e:
                    logger.error(f"Fehler beim Verarbeiten von Email {email_id}: {e}")
            
            mail.close()
            mail.logout()
            
        except Exception as e:
            logger.error(f"Fehler beim Email-Abruf: {e}")
    
    def _convert_email_to_crm_advanced(self, subject, anfrage_datum, body, html, email_id, mail):
        """Fortschrittliche E-Mail-zu-CRM-Konvertierung (aus email_service.py)"""
        try:
            db = SessionLocal()
            
            # Strukturierte E-Mail-Daten extrahieren
            fields = parse_structured_email(body, html)
            fields["betreff"] = subject
            fields["anfrage_datum"] = anfrage_datum or datetime.now()
            
            # Kontaktquelle aus Betreff extrahieren
            fields["kontaktquelle"] = parse_kontaktquelle_from_betreff(subject)
            
            logger.info(f"Extrahierte Felder aus E-Mail: {fields}")
            
            # CRM-Eintrag erstellen
            crm_entry = create_crm_entry_from_email(db, **fields)
            
            # E-Mail als gelesen markieren
            mail.store(email_id, '+FLAGS', '\\Seen')
            
            logger.info(f"CRM-Eintrag aus E-Mail erstellt: {subject} ({fields.get('email', 'Keine E-Mail')})")
            
        except Exception as e:
            logger.error(f"Fehler beim Umwandeln der E-Mail in CRM-Eintrag: {e}")
            if 'db' in locals():
                db.rollback()
        finally:
            if 'db' in locals():
                db.close()

# Globale Instanz
email_scheduler = EmailScheduler()

# Globale Funktionen für API-Zugriff
def start_email_scheduler():
    email_scheduler.start()

def stop_email_scheduler():
    email_scheduler.stop()

def get_scheduler_status():
    return email_scheduler.get_status()
