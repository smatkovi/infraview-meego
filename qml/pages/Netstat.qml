/*
  Open and listening sockets.

  Upstream reads these through a setuid-root helper, which is how it gets a
  process name for every socket on the system. A package installed here
  cannot have one: aegis grants no capabilities to a self-built package, and
  a setuid bit in the archive buys nothing. So netz.py reads /proc/net/tcp,
  tcp6, udp and udp6 itself and names the processes it is allowed to look at
  -- our own. The rest keep their uid, which is honest about what we can see.
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
    property variant alle: []

    Component.onCompleted: holen()

    function holen() {
        laeuft = true
        abfrage.starte("netstat", [])
    }

    function zeigen() {
        liste.model.clear()
        for (var i = 0; i < alle.length; ++i) {
            var eintrag = alle[i]
            if (sieb.selectedIndex === 1 && eintrag.zustand !== "LISTEN")
                continue
            if (sieb.selectedIndex === 2 && eintrag.zustand !== "ESTABLISHED")
                continue
            liste.model.append(eintrag)
        }
        anzahl.text = liste.model.count + " of " + alle.length
    }

    Abfrage {
        id: abfrage
        onAbschluss: {
            seite.laeuft = false
            if (daten.verbindungen === undefined) {
                anzahl.text = daten.fehler !== undefined ? daten.fehler : "No answer"
                return
            }
            seite.alle = daten.verbindungen
            zeigen()
        }
    }

    Column {
        id: kopfteil
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Kopf { titel: "Connections"; laeuft: seite.laeuft }

        ButtonRow {
            id: sieb
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            onCheckedButtonChanged: seite.zeigen()
            Button { text: "All" }
            Button { text: "Listening" }
            Button { text: "Established" }
        }

        Text {
            id: anzahl
            x: 16
            font.pixelSize: 16
            color: (theme.inverted ? "#808080" : "#6a6a6a")
        }
    }

    ListView {
        id: liste
        anchors.top: kopfteil.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: ListModel { }
        delegate: Item {
            width: liste.width
            height: 78
            Rectangle {
                anchors.fill: parent
                color: (theme.inverted ? "#2d2d2d" : "#c8c9ca")
                visible: beruehrung.pressed
            }
            Text {
                id: oben
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 8
                text: model.lokal + ":" + model.lokalport
                      + (model.fernport > 0 ? "  →  " + model.fern + ":" + model.fernport : "")
                font.pixelSize: 20
                color: (theme.inverted ? "#ffffff" : "#000000")
                elide: Text.ElideMiddle
            }
            Text {
                anchors.left: oben.left
                anchors.right: oben.right
                anchors.top: oben.bottom
                anchors.topMargin: 2
                text: model.art + (model.zustand.length > 0 ? "  ·  " + model.zustand : "")
                      + (model.name.length > 0 ? "  ·  " + model.name : "")
                font.pixelSize: 17
                color: model.zustand === "LISTEN" ? (theme.inverted ? "#1e9ee8" : "#0b74b8") : (theme.inverted ? "#909090" : "#5e5e5e")
                elide: Text.ElideRight
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
                onClicked: pageStack.push(Qt.resolvedUrl("NetstatInfo.qml"), {
                    "art": model.art, "lokal": model.lokal, "lokalport": model.lokalport,
                    "fern": model.fern, "fernport": model.fernport,
                    "zustand": model.zustand, "uid": model.uid,
                    "pid": model.pid, "name": model.name })
            }
        }
    }

    ScrollDecorator { flickableItem: liste }
}
