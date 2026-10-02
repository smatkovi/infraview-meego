/* A paragraph of running text at the page's margins. */
import QtQuick 1.1

Text {
    x: 16
    width: parent ? parent.width - 32 : 0
    font.pixelSize: 19
    color: (theme.inverted ? "#c0c0c0" : "#303030")
    wrapMode: Text.WordWrap
}
