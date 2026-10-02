/* Who made this, and what the port changed. */
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }

    Flickable {
        id: flaeche
        anchors.fill: parent
        contentWidth: width
        contentHeight: spalte.height + 32
        clip: true

        Column {
            id: spalte
            width: flaeche.width
            spacing: 10

            Kopf { titel: "About" }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "/usr/share/icons/hicolor/80x80/apps/infraview.png"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "InfraView " + fassung
                font.pixelSize: 26
                color: (theme.inverted ? "#ffffff" : "#000000")
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Device network information"
                font.pixelSize: 18
                color: (theme.inverted ? "#909090" : "#5e5e5e")
            }

            Ueberschrift { text: "Origin" }
            Item { width: 1; height: 6 }
            Absatz {
                text: "A port of InfraView for Sailfish OS by Arno Dekker (a-dekker). "
                      + "The pages, their layout and the lookups behind them are his; "
                      + "this build carries them to Harmattan."
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 32
                text: "github.com/a-dekker/infraview"
                onClicked: starter.oeffne("https://github.com/a-dekker/infraview")
            }

            Ueberschrift { text: "What is different here" }
            Item { width: 1; height: 6 }
            Absatz {
                text: "Silica became com.nokia.meego, and pyotherside -- which this "
                      + "platform does not have -- became a small bridge that runs the "
                      + "Python helpers out of process under python3.11."
            }
            Absatz {
                text: "Four tools upstream relies on are missing from the device, and each "
                      + "was replaced rather than dropped: the network sweep pokes every "
                      + "address and then reads the ARP cache, so devices that ignore ping "
                      + "still show up; the port scan is a plain connect; traceroute uses "
                      + "the socket error queue, because a raw socket is refused to us; and "
                      + "the ARP table is read straight out of /proc. Names come from the "
                      + "gateway, mDNS and NetBIOS -- the resolver on this phone knows "
                      + "nothing about the network it sits on. ConnMan has no counterpart "
                      + "on Harmattan, so its two pages are gone; what they showed about "
                      + "this connection is on the front page."
            }

            Ueberschrift { text: "Licence" }
            Item { width: 1; height: 6 }
            Absatz {
                text: "Upstream carries the three-clause BSD licence in its source "
                      + "headers, and that notice is kept here. Bundled dnspython is "
                      + "under the ISC licence, with its own LICENSE file beside it."
            }
            Item { width: 1; height: 16 }
        }
    }

    ScrollDecorator { flickableItem: flaeche }
}
