/*
  InfraView for Harmattan -- the bridge that replaces pyotherside.

  Upstream talks to its Python helpers through pyotherside's Python
  element, which embeds an interpreter in the QML engine. Harmattan has no
  pyotherside, and its own Python is 2.6 -- too old for the helpers and for
  the TLS the location lookup needs. So the helpers run out of process under
  the newer python3.11 in /opt/wunderw, and this object carries the calls.

  Every call returns an id at once; the answer arrives later as a signal
  carrying that id, which is the same shape pyotherside's call(..., callback)
  has, so the pages needed no restructuring. Long-running helpers (ping,
  traceroute, the device sweep) print a JSON object per line and reach QML
  through zeile() as they go, instead of only at the end.
*/
#ifndef HELFER_H
#define HELFER_H

#include <QHash>
#include <QObject>
#include <QProcess>
#include <QStringList>

class Helfer : public QObject
{
    Q_OBJECT
    /* The interpreter is installed by hand, not by a package, so a device
       without it has to say so instead of failing silently on every page. */
    Q_PROPERTY(bool bereit READ bereit CONSTANT)

public:
    explicit Helfer(QObject *eltern = 0);
    bool bereit() const;
    ~Helfer();

    /* Runs netz.<funktion>(args...) and returns the id of the call. */
    Q_INVOKABLE int rufe(const QString &funktion, const QStringList &argumente);
    Q_INVOKABLE void abbrechen(int kennung);

signals:
    /* One line of output from a helper that reports as it goes. */
    void zeile(int kennung, const QString &inhalt);
    /* The call ended. On success "inhalt" is the last line of output. */
    void fertig(int kennung, const QString &inhalt, bool erfolg);

private slots:
    void lesen();
    void beendet(int austritt, QProcess::ExitStatus art);
    void gescheitert(QProcess::ProcessError fehler);

private:
    int kennungVon(QProcess *prozess) const;
    void zerlegen(QProcess *prozess, int kennung);

    QHash<QProcess *, int> m_kennungen;
    QHash<int, QString> m_letzte;   /* last line seen, per call */
    QHash<int, QString> m_reste;    /* half-read line, per call */
    int m_naechste;
};

#endif
