/*
  InfraView for Harmattan.

  Ported from the Sailfish application by Arno Dekker (a-dekker),
  https://github.com/a-dekker/infraview. Upstream builds on sailfishapp and
  QQuickView; here the window is a plain QDeclarativeView holding
  com.nokia.meego QML, and the Python helpers are reached through Helfer
  rather than pyotherside.
*/
#include <QApplication>
#include <QDeclarativeComponent>
#include <QDir>
#include <QTextStream>
#include <unistd.h>
#include <QDeclarativeContext>
#include <QDeclarativeEngine>
#include <QDeclarativeError>
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

/* "infraview --pruefen" loads every page without showing anything, so a
   typo in QML turns up here instead of as a blank page on the device. It has
   to run on the device: only Qt 4.7 with com.nokia.meego installed can tell
   a real mistake from an import it cannot resolve. */
static int pruefen(QDeclarativeEngine *maschine, const QString &verzeichnis)
{
    QTextStream aus(stdout);
    int schlecht = 0;

    QDir ordner(verzeichnis);
    QStringList namen = ordner.entryList(QStringList() << QLatin1String("*.qml"), QDir::Files);
    namen.sort();
    namen.prepend(QLatin1String("../main.qml"));

    for (int i = 0; i < namen.size(); ++i) {
        const QString pfad = ordner.absoluteFilePath(namen.at(i));
        QDeclarativeComponent bauteil(maschine, QUrl::fromLocalFile(pfad));
        if (bauteil.isError()) {
            ++schlecht;
            aus << "FAIL " << namen.at(i) << "\n";
            const QList<QDeclarativeError> fehler = bauteil.errors();
            for (int f = 0; f < fehler.size(); ++f)
                aus << "     " << fehler.at(f).toString() << "\n";
            continue;
        }

        /* Compiling is not enough -- a property that does not exist on a
           com.nokia.meego element only bites when the object is built. The
           pages bind to pageStack, which is not there outside a window, so
           those warnings are expected; errors are not. */
        QObject *gebaut = bauteil.create();
        if (bauteil.isError()) {
            ++schlecht;
            aus << "FAIL " << namen.at(i) << " (while building)\n";
            const QList<QDeclarativeError> fehler = bauteil.errors();
            for (int f = 0; f < fehler.size(); ++f)
                aus << "     " << fehler.at(f).toString() << "\n";
        } else {
            aus << "ok   " << namen.at(i) << "\n";
        }
        /* Not deleted on purpose: tearing a Page down outside the window it
           expects crashes in the components themselves, and this process
           ends two lines further on anyway. */
        Q_UNUSED(gebaut);
    }
    aus << (schlecht == 0 ? "all pages load\n"
                          : QString("%1 page(s) broken\n").arg(schlecht));
    aus.flush();
    /* Left standing on purpose. Tearing the engine down with these objects
       still in it crashes inside the components; the verdict is already
       printed, so the process ends here rather than during cleanup. */
    _exit(schlecht == 0 ? 0 : 1);
}

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

    if (argc > 1 && QLatin1String(argv[1]) == QLatin1String("--pruefen"))
        return pruefen(ansicht.engine(),
                       argc > 2 ? QString::fromLocal8Bit(argv[2])
                                : QLatin1String("/opt/infraview/qml/pages"));

    ansicht.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    ansicht.setSource(QUrl::fromLocalFile(QLatin1String("/opt/infraview/qml/main.qml")));
    ansicht.showFullScreen();

    return anwendung.exec();
}

#include "main.moc"
