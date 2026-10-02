#!/bin/sh
# Loads and builds every page on the device, without showing a window.
#
# This has to run on the device: only Qt 4.7 with com.nokia.meego installed
# can tell a real mistake from an import a desktop qmlscene cannot resolve.
# It catches what a syntax check does not -- a property that does not exist
# on a meego element, or an id reached across a header/footer boundary, both
# of which only bite when the object is actually built.
#
#   tools/check-qml.sh               # the installed pages
#   tools/check-qml.sh --kanari      # prove the check can fail, then check
#
# The package has to be installed first; tools/mkdeb.sh makes it.
set -e
cd "$(dirname "$0")/.."

GERAET=${GERAET:-user@192.168.1.8}
SSH="ssh -oHostKeyAlgorithms=+ssh-rsa -oPubkeyAcceptedAlgorithms=+ssh-rsa -i $HOME/.ssh/id_rsa_n9"

# Noise from the graphics system, not from us.
LAERM='-e Meego -e MeeGo -e SGX/MBX -e "v1.4 driver" -e "X Error" -e Extension: -e opcode -e "Resource id" -e ^$'

if [ "$1" = "--kanari" ]; then
    echo "== canary: a page broken on purpose must be reported"
    $SSH "$GERAET" 'rm -rf ~/qmlkanari && cp -r /opt/infraview/qml ~/qmlkanari
        sed -i "s/font.pixelSize: 19/font.pixelSize: 19; gibtEsNicht: 1/" ~/qmlkanari/pages/Absatz.qml
        . /tmp/session_bus_address.user 2>/dev/null
        DISPLAY=:0 /opt/infraview/bin/infraview --pruefen ~/qmlkanari/pages 2>&1 | grep -e "^FAIL" -e "broken$"
        rm -rf ~/qmlkanari' || {
        echo "-- the canary passed; this check proves nothing"; exit 1; }
    echo
fi

echo "== checking the installed pages"
$SSH "$GERAET" '. /tmp/session_bus_address.user 2>/dev/null
    DISPLAY=:0 /opt/infraview/bin/infraview --pruefen' 2>&1 \
    | grep -v -e Meego -e MeeGo -e "SGX/MBX" -e "v1.4 driver" -e "X Error" \
              -e "Extension:" -e "opcode" -e "Resource id" -e "^$"
