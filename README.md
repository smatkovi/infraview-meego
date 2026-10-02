# InfraView for MeeGo / Harmattan

Device network information on the Nokia N9 and N950: what this device's own
connection looks like, the ARP cache, open and listening sockets, the other
devices answering in the local network, and where the connection comes out.
Ping, DNS lookups and traceroute are included.

A port of **[InfraView for Sailfish OS](https://github.com/a-dekker/infraview)
by Arno Dekker (a-dekker)**. The pages, their layout and the lookups behind
them are his; this carries them to a platform that is four years older than
the one he wrote them for.

![icon](icons/infraview-80.png)

## What the port had to change

**Silica became `com.nokia.meego`**, and the colours follow `theme.inverted`
so the app matches whichever theme the device is set to.

**pyotherside became a bridge.** Upstream embeds a Python interpreter in the
QML engine through pyotherside, which does not exist on Harmattan -- and the
system Python here is 2.6, too old for the helpers and for the TLS the
location page needs. So `src/helfer.cpp` runs the helpers out of process
under `python3.11` from `/opt/wunderw` and hands their output to QML line by
line, which is also how the slow pages (ping, traceroute, the sweep) report
as they go.

**Four tools upstream relies on are not on the device.** Each is replaced
rather than dropped:

| upstream | here |
|---|---|
| `nmap` sweep | poke every address, then read `/proc/net/arp` |
| `nmap` port scan | `connect_ex` against the common ports |
| `nmap` DHCP discovery | `ip -o -4 addr` and `/etc/resolv.conf` |
| `traceroute` | UDP socket with `IP_RECVERR`, hops out of the error queue |
| `arp` | `/proc/net/arp`, which is all the binary ever read |

Two of those are worth a word.

*The sweep* does not just ping. A host that drops ICMP -- most phones, plenty
of printers -- would never appear, and that is what nmap's local scan avoids
by going through ARP: every device on the segment has to answer ARP to be on
the network at all. So every address is poked once, and the ARP cache
afterwards says who is really there. On the network this was written on that
is six devices instead of four.

*Traceroute* needs no privileges. A raw socket is refused to a normal user,
and an aegis-installed package cannot earn the capability either. But a UDP
socket with `IP_RECVERR` set gets the ICMP time-exceeded delivered to its
error queue, which is how `tracepath` works, and that needs nothing.

**Names come from the gateway.** The resolver in `resolv.conf` is the proxy
icd2 runs, and it does not answer reverse queries for private addresses --
so `gethostbyaddr` returns nothing for every device on the network. The
router one hop away handed out the leases and knows them all, so it is asked
directly, with mDNS and NetBIOS behind it for devices the router does not
know.

**ConnMan has no counterpart on Harmattan**, so `ConnmanInfo` and
`ConnmanNetServices` are gone. What they showed about this connection --
type, name, address, netmask, gateway, resolver -- is on the front page
instead.

**The icon** is upstream's, filled out to Harmattan's squircle: the
background circle is swapped for a full-bleed rect in the SVG and then cut
with the alpha channel of a stock Blanco icon, so the silhouette is the
stock one pixel for pixel rather than an approximation. `make-icon.py`.

## Building

    make-icon.py            # the icon, needs cairosvg and Pillow
    tools/build.sh          # the binary, via MADDE on the build machine
    tools/mkdeb.sh 0.1.0    # -> build/infraview_0.1.0_armel.deb

Install with `aegis-dpkg -i` -- plain `dpkg -i` leaves the package unable to
start anything of its own.

Needs `python3.11` under `/opt/wunderw` on the device. The front page says so
if it is missing, rather than leaving every page silently empty.

## Licence

Upstream carries the three-clause BSD licence in its source headers
(Copyright 2013 Jolla Ltd., as the application template); that notice is in
`LICENSE`. Bundled dnspython is under the ISC licence and keeps its own
`LICENSE` file beside it in `python/dns/`.
