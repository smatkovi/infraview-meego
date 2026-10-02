/* A section heading -- Silica's SectionHeader has no counterpart here. */
import QtQuick 1.1

Item {
    property alias text: beschriftung.text

    width: parent ? parent.width : 0
    height: beschriftung.paintedHeight + 24

    Text {
        id: beschriftung
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: trenner.top
        anchors.bottomMargin: 4
        font.pixelSize: 22
        color: "#1e9ee8"
    }
    Rectangle {
        id: trenner
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        height: 1
        color: "#404040"
    }
}
