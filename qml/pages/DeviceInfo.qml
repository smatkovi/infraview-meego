/*
  One host, looked at a little closer.

  nmap's service and OS detection has no replacement here, so this is what a
  plain connect can tell: which of the common ports accept one. That is less
  than upstream shows, and the page says so rather than implying a full scan.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    property string ziel: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: { abfrage.abbrechen(); pageStack.pop() } }
        ToolIcon {
            iconId: abfrage.laeuft ? "toolbar-close" : "toolbar-refresh"
            onClicked: abfrage.laeuft ? abfrage.abbrechen() : holen()
        }
    }

    Component.onCompleted: holen()

    function holen() {
        haefen.model.clear()
        stand.text = "Knocking..."
        abfrage.starte("geraeteinfo", [ziel])
    }

    Abfrage {
        id: abfrage
        onAntwort: {
            if (daten.start !== undefined) {
                name.wert = daten.name
                hardware.wert = daten.hw
                stand.text = "Trying " + daten.anzahl + " common ports"
            } else if (daten.hafen !== undefined) {
                haefen.model.append(daten)
            } else if (daten.ende !== undefined) {
                stand.text = daten.offen === 0
                             ? "None of the common ports answered."
                             : daten.offen + " open port" + (daten.offen === 1 ? "" : "s")
            } else if (daten.fehler !== undefined) {
                stand.text = daten.fehler
            }
        }
    }

    Column {
        id: kopfteil
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        Kopf { titel: seite.ziel; laeuft: abfrage.laeuft }
        Zeile { id: name;     titel: "Name" }
        Zeile { id: hardware; titel: "MAC" }
        Item { width: 1; height: 8 }
        Ueberschrift { text: "Open ports" }
        Text {
            id: stand
            x: 16
            width: parent.width - 32
            font.pixelSize: 17
            color: (theme.inverted ? "#909090" : "#5e5e5e")
            wrapMode: Text.WordWrap
            height: paintedHeight + 10
        }
    }

    ListView {
        id: haefen
        anchors.top: kopfteil.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: fussnote.top
        clip: true
        model: ListModel { }
        delegate: Item {
            width: haefen.width
            height: 48
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 90
                text: model.hafen
                font.pixelSize: 22
                color: (theme.inverted ? "#1e9ee8" : "#0b74b8")
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 110
                anchors.verticalCenter: parent.verticalCenter
                text: model.dienst
                font.pixelSize: 20
                color: (theme.inverted ? "#d0d0d0" : "#202020")
            }
        }
    }

    Text {
        id: fussnote
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        x: 16
        width: parent.width - 32
        text: "Common ports only, and open means a connection was accepted -- "
              + "nmap's service and OS detection is not available on this device."
        font.pixelSize: 15
        color: (theme.inverted ? "#707070" : "#787878")
        wrapMode: Text.WordWrap
    }

    ScrollDecorator { flickableItem: haefen }
}
