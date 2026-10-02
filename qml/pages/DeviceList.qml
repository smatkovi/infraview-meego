/*
  Everything answering in the local network.

  Upstream runs nmap through its suid wrapper. There is no nmap here, so
  netz.py pings the whole /24 itself in a thread pool and reads the MACs out
  of /proc/net/arp, which the sweep has just filled. The hosts appear as they
  answer rather than all at once at the end.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: { abfrage.abbrechen(); pageStack.pop() } }
        ToolIcon {
            iconId: abfrage.laeuft ? "toolbar-close" : "toolbar-refresh"
            onClicked: abfrage.laeuft ? abfrage.abbrechen() : holen()
        }
    }

    property string netz: ""

    Component.onCompleted: holen()

    function holen() {
        liste.model.clear()
        stand.text = "Sweeping..."
        abfrage.starte("geraete", [])
    }

    Abfrage {
        id: abfrage
        onAntwort: {
            if (daten.start !== undefined) {
                seite.netz = daten.netz
                stand.text = "Pinging " + daten.anzahl + " addresses in " + daten.netz
            } else if (daten.stand !== undefined) {
                stand.text = daten.stand
            } else if (daten.ip !== undefined) {
                liste.model.append(daten)
            } else if (daten.ende !== undefined) {
                stand.text = daten.gefunden + " device"
                             + (daten.gefunden === 1 ? "" : "s") + " in " + seite.netz
            } else if (daten.fehler !== undefined) {
                stand.text = daten.fehler
            }
        }
        onAbschluss: {
            if (!erfolg && liste.model.count === 0)
                stand.text = "The sweep was stopped."
        }
    }

    Column {
        id: kopfteil
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        Kopf { titel: "Devices"; laeuft: abfrage.laeuft }
        Text {
            id: stand
            x: 16
            width: parent.width - 32
            font.pixelSize: 17
            color: (theme.inverted ? "#909090" : "#5e5e5e")
            wrapMode: Text.WordWrap
        }
    }

    ListView {
        id: liste
        anchors.top: kopfteil.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: ListModel { }
        delegate: Item {
            width: liste.width
            height: 80
            Rectangle {
                anchors.fill: parent
                color: (theme.inverted ? "#2d2d2d" : "#c8c9ca")
                visible: beruehrung.pressed
            }
            Text {
                id: oben
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: pfeil.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 10
                text: model.name.length > 0 ? model.name : model.ip
                font.pixelSize: 23
                color: model.selbst ? (theme.inverted ? "#1e9ee8" : "#0b74b8") : (theme.inverted ? "#ffffff" : "#000000")
                elide: Text.ElideRight
            }
            Text {
                anchors.left: oben.left
                anchors.right: oben.right
                anchors.top: oben.bottom
                anchors.topMargin: 2
                text: (model.name.length > 0 ? model.ip + "  ·  " : "") + model.hw
                      + (model.selbst ? "  ·  this device"
                                      : (model.ping ? "" : "  ·  quiet, found by ARP"))
                font.pixelSize: 17
                color: (theme.inverted ? "#909090" : "#5e5e5e")
                elide: Text.ElideRight
            }
            Image {
                id: pfeil
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                source: "image://theme/icon-m-common-drilldown-arrow"
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                height: 1
                color: (theme.inverted ? "#303030" : "#c4c4c4")
            }
            MouseArea {
                id: beruehrung
                anchors.fill: parent
                onClicked: pageStack.push(Qt.resolvedUrl("DeviceInfo.qml"),
                                          { "ziel": model.ip })
            }
        }
    }

    ScrollDecorator { flickableItem: liste }
}
