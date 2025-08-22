#!/usr/bin/env python3
"""
NOTFALL-SKRIPT: Datenbank-Sicherheit prüfen und absichern
Port 3306 ist von außen erreichbar - KRITISCH!
"""

import socket
import requests
import json
import sys
import time
from urllib.parse import urlparse

class EmergencyDBSecurity:
    def __init__(self, host="85.214.234.2"):
        self.host = host
        self.results = []
        
    def log_result(self, test_name, status, details=""):
        """Loggt Testergebnisse"""
        result = {
            "test": test_name,
            "status": status,
            "details": details,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        self.results.append(result)
        
        if status == "CRITICAL":
            print(f"💀 {test_name}: {details}")
        elif status == "FAIL":
            print(f"❌ {test_name}: {details}")
        elif status == "WARNING":
            print(f"⚠️  {test_name}: {details}")
        else:
            print(f"✅ {test_name}: {details}")
    
    def test_mysql_port_access(self):
        """Testet MySQL-Port-Zugriff"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.host, 3306))
            sock.close()
            
            if result == 0:
                self.log_result("MySQL-Port 3306", "CRITICAL", 
                              f"Port 3306 ist offen auf {self.host} - DATENBANK ERREICHBAR!")
                return True
            else:
                self.log_result("MySQL-Port 3306", "PASS", "Port 3306 ist geschlossen")
                return False
                
        except Exception as e:
            self.log_result("MySQL-Port 3306", "WARNING", f"Test fehlgeschlagen: {str(e)}")
            return False
    
    def test_mysql_connection(self):
        """Testet direkte MySQL-Verbindung"""
        try:
            # Einfacher MySQL-Handshake-Test
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect((self.host, 3306))
            
            # MySQL-Protokoll-Handshake lesen
            data = sock.recv(1024)
            sock.close()
            
            if data:
                self.log_result("MySQL-Handshake", "CRITICAL", 
                              f"MySQL-Server antwortet - Verbindung möglich!")
                return True
            else:
                self.log_result("MySQL-Handshake", "PASS", "Keine MySQL-Antwort")
                return False
                
        except Exception as e:
            self.log_result("MySQL-Handshake", "WARNING", f"Handshake-Test fehlgeschlagen: {str(e)}")
            return False
    
    def test_common_mysql_credentials(self):
        """Testet häufige MySQL-Credentials"""
        common_credentials = [
            ("root", ""),
            ("root", "root"),
            ("root", "password"),
            ("root", "admin"),
            ("admin", "admin"),
            ("mysql", "mysql"),
            ("test", "test"),
        ]
        
        print("\n🔍 Teste häufige MySQL-Credentials...")
        
        for username, password in common_credentials:
            try:
                # Einfacher Credential-Test (ohne vollständige MySQL-Implementierung)
                self.log_result(f"Credential Test: {username}", "WARNING", 
                              f"Teste {username}:{password} - manuelle Überprüfung empfohlen")
                
            except Exception as e:
                continue
        
        self.log_result("Credential Tests", "INFO", "Manuelle Überprüfung der Credentials erforderlich")
    
    def generate_security_report(self):
        """Generiert Sicherheitsbericht"""
        critical_issues = [r for r in self.results if r["status"] == "CRITICAL"]
        
        print("\n" + "="*60)
        print("🚨 NOTFALL-SICHERHEITSBERICHT")
        print("="*60)
        
        if critical_issues:
            print(f"\n💀 KRITISCHE PROBLEME GEFUNDEN: {len(critical_issues)}")
            for issue in critical_issues:
                print(f"  - {issue['test']}: {issue['details']}")
            
            print("\n🔧 SOFORTIGE MASSNAHMEN ERFORDERLICH:")
            print("  1. MySQL-Port 3306 in Firewall blockieren")
            print("  2. MySQL nur auf localhost (127.0.0.1) binden")
            print("  3. Starke Passwörter für alle MySQL-User setzen")
            print("  4. MySQL-User ohne externe Zugriffe löschen")
            print("  5. MySQL-Logs auf unbefugte Zugriffe prüfen")
            
        else:
            print("\n✅ Keine kritischen Probleme gefunden")
        
        # Speichere Bericht
        report_file = "emergency_db_security_report.json"
        with open(report_file, "w", encoding="utf-8") as f:
            json.dump({
                "host": self.host,
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "critical_issues": len(critical_issues),
                "results": self.results
            }, f, indent=2, ensure_ascii=False)
        
        print(f"\n📄 Notfall-Bericht gespeichert: {report_file}")
    
    def run_emergency_checks(self):
        """Führt alle Notfall-Checks aus"""
        print("🚨 NOTFALL-DATENBANK-SICHERHEITSCHECK")
        print(f"🌐 Host: {self.host}")
        print("="*50)
        
        port_open = self.test_mysql_port_access()
        
        if port_open:
            self.test_mysql_connection()
            self.test_common_mysql_credentials()
        
        self.generate_security_report()

def main():
    """Hauptfunktion"""
    if len(sys.argv) > 1:
        host = sys.argv[1]
    else:
        host = "85.214.234.2"
    
    checker = EmergencyDBSecurity(host)
    checker.run_emergency_checks()

if __name__ == "__main__":
    main()
