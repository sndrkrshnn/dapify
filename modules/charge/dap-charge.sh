#!/system/bin/sh
# DAPify charge bypass: while external power is connected and the battery is
# full, suspend battery charging so the phone runs from the wall instead of
# cycling at 100%. Resume when the battery reaches the configured standby
# threshold, or whenever the device is unplugged.
#
# The verified kenzo node is the QPNP/SMB battery-side suspend vote:
#   /sys/class/power_supply/battery/battery_charging_enabled
#
# Do not use the sibling `charging_enabled` node: on that device it also
# suspends the USB input path and the phone runs from the battery.
#
# The daemon runs as an init service in the qti_init_shell domain on kenzo.
# That domain has no binder access (no dumpsys) and cannot write
# /data/local/tmp, so every value is read from sysfs and events go to logcat
# and /dev/kmsg. On Magisk the same script is started by service.sh.
#
# Tune live:
#   su -c 'setprop persist.dap.charge.suspend 100'
#   su -c 'setprop persist.dap.charge.resume 90'

PATH=/system/bin:/system/xbin
CONF=${DAP_CONF:-/system/etc/dapify/device.conf}
[ -f "$CONF" ] || CONF=/data/adb/dapify/device.conf
[ -f "$CONF" ] && . "$CONF"

ENABLED=${DAP_CHARGE_NODE:-/sys/class/power_supply/battery/battery_charging_enabled}
BATT_DIR=$(dirname "$ENABLED")
ONLINE_NODES=${DAP_CHARGE_ONLINE_NODES:-usb ac wireless}
SUSPEND_AT=${DAP_CHARGE_SUSPEND:-100}
RESUME_AT=${DAP_CHARGE_RESUME:-90}
INTERVAL=${DAP_CHARGE_INTERVAL:-15}
case "$INTERVAL" in
    ''|*[!0-9]*) INTERVAL=15 ;;
esac
[ "$INTERVAL" -ge 5 ] || INTERVAL=5

dap_log() {
    /system/bin/log -t dap-charge "$*" 2>/dev/null
    echo "dap-charge: $*" > /dev/kmsg 2>/dev/null
}

read_thresholds() {
    suspend_at=$SUSPEND_AT
    resume_at=$RESUME_AT
    s=$(getprop persist.dap.charge.suspend)
    r=$(getprop persist.dap.charge.resume)
    case "$s" in
        ''|*[!0-9]*) ;;
        *) [ "$s" -ge 50 ] && [ "$s" -le 100 ] && suspend_at=$s ;;
    esac
    case "$r" in
        ''|*[!0-9]*) ;;
        *) [ "$r" -ge 10 ] && [ "$r" -lt "$suspend_at" ] && resume_at=$r ;;
    esac
}

is_online() {
    for node in $ONLINE_NODES; do
        if [ "$(cat /sys/class/power_supply/$node/online 2>/dev/null)" = "1" ]; then
            return 0
        fi
    done
    return 1
}

set_enabled() {
    echo "$1" > "$ENABLED" 2>/dev/null
}

if [ ! -e "$ENABLED" ]; then
    dap_log "ERROR charge node not found at $ENABLED; waiting"
    while [ ! -e "$ENABLED" ]; do
        sleep "$INTERVAL"
    done
fi

read_thresholds
dap_log "start suspend_at=$suspend_at resume_at=$resume_at pid=$$"

while true; do
    read_thresholds
    level=$(cat "$BATT_DIR/capacity" 2>/dev/null)
    case "$level" in
        ''|*[!0-9]*)
            sleep "$INTERVAL"
            continue
            ;;
    esac
    current=$(cat "$ENABLED" 2>/dev/null)
    online=0
    is_online && online=1

    if [ "$online" = "1" ] && [ "$level" -ge "$suspend_at" ]; then
        if [ "$current" != "0" ]; then
            if set_enabled 0; then
                warned=
                dap_log "suspend charging at level=$level"
            elif [ "$warned" != "suspend" ]; then
                warned=suspend
                dap_log "ERROR cannot suspend charging at level=$level"
            fi
        fi
    elif [ "$current" = "0" ] &&
        { [ "$online" = "0" ] || [ "$level" -le "$resume_at" ]; }; then
        if set_enabled 1; then
            warned=
            dap_log "resume charging at level=$level online=$online"
        elif [ "$warned" != "resume" ]; then
            warned=resume
            dap_log "ERROR cannot resume charging at level=$level"
        fi
    fi

    sleep "$INTERVAL"
done
