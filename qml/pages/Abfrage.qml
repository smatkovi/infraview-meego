/*
  One call to netz.py and its answer.

  Upstream writes python.call('mod.func', [args], callback) and gets the
  result handed to the callback. Here the call goes out of process, so the
  answer comes back as a signal carrying the call's id, and this wraps that
  back up into something a page can use: starte(), then antwort() for each
  line and abschluss() at the end.
*/
import QtQuick 1.1

Item {
    id: abfrage

    property int laufId: 0
    property bool laeuft: false

    /* One line of output, already parsed. */
    signal antwort(variant daten)
    /* The call ended; "daten" is its last line. */
    signal abschluss(variant daten, bool erfolg)

    function starte(funktion, argumente) {
        /* A page that asks again before the last answer arrived would
           otherwise show both, interleaved. */
        if (laeuft)
            helfer.abbrechen(laufId)
        laufId = helfer.rufe(funktion, argumente ? argumente : [])
        laeuft = true
    }

    function abbrechen() {
        if (laeuft)
            helfer.abbrechen(laufId)
    }

    /* A helper that dies mid-sentence leaves a half-written line; showing the
       raw text beats showing nothing. */
    function lese(text) {
        try {
            return JSON.parse(text)
        } catch (fehler) {
            return { "fehler": text }
        }
    }

    Connections {
        target: helfer
        onZeile: {
            if (kennung !== abfrage.laufId)
                return
            abfrage.antwort(abfrage.lese(inhalt))
        }
        onFertig: {
            if (kennung !== abfrage.laufId)
                return
            abfrage.laeuft = false
            abfrage.abschluss(abfrage.lese(inhalt), erfolg)
        }
    }
}
