#!/bin/sh
#
# Build both apps into dist/ and (optionally) create a GitHub release with the
# APKs attached.
#
#   ./scripts/release.sh            # build into dist/ only
#   ./scripts/release.sh 0.1.0      # build, tag, and create a GitHub release
#
# The player build needs the Flutter toolchain and an Android SDK; the settings
# build needs the API 25 SDK. Set DAP_KEYSTORE / DAP_KEYSTORE_PASS (and the
# player's android/key.properties) before building. See docs/building.md.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
DIST="$ROOT/dist"
VERSION="${1:-}"

[ -d "$DIST" ] || mkdir -p "$DIST"

info() { printf 'release: %s\n' "$*"; }

# --- player -----------------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
    info "building player (flutter)"
    ( cd "$ROOT/apps/classipod" && flutter pub get &&
      flutter build apk --release --flavor production --target-platform android-arm64 )
    cp "$ROOT/apps/classipod/build/app/outputs/flutter-apk/app-production-release.apk" \
        "$DIST/classipod.apk"
else
    [ -f "$DIST/classipod.apk" ] ||
        echo "flutter not found and no dist/classipod.apk; skipping player build" >&2
fi

# --- settings ----------------------------------------------------------------
if [ -n "${DAP_KEYSTORE:-}" ] || command -v java >/dev/null 2>&1; then
    info "building settings (api 25)"
    ( cd "$ROOT/apps/dapsettings" && ./build.sh )
    if [ -f "$ROOT/apps/dapsettings/build/dapsettings.apk" ]; then
        cp "$ROOT/apps/dapsettings/build/dapsettings.apk" "$DIST/dapsettings.apk"
    fi
fi

# --- checksums ----------------------------------------------------------------
( cd "$DIST" &&
  for apk in classipod.apk dapsettings.apk; do
      [ -f "$apk" ] || continue
      if command -v shasum >/dev/null 2>&1; then
          printf '%s  %s\n' "$(shasum -a 256 "$apk" | awk '{print $1}')" "$apk"
      else
          printf '%s  %s\n' "$(sha256sum "$apk" | awk '{print $1}')" "$apk"
      fi
  done > SHA256SUMS )

info "dist contents:"
( cd "$DIST" && ls -lh classipod.apk dapsettings.apk 2>/dev/null || true )
[ -f "$DIST/SHA256SUMS" ] && cat "$DIST/SHA256SUMS"

# --- release ------------------------------------------------------------------
if [ -n "$VERSION" ]; then
    command -v gh >/dev/null 2>&1 || { echo "gh not found; skipping release" >&2; exit 0; }
    info "creating GitHub release $VERSION"
    gh release create "$VERSION" \
        --title "DAPify $VERSION" \
        --notes "APKs for the verified kenzo build. Verify SHA-256 with SHA256SUMS." \
        "$DIST/classipod.apk" "$DIST/dapsettings.apk" "$DIST/SHA256SUMS"
    info "release $VERSION created"
else
    info "no version given; skipping GitHub release (pass a version to create one)"
fi
