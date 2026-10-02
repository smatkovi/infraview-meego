/* A page title with the spinner that belongs to it. */
import QtQuick 1.1
import com.nokia.meego 1.1

Item {
    property alias titel: beschriftung.text
    property bool laeuft: false

    width: parent ? parent.width : 0
    height: 72

    Text {
        id: beschriftung
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: dreher.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 30
        color: "#ffffff"
        elide: Text.ElideRight
    }
    BusyIndicator {
        id: dreher
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        running: parent.laeuft
        visible: running
        width: running ? 40 : 0
        platformStyle: BusyIndicatorStyle { size: "medium" }
    }
}
