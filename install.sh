#!/bin/sh
#
# DAPify installer.
#
# Usage:
#   ./install.sh install  [--device kenzo] [--modules all|list] [--apk-dir DIR]
#                         [--no-apps] [--yes] [--dry-run]
#   ./install.sh uninstall [--device kenzo] [--remove-apps] [--yes]
#   ./install.sh doctor   [--device kenzo]
#   ./install.sh list
#   ./install.sh help
#
# `install` applies the device profile: keylayout, haptics voltage, charge
# bypass, SystemUI removal and the ClassiPod/DAP Settings home stack.
#
# It is idempotent: safe to re-run, and it records the original home /
# SystemUI state so `uninstall` can restore it.

set -u

DAPIFY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$DAPIFY_ROOT/lib/common.sh"
# shellcheck source=lib/backend.sh
. "$DAPIFY_ROOT/lib/backend.sh"
# shellcheck source=lib/doctor.sh
. "$DAPIFY_ROOT/lib/doctor.sh"

DAP_DEVICE=""
MODULES="all"
APK_DIR="$DAPIFY_ROOT/dist"
NO_APPS=0
REMOVE_APPS=0

usage() {
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

cmd_install() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --device) DAP_DEVICE=${2:?}; shift 2 ;;
            --modules) MODULES=${2:?}; shift 2 ;;
            --apk-dir) APK_DIR=${2:?}; shift 2 ;;
            --no-apps) NO_APPS=1; shift ;;
            --yes) DAP_YES=1; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            *) die "install: unknown option $1 (see ./install.sh help)" ;;
        esac
    done
    if [ "$NO_APPS" = "1" ]; then
        case ",$MODULES," in *,home,*) MODULES=$(printf '%s\n' "$MODULES" | tr ',' '\n' | grep -v '^home$' | paste -sd, -) ;; esac
    fi
    do_install
}

cmd_uninstall() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --device) DAP_DEVICE=${2:?}; shift 2 ;;
            --remove-apps) REMOVE_APPS=1; shift ;;
            --yes) DAP_YES=1; shift ;;
            *) die "uninstall: unknown option $1 (see ./install.sh help)" ;;
        esac
    done
    do_uninstall
}

cmd_doctor() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --device) DAP_DEVICE=${2:?}; shift 2 ;;
            *) die "doctor: unknown option $1" ;;
        esac
    done
    do_doctor
}

cmd_list() {
    say "Available device profiles:"
    list_devices
    say
    say "Add a new profile by copying devices/_template to devices/<codename>."
    say "See docs/porting.md."
}

main() {
    [ $# -ge 1 ] || { usage; exit 1; }
    cmd=$1
    shift
    case "$cmd" in
        install) cmd_install "$@" ;;
        uninstall) cmd_uninstall "$@" ;;
        doctor) cmd_doctor "$@" ;;
        list) cmd_list "$@" ;;
        help|-h|--help) usage ;;
        *) usage; die "unknown command: $cmd" ;;
    esac
}

main "$@"
