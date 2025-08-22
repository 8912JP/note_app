#!/bin/bash
# ========================================
# FIREWALL-SICHERHEITS-FIX
# Port 3306 ist von außen erreichbar - KRITISCH!
# ========================================

echo "🚨 NOTFALL-FIREWALL-KONFIGURATION"
echo "=================================="

# Prüfe ob als Root ausgeführt
if [ "$EUID" -ne 0 ]; then
    echo "❌ Dieses Skript muss als Root ausgeführt werden!"
    echo "   Verwenden Sie: sudo bash firewall_security_fix.sh"
    exit 1
fi

# 1. UFW (Ubuntu/Debian)
if command -v ufw &> /dev/null; then
    echo "🔧 Konfiguriere UFW Firewall..."
    
    # UFW aktivieren
    ufw --force enable
    
    # Port 3306 blockieren
    ufw deny 3306
    
    # Standard-Ports erlauben
    ufw allow 22/tcp   # SSH
    ufw allow 80/tcp   # HTTP
    ufw allow 443/tcp  # HTTPS
    
    # UFW-Status anzeigen
    echo "📊 UFW-Status:"
    ufw status numbered
    
    echo "✅ UFW konfiguriert - Port 3306 blockiert"
fi

# 2. firewalld (CentOS/RHEL/Fedora)
if command -v firewall-cmd &> /dev/null; then
    echo "🔧 Konfiguriere firewalld..."
    
    # firewalld aktivieren
    systemctl enable firewalld
    systemctl start firewalld
    
    # Port 3306 blockieren
    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="3306" protocol="tcp" reject'
    
    # Standard-Ports erlauben
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    
    # Änderungen anwenden
    firewall-cmd --reload
    
    # Firewall-Status anzeigen
    echo "📊 Firewalld-Status:"
    firewall-cmd --list-all
    
    echo "✅ Firewalld konfiguriert - Port 3306 blockiert"
fi

# 3. iptables (Fallback)
if ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null; then
    echo "🔧 Konfiguriere iptables..."
    
    # Port 3306 blockieren
    iptables -A INPUT -p tcp --dport 3306 -j DROP
    iptables -A OUTPUT -p tcp --dport 3306 -j DROP
    
    # Standard-Ports erlauben
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT   # SSH
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # HTTP
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS
    
    # iptables-Regeln speichern
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo "✅ iptables konfiguriert - Port 3306 blockiert"
fi

# 4. MySQL-Konfiguration prüfen
echo "🔍 Prüfe MySQL-Konfiguration..."

# MySQL-Konfigurationsdatei finden
MYSQL_CONF=""
for conf in /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/my.cnf /etc/my.cnf; do
    if [ -f "$conf" ]; then
        MYSQL_CONF="$conf"
        break
    fi
done

if [ -n "$MYSQL_CONF" ]; then
    echo "📁 MySQL-Konfiguration gefunden: $MYSQL_CONF"
    
    # Prüfe bind-address
    if grep -q "bind-address" "$MYSQL_CONF"; then
        echo "✅ bind-address ist konfiguriert"
        grep "bind-address" "$MYSQL_CONF"
    else
        echo "⚠️  bind-address nicht gefunden - MySQL könnte auf allen Interfaces lauschen"
        echo "   Fügen Sie hinzu: bind-address = 127.0.0.1"
    fi
else
    echo "⚠️  MySQL-Konfigurationsdatei nicht gefunden"
fi

# 5. Aktive Verbindungen prüfen
echo "🔍 Prüfe aktive Verbindungen auf Port 3306..."
if command -v netstat &> /dev/null; then
    netstat -tlnp | grep :3306
elif command -v ss &> /dev/null; then
    ss -tlnp | grep :3306
fi

# 6. MySQL-Service neu starten (optional)
echo ""
read -p "🔄 MySQL-Service neu starten? (j/n): " restart_mysql
if [ "$restart_mysql" = "j" ] || [ "$restart_mysql" = "J" ]; then
    echo "🔄 Starte MySQL-Service neu..."
    systemctl restart mysql
    echo "✅ MySQL-Service neu gestartet"
fi

# 7. Finale Überprüfung
echo ""
echo "🔍 Finale Sicherheitsüberprüfung..."
echo "=================================="

# Port 3306 nochmal testen
if command -v nc &> /dev/null; then
    if nc -z localhost 3306 2>/dev/null; then
        echo "✅ Port 3306 ist lokal erreichbar (erwartet)"
    else
        echo "❌ Port 3306 ist nicht lokal erreichbar"
    fi
fi

# Externen Port-Test (falls möglich)
echo "🌐 Externer Port-Test (kann fehlschlagen wenn Firewall aktiv):"
if command -v nc &> /dev/null; then
    if nc -z 85.214.234.2 3306 2>/dev/null; then
        echo "❌ Port 3306 ist immer noch extern erreichbar!"
    else
        echo "✅ Port 3306 ist extern blockiert"
    fi
fi

echo ""
echo "✅ Firewall-Sicherheitsfix abgeschlossen!"
echo "📝 Überprüfen Sie die MySQL-Konfiguration manuell"
echo "🔍 Führen Sie regelmäßige Sicherheitstests durch"
