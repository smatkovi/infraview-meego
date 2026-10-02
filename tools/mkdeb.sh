#!/bin/sh
# Packs build/infraview, the QML and the Python helpers into a Harmattan .deb.
#
#   tools/mkdeb.sh 0.1.0             # -> build/infraview_0.1.0_armel.deb
#
# The binary has to be there already; tools/build.sh makes it.
set -e
cd "$(dirname "$0")/.."

VERSION=${1:-0.1.0}
STAGE=build/stage
DEB=build/infraview_${VERSION}_armel.deb

[ -f build/infraview ] || { echo "build/infraview is missing -- run tools/build.sh"; exit 1; }
[ -f icons/infraview-80.png ] || { echo "icons are missing -- run make-icon.py"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/opt/infraview/bin" \
         "$STAGE/opt/infraview/qml/pages" \
         "$STAGE/opt/infraview/python" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/80x80/apps"

cp build/infraview          "$STAGE/opt/infraview/bin/"
cp qml/main.qml             "$STAGE/opt/infraview/qml/"
cp qml/pages/*.qml          "$STAGE/opt/infraview/qml/pages/"
cp python/netz.py           "$STAGE/opt/infraview/python/"
cp -r python/dns            "$STAGE/opt/infraview/python/"
cp icons/infraview-80.png   "$STAGE/usr/share/icons/hicolor/80x80/apps/infraview.png"
chmod 755 "$STAGE/opt/infraview/bin/infraview" "$STAGE/opt/infraview/python/netz.py"

# Icon= wants the full path here; a bare name finds nothing in the launcher.
cat > "$STAGE/usr/share/applications/infraview.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=InfraView
Comment=Device network information
Exec=/opt/infraview/bin/infraview
Icon=/usr/share/icons/hicolor/80x80/apps/infraview.png
Categories=Network;
X-MeeGo-Logical-Id=infraview
DESKTOP

# The 64x64 copy rides along in the control file; that is what the Harmattan
# launcher actually draws.
ICON64=$(base64 -w0 < icons/infraview-64.png)

cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: infraview
Version: $VERSION
Architecture: armel
Maintainer: Sebastian Matkovich <sebastian.matkovich@gmail.com>
Section: user/network
Priority: optional
Depends: libqt4-declarative, qt-components, libqtcore4, libqtgui4
Description: Device network information
 What this device's connection looks like from the inside: address, netmask,
 gateway and resolver, the ARP cache, open and listening sockets, the other
 devices answering in the local network, and where the connection comes out.
 Ping, DNS lookups and traceroute are included.
 .
 A port of InfraView for Sailfish OS by Arno Dekker (a-dekker).
 .
 Needs python3.11 under /opt/wunderw; the stock Python 2.6 is too old for
 the lookups and for the TLS the location page uses.
XB-Maemo-Icon-26:
 $ICON64
CONTROL

python3 tools/mkdeb.py "$STAGE" "$DEB"
echo "== $DEB"
python3 tools/mkdeb.py --info "$DEB" | head -20
