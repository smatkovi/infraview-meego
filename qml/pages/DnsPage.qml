/*
  DNS lookups. Unchanged in substance from upstream's call_ip.py: an address
  is turned round into a PTR query, a name is asked for the chosen record
  type, and the whole answer is shown as dnspython prints it.

  The nameserver stays 127.0.0.1, as upstream has it. That was checked here
  rather than assumed -- Harmattan does run a local resolver, icd2's proxy,
  and it answers.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: { abfrage.abbrechen(); pageStack.pop() } }
    }

    property variant arten: ["A", "AAAA", "MX", "NS", "TXT", "SOA", "CNAME", "SRV", "PTR"]

    Abfrage {
        id: abfrage
        onAbschluss: {
            if (daten.text !== undefined)
                ausgabe.text = daten.text
            else if (daten.fehler !== undefined)
                ausgabe.text = daten.fehler
            else
                ausgabe.text = "No answer"
        }
    }

    function los() {
        if (eingabe.text.length === 0)
            return
        ausgabe.text = ""
        abfrage.starte("dns", [eingabe.text, seite.arten[wahl.selectedIndex]])
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
            spacing: 8

            Kopf { titel: "DNS lookup"; laeuft: abfrage.laeuft }

            Item {
                width: parent.width
                height: eingabe.height + 8
                TextField {
                    id: eingabe
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: knopf.left
                    anchors.rightMargin: 8
                    placeholderText: "name or address"
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: { platformCloseSoftwareInputPanel(); seite.los() }
                }
                Button {
                    id: knopf
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: eingabe.verticalCenter
                    width: 120
                    text: "Look up"
                    onClicked: { eingabe.platformCloseSoftwareInputPanel(); seite.los() }
                }
            }

            Item {
                width: parent.width
                height: wahl.height
                ButtonRow {
                    id: wahl
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    /* An address is always a PTR query whatever is picked
                       here, so the row only matters for names. */
                    Repeater {
                        model: seite.arten
                        Button { text: modelData }
                    }
                }
            }

            Text {
                id: ausgabe
                x: 16
                width: parent.width - 32
                font.family: "Nokia Pure Text Mono"
                font.pixelSize: 17
                color: (theme.inverted ? "#d0d0d0" : "#202020")
                wrapMode: Text.WrapAnywhere
            }
        }
    }

    ScrollDecorator { flickableItem: flaeche }
}
