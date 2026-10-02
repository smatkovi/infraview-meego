/* One label-and-value row, the shape every information page here uses. */
import QtQuick 1.1
import com.nokia.meego 1.1

Item {
    id: zeile

    property alias titel: beschriftung.text
    property alias wert: inhalt.text
    property bool betont: false

    width: parent ? parent.width : 0
    height: Math.max(beschriftung.paintedHeight, inhalt.paintedHeight) + 10
    visible: inhalt.text.length > 0

    Text {
        id: beschriftung
        width: parent.width * 0.42
        anchors.left: parent.left
        anchors.leftMargin: 16
        horizontalAlignment: Text.AlignRight
        font.pixelSize: 20
        color: (theme.inverted ? "#b0b0b0" : "#505050")
        wrapMode: Text.WordWrap
    }
    Text {
        id: inhalt
        anchors.left: beschriftung.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        font.pixelSize: 20
        font.bold: zeile.betont
        color: (theme.inverted ? "#ffffff" : "#000000")
        wrapMode: Text.WrapAnywhere
    }
}
