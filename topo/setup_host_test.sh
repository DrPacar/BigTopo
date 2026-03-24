#!/bin/bash
# AP 2.3 / AP 3.3 - Host-basierter Test ohne Ubuntu-VM
# Dieses Skript richtet auf dem Fedora-Host direkt die SNMP/Syslog-Test-Umgebung ein.
# GNS3 verbindet sich via TAP-Interface (tap-bigtopo) mit dem Netzwerk.
#
# Nutzung: sudo bash setup_host_test.sh [wien|ooe|clean]

if [ "$EUID" -ne 0 ]; then
  echo "Fehler: Bitte als Root ausfuehren (sudo bash setup_host_test.sh)"
  exit 1
fi

MODE="${1:-wien}"

TAP_IF="tap-bigtopo"
WIEN_GW="10.10.254.254"     # WIE-POP-1 gig0/1
WIEN_SNMP="10.10.254.1"     # SNMP-Server IP
WIEN_SYSLOG="10.10.254.10"  # Syslog-Server IP
OOE_GW="10.6.254.253"       # OOE-BB-1 gig0/2
OOE_SNMP="10.6.254.1"       # OOE SNMP-Server IP

clean_up() {
  echo "[*] Raeume auf..."
  ip link del "$TAP_IF" 2>/dev/null || true
  systemctl stop rsyslog-bigtopo 2>/dev/null || true
  rm -f /etc/rsyslog.d/60-bigtopo-test.conf
  echo "[*] Fertig."
}

setup_wien() {
  echo "======================================================"
  echo " BigTopo Test-Setup: Wien (AP 2.3)"
  echo " TAP-Interface: $TAP_IF"
  echo " SNMP-Server:   $WIEN_SNMP/24"
  echo " Syslog-Server: $WIEN_SYSLOG/24"
  echo " Gateway:       $WIEN_GW (WIE-POP-1 gig0/1)"
  echo "======================================================"

  # TAP Interface erstellen
  echo "[1/5] Erstelle TAP-Interface '$TAP_IF'..."
  ip tuntap del "$TAP_IF" mode tap 2>/dev/null || true
  ip tuntap add "$TAP_IF" mode tap user "$SUDO_USER"
  ip link set "$TAP_IF" up
  ip link set "$TAP_IF" promisc on

  # IPs fuer SNMP und Syslog auf das TAP-Interface
  echo "[2/5] Weise IPs zu..."
  ip addr add "$WIEN_SNMP/24"   dev "$TAP_IF" 2>/dev/null || true
  ip addr add "$WIEN_SYSLOG/24" dev "$TAP_IF" 2>/dev/null || true

  # Routing: Wien-Backbone via WIE-POP-1
  echo "[3/5] Setze Route fuer Wien-Backbone..."
  ip route add 10.10.0.0/16 via "$WIEN_GW" dev "$TAP_IF" 2>/dev/null || true

  # rsyslog fuer Empfang konfigurieren
  echo "[4/5] Konfiguriere rsyslog (Port 514)..."
  cat > /etc/rsyslog.d/60-bigtopo-test.conf << 'EOF'
module(load="imudp")
input(type="imudp" port="514")
module(load="imtcp")
input(type="imtcp" port="514")
template(name="BigTopoLogs" type="string"
         string="/var/log/bigtopo/%HOSTNAME%/%$YEAR%-%$MONTH%-%$DAY%-syslog.log")
if ($fromhost-ip startswith "10.10.") then {
    action(type="omfile" dynaFile="BigTopoLogs")
    stop
}
EOF
  mkdir -p /var/log/bigtopo
  systemctl restart rsyslog
  echo "[5/5] Firewall: Port 514 oeffnen..."
  firewall-cmd --add-port=514/udp --add-port=514/tcp 2>/dev/null || \
    iptables -I INPUT -p udp --dport 514 -j ACCEPT 2>/dev/null || true

  echo ""
  echo "======================================================"
  echo " SETUP FERTIG - Wien"
  echo "======================================================"
  echo ""
  echo " In GNS3:"
  echo "   1. 'Cloud' Node in Topologie ziehen"
  echo "   2. Cloud konfigurieren: Interface = $TAP_IF"
  echo "   3. Cloud verbinden mit: WIE-POP-1 gig0/1"
  echo "   4. GNS3-Topologie starten"
  echo ""
  echo " Dann testen:"
  echo "   Ping Gateway:  ping -c3 $WIEN_GW"
  echo "   Ping BB-1:     ping -c3 10.10.255.1"
  echo "   SNMP Wien BB:  snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.1 system"
  echo "   SNMP Wien POP: snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.11 system"
  echo "   Syslog Log:    tail -f /var/log/bigtopo/*/*syslog.log"
  echo "======================================================"
}

setup_ooe() {
  echo "======================================================"
  echo " BigTopo Test-Setup: OOE (AP 3.3)"
  echo " TAP-Interface: $TAP_IF"
  echo " SNMP-Server:   $OOE_SNMP/24"
  echo " Gateway:       $OOE_GW (OOE-BB-1 gig0/2)"
  echo "======================================================"

  echo "[1/3] Erstelle TAP-Interface '$TAP_IF'..."
  ip tuntap del "$TAP_IF" mode tap 2>/dev/null || true
  ip tuntap add "$TAP_IF" mode tap user "$SUDO_USER"
  ip link set "$TAP_IF" up
  ip link set "$TAP_IF" promisc on

  echo "[2/3] Weise IPs zu..."
  ip addr add "$OOE_SNMP/24" dev "$TAP_IF" 2>/dev/null || true

  echo "[3/3] Setze Route fuer OOE-Backbone..."
  ip route add 10.6.0.0/16 via "$OOE_GW" dev "$TAP_IF" 2>/dev/null || true

  echo ""
  echo "======================================================"
  echo " SETUP FERTIG - OOE"
  echo "======================================================"
  echo ""
  echo " In GNS3:"
  echo "   1. 'Cloud' Node in Topologie ziehen"
  echo "   2. Cloud konfigurieren: Interface = $TAP_IF"
  echo "   3. Cloud verbinden mit: OOE-BB-1 gig0/2 (oder OOE-S-1 fa0/1)"
  echo "   4. GNS3-Topologie starten"
  echo ""
  echo " Dann testen:"
  echo "   Ping Gateway:     ping -c3 $OOE_GW"
  echo "   Ping OOE-BB-1:    ping -c3 10.6.0.1"
  echo "   SNMP OOE BB (RW): snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 system"
  echo "   SNMP OOE POP (RO):snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.11 system"
  echo "   SNMP Set Test:    snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 sysContact.0 s 'DiagNet NOC'"
  echo "======================================================"
}

case "$MODE" in
  wien)  setup_wien ;;
  ooe)   setup_ooe  ;;
  clean) clean_up   ;;
  *)
    echo "Nutzung: sudo bash setup_host_test.sh [wien|ooe|clean]"
    exit 1
    ;;
esac
