/*
  InfraView for Harmattan.

  Ported from the Sailfish application by Arno Dekker (a-dekker),
  https://github.com/a-dekker/infraview. Upstream builds on sailfishapp and
  QQuickView; here the window is a plain QDeclarativeView holding
  com.nokia.meego QML, and the Python helpers are reached through Helfer
  rather than pyotherside.
*/
#include <QApplication>
#include <QDeclarativeContext>
#include <QDeclarativeEngine>
#include <QDeclarativeView>
#include <QDesktopServices>
#include <QUrl>

#include "helfer.h"

/* Opening a link is the one thing QML cannot do by itself here: Harmattan's
   QDesktopServices knows the browser, QtQuick 1.1 has no Qt.openUrlExternally
   that reaches it reliably from a plain view. */
class Starter : public QObject
{
    Q_OBJECT
public:
    explicit Starter(QObject *eltern = 0) : QObject(eltern) {}

    Q_INVOKABLE void oeffne(const QString &adresse)
    {
        QDesktopServices::openUrl(QUrl(adresse));
    }
};

int main(int argc, char *argv[])
{
    QApplication anwendung(argc, argv);
    anwendung.setApplicationName(QLatin1String("infraview"));

    QDeclarativeView ansicht;
    Helfer helfer;
    Starter starter;

    ansicht.engine()->rootContext()->setContextProperty(QLatin1String("helfer"), &helfer);
    ansicht.engine()->rootContext()->setContextProperty(QLatin1String("starter"), &starter);
    ansicht.engine()->rootContext()->setContextProperty(
        QLatin1String("fassung"), QLatin1String(INFRAVIEW_VERSION));

    ansicht.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    ansicht.setSource(QUrl::fromLocalFile(QLatin1String("/opt/infraview/qml/main.qml")));
    ansicht.showFullScreen();

    return anwendung.exec();
}

#include "main.moc"
