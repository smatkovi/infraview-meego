#include "helfer.h"

#include <QDebug>
#include <QFile>
#include <QStringList>

/* The newer interpreter -- see harmattan-tls-stacks. The stock /usr/bin/python
   is 2.6 on OpenSSL 0.9.8 and cannot reach the geo service at all. */
static const char *PYTHON = "/opt/wunderw/bin/python3.11";
static const char *SKRIPT = "/opt/infraview/python/netz.py";

Helfer::Helfer(QObject *eltern)
    : QObject(eltern)
    , m_naechste(1)
{
}

Helfer::~Helfer()
{
    /* The pages outlive single calls but not the application; anything still
       running when the window closes would otherwise keep the process up. */
    QHash<QProcess *, int>::const_iterator lauf = m_kennungen.constBegin();
    for (; lauf != m_kennungen.constEnd(); ++lauf) {
        lauf.key()->kill();
        lauf.key()->waitForFinished(500);
    }
}

bool Helfer::bereit() const
{
    return QFile::exists(QLatin1String(PYTHON));
}

int Helfer::rufe(const QString &funktion, const QStringList &argumente)
{
    const int kennung = m_naechste++;

    QProcess *prozess = new QProcess(this);
    prozess->setProcessChannelMode(QProcess::MergedChannels);
    connect(prozess, SIGNAL(readyRead()), this, SLOT(lesen()));
    connect(prozess, SIGNAL(finished(int, QProcess::ExitStatus)),
            this, SLOT(beendet(int, QProcess::ExitStatus)));
    connect(prozess, SIGNAL(error(QProcess::ProcessError)),
            this, SLOT(gescheitert(QProcess::ProcessError)));

    m_kennungen.insert(prozess, kennung);

    QStringList volle;
    volle << QLatin1String(SKRIPT) << funktion << argumente;
    prozess->start(QLatin1String(PYTHON), volle);

    return kennung;
}

void Helfer::abbrechen(int kennung)
{
    QHash<QProcess *, int>::const_iterator lauf = m_kennungen.constBegin();
    for (; lauf != m_kennungen.constEnd(); ++lauf) {
        if (lauf.value() == kennung) {
            lauf.key()->kill();
            return;
        }
    }
}

int Helfer::kennungVon(QProcess *prozess) const
{
    return m_kennungen.value(prozess, 0);
}

/* Output is read in whatever chunks the pipe hands over, so a line can arrive
   in two pieces -- the tail is kept until its newline turns up. */
void Helfer::zerlegen(QProcess *prozess, int kennung)
{
    QString text = m_reste.value(kennung) + QString::fromUtf8(prozess->readAll());
    const int letzter = text.lastIndexOf(QLatin1Char('\n'));
    if (letzter < 0) {
        m_reste.insert(kennung, text);
        return;
    }
    m_reste.insert(kennung, text.mid(letzter + 1));

    const QStringList zeilen = text.left(letzter).split(QLatin1Char('\n'));
    for (int i = 0; i < zeilen.size(); ++i) {
        const QString inhalt = zeilen.at(i).trimmed();
        if (inhalt.isEmpty())
            continue;
        m_letzte.insert(kennung, inhalt);
        emit zeile(kennung, inhalt);
    }
}

void Helfer::lesen()
{
    QProcess *prozess = qobject_cast<QProcess *>(sender());
    if (!prozess)
        return;
    zerlegen(prozess, kennungVon(prozess));
}

void Helfer::beendet(int austritt, QProcess::ExitStatus art)
{
    QProcess *prozess = qobject_cast<QProcess *>(sender());
    if (!prozess)
        return;
    const int kennung = kennungVon(prozess);

    zerlegen(prozess, kennung);
    const QString rest = m_reste.value(kennung).trimmed();
    if (!rest.isEmpty()) {
        m_letzte.insert(kennung, rest);
        emit zeile(kennung, rest);
    }

    const bool erfolg = (art == QProcess::NormalExit && austritt == 0);
    emit fertig(kennung, m_letzte.value(kennung), erfolg);

    m_kennungen.remove(prozess);
    m_letzte.remove(kennung);
    m_reste.remove(kennung);
    prozess->deleteLater();
}

void Helfer::gescheitert(QProcess::ProcessError fehler)
{
    QProcess *prozess = qobject_cast<QProcess *>(sender());
    if (!prozess)
        return;
    const int kennung = kennungVon(prozess);

    /* A crash still raises finished(), so only the ones that do not get
       reported here -- otherwise every kill would answer twice. */
    if (fehler == QProcess::Crashed)
        return;

    qWarning() << "infraview: helper could not run:" << fehler;
    emit fertig(kennung, QString::fromUtf8("{\"fehler\": \"helper could not be started\"}"), false);

    m_kennungen.remove(prozess);
    m_letzte.remove(kennung);
    m_reste.remove(kennung);
    prozess->deleteLater();
}
