#!/usr/bin/env python3
"""
Erweiterte Sicherheitstests für die Note App
Inklusive Penetration Testing und Vulnerability Scanning
"""

import requests
import socket
import ssl
import json
import sys
import time
import subprocess
import os
from urllib.parse import urlparse, urljoin
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

class AdvancedSecurityTester:
    def __init__(self, base_url="https://iqmedix.cloud"):
        self.base_url = base_url
        self.results = []
        self.session = requests.Session()
        
    def log_result(self, test_name, status, details="", severity="MEDIUM"):
        """Loggt Testergebnisse mit Schweregrad"""
        result = {
            "test": test_name,
            "status": status,
            "details": details,
            "severity": severity,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        self.results.append(result)
        
        # Farbige Ausgabe basierend auf Schweregrad
        if status == "PASS":
            print(f"✅ {test_name}: {details}")
        elif status == "FAIL":
            if severity == "HIGH":
                print(f"🚨 {test_name}: {details}")
            elif severity == "CRITICAL":
                print(f"💀 {test_name}: {details}")
            else:
                print(f"❌ {test_name}: {details}")
        else:
            print(f"⚠️  {test_name}: {details}")
    
    def test_sql_injection(self):
        """Testet auf SQL-Injection-Schwachstellen"""
        print("\n🔍 Teste SQL-Injection-Schwachstellen...")
        
        # SQL-Injection-Payloads
        payloads = [
            "' OR '1'='1",
            "'; DROP TABLE users; --",
            "' UNION SELECT * FROM users --",
            "admin'--",
            "1' OR '1' = '1' --",
            "' OR 1=1#",
            "' OR 1=1/*",
        ]
        
        # Teste verschiedene Endpunkte
        endpoints = [
            "/api/notes/",
            "/api/token",
            "/register/",
            "/api/users/"
        ]
        
        for endpoint in endpoints:
            url = urljoin(self.base_url, endpoint)
            
            for payload in payloads:
                try:
                    # Teste GET-Parameter
                    test_url = f"{url}?search={payload}"
                    response = self.session.get(test_url, timeout=10)
                    
                    # Prüfe auf SQL-Fehlermeldungen
                    error_indicators = [
                        "mysql_fetch_array",
                        "ORA-",
                        "PostgreSQL",
                        "SQL syntax",
                        "mysql_num_rows",
                        "mysql_fetch_assoc",
                        "mysql_fetch_object",
                        "mysql_fetch_row",
                        "mysql_fetch_field",
                        "mysql_fetch_lengths",
                        "mysql_fetch_all",
                        "mysql_fetch_array",
                        "mysql_fetch_assoc",
                        "mysql_fetch_object",
                        "mysql_fetch_row",
                        "mysql_fetch_field",
                        "mysql_fetch_lengths",
                        "mysql_fetch_all"
                    ]
                    
                    for indicator in error_indicators:
                        if indicator.lower() in response.text.lower():
                            self.log_result(f"SQL-Injection: {endpoint}", "FAIL", 
                                          f"SQL-Fehlermeldung erkannt: {indicator}", "CRITICAL")
                            return
                    
                    # Teste POST-Daten
                    if endpoint in ["/api/token", "/register/"]:
                        data = {"username": payload, "password": "test"}
                        response = self.session.post(url, data=data, timeout=10)
                        
                        for indicator in error_indicators:
                            if indicator.lower() in response.text.lower():
                                self.log_result(f"SQL-Injection POST: {endpoint}", "FAIL", 
                                              f"SQL-Fehlermeldung erkannt: {indicator}", "CRITICAL")
                                return
                                
                except Exception as e:
                    continue
        
        self.log_result("SQL-Injection", "PASS", "Keine SQL-Injection-Schwachstellen gefunden")
    
    def test_xss_vulnerabilities(self):
        """Testet auf XSS-Schwachstellen"""
        print("\n🔍 Teste XSS-Schwachstellen...")
        
        # XSS-Payloads
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "javascript:alert('XSS')",
            "<svg onload=alert('XSS')>",
            "'><script>alert('XSS')</script>",
            "<iframe src=javascript:alert('XSS')>",
            "<body onload=alert('XSS')>",
            "<input onfocus=alert('XSS') autofocus>",
        ]
        
        endpoints = [
            "/api/notes/",
            "/register/",
        ]
        
        for endpoint in endpoints:
            url = urljoin(self.base_url, endpoint)
            
            for payload in xss_payloads:
                try:
                    # Teste GET-Parameter
                    test_url = f"{url}?title={payload}&content={payload}"
                    response = self.session.get(test_url, timeout=10)
                    
                    # Prüfe ob Payload ungefiltert zurückgegeben wird
                    if payload in response.text:
                        self.log_result(f"XSS: {endpoint}", "FAIL", 
                                      f"XSS-Payload nicht gefiltert: {payload[:50]}...", "HIGH")
                        return
                    
                    # Teste POST-Daten
                    if endpoint == "/register/":
                        data = {
                            "username": payload,
                            "password": "test123",
                            "email": f"{payload}@test.com"
                        }
                        response = self.session.post(url, data=data, timeout=10)
                        
                        if payload in response.text:
                            self.log_result(f"XSS POST: {endpoint}", "FAIL", 
                                          f"XSS-Payload nicht gefiltert: {payload[:50]}...", "HIGH")
                            return
                            
                except Exception as e:
                    continue
        
        self.log_result("XSS-Schwachstellen", "PASS", "Keine XSS-Schwachstellen gefunden")
    
    def test_directory_traversal(self):
        """Testet auf Directory Traversal-Schwachstellen"""
        print("\n🔍 Teste Directory Traversal...")
        
        # Directory Traversal-Payloads
        traversal_payloads = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\drivers\\etc\\hosts",
            "....//....//....//etc/passwd",
            "..%2F..%2F..%2Fetc%2Fpasswd",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            "..%252F..%252F..%252Fetc%252Fpasswd",
            "..%c0%af..%c0%af..%c0%afetc%c0%afpasswd",
        ]
        
        endpoints = [
            "/api/notes/",
            "/api/users/",
            "/static/",
            "/files/",
        ]
        
        for endpoint in endpoints:
            url = urljoin(self.base_url, endpoint)
            
            for payload in traversal_payloads:
                try:
                    test_url = f"{url}?file={payload}"
                    response = self.session.get(test_url, timeout=10)
                    
                    # Prüfe auf typische Datei-Inhalte
                    if "root:" in response.text or "bin:" in response.text:
                        self.log_result(f"Directory Traversal: {endpoint}", "FAIL", 
                                      f"System-Datei erreichbar: {payload}", "CRITICAL")
                        return
                        
                except Exception as e:
                    continue
        
        self.log_result("Directory Traversal", "PASS", "Keine Directory Traversal-Schwachstellen gefunden")
    
    def test_authentication_bypass(self):
        """Testet auf Authentication Bypass-Schwachstellen"""
        print("\n🔍 Teste Authentication Bypass...")
        
        # Teste verschiedene Bypass-Techniken
        bypass_attempts = [
            # Leere Token
            {"Authorization": ""},
            # Ungültige Token
            {"Authorization": "Bearer invalid_token"},
            {"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"},
            # Falsche Token-Formate
            {"Authorization": "Basic dXNlcjpwYXNz"},
            {"Authorization": "Token invalid"},
            # Keine Header
            {},
        ]
        
        protected_endpoints = [
            "/api/notes/",
            "/api/users/",
        ]
        
        for endpoint in protected_endpoints:
            url = urljoin(self.base_url, endpoint)
            
            for headers in bypass_attempts:
                try:
                    response = self.session.get(url, headers=headers, timeout=10)
                    
                    # Prüfe ob Zugriff ohne gültige Authentifizierung möglich ist
                    if response.status_code == 200:
                        self.log_result(f"Auth Bypass: {endpoint}", "FAIL", 
                                      f"Zugriff ohne Authentifizierung möglich", "CRITICAL")
                        return
                        
                except Exception as e:
                    continue
        
        self.log_result("Authentication Bypass", "PASS", "Authentifizierung funktioniert korrekt")
    
    def test_information_disclosure(self):
        """Testet auf Information Disclosure"""
        print("\n🔍 Teste Information Disclosure...")
        
        # Sensible Endpunkte und Dateien
        sensitive_paths = [
            "/.env",
            "/config.php",
            "/wp-config.php",
            "/.git/config",
            "/.htaccess",
            "/robots.txt",
            "/sitemap.xml",
            "/api/",
            "/admin/",
            "/backup/",
            "/logs/",
            "/error_log",
            "/debug",
            "/test",
            "/phpinfo.php",
            "/info.php",
        ]
        
        for path in sensitive_paths:
            url = urljoin(self.base_url, path)
            try:
                response = self.session.get(url, timeout=10)
                
                # Prüfe auf sensible Informationen
                if response.status_code == 200:
                    content = response.text.lower()
                    
                    # Prüfe auf sensible Daten
                    sensitive_patterns = [
                        "database_password",
                        "db_password",
                        "secret_key",
                        "api_key",
                        "private_key",
                        "mysql",
                        "postgresql",
                        "sqlite",
                        "redis",
                        "mongodb",
                        "aws_access_key",
                        "aws_secret_key",
                        "stripe_secret_key",
                        "paypal_secret",
                    ]
                    
                    for pattern in sensitive_patterns:
                        if pattern in content:
                            self.log_result(f"Information Disclosure: {path}", "FAIL", 
                                          f"Sensible Informationen gefunden: {pattern}", "HIGH")
                            return
                    
                    # Prüfe auf Stack Traces
                    if "stack trace" in content or "exception" in content:
                        self.log_result(f"Information Disclosure: {path}", "FAIL", 
                                      f"Stack Trace gefunden", "MEDIUM")
                        return
                        
            except Exception as e:
                continue
        
        self.log_result("Information Disclosure", "PASS", "Keine sensiblen Informationen offengelegt")
    
    def test_port_scanning(self):
        """Führt einen Port-Scan durch"""
        print("\n🔍 Führe Port-Scan durch...")
        
        parsed_url = urlparse(self.base_url)
        host = parsed_url.hostname
        
        # Wichtige Ports zum Scannen
        important_ports = {
            21: "FTP",
            22: "SSH", 
            23: "Telnet",
            25: "SMTP",
            53: "DNS",
            80: "HTTP",
            110: "POP3",
            143: "IMAP",
            443: "HTTPS",
            3306: "MySQL",
            5432: "PostgreSQL",
            27017: "MongoDB",
            6379: "Redis",
            8080: "HTTP-Proxy",
            8443: "HTTPS-Alt",
            9000: "Jenkins/Web",
            9200: "Elasticsearch",
            27017: "MongoDB",
        }
        
        open_ports = []
        
        def scan_port(port):
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(3)
                result = sock.connect_ex((host, port))
                sock.close()
                return port if result == 0 else None
            except:
                return None
        
        # Paralleler Port-Scan
        with ThreadPoolExecutor(max_workers=20) as executor:
            future_to_port = {executor.submit(scan_port, port): port for port in important_ports.keys()}
            
            for future in as_completed(future_to_port):
                port = future.result()
                if port:
                    open_ports.append(port)
                    service = important_ports.get(port, "Unbekannt")
                    
                    # Bewerte die Sicherheit des offenen Ports
                    if port in [22, 80, 443]:
                        self.log_result(f"Port {port} ({service})", "PASS", "Standard-Port, erwartet")
                    elif port in [3306, 5432, 27017, 6379]:
                        self.log_result(f"Port {port} ({service})", "FAIL", 
                                      f"Datenbank-Port offen - Sicherheitsrisiko!", "CRITICAL")
                    elif port in [21, 23, 25, 110, 143]:
                        self.log_result(f"Port {port} ({service})", "FAIL", 
                                      f"Alter Service-Port offen - Sicherheitsrisiko!", "HIGH")
                    else:
                        self.log_result(f"Port {port} ({service})", "WARNING", 
                                      f"Ungewöhnlicher Port offen - Überprüfung empfohlen")
        
        if not open_ports:
            self.log_result("Port-Scan", "PASS", "Keine unerwarteten Ports offen")
    
    def test_ssl_tls_configuration(self):
        """Testet SSL/TLS-Konfiguration detailliert"""
        print("\n🔍 Teste SSL/TLS-Konfiguration...")
        
        parsed_url = urlparse(self.base_url)
        host = parsed_url.hostname
        
        try:
            # SSL-Kontext erstellen
            context = ssl.create_default_context()
            
            # Verbindung herstellen
            with socket.create_connection((host, 443), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=host) as ssock:
                    # SSL-Informationen abrufen
                    cipher = ssock.cipher()
                    version = ssock.version()
                    cert = ssock.getpeercert()
                    
                    # Teste SSL-Version
                    if "TLSv1.3" in version or "TLSv1.2" in version:
                        self.log_result("SSL-Version", "PASS", f"Moderne TLS-Version: {version}")
                    else:
                        self.log_result("SSL-Version", "FAIL", f"Veraltete SSL-Version: {version}", "HIGH")
                    
                    # Teste Cipher Suite
                    cipher_name = cipher[0]
                    if "AES" in cipher_name and "GCM" in cipher_name:
                        self.log_result("Cipher Suite", "PASS", f"Sichere Cipher: {cipher_name}")
                    elif "AES" in cipher_name:
                        self.log_result("Cipher Suite", "WARNING", f"Akzeptable Cipher: {cipher_name}")
                    else:
                        self.log_result("Cipher Suite", "FAIL", f"Schwache Cipher: {cipher_name}", "HIGH")
                    
                    # Teste Zertifikat
                    if cert:
                        subject = dict(x[0] for x in cert['subject'])
                        issuer = dict(x[0] for x in cert['issuer'])
                        
                        # Prüfe Zertifikat-Gültigkeit
                        not_after = cert.get('notAfter')
                        if not_after:
                            from datetime import datetime
                            expiry = datetime.strptime(not_after, '%b %d %H:%M:%S %Y %Z')
                            days_until_expiry = (expiry - datetime.now()).days
                            
                            if days_until_expiry > 30:
                                self.log_result("Zertifikat-Gültigkeit", "PASS", 
                                              f"Gültig für {days_until_expiry} Tage")
                            elif days_until_expiry > 0:
                                self.log_result("Zertifikat-Gültigkeit", "WARNING", 
                                              f"Läuft in {days_until_expiry} Tagen ab")
                            else:
                                self.log_result("Zertifikat-Gültigkeit", "FAIL", 
                                              f"Zertifikat abgelaufen!", "CRITICAL")
                        
                        self.log_result("Zertifikat-Details", "PASS", 
                                      f"Subject: {subject.get('commonName', 'N/A')}, "
                                      f"Issuer: {issuer.get('commonName', 'N/A')}")
                    
        except Exception as e:
            self.log_result("SSL/TLS-Konfiguration", "FAIL", f"SSL-Test fehlgeschlagen: {str(e)}", "HIGH")
    
    def run_all_tests(self):
        """Führt alle erweiterten Sicherheitstests aus"""
        print("🔒 Starte erweiterte Sicherheitstests für Note App...")
        print(f"🌐 Teste URL: {self.base_url}")
        print("=" * 70)
        
        self.test_sql_injection()
        self.test_xss_vulnerabilities()
        self.test_directory_traversal()
        self.test_authentication_bypass()
        self.test_information_disclosure()
        self.test_port_scanning()
        self.test_ssl_tls_configuration()
        
        print("=" * 70)
        self.generate_detailed_report()
    
    def generate_detailed_report(self):
        """Generiert einen detaillierten Sicherheitsbericht"""
        total_tests = len(self.results)
        passed = len([r for r in self.results if r["status"] == "PASS"])
        failed = len([r for r in self.results if r["status"] == "FAIL"])
        warnings = len([r for r in self.results if r["status"] == "WARNING"])
        
        # Nach Schweregrad gruppieren
        critical_issues = [r for r in self.results if r["status"] == "FAIL" and r["severity"] == "CRITICAL"]
        high_issues = [r for r in self.results if r["status"] == "FAIL" and r["severity"] == "HIGH"]
        medium_issues = [r for r in self.results if r["status"] == "FAIL" and r["severity"] == "MEDIUM"]
        
        print(f"\n📊 DETAILLIERTER SICHERHEITSBERICHT")
        print(f"Gesamt Tests: {total_tests}")
        print(f"✅ Bestanden: {passed}")
        print(f"❌ Fehlgeschlagen: {failed}")
        print(f"⚠️  Warnungen: {warnings}")
        
        print(f"\n🚨 KRITISCHE PROBLEME: {len(critical_issues)}")
        for issue in critical_issues:
            print(f"  💀 {issue['test']}: {issue['details']}")
        
        print(f"\n🔴 HOHE PROBLEME: {len(high_issues)}")
        for issue in high_issues:
            print(f"  🚨 {issue['test']}: {issue['details']}")
        
        print(f"\n🟡 MITTLERE PROBLEME: {len(medium_issues)}")
        for issue in medium_issues:
            print(f"  ⚠️  {issue['test']}: {issue['details']}")
        
        # Speichere detaillierten Bericht
        report_file = "advanced_security_report.json"
        with open(report_file, "w", encoding="utf-8") as f:
            json.dump({
                "summary": {
                    "total": total_tests,
                    "passed": passed,
                    "failed": failed,
                    "warnings": warnings,
                    "critical_issues": len(critical_issues),
                    "high_issues": len(high_issues),
                    "medium_issues": len(medium_issues)
                },
                "results": self.results
            }, f, indent=2, ensure_ascii=False)
        
        print(f"\n📄 Detaillierter Bericht gespeichert: {report_file}")
        
        # Sicherheitsbewertung
        if len(critical_issues) > 0:
            print("\n💀 SICHERHEITSBEWERTUNG: KRITISCH")
            print("   Sofortige Maßnahmen erforderlich!")
        elif len(high_issues) > 0:
            print("\n🚨 SICHERHEITSBEWERTUNG: HOCH")
            print("   Dringende Verbesserungen erforderlich!")
        elif len(medium_issues) > 0:
            print("\n⚠️  SICHERHEITSBEWERTUNG: MITTEL")
            print("   Verbesserungen empfohlen!")
        else:
            print("\n✅ SICHERHEITSBEWERTUNG: GUT")
            print("   App ist sicher konfiguriert!")

def main():
    """Hauptfunktion"""
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        url = "https://iqmedix.cloud"
    
    tester = AdvancedSecurityTester(url)
    tester.run_all_tests()

if __name__ == "__main__":
    main()
