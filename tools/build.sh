#!/bin/sh
# Builds the infraview binary for the N9/N950 on the build machine.
#
# Qt 4.7 and C++03, so this uses MADDE's own gcc 4.4 -- not the GCC 14 cross
# toolchain in ~/ps/toolchains, which is there for C++17 ports and would need
# a different libstdc++ on the device.
#
#   tools/build.sh                   # -> build/infraview (stripped)
set -e
cd "$(dirname "$0")/.."

TARGET=harmattan_10.2011.34-1_rt1.2
REMOTE=/tmp/infraview-meego

HOST=$(sh "$HOME/ps/nfsshift-sfos/tools/buildhost.sh")
echo "== build host: $HOST"

echo "== syncing sources"
ssh "$HOST" "mkdir -p $REMOTE/src"
rsync -a --delete -e ssh src/ "$HOST:$REMOTE/src/"

ssh "$HOST" "set -e
    export PATH=\$HOME/QtSDK/Madde/bin:\$PATH
    cd $REMOTE/src
    mad -t $TARGET qmake >/dev/null
    mad -t $TARGET make -j4 > /tmp/infraview-build.log 2>&1 || {
        echo '-- build failed'; tail -40 /tmp/infraview-build.log; exit 1; }
    \$HOME/QtSDK/Madde/targets/$TARGET/bin/strip --strip-unneeded infraview
    ls -la infraview"

mkdir -p build
rsync -a -e ssh "$HOST:$REMOTE/src/infraview" build/
echo "== build/infraview"
file build/infraview
