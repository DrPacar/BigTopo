# BigTopo - GNS3 Testanleitung fuer AP 2.3 und AP 3.3

## Voraussetzungen

- GNS3 installiert und geoeffnet
- `net-snmp-utils` installiert: `sudo dnf install net-snmp-utils`

---

## Schritt 1: TAP-Interface erstellen

Das TAP-Interface verbindet den Fedora-Host direkt mit GNS3 (keine VM noetig).

### Wien (AP 2.3):
```bash
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/setup_host_test.sh wien
```

### OOE (AP 3.3):
```bash
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/setup_host_test.sh ooe
```

Das Skript erstellt automatisch:
- TAP-Interface `tap-bigtopo` (persistent via nmcli, ueberlebt Reboot)
- IP 10.10.254.1 + 10.10.254.10 (Wien) bzw. 10.6.254.1 (OOE)
- Route zum jeweiligen Backbone
- rsyslog-Empfang auf Port 514 (nur Wien)

---

## Schritt 2: GNS3 Cloud-Node verbinden

1. GNS3 oeffnen, BigTopo-Projekt laden
2. **Cloud-Node** aus der Geraete-Liste in die Topologie ziehen
3. Cloud-Node **doppelklicken** → Tab **"TAP interfaces"**
4. **Refresh** klicken → `tap-bigtopo` erscheint in der Dropdown-Liste
5. `tap-bigtopo` auswaehlen → **Add** klicken
6. Cloud-Node mit dem Router verbinden:
   - **Wien**: Cloud → **WIE-POP-1 gig0/1**
   - **OOE**: Cloud → **OOE-BB-1 gig0/2**
7. Topologie starten (Play-Button)

---

## Schritt 3: Setup-Skripte auf dem "Server" ausfuehren

Da kein Ubuntu-Server laeuft, werden die Skripte direkt auf dem Fedora-Host ausgefuehrt.
Das setup_host_test.sh Skript (Schritt 1) hat die Netzwerkkonfiguration bereits uebernommen.
Die folgenden Skripte installieren zusaetzlich snmpd/rsyslog:

### Wien Syslog-Server einrichten:
```bash
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/Backbone_Wien/WIE-SYSLOG
```

### Wien SNMP-Server einrichten:
```bash
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/Backbone_Wien/snmp
```

### OOE SNMP-Server einrichten:
```bash
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/Backbone_Oberoesterreich/OOE-SNMP.txt
```

---

## Schritt 4: Testen

### Konnektivitaet pruefen (zuerst!)

**Wien:**
```bash
ping -c 3 10.10.254.254   # Gateway WIE-POP-1
ping -c 3 10.10.255.1     # WIE-BB-1
ping -c 3 10.10.255.2     # WIE-BB-2
ping -c 3 10.10.255.11    # WIE-POP-1
ping -c 3 10.10.255.12    # WIE-POP-2
ping -c 3 10.10.255.13    # WIE-POP-3
ping -c 3 10.10.255.14    # WIE-POP-4
```

**OOE:**
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

### SNMP testen - Lesen (alle Geraete)

**Wien BB-Router (Read-Write konfiguriert):**
```bash
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.1 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.2 system
```

**Wien POP-Router (Read-Only konfiguriert):**
```bash
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.11 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.12 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.13 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.14 system
```

**OOE BB-Router (Read-Write):**
```bash
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.2 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.3 system
```

**OOE POP-Router (Read-Only):**
```bash
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.11 system
snmpwalk -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.12 system
```

### SNMP testen - Schreiben (nur BB-Geraete)

**Wien BB (sollte funktionieren - RW):**
```bash
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.1 sysContact.0 s "DiagNet NOC"
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.2 sysContact.0 s "DiagNet NOC"
```

**Wien POP (muss FEHLSCHLAGEN - nur RO):**
```bash
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.10.255.11 sysContact.0 s "Test"
# Erwarteter Fehler: noAccess oder authorizationError
```

**OOE BB (sollte funktionieren - RW):**
```bash
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.1 sysContact.0 s "DiagNet NOC"
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.2 sysContact.0 s "DiagNet NOC"
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.3 sysContact.0 s "DiagNet NOC"
```

**OOE POP (muss FEHLSCHLAGEN - nur RO):**
```bash
snmpset -v3 -u bigtopo123 -l authPriv -a SHA -A bigtopo123 -x AES -X bigtopo123 10.6.0.11 sysContact.0 s "Test"
# Erwarteter Fehler: noAccess
```

### Syslog testen (Wien)

```bash
# Eingehende Logs beobachten:
tail -f /var/log/bigtopo/*/*syslog.log

# Testmeldung manuell senden:
logger -n 10.10.254.10 -P 514 "Test BigTopo Syslog"

# Auf dem Router in GNS3 (WIE-BB-1 Console) ein Interface kurz down/up:
# WIE-BB-1(config)# interface gig0/0
# WIE-BB-1(config-if)# shutdown
# WIE-BB-1(config-if)# no shutdown
# -> Log erscheint in /var/log/bigtopo/WIE-BB-1/
```

---

## Aufraeumen

```bash
sudo bash /home/dxnijel_s/Documents/BigTopo/topo/setup_host_test.sh clean
```

---

## Troubleshooting

| Problem | Loesung |
|---------|---------|
| `tap-bigtopo` erscheint nicht in GNS3 | Setup-Skript ausfuehren, dann **Refresh** in GNS3 Cloud-Node klicken |
| Kein Ping zum Gateway | OSPF/IS-IS pruefen: `show ospfv3 neighbor` / `show isis neighbors` |
| SNMP Timeout | ACL pruefen: `show access-list ACL_SNMP_SERVER` auf dem Router |
| Syslog kommt nicht an | `sudo tcpdump -i tap-bigtopo port 514` |
| Interface weg nach Reboot | `sudo bash setup_host_test.sh wien` erneut ausfuehren |

### Nuetzliche Router-Befehle (GNS3 Console)
```
show snmp user
show snmp group
show logging
show ip route
show ospfv3 neighbor
show isis neighbors
```
