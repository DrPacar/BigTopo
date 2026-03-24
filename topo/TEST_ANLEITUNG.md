# BigTopo - GNS3 Testanleitung fuer AP 2.3 und AP 3.3

## Voraussetzungen

- GNS3 (Version 2.2+) installiert
- VirtualBox mit Ubuntu 22.04 LTS VM
- BigTopo-Topologie in GNS3 geladen
- VM hat mindestens 2 Netzwerkadapter konfiguriert (fuer Wien: SNMP + Syslog)

---

## 1. VirtualBox VM vorbereiten

### VM-Netzwerkadapter in VirtualBox konfigurieren

Die Ubuntu-VM benoetigt **einen zusaetzlichen Adapter** fuer GNS3 (Adapter 1 = NAT bleibt unveraendert).

1. VirtualBox oeffnen, VM auswaehlen, **Einstellungen** > **Netzwerk**
2. **Adapter 1**: NAT belassen (fuer Internet-Zugang der VM) - Promiscuous "Deny" ist bei NAT normal und unveraenderbar
3. **Adapter 2** (Tab anklicken):
   - Haken bei "Enable Network Adapter" setzen
   - **Attached to**: `Not attached` (Nicht angeschlossen)
   - **Erweitert** > Adaptertyp: **Intel PRO/1000 MT Desktop (82540EM)**
   - **Promiscuous-Modus**: Bleibt zunaechst "Deny" - GNS3 setzt diesen automatisch auf "Allow All" wenn die VM in die Topologie gezogen wird

> **Hinweis**: NAT-Adapter haben immer gesperrtes Promiscuous Mode (ausgegraut) - das ist normales VirtualBox-Verhalten und kein Fehler. GNS3 benoetigt Promiscuous Mode nur auf dem Adapter, den es selbst verwaltet (Adapter 2).

---

## 2. Wien - Syslog und SNMP Server einrichten

### 2.1 GNS3-Topologie: VM mit WIE-POP-1 verbinden

1. In GNS3: **Edit** > **Preferences** > **VirtualBox VMs**
2. **New** > VM auswaehlen (Ubuntu 22.04) > **Finish**
3. Die VirtualBox-VM in die Topologie ziehen
4. **Verbindung herstellen**:
   - VM **eth0** <---> **WIE-POP-1 gig0/1** (Management-Netz 10.10.254.0/24)

### 2.2 VM starten und Netzwerk konfigurieren

In der Ubuntu-VM ein Terminal oeffnen:

```bash
# SNMP-Server IP (10.10.254.1) und Syslog-Server IP (10.10.254.10) auf eth0
# Beide Server teilen sich das gleiche Subnetz, also zwei IPs auf einem Interface:
sudo ip addr add 10.10.254.1/24 dev eth0
sudo ip addr add 10.10.254.10/24 dev eth0
sudo ip link set eth0 up
sudo ip route add default via 10.10.254.254
```

### 2.3 Setup-Skripte ausfuehren

```bash
# Syslog-Server einrichten
cd /pfad/zu/BigTopo/topo/Backbone_Wien/
sudo bash WIE-SYSLOG

# SNMP-Server einrichten
sudo bash snmp
```

### 2.4 Wien testen

#### Konnektivitaet pruefen
```bash
# Ping zum Gateway (WIE-POP-1)
ping -c 3 10.10.254.254

# Ping zu Loopbacks (muessen via OSPF erreichbar sein)
ping -c 3 10.10.255.1    # WIE-BB-1
ping -c 3 10.10.255.2    # WIE-BB-2
ping -c 3 10.10.255.11   # WIE-POP-1
ping -c 3 10.10.255.12   # WIE-POP-2
ping -c 3 10.10.255.13   # WIE-POP-3
ping -c 3 10.10.255.14   # WIE-POP-4
```

#### SNMP testen - Lesender Zugriff (alle Geraete)
```bash
# SNMPv3 Walk auf WIE-BB-1 (BB = Read-Write)
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.1 system

# SNMPv3 Get auf WIE-POP-1 (POP = Read-Only)
snmpget -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.11 sysName.0

# SNMPv3 Walk auf WIE-POP-2
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.12 system

# SNMPv3 Walk auf WIE-POP-3
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.13 system

# SNMPv3 Walk auf WIE-POP-4
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.14 system
```

#### SNMP testen - Schreibender Zugriff (nur BB-Geraete)
```bash
# SNMPv3 Set auf WIE-BB-1 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.1 sysContact.0 s "DiagNet NOC"

# SNMPv3 Set auf WIE-BB-2 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.2 sysContact.0 s "DiagNet NOC"

# SNMPv3 Set auf WIE-POP-1 (sollte FEHLSCHLAGEN - nur RO)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.11 sysContact.0 s "Test"
# Erwarteter Fehler: "noAccess" oder "authorizationError"
```

#### Syslog testen
```bash
# Auf dem Router (WIE-BB-1 CLI in GNS3):
# WIE-BB-1# debug ip ospf events
# WIE-BB-1# conf t
# WIE-BB-1(config)# interface gig0/0
# WIE-BB-1(config-if)# shutdown
# WIE-BB-1(config-if)# no shutdown

# Auf dem Syslog-Server pruefen:
ls /var/log/network/
tail -f /var/log/network/*/$(date +%Y-%m-%d)-syslog.log

# Manuell Syslog-Nachricht senden (Test):
logger -n 10.10.254.10 -P 514 "TestNachricht von der Management-VM"
```

---

## 3. Oberoesterreich (OOE) - SNMP Server einrichten

### 3.1 GNS3-Topologie: VM mit OOE-BB-1 via OOE-S-1 verbinden

1. Eine zweite VirtualBox-VM (oder die gleiche mit anderem Adapter) in GNS3 ziehen
2. **Verbindung herstellen**:
   - VM **eth0** <---> **OOE-S-1 fa0/1** (Management-Netz 10.6.254.0/24)
3. OOE-S-1 ist bereits verbunden:
   - **fa0/24** <---> **OOE-BB-3 gig0/1** (10.6.254.252 - Gateway zum IS-IS Backbone)
   - **fa0/23** <---> **OOE-BB-1 gig0/2** (10.6.254.253 - zweiter Uplink)

### 3.2 VM starten und Netzwerk konfigurieren

```bash
sudo ip addr add 10.6.254.1/24 dev eth0
sudo ip link set eth0 up
sudo ip route add default via 10.6.254.253
```

### 3.3 Setup-Skript ausfuehren

```bash
cd /pfad/zu/BigTopo/topo/Backbone_Oberoesterreich/
sudo bash OOE-SNMP.txt
```

### 3.4 OOE testen

#### Konnektivitaet pruefen
```bash
# Ping zum Gateway (OOE-BB-1)
ping -c 3 10.6.254.253

# Ping zu Loopbacks (muessen via IS-IS erreichbar sein)
ping -c 3 10.6.0.1     # OOE-BB-1
ping -c 3 10.6.0.2     # OOE-BB-2
ping -c 3 10.6.0.3     # OOE-BB-3
ping -c 3 10.6.0.11    # OOE-POP-1
ping -c 3 10.6.0.12    # OOE-POP-2
ping -c 3 10.6.0.13    # OOE-POP-3
ping -c 3 10.6.0.14    # OOE-POP-4
```

#### SNMP testen - Lesender Zugriff (alle Geraete)
```bash
# SNMPv3 Walk auf OOE-BB-1 (BB = Read-Write)
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 system

# SNMPv3 Walk auf OOE-POP-1 (POP = Read-Only)
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.11 system
```

#### SNMP testen - Schreibender Zugriff (alle OOE-Geraete laut AP 3.3: BB = RW)
```bash
# SNMPv3 Set auf OOE-BB-1 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 sysContact.0 s "DiagNet NOC"

# SNMPv3 Set auf OOE-BB-2 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.2 sysContact.0 s "DiagNet NOC"

# SNMPv3 Set auf OOE-BB-3 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.3 sysContact.0 s "DiagNet NOC"

# SNMPv3 Set auf OOE-POP-1 (sollte FEHLSCHLAGEN - nur RO)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.11 sysContact.0 s "Test"
# Erwarteter Fehler: "noAccess"
```

---

## 4. GNS3 Einstellungen / Tipps

### VirtualBox-Adapter in GNS3

- In GNS3 die VM als **VirtualBox VM** hinzufuegen (nicht als Docker/QEMU)
- Unter VM-Einstellungen in GNS3: **Adapters** auf 2 setzen (fuer Wien, 1 fuer OOE)
- Adaptertyp: **Intel PRO/1000 MT Desktop**
- "Allow GNS3 to use any configured VirtualBox adapter" aktivieren

### Haeufige Probleme

1. **Kein Ping zum Gateway**: OSPF/IS-IS Adjacency pruefen (`show ospfv3 neighbor` / `show isis neighbors`)
2. **SNMP Timeout**: ACL auf dem Router pruefen (`show access-list ACL_SNMP_SERVER`)
3. **Syslog kommt nicht an**: `tcpdump -i eth0 port 514` auf dem Server ausfuehren
4. **VM sieht das Netzwerk nicht**: VirtualBox Promiscuous-Modus pruefen

### Nuetzliche Router-Befehle (GNS3 Console)
```
show snmp user
show snmp group
show logging
show ip route
show ospfv3 neighbor
show isis neighbors
```
