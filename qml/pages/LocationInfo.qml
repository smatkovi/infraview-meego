/*
  Where this connection comes out: the external address and what the geo
  service knows about it. Same two requests upstream makes (api.ipify.org,
  then tools.keycdn.com), which still answer.

  The stock Python here is 2.6 on OpenSSL 0.9.8 and could not open either
  connection; this runs under the newer interpreter in /opt/wunderw, as
  everything else on this device that speaks TLS does.
*/
import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    id: seite

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
        ToolIcon { iconId: "toolbar-refresh"; onClicked: holen() }
    }

    property bool laeuft: false

    Component.onCompleted: holen()

    function holen() {
        laeuft = true
        fehler.text = ""
        abfrage.starte("ort", [])
    }

    Abfrage {
        id: abfrage
        onAbschluss: {
            seite.laeuft = false
            if (daten.fehler !== undefined || daten.ip === undefined) {
                fehler.text = daten.fehler !== undefined ? daten.fehler : "No answer"
                return
            }
            adresse.wert = daten.ip
            rechner.wert = daten.host
            anbieter.wert = daten.isp
            asn.wert = daten.asn === "" ? "" : "AS" + daten.asn
            land.wert = daten.country_name + " (" + daten.country_code + ")"
            erdteil.wert = daten.continent_code
            stadt.wert = daten.city
            plz.wert = daten.postal_code
            zeitzone.wert = daten.timezone
            breite.wert = "" + daten.latitude
            laenge.wert = "" + daten.longitude
        }
    }

    Flickable {
        id: flaeche
        anchors.fill: parent
        contentWidth: width
        contentHeight: spalte.height + 24
        clip: true

        Column {
            id: spalte
            width: flaeche.width

            Kopf { titel: "External IP"; laeuft: seite.laeuft }

            Text {
                id: fehler
                x: 16
                width: parent.width - 32
                font.pixelSize: 18
                color: "#e06060"
                wrapMode: Text.WordWrap
                height: text.length > 0 ? paintedHeight + 16 : 0
            }

            Ueberschrift { text: "Address" }
            Item { width: 1; height: 8 }
            Zeile { id: adresse;  titel: "External IP"; betont: true }
            Zeile { id: rechner;  titel: "Host" }
            Zeile { id: anbieter; titel: "Provider" }
            Zeile { id: asn;      titel: "AS number" }

            Ueberschrift { text: "Place" }
            Item { width: 1; height: 8 }
            Zeile { id: land;     titel: "Country" }
            Zeile { id: erdteil;  titel: "Continent" }
            Zeile { id: stadt;    titel: "City" }
            Zeile { id: plz;      titel: "Postal code" }
            Zeile { id: zeitzone; titel: "Time zone" }
            Zeile { id: breite;   titel: "Latitude" }
            Zeile { id: laenge;   titel: "Longitude" }

            Item { width: 1; height: 16 }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 32
                text: "Show on the map"
                visible: breite.wert.length > 0
                onClicked: starter.oeffne("http://www.openstreetmap.org/?mlat="
                                          + breite.wert + "&mlon=" + laenge.wert
                                          + "&zoom=12")
            }
        }
    }

    ScrollDecorator { flickableItem: flaeche }
}
