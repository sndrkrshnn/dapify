# DAPify shared shell helpers. POSIX sh; sourced by install.sh.

DAPIFY_VERSION="${DAPIFY_VERSION:-0.1.0}"
DAPIFY_REPO="${DAPIFY_REPO:-sndrkrshnn/dapify}"
ADB="${ADB:-adb}"
DAP_YES="${DAP_YES:-0}"
DRY_RUN="${DRY_RUN:-0}"

if [ -t 1 ]; then
    C_RESET=$(printf '\033[0m')
    C_BOLD=$(printf '\033[1m')
    C_DIM=$(printf '\033[2m')
    C_RED=$(printf '\033[31m')
    C_GREEN=$(printf '\033[32m')
    C_YELLOW=$(printf '\033[33m')
    C_BLUE=$(printf '\033[34m')
else
    C_RESET= C_BOLD= C_DIM= C_RED= C_GREEN= C_YELLOW= C_BLUE=
fi

say() { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s ok %s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err() { printf '%serr %s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die() { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

confirm() {
    [ "$DAP_YES" = "1" ] && return 0
    printf '%s [y/N] ' "$1"
    IFS= read -r answer || return 1
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

is_uint() {
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

md5_of() {
    # md5 of a file; works with `md5` (macOS/BSD) and `md5sum` (GNU).
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$1" 2>/dev/null
    else
        md5sum "$1" 2>/dev/null | awk '{print $1}'
    fi
}

md5_of_stdin() {
    if command -v md5 >/dev/null 2>&1; then
        md5 -q 2>/dev/null
    else
        md5sum 2>/dev/null | awk '{print $1}'
    fi
}

adb_do() {
    if [ -n "${ADB_SERIAL:-}" ]; then
        "$ADB" -s "$ADB_SERIAL" "$@"
    else
        "$ADB" "$@"
    fi
}

adb_shell() {
    adb_do shell "$@" | tr -d '\r'
}

adb_root() {
    # Callers pass a simple command line without embedded single quotes.
    adb_shell "${SU_CMD:-su} -c '$*'"
}

adb_root_script() {
    # Run a multi-line root script without host/device quoting games. The
    # staging directory must already exist.
    _script=$(mktemp "${TMPDIR:-/tmp}/dapify-root.XXXXXX") ||
        die "cannot create temporary script"
    printf '%s\n' "$1" > "$_script"
    adb_do push "$_script" /data/local/tmp/dapify/root.sh >/dev/null ||
        { rm -f "$_script"; die "cannot push root script"; }
    rm -f "$_script"
    adb_do shell "${SU_CMD:-su} -c 'sh /data/local/tmp/dapify/root.sh'"
}

adb_root_cat() {
    # Read a single file as root. `su -c` alone mangles paths (it can treat a
    # leading slash as an option and the path as an `id` argument), so wrap
    # the read in `sh -c`.
    adb_do shell "${SU_CMD:-su} -c 'sh -c \"cat $1\"'" 2>/dev/null | tr -d '\r'
}

require_adb() {
    have "$ADB" || die "adb not found; install Android platform-tools"
    adb_do get-state >/dev/null 2>&1 ||
        die "no adb device; connect the phone with USB debugging enabled"
    if [ -z "${ADB_SERIAL:-}" ]; then
        ADB_SERIAL=$(adb_do get-serialno | tr -d '\r')
    fi
    [ -n "$ADB_SERIAL" ] || die "could not determine adb serial"
    ok "adb device $ADB_SERIAL"
}

detect_su() {
    for candidate in su /system/xbin/su /system/bin/su; do
        if adb_shell "$candidate -c id" 2>/dev/null | grep -q 'uid=0'; then
            SU_CMD=$candidate
            ok "root via $SU_CMD"
            return 0
        fi
    done
    return 1
}

require_root() {
    detect_su || die "root not available; install CM root, LineageOS su, or Magisk"
}

device_prop() {
    adb_shell getprop "$1" 2>/dev/null
}

device_codename() {
    device_prop ro.product.device
}

device_sdk() {
    device_prop ro.build.version.sdk
}

device_android() {
    device_prop ro.build.version.release
}

detect_backend() {
    case "${DAP_ROOT_BACKEND:-auto}" in
        system|magisk)
            printf '%s\n' "$DAP_ROOT_BACKEND"
            return 0
            ;;
    esac
    # Probe as root: /data/adb is often not visible to a non-root adb shell, so
    # a plain `test -d` would wrongly report "system". Use the detected su.
    if adb_root "test -d /data/adb/magisk && echo magisk" 2>/dev/null | grep -q magisk; then
        printf 'magisk\n'
    else
        printf 'system\n'
    fi
}

profile_dir() {
    printf '%s/devices/%s\n' "$DAPIFY_ROOT" "${1:-$DAP_DEVICE_CODENAME}"
}

load_device() {
    wanted=${1:-${DAP_DEVICE:-}}
    [ -n "$wanted" ] || wanted=$(device_codename)
    [ -n "$wanted" ] || die "cannot detect device codename; use --device <codename>"

    DAP_PROFILE_DIR="$DAPIFY_ROOT/devices/$wanted"
    [ -f "$DAP_PROFILE_DIR/device.conf" ] ||
        die "no profile for '$wanted'; see docs/porting.md and devices/_template"

    # shellcheck disable=SC1090
    . "$DAP_PROFILE_DIR/device.conf"
    DAP_DEVICE_CODENAME=${DAP_DEVICE_CODENAME:-$wanted}

    : "${DAP_PLAYER_PACKAGE:?profile missing DAP_PLAYER_PACKAGE}"
    : "${DAP_PLAYER_ACTIVITY:?profile missing DAP_PLAYER_ACTIVITY}"
    : "${DAP_SETTINGS_PACKAGE:?profile missing DAP_SETTINGS_PACKAGE}"
    : "${DAP_SETTINGS_ACTIVITY:?profile missing DAP_SETTINGS_ACTIVITY}"
    : "${DAP_SYSTEMUI_PACKAGE:?profile missing DAP_SYSTEMUI_PACKAGE}"

    DAP_HAPTICS_MV=${DAP_HAPTICS_MV:-2800}
    DAP_HAPTICS_MIN_MV=${DAP_HAPTICS_MIN_MV:-800}
    DAP_HAPTICS_MAX_MV=${DAP_HAPTICS_MAX_MV:-3600}
    DAP_CHARGE_NODE=${DAP_CHARGE_NODE:-/sys/class/power_supply/battery/battery_charging_enabled}
    DAP_CHARGE_ONLINE_NODES=${DAP_CHARGE_ONLINE_NODES:-usb ac wireless}
    DAP_CHARGE_SUSPEND=${DAP_CHARGE_SUSPEND:-100}
    DAP_CHARGE_RESUME=${DAP_CHARGE_RESUME:-90}
    DAP_CHARGE_INTERVAL=${DAP_CHARGE_INTERVAL:-15}
    DAP_INIT_DOMAIN=${DAP_INIT_DOMAIN:-}
    DAP_VIBRATOR_DIR=${DAP_VIBRATOR_DIR:-/sys/devices/virtual/timed_output/vibrator}
    DAP_KEYLAYOUT_TARGET=${DAP_KEYLAYOUT_TARGET:-}
    DAP_KEYLAYOUT_SOURCE=${DAP_KEYLAYOUT_SOURCE:-}
    DAP_AUDIO_SOURCE=${DAP_AUDIO_SOURCE:-}
    DAP_AUDIO_TARGET=${DAP_AUDIO_TARGET:-/system/etc/audio_policy_configuration.xml}
    DAP_ROOT_BACKEND=${DAP_ROOT_BACKEND:-auto}
}

list_devices() {
    for conf in "$DAPIFY_ROOT"/devices/*/device.conf; do
        [ -f "$conf" ] || continue
        (
            # shellcheck disable=SC1090
            . "$conf"
            case "${DAP_DEVICE_CODENAME:-}" in
                ''|CHANGEME) exit 0 ;;
            esac
            printf '%-14s %s\n' "${DAP_DEVICE_CODENAME:-?}" "${DAP_DEVICE_NAME:-?}"
        )
    done
}

state_dir() {
    printf '%s/dist/state\n' "$DAPIFY_ROOT"
}

state_file() {
    printf '%s/%s.env\n' "$(state_dir)" "${ADB_SERIAL:-unknown}"
}

save_state() {
    mkdir -p "$(state_dir)"
    {
        printf 'ORIGINAL_HOME=%s\n' "${ORIGINAL_HOME:-}"
        printf 'SYSTEMUI_WAS_DISABLED=%s\n' "${SYSTEMUI_WAS_DISABLED:-0}"
        printf 'LOCKSCREEN_WAS_DISABLED=%s\n' "${LOCKSCREEN_WAS_DISABLED:-0}"
        printf 'DAP_BACKEND=%s\n' "${DAP_BACKEND:-}"
        printf 'DAP_DEVICE_CODENAME=%s\n' "${DAP_DEVICE_CODENAME:-}"
    } > "$(state_file)"
}

load_state() {
    [ -f "$(state_file)" ] || return 1
    # shellcheck disable=SC1090
    . "$(state_file)"
    return 0
}

require_dry_run_ok() {
    [ "$DRY_RUN" = "1" ] || return 0
    say "${C_DIM}[dry-run]${C_RESET} $*"
}
