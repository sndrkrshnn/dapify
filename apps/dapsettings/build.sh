#!/bin/bash
#
# Build the DAP Settings companion APK with the Android 7 SDK (API 25).
#
# Signing is deliberately external to the repository. Set these variables to
# produce an installable APK:
#
#   DAP_KEYSTORE       path to the keystore (never commit it)
#   DAP_KEYSTORE_PASS  keystore password
#   DAP_KEY_ALIAS      key alias (default: dap)
#   DAP_KEY_PASS       key password (default: keystore password)
#
# Without DAP_KEYSTORE the script still builds and verifies the unsigned APK
# at build/dapsettings-unsigned.apk. That is useful for CI checks, but the
# result cannot be installed on a device.
#
# This project intentionally uses v1 jarsigner signing: Android 7 accepts it,
# and apksigner crashes under Java 17 on some hosts with
# InaccessibleObjectException.
set -euo pipefail

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
BT="${DAP_BUILD_TOOLS:-$SDK/build-tools/25.0.3}"
PLATFORM="${DAP_PLATFORM:-$SDK/platforms/android-25/android.jar}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

[ -x "$BT/aapt" ] || die "aapt not found at $BT/aapt (set ANDROID_SDK_ROOT)"
[ -f "$PLATFORM" ] || die "android.jar not found at $PLATFORM"

rm -rf build/gen build/classes build/app-unaligned.apk build/classes.dex \
       build/app-with-dex.apk build/app-aligned.apk \
       build/dapsettings.apk build/dapsettings-unsigned.apk
mkdir -p build/gen build/classes

"$BT/aapt" package -f -m \
    -J build/gen \
    -M AndroidManifest.xml \
    -S res \
    -A assets \
    -I "$PLATFORM" \
    -F build/app-unaligned.apk

find src build/gen -name '*.java' > build/sources.txt
javac -source 7 -target 7 -bootclasspath "$PLATFORM" \
    -d build/classes @build/sources.txt

"$BT/dx" --dex --output=build/classes.dex build/classes

cp build/app-unaligned.apk build/app-with-dex.apk
( cd build && "$BT/aapt" add app-with-dex.apk classes.dex >/dev/null )

"$BT/zipalign" -f 4 build/app-with-dex.apk build/app-aligned.apk

if [ -n "${DAP_KEYSTORE:-}" ]; then
    [ -f "$DAP_KEYSTORE" ] || die "keystore not found: $DAP_KEYSTORE"
    : "${DAP_KEYSTORE_PASS:?set DAP_KEYSTORE_PASS}"
    DAP_KEY_ALIAS="${DAP_KEY_ALIAS:-dap}"
    DAP_KEY_PASS="${DAP_KEY_PASS:-$DAP_KEYSTORE_PASS}"

    jarsigner -keystore "$DAP_KEYSTORE" \
        -storepass "$DAP_KEYSTORE_PASS" \
        -keypass "$DAP_KEY_PASS" \
        -sigalg SHA256withRSA -digestalg SHA-256 \
        -signedjar build/dapsettings.apk build/app-aligned.apk \
        "$DAP_KEY_ALIAS"

    jarsigner -verify build/dapsettings.apk >/dev/null
    printf 'signed APK: %s\n' "$HERE/build/dapsettings.apk"
else
    cp build/app-aligned.apk build/dapsettings-unsigned.apk
    printf 'unsigned APK: %s\n' "$HERE/build/dapsettings-unsigned.apk"
    printf 'Set DAP_KEYSTORE and DAP_KEYSTORE_PASS to sign it.\n'
fi
