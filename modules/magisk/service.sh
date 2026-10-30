#!/system/bin/sh
# DAPify Magisk late-start service.
#
# Magisk mounts this module's system/ overlay before late_start, so the
# normal /system/etc/dapify paths work. The /data/adb/dapify fallback keeps
# the scripts usable before the overlay is mounted (and for manual testing).

MODDIR=${0%/*}
DAP=/system/etc/dapify
[ -f "$DAP/device.conf" ] || DAP=/data/adb/dapify
export DAP_CONF="$DAP/device.conf"

log() {
    /system/bin/log -t dapify "$*" 2>/dev/null
    echo "dapify: $*" >> /data/adb/dapify/service.log 2>/dev/null
}

mkdir -p /data/adb/dapify 2>/dev/null

# Wait until the framework is ready; writing the vibrator node earlier is
# harmless but the boot-completed trigger keeps the timing predictable.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 120 ]; do
    sleep 2
    i=$((i + 1))
done

if [ -f "$DAP/dap-haptics.sh" ]; then
    /system/bin/sh "$DAP/dap-haptics.sh" || log "haptics apply failed"
fi

charge_running() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f 'dap-charge.sh' >/dev/null 2>&1 && return 0
    fi
    ps 2>/dev/null | grep -q '[d]ap-charge.sh' && return 0
    ps -A 2>/dev/null | grep -q '[d]ap-charge.sh' && return 0
    return 1
}

if [ -f "$DAP/dap-charge.sh" ] && ! charge_running; then
    # Keep a supervisor so the daemon is restarted if it ever dies. Magisk
    # does not supervise service.sh children itself.
    if command -v setsid >/dev/null 2>&1; then
        setsid /system/bin/sh -c \
            "while true; do /system/bin/sh '$DAP/dap-charge.sh'; sleep 10; done" \
            >/dev/null 2>&1 &
    else
        nohup /system/bin/sh -c \
            "while true; do /system/bin/sh '$DAP/dap-charge.sh'; sleep 10; done" \
            >/dev/null 2>&1 &
    fi
    log "charge daemon started"
fi
