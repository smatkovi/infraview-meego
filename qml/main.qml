/*
  InfraView for Harmattan -- ported from the Sailfish application by
  Arno Dekker (a-dekker), https://github.com/a-dekker/infraview.
*/
import QtQuick 1.1
import com.nokia.meego 1.1
import "pages"

PageStackWindow {
    id: appWindow

    showStatusBar: true
    showToolBar: true
    initialPage: MainPage { }

    /* Shared with every page, so the overview does not have to be asked
       again each time one of them needs the local address. */
    property string eigeneIp: ""
    property string eigenesNetz: ""
    property string netzName: ""
    property string netzArt: ""
}
