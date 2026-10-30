#!/bin/sh
#
# Download the prebuilt release APKs (and their checksums) into dist/ so
# `./install.sh install` can install them without a build. This is the
# "no Flutter / no Android SDK" path: you only need ADB + the script.
#
#   ./scripts/fetch-release.sh            # latest release
#   ./scripts/fetch-release.sh 0.1.0      # a specific tag
#
# Requires `curl` and `shasum` (or `sha256sum`). The APKs are pulled from the
# GitHub release of $DAPIFY_REPO.

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
DIST="$ROOT/dist"
REPO="${DAPIFY_REPO:-sndrkrshnn/dapify}"
TAG="${1:-}"

mkdir -p "$DIST"

info() { printf 'fetch: %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

have curl || { echo "curl not found; install it or build the apps yourself" >&2; exit 1; }

# Resolve the tag (default = latest release).
if [ -n "$TAG" ]; then
    info "using tag $TAG"
else
    if have gh; then
        TAG=$(gh api "repos/$REPO/releases/latest" --jq '.tag_name' 2>/dev/null || true)
    fi
    [ -n "$TAG" ] || TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
    [ -n "$TAG" ] || { echo "could not determine the latest release of $REPO" >&2; exit 1; }
    info "latest release: $TAG"
fi

# List the assets we want, then download each by name.
assets=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/tags/$TAG" \
    | sed -n 's/.*"name": *"\([^"]*\).*/\1/p')

downloaded=0
for name in $assets; do
    case "$name" in
        classipod.apk|dapsettings.apk|SHA256SUMS)
            url="https://github.com/$REPO/releases/download/$TAG/$name"
            info "downloading $name"
            curl -fsSL "$url" -o "$DIST/$name" || { echo "failed to fetch $name" >&2; exit 1; }
            downloaded=$((downloaded + 1))
            ;;
    esac
done

[ "$downloaded" -gt 0 ] || { echo "release $TAG has no DAPify assets (classipod.apk / dapsettings.apk)" >&2; exit 1; }

# Verify checksums if SHA256SUMS was downloaded.
if [ -f "$DIST/SHA256SUMS" ]; then
    ( cd "$DIST" &&
      if have shasum; then shasum -a 256 -c SHA256SUMS;
      else sha256sum -c SHA256SUMS; fi ) || {
        echo "checksum mismatch — do not use these APKs" >&2
        exit 1
    }
    info "checksums verified"
else
    echo "warn: no SHA256SUMS in the release; skipping verification" >&2
fi

info "ready in $DIST:"
( cd "$DIST" && ls -lh classipod.apk dapsettings.apk 2>/dev/null || true )
info "now run: ./install.sh install --device <codename>"
