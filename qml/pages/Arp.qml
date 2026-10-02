/*
  The ARP cache. Upstream shells out to the arp binary; this device has none,
  but the binary only ever read /proc/net/arp, which netz.py reads directly.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
        ToolIcon { iconId: "toolbar-refresh"; onClicked: holen() }
    }

    property bool laeuft: false
    /* The note lives in the list's footer, and an id inside a footer cannot
       be reached from out here -- the footer is its own component. So the
       text is a property of the page and the footer binds to it. */
    property string hinweistext: ""

    Component.onCompleted: holen()

    function holen() {
        laeuft = true
        liste.model.clear()
        abfrage.starte("arp", [])
    }

    Abfrage {
        id: abfrage
        onAbschluss: {
            seite.laeuft = false
            if (daten.eintraege === undefined) {
                seite.hinweistext = daten.fehler !== undefined ? daten.fehler : "No answer"
                return
            }
            for (var i = 0; i < daten.eintraege.length; ++i)
                liste.model.append(daten.eintraege[i])
            seite.hinweistext = daten.eintraege.length === 0
                                ? "The cache is empty -- talk to something first." : ""
        }
    }

    ListView {
        id: liste
        anchors.fill: parent
        clip: true
        model: ListModel { }
        header: Kopf { titel: "ARP cache"; laeuft: seite.laeuft }
        delegate: Item {
            width: liste.width
            height: 92
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: model.name.length > 0 ? model.name : model.ip
                    font.pixelSize: 24
                    color: "#ffffff"
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: (model.name.length > 0 ? model.ip + "  " : "") + model.hw
                    font.pixelSize: 18
                    color: "#1e9ee8"
                }
                Text {
                    text: model.hwtyp + " on " + model.geraet
                    font.pixelSize: 16
                    color: "#808080"
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                height: 1
                color: "#303030"
            }
        }
        footer: Text {
            text: seite.hinweistext
            width: liste.width - 32
            x: 16
            font.pixelSize: 18
            color: "#909090"
            wrapMode: Text.WordWrap
            height: text.length > 0 ? paintedHeight + 24 : 0
        }
    }

    ScrollDecorator { flickableItem: liste }
}
