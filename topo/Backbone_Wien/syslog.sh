Syslog Skript:

#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Führe dieses Skript als Root aus (sudo ./setup-syslog.sh)"
  exit
fi

echo "[1/5] Aktualisiere Paketquellen und installiere rsyslog..."
apt-get update -qq
apt-get install rsyslog -y -qq

echo "[2/5] Erstelle rsyslog-Konfiguration für externe Geräte..."

cat << 'EOF' > /etc/rsyslog.d/50-network-devices.conf
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port="514")

template(name="RemoteDeviceLogs" type="string" string="/var/log/network/%HOSTNAME%/%$YEAR%-%$MONTH%-%$DAY%-syslog.log")

if ($fromhost-ip != '127.0.0.1') then {
    action(type="omfile" dynaFile="RemoteDeviceLogs")
    stop
}
EOF

echo "[3/5] Erstelle Zielverzeichnis /var/log/network/ ..."
mkdir -p /var/log/network/
chown syslog:adm /var/log/network/
chmod 755 /var/log/network/

echo "[4/5] Starte rsyslog Dienst neu..."
systemctl restart rsyslog
systemctl enable rsyslog

echo "[5/5] Konfiguriere Firewall (UFW) für Port 514 (TCP/UDP)..."
ufw allow 514/tcp comment 'Syslog TCP'
ufw allow 514/udp comment 'Syslog UDP'

echo "======================================================"
echo "✅ Einrichtung abgeschlossen!"
echo "Der Server lauscht nun auf Port 514 (UDP & TCP)."
echo "Eingehende Logs der Netzwerkkomponenten findest du unter:"
echo "/var/log/network/<Geräte-IP-oder-Name>/"
echo "======================================================"