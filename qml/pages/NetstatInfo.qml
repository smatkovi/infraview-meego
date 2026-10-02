/* One connection in full. */
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    property string art: ""
    property string lokal: ""
    property int lokalport: 0
    property string fern: ""
    property int fernport: 0
    property string zustand: ""
    property string uid: ""
    property string pid: ""
    property string name: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
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

            Kopf { titel: "Connection" }

            Ueberschrift { text: "This end" }
            Item { width: 1; height: 8 }
            Zeile { titel: "Protocol"; wert: seite.art }
            Zeile { titel: "Address"; wert: seite.lokal; betont: true }
            Zeile { titel: "Port"; wert: "" + seite.lokalport }
            Zeile { titel: "State"; wert: seite.zustand }

            Ueberschrift { text: "Other end"; visible: seite.fernport > 0 }
            Item { width: 1; height: 8; visible: seite.fernport > 0 }
            Zeile { titel: "Address"; wert: seite.fernport > 0 ? seite.fern : "" }
            Zeile { titel: "Port"; wert: seite.fernport > 0 ? "" + seite.fernport : "" }

            Ueberschrift { text: "Owner" }
            Item { width: 1; height: 8 }
            Zeile { titel: "User id"; wert: seite.uid }
            Zeile { titel: "Process"; wert: seite.pid }
            Zeile { titel: "Name"; wert: seite.name }

            Item { width: 1; height: 12 }

            Text {
                /* Better to say why than to leave a blank where upstream
                   shows a name. */
                visible: seite.name.length === 0
                x: 16
                width: parent.width - 32
                text: "The owning process can only be named for sockets this user may look at. "
                      + "Upstream reads the rest through a setuid helper; a package installed "
                      + "here gets no such privilege from aegis."
                font.pixelSize: 16
                color: (theme.inverted ? "#808080" : "#6a6a6a")
                wrapMode: Text.WordWrap
            }
        }
    }

    ScrollDecorator { flickableItem: flaeche }
}
