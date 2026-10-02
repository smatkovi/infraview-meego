/*
  The overview: what this device's own connection looks like, and the way in
  to every other page.

  Upstream reads network type and name from contextkit (ContextProperty on
  Internet.NetworkType / Internet.NetworkName) and the rest from
  get_ip_address.sh, which asks nmap for a DHCP broadcast. Harmattan ships
  contextkit's providers but not its QML plugin, and has no nmap, so netzinfo
  in netz.py reads both off the interface instead.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: mainPage

    tools: ToolBarLayout {
        ToolIcon {
            iconId: "toolbar-refresh"
            onClicked: holen()
        }
        ToolIcon {
            iconId: "toolbar-view-menu"
            onClicked: pageStack.push(Qt.resolvedUrl("About.qml"))
        }
    }

    property bool laeuft: false
    property string netzbereich: ""

    Component.onCompleted: holen()

    function holen() {
        laeuft = true
        abfrage.starte("netzinfo", [])
    }

    Abfrage {
        id: abfrage
        onAbschluss: {
            mainPage.laeuft = false
            if (daten.fehler !== undefined) {
                geraet.wert = daten.fehler
                return
            }
            geraet.wert = daten.geraet
            adresse.wert = daten.ip
            maske.wert = daten.maske
            netz.wert = daten.netz
            rundruf.wert = daten.rundruf
            tor.wert = daten.tor
            dns.wert = daten.dns
            art.wert = daten.art
            name.wert = daten.ssid

            mainPage.netzbereich = daten.netz
        }
    }

    Flickable {
        id: flaeche
        anchors.fill: parent
        contentWidth: width
        contentHeight: spalte.height + 24
        clip: true

        Column {
            id: spalte
            width: flaeche.width
            spacing: 0

            Item {
                width: parent.width
                height: 72
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "InfraView"
                    font.pixelSize: 32
                    color: "#ffffff"
                }
                BusyIndicator {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    running: mainPage.laeuft
                    visible: running
                    platformStyle: BusyIndicatorStyle { size: "medium" }
                }
            }

            Text {
                /* python3.11 lives in /opt/wunderw and is put there by hand,
                   not by a package -- so this is a plausible state to be in,
                   and every page would otherwise just stay empty. */
                visible: !helfer.bereit
                x: 16
                width: parent.width - 32
                text: "python3.11 was not found in /opt/wunderw. "
                      + "Nothing on these pages can be looked up without it."
                font.pixelSize: 19
                color: "#e06060"
                wrapMode: Text.WordWrap
            }

            Ueberschrift { text: "Look around" }

            Eintrag {
                titel: "External IP info"
                beschreibung: "Where this connection comes out"
                onClicked: pageStack.push(Qt.resolvedUrl("LocationInfo.qml"))
            }
            Eintrag {
                titel: "Devices in current network"
                beschreibung: mainPage.netzbereich.length > 0
                              ? mainPage.netzbereich : "Scan the local network"
                onClicked: pageStack.push(Qt.resolvedUrl("DeviceList.qml"))
            }
            Eintrag {
                titel: "ARP cache table"
                beschreibung: "Neighbours this device has talked to"
                onClicked: pageStack.push(Qt.resolvedUrl("Arp.qml"))
            }
            Eintrag {
                titel: "Network port connections"
                beschreibung: "Open and listening sockets"
                onClicked: pageStack.push(Qt.resolvedUrl("Netstat.qml"))
            }

            Ueberschrift { text: "Tools" }

            Eintrag {
                titel: "Ping"
                beschreibung: "Is it there, and how far"
                onClicked: pageStack.push(Qt.resolvedUrl("PingPage.qml"))
            }
            Eintrag {
                titel: "DNS lookup"
                beschreibung: "Names, addresses and records"
                onClicked: pageStack.push(Qt.resolvedUrl("DnsPage.qml"))
            }
            Eintrag {
                titel: "Traceroute"
                beschreibung: "Every hop on the way out"
                onClicked: pageStack.push(Qt.resolvedUrl("TraceroutePage.qml"))
            }

            Ueberschrift { text: "This connection" }

            Item { width: 1; height: 8 }

            Zeile { id: art;     titel: "Network type" }
            Zeile { id: name;    titel: "Network name" }
            Zeile { id: geraet;  titel: "Interface" }
            Zeile { id: adresse; titel: "IP address"; betont: true }
            Zeile { id: maske;   titel: "Netmask" }
            Zeile { id: netz;    titel: "Network" }
            Zeile { id: rundruf; titel: "Broadcast" }
            Zeile { id: tor;     titel: "Gateway" }
            Zeile { id: dns;     titel: "Resolver" }

            Item { width: 1; height: 8 }

            Text {
                /* Worth saying plainly: the address in resolv.conf is icd2's
                   own proxy, not the server the network handed out. */
                visible: dns.wert === "127.0.0.1"
                width: parent.width - 32
                x: 16
                text: "The resolver is the local proxy icd2 runs; the addresses behind it are not exposed."
                font.pixelSize: 16
                color: "#808080"
                wrapMode: Text.WordWrap
            }
        }
    }

    ScrollDecorator { flickableItem: flaeche }
}
