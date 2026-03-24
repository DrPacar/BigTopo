# BigTopo - GNS3 Testanleitung fuer AP 2.3 und AP 3.3

## Voraussetzungen

- GNS3 (Version 2.2+) installiert
- BigTopo-Topologie in GNS3 geladen
- `net-snmp-utils` auf dem Host installiert (`sudo dnf install net-snmp-utils`)

> **Empfohlen: Option C - kein Ubuntu noetig!**
> Der Fedora-Host verbindet sich direkt per TAP-Interface mit GNS3.

---

## 1. Host-Test (Option C - empfohlen, kein Ubuntu noetig)

### 1.1 Setup-Skript ausfuehren

```bash
# Wien testen (AP 2.3):
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/setup_host_test.sh wien

# OOE testen (AP 3.3):
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/setup_host_test.sh ooe

# Aufraeumen danach:
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/setup_host_test.sh clean
```

Das Skript erstellt automatisch:
- TAP-Interface `tap-bigtopo` auf dem Host
- IP 10.10.254.1 + 10.10.254.10 (Wien) bzw. 10.6.254.1 (OOE)
- Route zum jeweiligen Backbone
- rsyslog-Empfang auf Port 514

### 1.2 GNS3: Cloud-Node verbinden

1. GNS3 oeffnen, BigTopo-Projekt laden
2. **Cloud-Node** in die Topologie ziehen (aus der Geraete-Liste)
3. Cloud-Node **doppelklicken** → Reiter **"Ethernet interfaces"**
4. Interface **`tap-bigtopo`** auswaehlen und hinzufuegen
5. Cloud-Node verbinden mit:
   - **Wien**: Cloud → WIE-POP-1 **gig0/1**
   - **OOE**: Cloud → OOE-BB-1 **gig0/2** (oder OOE-S-1 fa0/1)
6. Topologie starten

---

## 2. Wien - Syslog und SNMP Server (AP 2.3)

### 2.1 Setup-Skripte (werden auf dem Server ausgefuehrt)

```bash
# Syslog-Server einrichten:
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/Backbone_Wien/WIE-SYSLOG

# SNMP-Server einrichten:
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/Backbone_Wien/snmp
```

### 2.2 Wien testen

#### Konnektivitaet pruefen
```bash
ping -c 3 10.10.254.254   # Gateway WIE-POP-1
ping -c 3 10.10.255.1     # WIE-BB-1
ping -c 3 10.10.255.2     # WIE-BB-2
ping -c 3 10.10.255.11    # WIE-POP-1
ping -c 3 10.10.255.12    # WIE-POP-2
ping -c 3 10.10.255.13    # WIE-POP-3
ping -c 3 10.10.255.14    # WIE-POP-4
```

#### SNMP testen - Lesender Zugriff (alle Geraete)
```bash
# BB-Router (Read-Write konfiguriert)
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.1 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.2 system

# POP-Router (Read-Only konfiguriert)
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.11 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.12 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.13 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.14 system
```

#### SNMP testen - Schreibender Zugriff (nur BB-Geraete)
```bash
# WIE-BB-1 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.1 sysContact.0 s "DiagNet NOC"

# WIE-BB-2 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.2 sysContact.0 s "DiagNet NOC"

# WIE-POP-1 (sollte FEHLSCHLAGEN - nur RO)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.11 sysContact.0 s "Test"
# Erwarteter Fehler: "noAccess" oder "authorizationError"
```

#### Syslog testen
```bash
# Auf dem Syslog-Server: eingehende Logs anzeigen
tail -f /var/log/bigtopo/*/*syslog.log

# Manuell eine Syslog-Nachricht senden (Test vom Host):
logger -n 10.10.254.10 -P 514 "TestNachricht BigTopo"

# Auf dem Router in GNS3 (WIE-BB-1 Console):
# WIE-BB-1# conf t
# WIE-BB-1(config)# interface gig0/0
# WIE-BB-1(config-if)# shutdown
# WIE-BB-1(config-if)# no shutdown
# -> Log erscheint dann in /var/log/bigtopo/WIE-BB-1/
```

---

## 3. Oberoesterreich - SNMP Server (AP 3.3)

### 3.1 Setup-Skript (wird auf dem Server ausgefuehrt)

```bash
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/Backbone_Oberoesterreich/OOE-SNMP.txt
```

### 3.2 OOE testen

#### Konnektivitaet pruefen
```bash
ping -c 3 10.6.254.253    # Gateway OOE-BB-1
ping -c 3 10.6.0.1        # OOE-BB-1
ping -c 3 10.6.0.2        # OOE-BB-2
ping -c 3 10.6.0.3        # OOE-BB-3
ping -c 3 10.6.0.11       # OOE-POP-1
ping -c 3 10.6.0.12       # OOE-POP-2
ping -c 3 10.6.0.13       # OOE-POP-3
ping -c 3 10.6.0.14       # OOE-POP-4
```

#### SNMP testen - Lesender Zugriff (alle Geraete)
```bash
# BB-Router (Read-Write)
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.2 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.3 system

# POP-Router (Read-Only)
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.11 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.12 system
```

#### SNMP testen - Schreibender Zugriff (BB-Geraete)
```bash
# OOE-BB-1 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 sysContact.0 s "DiagNet NOC"

# OOE-BB-2 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.2 sysContact.0 s "DiagNet NOC"

# OOE-BB-3 (sollte funktionieren - RW)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.3 sysContact.0 s "DiagNet NOC"

# OOE-POP-1 (sollte FEHLSCHLAGEN - nur RO)
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.11 sysContact.0 s "Test"
# Erwarteter Fehler: "noAccess"
```

---

## 4. Tipps und Troubleshooting

### Haeufige Probleme

1. **Kein Ping zum Gateway**: OSPF/IS-IS Adjacency pruefen
   - Wien: `show ospfv3 neighbor` auf WIE-POP-1
   - OOE: `show isis neighbors` auf OOE-BB-1
2. **SNMP Timeout**: ACL auf dem Router pruefen: `show access-list ACL_SNMP_SERVER`
3. **Syslog kommt nicht an**: `tcpdump -i tap-bigtopo port 514`
4. **tap-bigtopo fehlt**: Setup-Skript nochmals ausfuehren

### Nuetzliche Router-Befehle (GNS3 Console)
```
show snmp user
show snmp group
show logging
show ip route
show ospfv3 neighbor
show isis neighbors
```
