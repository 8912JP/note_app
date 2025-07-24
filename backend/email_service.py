import imaplib
import email
import re
import os
import email.utils
import datetime
from crud import create_crm_entry_from_email  # Schreibe diese Hilfsfunktion!
from database import SessionLocal
from dotenv import load_dotenv  # <--- NEU

# .env laden
load_dotenv()

IMAP_SERVER = os.getenv("IMAP_SERVER")
IMAP_USER = os.getenv("IMAP_USER")
IMAP_PASS = os.getenv("IMAP_PASS")
SENDER_FILTER = os.getenv("SENDER_FILTER")

def extract_from_html(html):
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
    th_pattern = r'Zu welchem Informationsgebiet dürfen wir Sie.*?</th>\s*<td[^>]*>.*?<li[^>]*>([^<]+)</li>'
    match = re.search(th_pattern, html, re.DOTALL)
    if match:
        return match.group(1).strip()
    return ""

def parse_kontaktquelle_from_betreff(betreff: str) -> str:
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

def fetch_and_process_emails():
    imap = imaplib.IMAP4_SSL(IMAP_SERVER)
    imap.login(IMAP_USER, IMAP_PASS)
    imap.select("INBOX")
    status, messages = imap.search(None, f'(UNSEEN FROM "{SENDER_FILTER}")')
    db = SessionLocal()
    for num in messages[0].split():
        status, data = imap.fetch(num, "(RFC822)")
        msg = email.message_from_bytes(data[0][1])
        subject = msg["Subject"] if msg["Subject"] else ""
        # Anfrage-Datum aus E-Mail-Header
        date_tuple = email.utils.parsedate_tz(msg["Date"])
        anfrage_datum = None
        if date_tuple:
            anfrage_datum = datetime.datetime.fromtimestamp(email.utils.mktime_tz(date_tuple))
        if msg.is_multipart():
            body = ""
            html = None
            for part in msg.walk():
                if part.get_content_type() == "text/plain":
                    body += part.get_payload(decode=True).decode()
                elif part.get_content_type() == "text/html":
                    html = part.get_payload(decode=True).decode()
        else:
            body = msg.get_payload(decode=True).decode()
            html = None
        fields = parse_structured_email(body, html)
        fields["betreff"] = subject
        fields["anfrage_datum"] = anfrage_datum
        # Kontaktquelle aus Betreff extrahieren
        fields["kontaktquelle"] = parse_kontaktquelle_from_betreff(subject)
        print("Extrahierte Felder:", fields)  # Debug-Ausgabe
        create_crm_entry_from_email(db, **fields)
        imap.store(num, '+FLAGS', '\\Seen')
    imap.logout()
    db.close()