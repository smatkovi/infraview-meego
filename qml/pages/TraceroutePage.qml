/*
  Traceroute without a traceroute.

  The device has no such binary and refuses a raw socket to a normal user --
  aegis grants no capabilities to a self-built package, so there is no way to
  earn one either. The unprivileged route works instead: a UDP socket with
  IP_RECVERR set gets the ICMP time-exceeded delivered to its error queue,
  which is how tracepath does it. The hops arrive one at a time; see
  traceroute() in netz.py.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: { abfrage.abbrechen(); pageStack.pop() } }
    }

    property string fehlertext: ""

    Abfrage {
        id: abfrage
        onAntwort: {
            if (daten.sprung !== undefined)
                spruenge.model.append({
                    "nummer": daten.sprung, "station": daten.station,
                    "name": daten.name, "ms": daten.ms })
            else if (daten.fehler !== undefined)
                seite.fehlertext = daten.fehler
        }
    }

    function los() {
        if (abfrage.laeuft) {
            abfrage.abbrechen()
            return
        }
        if (eingabe.text.length === 0)
            return
        fehlertext = ""
        spruenge.model.clear()
        abfrage.starte("traceroute", [eingabe.text, "20"])
    }

    Column {
        id: kopfteil
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Kopf { titel: "Traceroute"; laeuft: abfrage.laeuft }

        Item {
            width: parent.width
            height: eingabe.height + 8
            TextField {
                id: eingabe
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: knopf.left
                anchors.rightMargin: 8
                placeholderText: "host or address"
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                Keys.onReturnPressed: { platformCloseSoftwareInputPanel(); seite.los() }
            }
            Button {
                id: knopf
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: eingabe.verticalCenter
                width: 120
                text: abfrage.laeuft ? "Stop" : "Go"
                onClicked: { eingabe.platformCloseSoftwareInputPanel(); seite.los() }
            }
        }
        Text {
            visible: seite.fehlertext.length > 0
            x: 16
            width: parent.width - 32
            text: seite.fehlertext
            font.pixelSize: 18
            color: "#e06060"
            wrapMode: Text.WordWrap
        }
    }

    ListView {
        id: spruenge
        anchors.top: kopfteil.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: ListModel { }
        delegate: Item {
            width: spruenge.width
            height: model.name.length > 0 ? 72 : 52
            Text {
                id: nummer
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 4
                width: 36
                horizontalAlignment: Text.AlignRight
                text: model.nummer
                font.pixelSize: 22
                color: "#606060"
            }
            Text {
                id: station
                anchors.left: nummer.right
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 4
                text: model.station
                font.pixelSize: 22
                color: model.station === "*" ? "#707070" : "#ffffff"
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.baseline: station.baseline
                text: model.ms > 0 ? model.ms + " ms" : ""
                font.pixelSize: 18
                color: "#1e9ee8"
            }
            Text {
                anchors.left: station.left
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: station.bottom
                text: model.name
                visible: model.name.length > 0
                font.pixelSize: 16
                color: "#909090"
                elide: Text.ElideRight
            }
        }
    }

    ScrollDecorator { flickableItem: spruenge }
}
