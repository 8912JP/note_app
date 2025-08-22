#!/usr/bin/env python3
"""
Sicherheitstest-Skript für die Note App
Testet HTTPS, API-Sicherheit, Datenbank-Zugriff und allgemeine Sicherheitsaspekte
"""

import requests
import socket
import ssl
import json
import sys
import time
from urllib.parse import urlparse
import subprocess
import os

class SecurityTester:
    def __init__(self, base_url="https://iqmedix.cloud"):
        self.base_url = base_url
        self.results = []
        
    def log_result(self, test_name, status, details=""):
        """Loggt Testergebnisse"""
        result = {
            "test": test_name,
            "status": status,  # PASS, FAIL, WARNING
            "details": details,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        self.results.append(result)
        
        # Farbige Ausgabe
        if status == "PASS":
            print(f"✅ {test_name}: {details}")
        elif status == "FAIL":
            print(f"❌ {test_name}: {details}")
        else:
            print(f"⚠️  {test_name}: {details}")
    
    def test_https_connection(self):
        """Testet HTTPS-Verbindung und Zertifikat"""
        try:
            response = requests.get(self.base_url, timeout=10, verify=True)
            self.log_result("HTTPS-Verbindung", "PASS", f"Status: {response.status_code}")
            
            # Zertifikat-Informationen
            parsed_url = urlparse(self.base_url)
            context = ssl.create_default_context()
            with socket.create_connection((parsed_url.hostname, 443), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=parsed_url.hostname) as ssock:
                    cert = ssock.getpeercert()
                    subject = dict(x[0] for x in cert['subject'])
                    issuer = dict(x[0] for x in cert['issuer'])
                    
                    self.log_result("SSL-Zertifikat", "PASS", 
                                  f"Subject: {subject.get('commonName', 'N/A')}, "
                                  f"Issuer: {issuer.get('commonName', 'N/A')}")
                    
        except requests.exceptions.SSLError as e:
            self.log_result("HTTPS-Verbindung", "FAIL", f"SSL-Fehler: {str(e)}")
        except Exception as e:
            self.log_result("HTTPS-Verbindung", "FAIL", f"Verbindungsfehler: {str(e)}")
    
    def test_http_redirect(self):
        """Testet ob HTTP auf HTTPS umleitet"""
        try:
            http_url = self.base_url.replace("https://", "http://")
            response = requests.get(http_url, timeout=10, allow_redirects=False)
            
            if response.status_code in [301, 302, 307, 308]:
                self.log_result("HTTP zu HTTPS Redirect", "PASS", 
                              f"Redirect Status: {response.status_code}")
            else:
                self.log_result("HTTP zu HTTPS Redirect", "FAIL", 
                              f"Kein Redirect, Status: {response.status_code}")
        except Exception as e:
            self.log_result("HTTP zu HTTPS Redirect", "FAIL", f"Fehler: {str(e)}")
    
    def test_security_headers(self):
        """Testet wichtige Security-Header"""
        try:
            response = requests.get(self.base_url, timeout=10)
            headers = response.headers
            
            # Wichtige Security-Header prüfen
            security_headers = {
                "Strict-Transport-Security": "HSTS",
                "X-Content-Type-Options": "Content-Type-Options",
                "X-Frame-Options": "Frame-Options",
                "X-XSS-Protection": "XSS-Protection",
                "Content-Security-Policy": "CSP"
            }
            
            for header, name in security_headers.items():
                if header in headers:
                    self.log_result(f"Security-Header: {name}", "PASS", 
                                  f"Header gefunden: {headers[header]}")
                else:
                    self.log_result(f"Security-Header: {name}", "WARNING", 
                                  f"Header fehlt")
                    
        except Exception as e:
            self.log_result("Security-Header", "FAIL", f"Fehler: {str(e)}")
    
    def test_api_endpoints_security(self):
        """Testet API-Endpunkte auf Sicherheit"""
        api_endpoints = [
            "/api/notes/",
            "/api/token",
            "/register/",
            "/api/users/"
        ]
        
        for endpoint in api_endpoints:
            url = f"{self.base_url}{endpoint}"
            try:
                # Test ohne Authentifizierung
                response = requests.get(url, timeout=10)
                
                if response.status_code == 401:
                    self.log_result(f"API-Sicherheit: {endpoint}", "PASS", 
                                  "Authentifizierung erforderlich")
                elif response.status_code == 405:
                    self.log_result(f"API-Sicherheit: {endpoint}", "PASS", 
                                  "Methode nicht erlaubt (erwartet)")
                else:
                    self.log_result(f"API-Sicherheit: {endpoint}", "WARNING", 
                                  f"Status: {response.status_code} - Überprüfung empfohlen")
                    
            except Exception as e:
                self.log_result(f"API-Sicherheit: {endpoint}", "FAIL", f"Fehler: {str(e)}")
    
    def test_database_exposure(self):
        """Testet ob Datenbank direkt erreichbar ist"""
        # Teste bekannte Datenbank-Ports
        db_ports = [3306, 5432, 27017, 6379]  # MySQL, PostgreSQL, MongoDB, Redis
        
        parsed_url = urlparse(self.base_url)
        host = parsed_url.hostname
        
        for port in db_ports:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex((host, port))
                sock.close()
                
                if result == 0:
                    self.log_result(f"Datenbank-Port {port}", "FAIL", 
                                  f"Port {port} ist offen - Datenbank könnte erreichbar sein!")
                else:
                    self.log_result(f"Datenbank-Port {port}", "PASS", 
                                  f"Port {port} ist geschlossen")
                    
            except Exception as e:
                self.log_result(f"Datenbank-Port {port}", "WARNING", f"Test fehlgeschlagen: {str(e)}")
    
    def test_cors_configuration(self):
        """Testet CORS-Konfiguration"""
        try:
            # Teste mit verschiedenen Origins
            test_origins = [
                "https://malicious-site.com",
                "http://evil.com",
                "https://iqmedix.cloud",
                "https://subdomain.iqmedix.cloud"
            ]
            
            for origin in test_origins:
                headers = {"Origin": origin}
                response = requests.options(f"{self.base_url}/api/notes/", 
                                          headers=headers, timeout=10)
                
                cors_header = response.headers.get("Access-Control-Allow-Origin", "")
                
                if origin == "https://iqmedix.cloud" and cors_header == origin:
                    self.log_result(f"CORS für {origin}", "PASS", "Korrekt konfiguriert")
                elif origin != "https://iqmedix.cloud" and cors_header != "*":
                    self.log_result(f"CORS für {origin}", "PASS", "Nicht erlaubt (sicher)")
                else:
                    self.log_result(f"CORS für {origin}", "WARNING", 
                                  f"CORS-Header: {cors_header}")
                    
        except Exception as e:
            self.log_result("CORS-Konfiguration", "FAIL", f"Fehler: {str(e)}")
    
    def test_rate_limiting(self):
        """Testet Rate Limiting (falls implementiert)"""
        try:
            # Sende mehrere Anfragen schnell hintereinander
            responses = []
            for i in range(10):
                response = requests.get(f"{self.base_url}/api/notes/", timeout=5)
                responses.append(response.status_code)
                time.sleep(0.1)  # 100ms Pause
            
            # Prüfe ob Rate Limiting aktiv ist
            if 429 in responses:  # Too Many Requests
                self.log_result("Rate Limiting", "PASS", "Rate Limiting ist aktiv")
            else:
                self.log_result("Rate Limiting", "WARNING", "Rate Limiting nicht erkannt")
                
        except Exception as e:
            self.log_result("Rate Limiting", "FAIL", f"Fehler: {str(e)}")
    
    def test_websocket_security(self):
        """Testet WebSocket-Sicherheit"""
        try:
            ws_url = f"{self.base_url.replace('https://', 'wss://')}/ws/"
            
            # Einfacher WebSocket-Test (erfordert websocket-client library)
            self.log_result("WebSocket-Sicherheit", "INFO", 
                          "WebSocket-Test erfordert zusätzliche Library - manuell prüfen empfohlen")
            
        except Exception as e:
            self.log_result("WebSocket-Sicherheit", "WARNING", f"Test nicht möglich: {str(e)}")
    
    def run_all_tests(self):
        """Führt alle Sicherheitstests aus"""
        print("🔒 Starte Sicherheitstests für Note App...")
        print(f"🌐 Teste URL: {self.base_url}")
        print("=" * 60)
        
        self.test_https_connection()
        self.test_http_redirect()
        self.test_security_headers()
        self.test_api_endpoints_security()
        self.test_database_exposure()
        self.test_cors_configuration()
        self.test_rate_limiting()
        self.test_websocket_security()
        
        print("=" * 60)
        self.generate_report()
    
    def generate_report(self):
        """Generiert einen Sicherheitsbericht"""
        total_tests = len(self.results)
        passed = len([r for r in self.results if r["status"] == "PASS"])
        failed = len([r for r in self.results if r["status"] == "FAIL"])
        warnings = len([r for r in self.results if r["status"] == "WARNING"])
        
        print(f"\n📊 SICHERHEITSBERICHT")
        print(f"Gesamt Tests: {total_tests}")
        print(f"✅ Bestanden: {passed}")
        print(f"❌ Fehlgeschlagen: {failed}")
        print(f"⚠️  Warnungen: {warnings}")
        
        # Speichere Bericht
        report_file = "security_report.json"
        with open(report_file, "w", encoding="utf-8") as f:
            json.dump({
                "summary": {
                    "total": total_tests,
                    "passed": passed,
                    "failed": failed,
                    "warnings": warnings
                },
                "results": self.results
            }, f, indent=2, ensure_ascii=False)
        
        print(f"\n📄 Detaillierter Bericht gespeichert: {report_file}")
        
        # Empfehlungen
        if failed > 0:
            print("\n🚨 KRITISCHE PROBLEME GEFUNDEN:")
            for result in self.results:
                if result["status"] == "FAIL":
                    print(f"  - {result['test']}: {result['details']}")
        
        if warnings > 0:
            print("\n⚠️  EMPFOHLENE VERBESSERUNGEN:")
            for result in self.results:
                if result["status"] == "WARNING":
                    print(f"  - {result['test']}: {result['details']}")

def main():
    """Hauptfunktion"""
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        url = "https://iqmedix.cloud"
    
    tester = SecurityTester(url)
    tester.run_all_tests()

if __name__ == "__main__":
    main()
