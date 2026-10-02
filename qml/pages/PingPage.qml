/*
  Ping, with the output arriving line by line rather than in one lump at the
  end -- that is what the Helfer's zeile() signal is for.

  ping is not setuid on this device and a raw socket is refused to us, yet
  /bin/ping works as a normal user: aegis holds the capability for it.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: { abfrage.abbrechen(); pageStack.pop() } }
    }

    Abfrage {
        id: abfrage
        onAntwort: {
            if (daten.zeile !== undefined)
                ausgabe.model.append({ "text": daten.zeile })
            else if (daten.fehler !== undefined)
                ausgabe.model.append({ "text": daten.fehler })
        }
        onAbschluss: ausgabe.positionViewAtEnd()
    }

    function los() {
        if (abfrage.laeuft) {
            abfrage.abbrechen()
            return
        }
        if (eingabe.text.length === 0)
            return
        ausgabe.model.clear()
        abfrage.starte("ping", [eingabe.text, "5"])
    }

    Column {
        id: kopfteil
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Kopf { titel: "Ping"; laeuft: abfrage.laeuft }

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
                text: abfrage.laeuft ? "Stop" : "Ping"
                onClicked: { eingabe.platformCloseSoftwareInputPanel(); seite.los() }
            }
        }
    }

    ListView {
        id: ausgabe
        anchors.top: kopfteil.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: ListModel { }
        delegate: Text {
            x: 16
            width: ausgabe.width - 32
            text: model.text
            font.family: "Nokia Pure Text Mono"
            font.pixelSize: 17
            color: (theme.inverted ? "#d0d0d0" : "#202020")
            wrapMode: Text.WrapAnywhere
        }
    }

    ScrollDecorator { flickableItem: ausgabe }
}
