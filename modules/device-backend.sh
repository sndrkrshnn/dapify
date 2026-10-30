#!/system/bin/sh
# DAPify device-side installer. Runs as root through `su`.
#
# Usage (host pushes this file and the module payload to
# /data/local/tmp/dapify, then runs):
#   su -c 'sh /data/local/tmp/dapify/device-backend.sh install'
#   su -c 'sh /data/local/tmp/dapify/device-backend.sh uninstall'
#   su -c 'sh /data/local/tmp/dapify/device-backend.sh status'
#
# It writes only the documented DAPify files, backs up every file it replaces
# under /data/dapify/backup, and records the list in /data/dapify/manifest so
# `uninstall` can restore the device.

set -u

BASE=/data/local/tmp/dapify
CONF=$BASE/device.conf
SYSTEM_DIR=/system/etc/dapify
STATE=/data/dapify
BACKUP=$STATE/backup
MANIFEST=$STATE/manifest
VERSION=${DAPIFY_VERSION:-0.1.0}

[ -f "$CONF" ] || { echo "dapify: missing $CONF" >&2; exit 1; }
. "$CONF"

log() {
    echo "dapify: $*"
    /system/bin/log -t dapify "$*" 2>/dev/null
}

die() {
    log "ERROR $*"
    exit 1
}

remount_rw() {
    mount -o rw,remount /system 2>/dev/null && return 0
    mount -o rw,remount / 2>/dev/null && return 0
    return 1
}

remount_ro() {
    mount -o ro,remount /system 2>/dev/null ||
        mount -o ro,remount / 2>/dev/null || true
}

backup_file() {
    target=$1
    rel=${target#/}
    bfile=$BACKUP/$rel
    [ -e "$bfile" ] && return 0
    mkdir -p "$(dirname "$bfile")" || die "cannot create backup dir for $target"
    if [ -e "$target" ]; then
        cp -p "$target" "$bfile" || die "cannot back up $target"
    fi
}

record_file() {
    grep -qxF "$1" "$MANIFEST" 2>/dev/null || echo "$1" >> "$MANIFEST"
}

install_file() {
    src=$1
    dst=$2
    mode=$3
    [ -f "$src" ] || die "missing payload $src"
    backup_file "$dst"
    mkdir -p "$(dirname "$dst")" || die "cannot create $(dirname "$dst")"
    cp -f "$src" "$dst" || die "cannot copy to $dst"
    chmod "$mode" "$dst" || die "cannot chmod $dst"
    restorecon "$dst" 2>/dev/null || true
    record_file "$dst"
}

render_charge_rc() {
    sed "s|__DAP_INIT_DOMAIN__|$DAP_INIT_DOMAIN|g" \
        "$BASE/dap-charge.rc" > "$BASE/dap-charge.rc.rendered" ||
        die "cannot render dap-charge.rc"
    if [ -z "$DAP_INIT_DOMAIN" ]; then
        grep -v '^[[:space:]]*seclabel' "$BASE/dap-charge.rc.rendered" \
            > "$BASE/dap-charge.rc.rendered.tmp" ||
            die "cannot remove seclabel"
        mv -f "$BASE/dap-charge.rc.rendered.tmp" "$BASE/dap-charge.rc.rendered"
    fi
}

start_charge() {
    if [ "$(getprop init.svc.dap-charge)" = "running" ]; then
        return 0
    fi
    start dap-charge 2>/dev/null || true
    [ "$(getprop init.svc.dap-charge)" = "running" ] && return 0

    # The rc file is parsed at boot, so on a fresh install the service does
    # not exist yet. Start a temporary daemon now; init takes over on reboot.
    if command -v setsid >/dev/null 2>&1; then
        setsid /system/bin/sh "$SYSTEM_DIR/dap-charge.sh" >/dev/null 2>&1 &
    else
        nohup /system/bin/sh "$SYSTEM_DIR/dap-charge.sh" >/dev/null 2>&1 &
    fi
    return 0
}

case "${1:-}" in
    install)
        [ "$(id -u)" = "0" ] || die "must run as root"
        remount_rw || die "cannot remount /system read-write"
        trap 'remount_ro' EXIT

        mkdir -p "$SYSTEM_DIR" "$STATE" "$BACKUP" ||
            die "cannot create state directories"

        install_file "$BASE/device.conf" "$SYSTEM_DIR/device.conf" 644
        install_file "$BASE/dap-haptics.sh" "$SYSTEM_DIR/dap-haptics.sh" 755
        install_file "$BASE/dap-charge.sh" "$SYSTEM_DIR/dap-charge.sh" 755
        install_file "$BASE/dap-haptics.rc" \
            /system/etc/init/dap-haptics.rc 644
        render_charge_rc
        install_file "$BASE/dap-charge.rc.rendered" \
            /system/etc/init/dap-charge.rc 644

        if [ -n "${DAP_KEYLAYOUT_TARGET:-}" ] &&
            [ -f "$BASE/keylayout/$DAP_KEYLAYOUT_TARGET" ]; then
            install_file "$BASE/keylayout/$DAP_KEYLAYOUT_TARGET" \
                "/system/usr/keylayout/$DAP_KEYLAYOUT_TARGET" 644
        else
            log "WARN no keylayout payload for ${DAP_KEYLAYOUT_TARGET:-<unset>}"
        fi

        printf '%s\n' "$VERSION" > "$SYSTEM_DIR/version" ||
            die "cannot write version"
        chmod 644 "$SYSTEM_DIR/version"
        record_file "$SYSTEM_DIR/version"

        # Preserve any value the user has already tuned.
        [ -n "$(getprop persist.dap.haptics.vtg)" ] ||
            setprop persist.dap.haptics.vtg "$DAP_HAPTICS_MV"
        [ -n "$(getprop persist.dap.charge.suspend)" ] ||
            setprop persist.dap.charge.suspend "$DAP_CHARGE_SUSPEND"
        [ -n "$(getprop persist.dap.charge.resume)" ] ||
            setprop persist.dap.charge.resume "$DAP_CHARGE_RESUME"

        remount_ro
        trap - EXIT

        /system/bin/sh "$SYSTEM_DIR/dap-haptics.sh" ||
            log "WARN haptics apply failed"
        start_charge
        setprop dap.haptics.apply 1 2>/dev/null || true
        setprop dap.charge.apply 1 2>/dev/null || true

        log "installed version=$VERSION"
        ;;

    uninstall)
        [ "$(id -u)" = "0" ] || die "must run as root"
        remount_rw || die "cannot remount /system read-write"
        trap 'remount_ro' EXIT

        stop dap-charge 2>/dev/null || true
        pkill -f "$SYSTEM_DIR/dap-charge.sh" 2>/dev/null || true

        if [ -f "$MANIFEST" ]; then
            while IFS= read -r target; do
                [ -n "$target" ] || continue
                rel=${target#/}
                if [ -f "$BACKUP/$rel" ]; then
                    mkdir -p "$(dirname "$target")"
                    cp -p "$BACKUP/$rel" "$target" ||
                        log "WARN cannot restore $target"
                    restorecon "$target" 2>/dev/null || true
                else
                    rm -f "$target"
                fi
            done < "$MANIFEST"
        else
            log "WARN no manifest; removing known DAPify files"
            rm -f /system/etc/init/dap-haptics.rc \
                  /system/etc/init/dap-charge.rc
            rm -rf "$SYSTEM_DIR"
        fi

        rm -rf "$SYSTEM_DIR" "$STATE"
        remount_ro
        trap - EXIT
        log "uninstalled"
        ;;

    status)
        echo "version=$(cat "$SYSTEM_DIR/version" 2>/dev/null || echo unknown)"
        echo "manifest=$MANIFEST"
        [ -f "$MANIFEST" ] && cat "$MANIFEST"
        echo "vtg=$(cat "$DAP_VIBRATOR_DIR/vtg_level" 2>/dev/null || echo n/a)"
        echo "persist_vtg=$(getprop persist.dap.haptics.vtg)"
        echo "charge_service=$(getprop init.svc.dap-charge)"
        echo "charge_node=$(cat "$DAP_CHARGE_NODE" 2>/dev/null || echo n/a)"
        ;;

    *)
        echo "usage: $0 install|uninstall|status" >&2
        exit 2
        ;;
esac
