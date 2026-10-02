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

    /* Black ground and white type, whatever the device is set to. The
       platform's own chrome -- toolbar, buttons, text fields -- follows this
       too; PageStackWindowStyle paints #000000 when it is set. */
    Component.onCompleted: theme.inverted = true
}
