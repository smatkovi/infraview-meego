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
#include <QEventLoop>
#include <QGraphicsObject>
#include <QTimer>
#include <QDir>
#include <QImage>
#include <QPainter>
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

/* "infraview --bild <datei>" draws the window into a PNG without putting
   anything on the screen -- WA_DontShowOnScreen lays the widget out and
   renders it, but the compositor never sees it. That is how the look can be
   checked while someone is using the phone. */
static int abbilden(QDeclarativeView *ansicht, const QString &datei)
{
    ansicht->setAttribute(Qt::WA_DontShowOnScreen, true);
    ansicht->resize(480, 854);
    ansicht->show();

    /* The page asks its helpers for data on the way up; without a turn of the
       event loop the picture would show every field still empty. */
    QEventLoop schleife;
    QTimer::singleShot(6000, &schleife, SLOT(quit()));
    schleife.exec();

    /* com.nokia.meego turns its content to the orientation the phone reports,
       so the window knows better than we do how big the canvas should be --
       guess it and the picture comes out sideways and clipped. */
    QGraphicsObject *wurzel = ansicht->rootObject();
    if (wurzel && wurzel->property("width").toInt() > 0) {
        ansicht->resize(wurzel->property("width").toInt(),
                        wurzel->property("height").toInt());
        QEventLoop nochmal;
        QTimer::singleShot(500, &nochmal, SLOT(quit()));
        nochmal.exec();
    }

    QImage bild(ansicht->size(), QImage::Format_ARGB32);
    bild.fill(0);
    QPainter maler(&bild);
    ansicht->render(&maler);
    maler.end();

    const bool gut = bild.save(datei, "PNG");
    QTextStream(stdout) << (gut ? "wrote " : "could not write ") << datei << "\n";
    _exit(gut ? 0 : 1);
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

    if (argc > 2 && QLatin1String(argv[1]) == QLatin1String("--bild")) {
        ansicht.setSource(QUrl::fromLocalFile(QLatin1String("/opt/infraview/qml/main.qml")));
        return abbilden(&ansicht, QString::fromLocal8Bit(argv[2]));
    }

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
