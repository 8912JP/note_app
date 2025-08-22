-- ========================================
-- MYSQL SICHERHEITS-FIXES
-- Port 3306 ist von außen erreichbar - KRITISCH!
-- ========================================

-- 1. Alle MySQL-User anzeigen
SELECT User, Host FROM mysql.user;

-- 2. Alle User mit externem Zugriff löschen (außer localhost)
DELETE FROM mysql.user WHERE Host NOT IN ('localhost', '127.0.0.1', '::1');

-- 3. Root-User nur für localhost erlauben
UPDATE mysql.user SET Host = 'localhost' WHERE User = 'root' AND Host != 'localhost';

-- 4. Starke Passwörter setzen (CHANGE DIESE PASSWÖRTER!)
ALTER USER 'root'@'localhost' IDENTIFIED BY 'IhrSicheresPasswort123!';
-- ALTER USER 'ihr_app_user'@'localhost' IDENTIFIED BY 'IhrAppPasswort456!';

-- 5. Alle Privilegien für Root auf localhost beschränken
REVOKE ALL PRIVILEGES ON *.* FROM 'root'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;

-- 6. App-User mit minimalen Rechten erstellen (falls nicht vorhanden)
-- CREATE USER 'note_app'@'localhost' IDENTIFIED BY 'IhrAppPasswort456!';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON note_app.* TO 'note_app'@'localhost';

-- 7. Alle Änderungen anwenden
FLUSH PRIVILEGES;

-- 8. Überprüfung: Zeige alle aktiven User
SELECT User, Host FROM mysql.user WHERE Host != 'localhost';

-- 9. Zeige aktuelle MySQL-Konfiguration
SHOW VARIABLES LIKE 'bind_address';
SHOW VARIABLES LIKE 'skip_networking';

-- ========================================
-- ZUSÄTZLICHE SICHERHEITSMAßNAHMEN
-- ========================================

-- 10. MySQL-Logs aktivieren (falls nicht aktiv)
-- SET GLOBAL general_log = 'ON';
-- SET GLOBAL general_log_file = '/var/log/mysql/mysql.log';

-- 11. Zeige aktuelle Verbindungen
SHOW PROCESSLIST;

-- 12. Zeige MySQL-Version und Sicherheitsstatus
SELECT VERSION();
SHOW VARIABLES LIKE 'version%';

-- ========================================
-- NOTFALL-BEFEHLE (nur bei Problemen)
-- ========================================

-- MySQL komplett stoppen (nur im Notfall!)
-- sudo systemctl stop mysql

-- MySQL nur auf localhost binden (in my.cnf):
-- bind-address = 127.0.0.1

-- Firewall-Regel hinzufügen (Ubuntu/Debian):
-- sudo ufw deny 3306

-- Firewall-Regel hinzufügen (CentOS/RHEL):
-- sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="3306" protocol="tcp" reject'
-- sudo firewall-cmd --reload
