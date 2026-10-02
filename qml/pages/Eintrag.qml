/* A tappable entry on the overview. */
import QtQuick 1.1

Item {
    id: eintrag

    property alias titel: ueberschrift.text
    property alias beschreibung: unterschrift.text
    signal clicked()

    width: parent ? parent.width : 0
    height: 76

    Rectangle {
        anchors.fill: parent
        color: (theme.inverted ? "#2d2d2d" : "#c8c9ca")
        visible: beruehrung.pressed
    }
    Text {
        id: ueberschrift
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 12
        font.pixelSize: 24
        color: (theme.inverted ? "#ffffff" : "#000000")
    }
    Text {
        id: unterschrift
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: pfeil.left
        anchors.top: ueberschrift.bottom
        anchors.topMargin: 2
        font.pixelSize: 17
        color: (theme.inverted ? "#909090" : "#5e5e5e")
        elide: Text.ElideRight
    }
    Image {
        id: pfeil
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        source: "image://theme/icon-m-common-drilldown-arrow"
    }
    MouseArea {
        id: beruehrung
        anchors.fill: parent
        onClicked: eintrag.clicked()
    }
}
