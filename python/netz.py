#!/opt/wunderw/bin/python3.11
# -*- coding: utf-8 -*-
"""The helpers behind InfraView's pages, for Harmattan.

Upstream splits these over call_arp.py, call_ip.py, call_location.py,
call_netstat.py, call_nmap.py and get_ip_address.sh, and reaches them through
pyotherside. Here they are one script that the C++ side starts per call
(see src/helfer.cpp): argv[1] names the function, the rest are its arguments,
and the answer is JSON -- one object per line, so the slow ones (ping,
traceroute, the sweep) can report as they go instead of only at the end.

Four of upstream's tools are not on the device, and each is replaced rather
than dropped:

  nmap        -- the device sweep pings the /24 itself, in a thread pool,
                 and reads the MACs out of /proc/net/arp afterwards; the
                 port scan is connect_ex against a list of common ports.
  nmap (DHCP) -- get_ip_address.sh asked nmap's broadcast-dhcp-discover for
                 netmask, broadcast and domain. All three are in
                 `ip -o -4 addr` and /etc/resolv.conf already.
  traceroute  -- no binary, and a raw socket is refused to a normal user
                 (aegis grants no capabilities to self-built packages). The
                 unprivileged route works: a UDP socket with IP_RECVERR set
                 gets the ICMP time-exceeded delivered to its error queue,
                 which is how tracepath does it. Measured on the N950.
  arp         -- the binary only reads /proc/net/arp, which we read directly.
"""
import json
import os
import re
import socket
import struct
import subprocess
import sys

sys.path.insert(0, "/opt/infraview/python")

PING = "/bin/ping"


def sende(**felder):
    """One JSON object, one line, flushed -- the C++ side reads lines."""
    sys.stdout.write(json.dumps(felder) + "\n")
    sys.stdout.flush()


# ---------------------------------------------------------------- Netzwerk

def _route():
    """Active device and gateway, out of the routing table."""
    geraet, tor = "", ""
    try:
        aus = subprocess.check_output(["/bin/ip", "route"], stderr=subprocess.DEVNULL)
    except Exception:
        return geraet, tor
    for zeile in aus.decode("utf-8", "replace").splitlines():
        teile = zeile.split()
        if not teile:
            continue
        if teile[0] == "default":
            if "via" in teile:
                tor = teile[teile.index("via") + 1]
            if "dev" in teile:
                geraet = teile[teile.index("dev") + 1]
    if not geraet:
        for zeile in aus.decode("utf-8", "replace").splitlines():
            teile = zeile.split()
            if "dev" in teile:
                geraet = teile[teile.index("dev") + 1]
                break
    return geraet, tor


def _adresse(geraet):
    """Address, prefix and broadcast of one device."""
    ip, praefix, rund = "", 0, ""
    if not geraet:
        return ip, praefix, rund
    try:
        aus = subprocess.check_output(["/bin/ip", "-o", "-4", "addr", "list", geraet],
                                      stderr=subprocess.DEVNULL)
    except Exception:
        return ip, praefix, rund
    for zeile in aus.decode("utf-8", "replace").splitlines():
        teile = zeile.split()
        if "inet" not in teile:
            continue
        gefunden = teile[teile.index("inet") + 1]
        ip, _, breite = gefunden.partition("/")
        praefix = int(breite) if breite.isdigit() else 0
        if "brd" in teile:
            rund = teile[teile.index("brd") + 1]
    return ip, praefix, rund


def _maske(praefix):
    if not praefix:
        return ""
    bits = (0xFFFFFFFF << (32 - praefix)) & 0xFFFFFFFF
    return socket.inet_ntoa(struct.pack(">I", bits))


def _namensdienste():
    """The resolvers in /etc/resolv.conf. On Harmattan that is the local
       proxy icd2 runs; the addresses behind it are not exposed to us."""
    dienste = []
    try:
        with open("/etc/resolv.conf") as datei:
            for zeile in datei:
                teile = zeile.split()
                if len(teile) >= 2 and teile[0] == "nameserver":
                    dienste.append(teile[1])
    except Exception:
        pass
    return dienste


def _ssid(geraet):
    """Network name. Upstream takes this from contextkit's
       Internet.NetworkName; Harmattan ships the providers but not the QML
       plugin, so it is read off the interface instead."""
    if not geraet or not geraet.startswith("wlan"):
        return ""
    for werkzeug in ("/sbin/iwconfig", "/usr/sbin/iwconfig", "/bin/iwconfig"):
        if not os.path.exists(werkzeug):
            continue
        try:
            aus = subprocess.check_output([werkzeug, geraet], stderr=subprocess.DEVNULL)
        except Exception:
            continue
        treffer = re.search(r'ESSID:"([^"]*)"', aus.decode("utf-8", "replace"))
        if treffer:
            return treffer.group(1)
    return ""


def _art(geraet):
    if not geraet:
        return "none"
    if geraet.startswith("wlan"):
        return "WLAN"
    if geraet.startswith(("gprs", "ppp", "pdp", "rmnet", "usb")):
        return "Mobile"
    return geraet


def netzinfo():
    geraet, tor = _route()
    ip, praefix, rund = _adresse(geraet)
    dienste = _namensdienste()
    sende(geraet=geraet, tor=tor, ip=ip, praefix=praefix,
          netz=("%s/%d" % (_netzadresse(ip, praefix), praefix)) if ip and praefix else "",
          maske=_maske(praefix), rundruf=rund,
          dns=", ".join(dienste), ssid=_ssid(geraet), art=_art(geraet))


def _netzadresse(ip, praefix):
    if not ip or not praefix:
        return ""
    roh, = struct.unpack(">I", socket.inet_aton(ip))
    bits = (0xFFFFFFFF << (32 - praefix)) & 0xFFFFFFFF
    return socket.inet_ntoa(struct.pack(">I", roh & bits))


# --------------------------------------------------------------------- ARP

def arp():
    """The ARP cache. Same source the arp binary uses, same filtering as
       upstream's call_arp.py: incomplete entries (flags 0x0) are dropped."""
    from concurrent.futures import ThreadPoolExecutor

    eintraege = []
    try:
        with open("/proc/net/arp") as datei:
            next(datei)                      # header
            for zeile in datei:
                teile = zeile.split()
                if len(teile) < 6 or teile[2] == "0x0":
                    continue
                eintraege.append({
                    "ip": teile[0],
                    "hwtyp": "ether" if teile[1] == "0x1" else teile[1],
                    "flags": teile[2],
                    "hw": teile[3],
                    "geraet": teile[5],
                    "name": "",
                })
    except Exception as fehler:
        sende(fehler=str(fehler))
        return

    """Names come from the same places the device list uses -- the gateway
       first, which is the only one that knows the local leases. Done at once
       rather than one after another, or a full cache would take a minute."""
    with ThreadPoolExecutor(max_workers=16) as werkstatt:
        namen = list(werkstatt.map(lambda e: _geraetename(e["ip"]), eintraege))
    for eintrag, name in zip(eintraege, namen):
        eintrag["name"] = name

    sende(eintraege=eintraege)


def _rueckwaerts(ip):
    try:
        socket.setdefaulttimeout(1.0)
        return socket.gethostbyaddr(ip)[0]
    except Exception:
        return ""


# --------------------------------------------------------------------- DNS

def _ist_ip(text):
    for familie in (socket.AF_INET, socket.AF_INET6):
        try:
            socket.inet_pton(familie, text)
            return True
        except OSError:
            continue
    return False


def dnsabfrage(name, art="A"):
    """Upstream's show_ip_info, unchanged in substance. The nameserver stays
       127.0.0.1: Harmattan does run a local resolver (icd2's proxy), which
       was checked on the device rather than assumed."""
    try:
        import dns.flags
        import dns.message
        import dns.name
        import dns.rdatatype
        import dns.query
        import dns.resolver
        import dns.reversename
    except ImportError as fehler:
        sende(fehler="dnspython missing: %s" % fehler)
        return

    try:
        if _ist_ip(name):
            rueck = dns.reversename.from_address(name)
            antwort = dns.resolver.query(rueck, "PTR")[0]
        else:
            ZUSATZ = 65535
            typ = dns.rdatatype.from_text(art)
            frage = dns.message.make_query(name, typ)
            frage.flags |= dns.flags.AD
            frage.find_rrset(frage.additional, dns.name.root, ZUSATZ,
                             dns.rdatatype.OPT, create=True, force_unique=True)
            antwort = dns.query.udp(frage, "127.0.0.1", timeout=10)
        sende(text=str(antwort))
    except Exception as fehler:
        sende(fehler="%s: %s" % (type(fehler).__name__, fehler))


# -------------------------------------------------------------------- Ping

def ping(ziel, anzahl="4"):
    """Runs the system ping and passes its lines straight through. ping is
       not setuid here but still works as a user -- aegis holds the
       capability for it."""
    try:
        prozess = subprocess.Popen(
            [PING, "-c", str(int(anzahl)), "-W", "2", ziel],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    except Exception as fehler:
        sende(fehler=str(fehler))
        return
    for roh in prozess.stdout:
        zeile = roh.decode("utf-8", "replace").rstrip()
        if zeile:
            sende(zeile=zeile)
    prozess.wait()
    sende(ende=True, code=prozess.returncode)


# -------------------------------------------------------------- Traceroute

IP_RECVERR = 11
IP_TTL = 2
OFFENDER = 16          # offset of ee_offender in struct sock_extended_err


def traceroute(ziel, grenze="20"):
    """Hop by hop, without a raw socket: a UDP socket with IP_RECVERR set
       gets the ICMP time-exceeded in its error queue (MSG_ERRQUEUE), which
       needs no privileges at all. Same idea as tracepath."""
    try:
        adresse = socket.gethostbyname(ziel)
    except Exception as fehler:
        sende(fehler="%s: %s" % (type(fehler).__name__, fehler))
        return
    sende(start=True, ziel=ziel, adresse=adresse)

    import time
    for ttl in range(1, int(grenze) + 1):
        buchse = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        buchse.setsockopt(socket.IPPROTO_IP, IP_RECVERR, 1)
        buchse.setsockopt(socket.IPPROTO_IP, IP_TTL, ttl)
        buchse.settimeout(3.0)
        begonnen = time.time()
        station, fertig = "", False
        try:
            buchse.sendto(b"\0" * 12, (adresse, 33434 + ttl))
            try:
                buchse.recvfrom(512)        # the target answered itself
                station, fertig = adresse, True
            except socket.timeout:
                station = ""
            except OSError:
                _, zusatz, _, _ = buchse.recvmsg(512, 1024, socket.MSG_ERRQUEUE)
                for _stufe, _typ, daten in zusatz:
                    gegenueber = daten[OFFENDER:OFFENDER + 16]
                    familie, = struct.unpack("H", gegenueber[:2])
                    if familie == socket.AF_INET:
                        station = socket.inet_ntoa(gegenueber[4:8])
                    """ICMP type 3 is destination-unreachable: the datagram
                       arrived, so this hop is the target."""
                    fehlerart = struct.unpack("IBBBBII", daten[:16])[4]
                    if fehlerart == 3:
                        fertig = True
        except Exception as fehler:
            station = "(%s)" % fehler
        finally:
            buchse.close()

        dauer = (time.time() - begonnen) * 1000.0
        sende(sprung=ttl, station=station or "*",
              name=_rueckwaerts(station) if station else "",
              ms=round(dauer, 1) if station else 0)
        if fertig or station == adresse:
            break
    sende(ende=True)


# ----------------------------------------------------------------- Netstat

ZUSTAENDE = {
    "01": "ESTABLISHED", "02": "SYN_SENT", "03": "SYN_RECV", "04": "FIN_WAIT1",
    "05": "FIN_WAIT2", "06": "TIME_WAIT", "07": "CLOSE", "08": "CLOSE_WAIT",
    "09": "LAST_ACK", "0A": "LISTEN", "0B": "CLOSING",
}


def _adresse_lesen(roh, sechs):
    teil, _, hafen = roh.partition(":")
    hafen = int(hafen, 16)
    if sechs:
        gruppen = [teil[i:i + 8] for i in range(0, 32, 8)]
        bytes_ = b"".join(struct.pack("<I", int(g, 16)) for g in gruppen)
        return socket.inet_ntop(socket.AF_INET6, bytes_), hafen
    return socket.inet_ntoa(struct.pack("<I", int(teil, 16))), hafen


def _inoden():
    """inode -> process name, for whatever we are allowed to look at. As a
       normal user that is our own processes; upstream reads them all through
       a setuid helper, which an aegis-installed package cannot have."""
    tabelle = {}
    for eintrag in os.listdir("/proc"):
        if not eintrag.isdigit():
            continue
        pfad = "/proc/%s/fd" % eintrag
        try:
            namen = os.listdir(pfad)
        except OSError:
            continue
        """/proc/<pid>/comm only turned up in 2.6.33; this kernel is 2.6.32,
           so the name comes out of stat's second field instead."""
        name = ""
        try:
            with open("/proc/%s/stat" % eintrag) as datei:
                roh = datei.read()
            name = roh[roh.find("(") + 1:roh.rfind(")")]
        except OSError:
            pass
        for fd in namen:
            try:
                ziel = os.readlink("%s/%s" % (pfad, fd))
            except OSError:
                continue
            if ziel.startswith("socket:["):
                tabelle[ziel[8:-1]] = (eintrag, name)
    return tabelle


def netstat():
    besitzer = _inoden()
    verbindungen = []
    for datei, art, sechs in (("/proc/net/tcp", "tcp", False),
                              ("/proc/net/tcp6", "tcp6", True),
                              ("/proc/net/udp", "udp", False),
                              ("/proc/net/udp6", "udp6", True)):
        try:
            with open(datei) as griff:
                next(griff)
                for zeile in griff:
                    teile = zeile.split()
                    if len(teile) < 10:
                        continue
                    hier, hafen = _adresse_lesen(teile[1], sechs)
                    dort, gegenhafen = _adresse_lesen(teile[2], sechs)
                    pid, name = besitzer.get(teile[9], ("", ""))
                    verbindungen.append({
                        "art": art,
                        "lokal": hier, "lokalport": hafen,
                        "fern": dort, "fernport": gegenhafen,
                        "zustand": ZUSTAENDE.get(teile[3].upper(), teile[3])
                                   if art.startswith("tcp") else "",
                        "uid": teile[7], "pid": pid, "name": name,
                    })
        except OSError:
            continue
    sende(verbindungen=verbindungen)


# ------------------------------------------------------------------- Geräte

HAEUFIGE_HAEFEN = [21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 548,
                   554, 631, 993, 995, 1723, 3306, 3389, 5000, 5060, 5353,
                   6881, 8008, 8080, 8443, 9100]


def _anstossen(ziele):
    """Touch every address once so the kernel has to resolve it. A host that
       ignores ping still has to answer ARP to stay on the network at all,
       and that answer lands in /proc/net/arp -- which is how nmap finds the
       quiet ones too."""
    buchse = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    buchse.setblocking(False)
    for ziel in ziele:
        try:
            buchse.sendto(b"", (ziel, 9))       # discard port
        except OSError:
            pass
    buchse.close()


def _arptabelle():
    """ip -> MAC for every complete entry."""
    tabelle = {}
    try:
        with open("/proc/net/arp") as datei:
            next(datei)
            for zeile in datei:
                teile = zeile.split()
                if len(teile) >= 4 and teile[2] != "0x0" and teile[3] != "00:00:00:00:00:00":
                    tabelle[teile[0]] = teile[3]
    except OSError:
        pass
    return tabelle


def geraete():
    """Everything answering in the local network.

       Upstream runs nmap through its suid wrapper. There is none here, so
       this does what nmap's local sweep does, in two passes: first every
       address is poked so the kernel ARPs for it, then the ARP cache says
       who answered. Ping alone would miss every host that drops ICMP --
       which on a home network is most phones and plenty of printers."""
    from concurrent.futures import ThreadPoolExecutor

    geraet, _tor = _route()
    ip, praefix, _rund = _adresse(geraet)
    if not ip:
        sende(fehler="no address on this device")
        return
    if praefix < 22:
        praefix = 24                       # a /16 sweep would never finish
    basis = _netzadresse(ip, praefix)
    roh, = struct.unpack(">I", socket.inet_aton(basis))
    anzahl = (1 << (32 - praefix)) - 2
    sende(start=True, netz="%s/%d" % (basis, praefix), anzahl=anzahl)

    ziele = [socket.inet_ntoa(struct.pack(">I", roh + n)) for n in range(1, anzahl + 1)]

    vorher = set(_arptabelle())
    _anstossen(ziele)

    def klopfen(ziel):
        try:
            return ziel, subprocess.call(
                [PING, "-c", "1", "-W", "1", ziel],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0
        except Exception:
            return ziel, False

    lebendig = set()
    with ThreadPoolExecutor(max_workers=32) as werkstatt:
        for ziel, da in werkstatt.map(klopfen, ziele):
            if da:
                lebendig.add(ziel)
    sende(stand="asking for names", gefunden=len(lebendig))

    """The sweep has just refilled the cache; anything with a MAC in it is on
       this network whether it answered ping or not. Entries that were already
       there before the sweep are kept too -- they are neighbours we have
       talked to recently."""
    tabelle = _arptabelle()
    gefunden = sorted(lebendig | set(tabelle) | vorher,
                      key=lambda a: struct.unpack(">I", socket.inet_aton(a))[0])
    gefunden = [a for a in gefunden if a in tabelle or a in lebendig or a == ip]

    def beschreiben(ziel):
        """A device never ARPs for itself, so its own row has to be filled
           from the interface instead of from the cache."""
        if ziel == ip:
            return {"ip": ziel, "name": socket.gethostname(),
                    "hw": _eigene_hardware(geraet), "selbst": True, "ping": True}
        return {"ip": ziel, "name": _geraetename(ziel),
                "hw": tabelle.get(ziel, ""), "selbst": False,
                "ping": ziel in lebendig}

    with ThreadPoolExecutor(max_workers=16) as werkstatt:
        for eintrag in werkstatt.map(beschreiben, gefunden):
            sende(**eintrag)
    sende(ende=True, gefunden=len(gefunden))


def _eigene_hardware(geraet):
    try:
        with open("/sys/class/net/%s/address" % geraet) as datei:
            return datei.read().strip()
    except OSError:
        return ""


def _hardware(ziel):
    """The MAC of one address, out of the ARP cache."""
    return _arptabelle().get(ziel, "")


def _geraetename(ziel):
    """What to call a device on the local network.

       The resolver on this phone is icd2's proxy and knows nothing about the
       network it sits on, so a reverse lookup almost always comes back
       empty. The devices themselves do answer, though, each in its own
       dialect: Apple, Android and printers speak mDNS, Windows and Samba
       speak NetBIOS. Both are asked directly, which is where nmap gets its
       names from as well."""
    for weg in (_ptr_vom_tor, _mdns_name, _netbios_name, _rueckwaerts):
        try:
            name = weg(ziel)
        except Exception:
            name = ""
        if name:
            return name
    return ""


def _ptr_vom_tor(ziel):
    """The router almost always knows: it handed out the leases, and its own
       resolver answers for them. Asking it directly matters -- the proxy in
       resolv.conf does not forward reverse queries for private addresses,
       so the system call returns nothing while the gateway, one hop away,
       has every name."""
    _geraet, tor = _route()
    if not tor:
        return ""
    try:
        import dns.message
        import dns.rdatatype
        import dns.reversename
        import dns.query
    except ImportError:
        return ""
    frage = dns.message.make_query(dns.reversename.from_address(ziel),
                                   dns.rdatatype.PTR)
    antwort = dns.query.udp(frage, tor, timeout=2)
    for satz in antwort.answer:
        if satz.rdtype == dns.rdatatype.PTR:
            return str(satz[0]).rstrip(".")
    return ""


def _mdns_name(ziel):
    """Ask the device itself for its .local name: a reverse PTR query to the
       multicast address, which is what Bonjour and Avahi answer."""
    try:
        import dns.message
        import dns.rdatatype
        import dns.reversename
    except ImportError:
        return ""

    frage = dns.message.make_query(dns.reversename.from_address(ziel),
                                   dns.rdatatype.PTR)
    frage.id = 0                       # mDNS ignores the id and answers with 0
    buchse = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    buchse.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
    buchse.settimeout(1.2)
    try:
        buchse.sendto(frage.to_wire(), ("224.0.0.251", 5353))
        """Everything on the segment hears the question, so an answer is not
           necessarily to ours -- read on until one carries a PTR for it."""
        while True:
            roh, _woher = buchse.recvfrom(2048)
            try:
                antwort = dns.message.from_wire(roh)
            except Exception:
                continue
            for satz in antwort.answer:
                if satz.rdtype == dns.rdatatype.PTR:
                    return str(satz[0]).rstrip(".")
    except socket.timeout:
        return ""
    except OSError:
        return ""
    finally:
        buchse.close()
    return ""


def _netbios_name(ziel):
    """NetBIOS node status. The question is the name "*" padded to 16 bytes
       and written in the half-byte encoding NetBIOS uses, asked as NBSTAT;
       Windows and Samba answer with their name table."""
    roh = b"*" + b"\x00" * 15
    kodiert = bytearray()
    for byte in roh:
        kodiert.append(ord("A") + (byte >> 4))
        kodiert.append(ord("A") + (byte & 0x0F))
    frage = (struct.pack(">HHHHHH", 0x4247, 0x0000, 1, 0, 0, 0)
             + bytes([len(kodiert)]) + bytes(kodiert) + b"\x00"
             + struct.pack(">HH", 0x0021, 0x0001))

    buchse = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    buchse.settimeout(1.2)
    try:
        buchse.sendto(frage, (ziel, 137))
        antwort, _woher = buchse.recvfrom(1024)
    except OSError:
        return ""
    finally:
        buchse.close()

    """Past the header and the echoed question, then the answer's fixed part;
       the rdata starts with how many names follow, each 15 bytes plus a
       one-byte suffix and two flag bytes."""
    stelle = 12 + 1 + len(kodiert) + 1 + 4 + 4 + 2
    if len(antwort) < stelle + 1:
        return ""
    wieviele = antwort[stelle]
    stelle += 1
    for _ in range(wieviele):
        if len(antwort) < stelle + 18:
            break
        name = antwort[stelle:stelle + 15].decode("ascii", "replace").strip()
        kennung = antwort[stelle + 15]
        flaggen, = struct.unpack(">H", antwort[stelle + 16:stelle + 18])
        stelle += 18
        """Suffix 0x00 is the workstation name; the group bit marks the
           workgroup, which is not the machine."""
        if kennung == 0x00 and not (flaggen & 0x8000) and name:
            return name
    return ""


def geraeteinfo(ziel):
    """What upstream gets from nmap's port scan, as far as a plain connect
       can tell: which of the common ports accept a connection."""
    sende(start=True, ziel=ziel, name=_rueckwaerts(ziel), hw=_hardware(ziel),
          anzahl=len(HAEUFIGE_HAEFEN))
    from concurrent.futures import ThreadPoolExecutor

    def klopfen(hafen):
        buchse = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        buchse.settimeout(1.5)
        try:
            return hafen, buchse.connect_ex((ziel, hafen)) == 0
        except Exception:
            return hafen, False
        finally:
            buchse.close()

    offen = 0
    with ThreadPoolExecutor(max_workers=16) as werkstatt:
        for hafen, da in werkstatt.map(klopfen, HAEUFIGE_HAEFEN):
            if da:
                offen += 1
                sende(hafen=hafen, dienst=_dienstname(hafen))
    sende(ende=True, offen=offen)


def _dienstname(hafen):
    try:
        return socket.getservbyport(hafen)
    except Exception:
        return ""


# --------------------------------------------------------------------- Ort

def ort():
    """Geolocation of the external address, exactly upstream's source."""
    try:
        from requests import get
    except ImportError as fehler:
        sende(fehler="requests missing: %s" % fehler)
        return
    try:
        aussen = get("https://api.ipify.org", timeout=20).text.strip()
        antwort = get(url="https://tools.keycdn.com/geo.json?host=" + aussen,
                      headers={"User-Agent": "keycdn-tools:https://example.com"},
                      timeout=20).json()
        geo = antwort["data"]["geo"]
        sende(ip=aussen, **{schluessel: geo.get(schluessel, "") for schluessel in (
            "latitude", "longitude", "timezone", "continent_code", "country_code",
            "country_name", "city", "postal_code", "isp", "host", "asn")})
    except Exception as fehler:
        sende(fehler="%s: %s" % (type(fehler).__name__, fehler))


# -------------------------------------------------------------------------

FUNKTIONEN = {
    "netzinfo": netzinfo, "arp": arp, "dns": dnsabfrage, "ping": ping,
    "traceroute": traceroute, "netstat": netstat, "geraete": geraete,
    "geraeteinfo": geraeteinfo, "ort": ort,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in FUNKTIONEN:
        sende(fehler="usage: netz.py <%s> [args]" % "|".join(sorted(FUNKTIONEN)))
        return 2
    try:
        FUNKTIONEN[sys.argv[1]](*sys.argv[2:])
    except TypeError as fehler:
        sende(fehler="wrong arguments: %s" % fehler)
        return 2
    except Exception as fehler:
        sende(fehler="%s: %s" % (type(fehler).__name__, fehler))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
